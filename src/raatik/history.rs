use serde::{Deserialize, Serialize};
use std::{
    sync::{
        atomic::{AtomicBool, AtomicI64, AtomicU64, AtomicUsize, Ordering},
        Arc, Condvar, Mutex, Weak,
    },
    time::{Instant, SystemTime, UNIX_EPOCH},
};
use uuid::Uuid;

pub(crate) const MAX_RECORD_BYTES: usize = 32_768;
pub(crate) const MAX_NOTE_SCALARS: usize = 2_000;
const MAX_PEER_ID_SCALARS: usize = 1_024;
const MAX_PEER_NAME_SCALARS: usize = 512;
const MAX_SEARCH_SCALARS: usize = 256;
const MAX_PAGE_LIMIT: u32 = 100;

const CONNECTION_TYPES: [&str; 6] = [
    "desktop",
    "file_transfer",
    "port_forward",
    "rdp",
    "camera",
    "terminal",
];

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HistoryRecord {
    pub schema: u32,
    pub record_id: String,
    pub connection_type: String,
    pub peer_id: String,
    pub peer_name: String,
    pub started_at_utc_ms: i64,
    pub ended_at_utc_ms: Option<i64>,
    pub elapsed_ms: u64,
    pub checkpoint_at_utc_ms: i64,
    pub status: String,
    pub owner_pid: u32,
    pub owner_started_at: u64,
    pub note: String,
    pub note_revision: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HistoryQuery {
    pub search: String,
    pub from_utc_ms: Option<i64>,
    pub to_utc_ms: Option<i64>,
    pub offset: u32,
    pub limit: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HistoryPage {
    pub records: Vec<HistoryRecord>,
    pub total: u64,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HistoryError {
    Io,
    Busy,
    InvalidInput,
    NotFound,
    NoteConflict,
    FutureSchema,
}

impl std::fmt::Display for HistoryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            HistoryError::Io => "history io failure",
            HistoryError::Busy => "history is busy",
            HistoryError::InvalidInput => "history input is invalid",
            HistoryError::NotFound => "history record was not found",
            HistoryError::NoteConflict => "history note conflict",
            HistoryError::FutureSchema => "history schema is newer",
        })
    }
}

impl std::error::Error for HistoryError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OwnerState {
    Alive,
    Dead,
    Unknown,
}

pub trait OwnerProbe {
    fn state(&self, pid: u32, started_at: u64) -> OwnerState;
}

#[derive(Debug)]
pub(crate) enum Decoded {
    Record(HistoryRecord),
    FutureSchema,
    Unreadable,
}

pub(crate) fn canonical_record_id(id: &str) -> Result<String, HistoryError> {
    let uuid = Uuid::parse_str(id).map_err(|_| HistoryError::InvalidInput)?;
    if uuid.get_version() != Some(uuid::Version::Random)
        || uuid.get_variant() != uuid::Variant::RFC4122
    {
        return Err(HistoryError::InvalidInput);
    }
    let canonical = uuid.hyphenated().to_string();
    if canonical != id {
        return Err(HistoryError::InvalidInput);
    }
    Ok(canonical)
}

pub(crate) fn normalize_note(note: &str) -> Result<String, HistoryError> {
    let mut out = String::with_capacity(note.len());
    let mut chars = note.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\r' {
            if chars.peek() == Some(&'\n') {
                chars.next();
            }
            out.push('\n');
            continue;
        }
        if c.is_control() && c != '\n' && c != '\t' {
            return Err(HistoryError::InvalidInput);
        }
        out.push(c);
    }
    if out.chars().count() > MAX_NOTE_SCALARS {
        return Err(HistoryError::InvalidInput);
    }
    if out.chars().all(|c| c.is_whitespace()) {
        return Ok(String::new());
    }
    Ok(out)
}

pub(crate) fn validate_record(record: &HistoryRecord) -> Result<(), HistoryError> {
    if record.schema != 1 {
        return Err(if record.schema > 1 {
            HistoryError::FutureSchema
        } else {
            HistoryError::InvalidInput
        });
    }
    canonical_record_id(&record.record_id)?;
    if !CONNECTION_TYPES.contains(&record.connection_type.as_str()) {
        return Err(HistoryError::InvalidInput);
    }
    let peer_id_len = record.peer_id.chars().count();
    if peer_id_len == 0 || peer_id_len > MAX_PEER_ID_SCALARS {
        return Err(HistoryError::InvalidInput);
    }
    if record.peer_name.chars().count() > MAX_PEER_NAME_SCALARS {
        return Err(HistoryError::InvalidInput);
    }
    match record.status.as_str() {
        "active" | "interrupted" => {
            if record.ended_at_utc_ms.is_some() {
                return Err(HistoryError::InvalidInput);
            }
        }
        "completed" => {
            if record.ended_at_utc_ms.is_none() {
                return Err(HistoryError::InvalidInput);
            }
            // ended_at_utc_ms < started_at_utc_ms is a wall-clock rollback, not a corrupt record.
        }
        _ => return Err(HistoryError::InvalidInput),
    }
    match normalize_note(&record.note) {
        Ok(normalized) if normalized == record.note => Ok(()),
        _ => Err(HistoryError::InvalidInput),
    }
}

pub(crate) fn validate_query(query: &HistoryQuery) -> Result<(), HistoryError> {
    if query.limit == 0 || query.limit > MAX_PAGE_LIMIT {
        return Err(HistoryError::InvalidInput);
    }
    if query.search.chars().count() > MAX_SEARCH_SCALARS {
        return Err(HistoryError::InvalidInput);
    }
    if let (Some(from), Some(to)) = (query.from_utc_ms, query.to_utc_ms) {
        if from >= to {
            return Err(HistoryError::InvalidInput);
        }
    }
    Ok(())
}

pub(crate) fn started_in_window(record: &HistoryRecord, query: &HistoryQuery) -> bool {
    if let Some(from) = query.from_utc_ms {
        if record.started_at_utc_ms < from {
            return false;
        }
    }
    if let Some(to) = query.to_utc_ms {
        if record.started_at_utc_ms >= to {
            return false;
        }
    }
    true
}

pub(crate) fn matches_search(record: &HistoryRecord, search: &str) -> bool {
    let query = normalize_search_text(search, true);
    if query.is_empty() {
        return true;
    }
    let name = normalize_search_text(&record.peer_name, false);
    if name.contains(&query) {
        return true;
    }
    let peer_id = normalize_search_text(&record.peer_id, false);
    if peer_id.contains(&query) {
        return true;
    }
    match (compact_numeric_id(&query), compact_numeric_id(&peer_id)) {
        (Some(query_digits), Some(id_digits)) if id_digits.contains(&query_digits) => true,
        _ => false,
    }
}

pub(crate) fn decode_stored(bytes: &[u8]) -> Decoded {
    if bytes.len() > MAX_RECORD_BYTES || std::str::from_utf8(bytes).is_err() {
        return Decoded::Unreadable;
    }
    let value: serde_json::Value = match serde_json::from_slice(bytes) {
        Ok(value) => value,
        Err(_) => return Decoded::Unreadable,
    };
    let Some(schema) = value.get("schema").and_then(serde_json::Value::as_u64) else {
        return Decoded::Unreadable;
    };
    if schema > 1 {
        return Decoded::FutureSchema;
    }
    if schema != 1 {
        return Decoded::Unreadable;
    }
    let record: HistoryRecord = match serde_json::from_value(value) {
        Ok(record) => record,
        Err(_) => return Decoded::Unreadable,
    };
    if validate_record(&record).is_err() {
        return Decoded::Unreadable;
    }
    Decoded::Record(record)
}

pub(crate) fn encode_record(record: &HistoryRecord) -> Result<Vec<u8>, HistoryError> {
    validate_record(record)?;
    let mut bytes = serde_json::to_vec_pretty(record).map_err(|_| HistoryError::Io)?;
    bytes.push(b'\n');
    if bytes.len() > MAX_RECORD_BYTES {
        return Err(HistoryError::InvalidInput);
    }
    Ok(bytes)
}

fn normalize_search_text(value: &str, trim: bool) -> String {
    let value = if trim { value.trim() } else { value };
    let mut out = String::with_capacity(value.len());
    for c in value.chars() {
        for lower in fold_search_char(c).to_lowercase() {
            out.push(lower);
        }
    }
    out
}

fn fold_search_char(c: char) -> char {
    match c {
        '\u{06F0}'..='\u{06F9}' => {
            char::from_u32(u32::from('0') + (u32::from(c) - u32::from('\u{06F0}'))).unwrap_or(c)
        }
        '\u{0660}'..='\u{0669}' => {
            char::from_u32(u32::from('0') + (u32::from(c) - u32::from('\u{0660}'))).unwrap_or(c)
        }
        '\u{064A}' | '\u{0649}' => '\u{06CC}',
        '\u{0643}' => '\u{06A9}',
        other => other,
    }
}

fn compact_numeric_id(value: &str) -> Option<String> {
    if value.is_empty() || !value.chars().all(|c| c.is_ascii_digit() || c == ' ') {
        return None;
    }
    if !value.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }
    Some(value.chars().filter(|c| *c != ' ').collect())
}

pub const HISTORY_SAVE_WARNING_TEXT: &str =
    "ثبت تاریخچه روی این رایانه انجام نشد؛ اتصال برقرار است.";
pub const HISTORY_SAVE_WARNING_ACTION: &str = "تلاش دوباره";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HistorySaveWarning {
    pub text: String,
    pub action: String,
    pub record_id: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OwnerIdentity {
    pub pid: u32,
    pub started_at: u64,
}

static SAVE_WARNING: Mutex<Option<HistorySaveWarning>> = Mutex::new(None);
static LIVE_INTERVALS: Mutex<Vec<Weak<IntervalInner>>> = Mutex::new(Vec::new());

pub fn history_save_warning() -> Option<HistorySaveWarning> {
    SAVE_WARNING
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .clone()
}

pub fn clear_history_save_warning() {
    *SAVE_WARNING.lock().unwrap_or_else(|err| err.into_inner()) = None;
}

pub fn retry_history_save() -> Result<(), HistoryError> {
    let record_id = {
        let guard = SAVE_WARNING.lock().unwrap_or_else(|err| err.into_inner());
        match guard.as_ref() {
            Some(warning) if !warning.record_id.is_empty() => warning.record_id.clone(),
            Some(_) => return Err(HistoryError::InvalidInput),
            None => return Ok(()),
        }
    };
    let inner = {
        let mut live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
        live.retain(|weak| weak.strong_count() > 0);
        live.iter().find_map(|weak| {
            let inner = weak.upgrade()?;
            (inner.record_id == record_id).then_some(inner)
        })
    };
    match inner {
        Some(inner) => inner.checkpoint(),
        None => Err(HistoryError::NotFound),
    }
}

/// First authenticated PeerInfo of an empty slot starts one interval.
/// A duplicate round does not create another record. A different round does not finish the stored one.
pub(crate) fn admit_peer_info(
    slot: &mut Option<(u32, HistoryInterval)>,
    round: u32,
    create: impl FnOnce() -> Result<HistoryInterval, HistoryError>,
) -> Result<(), HistoryError> {
    if slot.is_some() {
        let _ = round;
        return Ok(());
    }
    *slot = Some((round, create()?));
    Ok(())
}

/// Finish only the interval that belongs to `round`.
pub(crate) fn finish_round(
    slot: &mut Option<(u32, HistoryInterval)>,
    round: u32,
) -> Result<(), HistoryError> {
    let Some((stored, _)) = slot.as_ref() else {
        return Ok(());
    };
    if *stored != round {
        return Ok(());
    }
    let (_, interval) = slot.take().expect("history interval present");
    interval.finish()
}

pub(crate) fn note_login_failure(slot: &Option<(u32, HistoryInterval)>) {
    let _ = slot;
}

pub(crate) fn note_approval_canceled(slot: &Option<(u32, HistoryInterval)>) {
    let _ = slot;
}

pub(crate) fn snapshot_peer_name(alias: &str, hostname: &str, peer_id: &str) -> String {
    let chosen = if !alias.is_empty() {
        alias
    } else if !hostname.is_empty() {
        hostname
    } else {
        peer_id
    };
    truncate_scalars(chosen, MAX_PEER_NAME_SCALARS)
}

#[cfg(all(windows, not(raatik_history_harness)))]
pub(crate) fn begin_current_interval(
    peer_id: String,
    peer_name: String,
    connection_type: String,
) -> Result<Option<HistoryInterval>, HistoryError> {
    if crate::platform::is_root() {
        return Ok(None);
    }
    let pid = std::process::id();
    let Some(started_at) = super::history_store::process_creation_filetime(pid) else {
        report_failure("", HistoryError::Io);
        return Ok(None);
    };
    let store = interactive_store()?;
    HistoryInterval::start(
        store,
        peer_id,
        peer_name,
        connection_type,
        OwnerIdentity { pid, started_at },
    )
    .map(Some)
}

#[cfg(all(windows, not(raatik_history_harness)))]
fn interactive_store() -> Result<Arc<super::history_store::HistoryStore>, HistoryError> {
    use std::sync::OnceLock;
    static SLOT: OnceLock<Arc<super::history_store::HistoryStore>> = OnceLock::new();
    if let Some(store) = SLOT.get() {
        return Ok(store.clone());
    }
    let path = hbb_common::config::Config::path("history/v1");
    if path.as_os_str().is_empty() {
        return Err(HistoryError::Io);
    }
    match SLOT.get_or_try_init(|| super::history_store::HistoryStore::open(path).map(Arc::new)) {
        Ok(store) => Ok(store.clone()),
        Err(err) => Err(err),
    }
}

#[derive(Clone)]
pub struct HistoryInterval {
    inner: Arc<IntervalInner>,
}

enum TimeBase {
    System {
        started: Instant,
    },
    Manual {
        origin: u64,
        mono: Arc<AtomicU64>,
        wall: Arc<AtomicI64>,
    },
}

struct IntervalInner {
    store: Arc<super::history_store::HistoryStore>,
    record_id: String,
    peer_id: String,
    peer_name: String,
    connection_type: String,
    owner: OwnerIdentity,
    started_at_utc_ms: i64,
    time: TimeBase,
    inserted: AtomicBool,
    finished: AtomicBool,
    pending: AtomicUsize,
    pending_lock: Mutex<()>,
    pending_cv: Condvar,
    op: Mutex<()>,
}

impl HistoryInterval {
    pub fn start(
        store: Arc<super::history_store::HistoryStore>,
        peer_id: String,
        peer_name: String,
        connection_type: String,
        owner: OwnerIdentity,
    ) -> Result<Self, HistoryError> {
        Self::open(
            store,
            peer_id,
            peer_name,
            connection_type,
            owner,
            TimeBase::System {
                started: Instant::now(),
            },
        )
    }

    #[cfg(test)]
    pub fn start_with_clock(
        store: Arc<super::history_store::HistoryStore>,
        peer_id: String,
        peer_name: String,
        connection_type: String,
        owner: OwnerIdentity,
        wall_ms: Arc<AtomicI64>,
        monotonic_ms: Arc<AtomicU64>,
    ) -> Result<Self, HistoryError> {
        let origin = monotonic_ms.load(Ordering::SeqCst);
        Self::open(
            store,
            peer_id,
            peer_name,
            connection_type,
            owner,
            TimeBase::Manual {
                origin,
                mono: monotonic_ms,
                wall: wall_ms,
            },
        )
    }

    pub fn record_id(&self) -> &str {
        &self.inner.record_id
    }

    pub fn checkpoint(&self) -> Result<(), HistoryError> {
        self.inner.checkpoint()
    }

    pub fn finish(&self) -> Result<(), HistoryError> {
        self.inner.finish()
    }

    fn open(
        store: Arc<super::history_store::HistoryStore>,
        peer_id: String,
        peer_name: String,
        connection_type: String,
        owner: OwnerIdentity,
        time: TimeBase,
    ) -> Result<Self, HistoryError> {
        if let Err(err) = validate_peer_id(&peer_id) {
            report_failure("", err);
            return Err(err);
        }
        if !CONNECTION_TYPES.contains(&connection_type.as_str()) {
            report_failure("", HistoryError::InvalidInput);
            return Err(HistoryError::InvalidInput);
        }
        if owner.started_at == 0 {
            report_failure("", HistoryError::Io);
            return Err(HistoryError::Io);
        }
        let peer_name = if peer_name.is_empty() {
            truncate_scalars(&peer_id, MAX_PEER_NAME_SCALARS)
        } else {
            truncate_scalars(&peer_name, MAX_PEER_NAME_SCALARS)
        };
        let started_at_utc_ms = wall_from_base(&time);
        let inner = Arc::new(IntervalInner {
            store,
            record_id: Uuid::new_v4().hyphenated().to_string(),
            peer_id,
            peer_name,
            connection_type,
            owner,
            started_at_utc_ms,
            time,
            inserted: AtomicBool::new(false),
            finished: AtomicBool::new(false),
            pending: AtomicUsize::new(0),
            pending_lock: Mutex::new(()),
            pending_cv: Condvar::new(),
            op: Mutex::new(()),
        });
        register_live(&inner);
        let interval = Self { inner };
        let inserted = {
            let _op = interval
                .inner
                .op
                .lock()
                .unwrap_or_else(|err| err.into_inner());
            interval
                .inner
                .ensure_inserted(interval.inner.elapsed_ms(), interval.inner.wall_now())
        };
        if let Err(err) = inserted {
            report_failure(&interval.inner.record_id, err);
            if matches!(err, HistoryError::Io | HistoryError::Busy) {
                return Ok(interval);
            }
            return Err(err);
        }
        Ok(interval)
    }
}

impl IntervalInner {
    fn checkpoint(&self) -> Result<(), HistoryError> {
        self.pending.fetch_add(1, Ordering::SeqCst);
        let _pending = PendingCheckpoint(self);
        self.checkpoint_body()
    }

    fn finish(&self) -> Result<(), HistoryError> {
        let mut guard = self
            .pending_lock
            .lock()
            .unwrap_or_else(|err| err.into_inner());
        while self.pending.load(Ordering::SeqCst) > 0 {
            guard = self
                .pending_cv
                .wait(guard)
                .unwrap_or_else(|err| err.into_inner());
        }
        drop(guard);
        self.finish_body()
    }

    fn checkpoint_body(&self) -> Result<(), HistoryError> {
        let _op = self.op.lock().unwrap_or_else(|err| err.into_inner());
        if self.finished.load(Ordering::SeqCst) {
            return Ok(());
        }
        let elapsed = self.elapsed_ms();
        let wall = self.wall_now();
        if let Err(err) = self.ensure_inserted(elapsed, wall) {
            report_failure(&self.record_id, err);
            return Err(err);
        }
        match self.store.checkpoint(&self.record_id, elapsed, wall) {
            Ok(()) => {
                clear_failure(&self.record_id);
                Ok(())
            }
            Err(err) => {
                report_failure(&self.record_id, err);
                Err(err)
            }
        }
    }

    fn finish_body(&self) -> Result<(), HistoryError> {
        let _op = self.op.lock().unwrap_or_else(|err| err.into_inner());
        if self.finished.load(Ordering::SeqCst) {
            return Ok(());
        }
        let elapsed = self.elapsed_ms();
        let wall = self.wall_now();
        if let Err(err) = self.ensure_inserted(elapsed, wall) {
            report_failure(&self.record_id, err);
            return Err(err);
        }
        match self.store.finish(&self.record_id, elapsed, wall) {
            Ok(()) => {
                self.finished.store(true, Ordering::SeqCst);
                clear_failure(&self.record_id);
                Ok(())
            }
            Err(err) => {
                report_failure(&self.record_id, err);
                Err(err)
            }
        }
    }

    fn ensure_inserted(&self, elapsed_ms: u64, wall_ms: i64) -> Result<(), HistoryError> {
        if self.inserted.load(Ordering::SeqCst) {
            return Ok(());
        }
        let record = self.active_record(elapsed_ms, wall_ms);
        match self.store.insert(&record) {
            Ok(()) => {
                self.inserted.store(true, Ordering::SeqCst);
                Ok(())
            }
            Err(HistoryError::InvalidInput) => match self.store.get(&self.record_id) {
                Ok(_) => {
                    self.inserted.store(true, Ordering::SeqCst);
                    Ok(())
                }
                Err(_) => Err(HistoryError::InvalidInput),
            },
            Err(err) => Err(err),
        }
    }

    fn active_record(&self, elapsed_ms: u64, wall_ms: i64) -> HistoryRecord {
        HistoryRecord {
            schema: 1,
            record_id: self.record_id.clone(),
            connection_type: self.connection_type.clone(),
            peer_id: self.peer_id.clone(),
            peer_name: self.peer_name.clone(),
            started_at_utc_ms: self.started_at_utc_ms,
            ended_at_utc_ms: None,
            elapsed_ms,
            checkpoint_at_utc_ms: wall_ms,
            status: "active".to_owned(),
            owner_pid: self.owner.pid,
            owner_started_at: self.owner.started_at,
            note: String::new(),
            note_revision: 0,
        }
    }

    fn elapsed_ms(&self) -> u64 {
        match &self.time {
            TimeBase::System { started } => {
                u64::try_from(started.elapsed().as_millis()).unwrap_or(u64::MAX)
            }
            TimeBase::Manual { origin, mono, .. } => {
                mono.load(Ordering::SeqCst).saturating_sub(*origin)
            }
        }
    }

    fn wall_now(&self) -> i64 {
        wall_from_base(&self.time)
    }
}

struct PendingCheckpoint<'a>(&'a IntervalInner);

impl Drop for PendingCheckpoint<'_> {
    fn drop(&mut self) {
        let _guard = self
            .0
            .pending_lock
            .lock()
            .unwrap_or_else(|err| err.into_inner());
        self.0.pending.fetch_sub(1, Ordering::SeqCst);
        self.0.pending_cv.notify_all();
    }
}

impl Drop for IntervalInner {
    fn drop(&mut self) {
        if self.finished.load(Ordering::SeqCst) {
            return;
        }
        self.finished.store(true, Ordering::SeqCst);
        let elapsed = self.elapsed_ms();
        let wall = self.wall_now();
        let store = self.store.clone();
        let record_id = self.record_id.clone();
        let inserted = self.inserted.load(Ordering::SeqCst);
        let record = self.active_record(elapsed, wall);
        let persist = move || persist_final(&store, &record_id, inserted, &record, elapsed, wall);
        if cfg!(test) {
            let _ = persist();
        } else {
            let _ = std::thread::Builder::new()
                .name("raatik-history-finish".to_owned())
                .spawn(persist);
        }
    }
}

fn persist_final(
    store: &super::history_store::HistoryStore,
    record_id: &str,
    inserted: bool,
    record: &HistoryRecord,
    elapsed_ms: u64,
    end_utc_ms: i64,
) -> Result<(), HistoryError> {
    if !inserted {
        match store.insert(record) {
            Ok(()) => {}
            Err(HistoryError::InvalidInput) => match store.get(record_id) {
                Ok(_) => {}
                Err(err) => {
                    report_failure(record_id, err);
                    return Err(err);
                }
            },
            Err(err) => {
                report_failure(record_id, err);
                return Err(err);
            }
        }
    }
    match store.finish(record_id, elapsed_ms, end_utc_ms) {
        Ok(()) => {
            clear_failure(record_id);
            Ok(())
        }
        Err(err) => {
            report_failure(record_id, err);
            Err(err)
        }
    }
}

fn wall_from_base(time: &TimeBase) -> i64 {
    match time {
        TimeBase::System { .. } => system_wall_ms(),
        TimeBase::Manual { wall, .. } => wall.load(Ordering::SeqCst),
    }
}

fn system_wall_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| i64::try_from(elapsed.as_millis()).unwrap_or(i64::MAX))
        .unwrap_or(0)
}

fn validate_peer_id(peer_id: &str) -> Result<(), HistoryError> {
    let len = peer_id.chars().count();
    if len == 0 || len > MAX_PEER_ID_SCALARS {
        Err(HistoryError::InvalidInput)
    } else {
        Ok(())
    }
}

fn truncate_scalars(value: &str, max: usize) -> String {
    value.chars().take(max).collect()
}

fn register_live(inner: &Arc<IntervalInner>) {
    let mut live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
    live.retain(|weak| weak.strong_count() > 0);
    live.push(Arc::downgrade(inner));
}

fn report_failure(record_id: &str, err: HistoryError) {
    *SAVE_WARNING
        .lock()
        .unwrap_or_else(|poison| poison.into_inner()) = Some(HistorySaveWarning {
        text: HISTORY_SAVE_WARNING_TEXT.to_owned(),
        action: HISTORY_SAVE_WARNING_ACTION.to_owned(),
        record_id: record_id.to_owned(),
    });
    history_warn(format!("history save failed: {err}"));
}

fn clear_failure(record_id: &str) {
    let mut guard = SAVE_WARNING.lock().unwrap_or_else(|err| err.into_inner());
    if guard.as_ref().map(|warning| warning.record_id.as_str()) == Some(record_id) {
        *guard = None;
    }
}

fn history_warn(message: impl std::fmt::Display) {
    #[cfg(not(raatik_history_harness))]
    hbb_common::log::warn!("{}", message);
    #[cfg(raatik_history_harness)]
    let _ = message;
}
