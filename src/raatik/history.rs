use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicBool, AtomicI64, AtomicU64, AtomicUsize, Ordering},
        Arc, Condvar, Mutex, OnceLock, Weak,
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

static LIVE_INTERVALS: Mutex<Vec<LiveRef>> = Mutex::new(Vec::new());
static STATUS_HOOK: Mutex<Option<fn(&str, bool, &str, &str)>> = Mutex::new(None);

fn warnings() -> &'static Mutex<HashMap<String, HistorySaveWarning>> {
    static SLOT: OnceLock<Mutex<HashMap<String, HistorySaveWarning>>> = OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(HashMap::new()))
}

fn active_intervals() -> &'static Mutex<HashMap<String, HistoryInterval>> {
    static SLOT: OnceLock<Mutex<HashMap<String, HistoryInterval>>> = OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(HashMap::new()))
}

fn pending_begins() -> &'static Mutex<HashMap<String, PendingBegin>> {
    static SLOT: OnceLock<Mutex<HashMap<String, PendingBegin>>> = OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(HashMap::new()))
}

struct LiveRef {
    session_key: String,
    interval: Weak<IntervalInner>,
}

struct PendingBegin {
    session_key: String,
    park_id: String,
    peer_id: String,
    peer_name: String,
    connection_type: String,
    owner: OwnerIdentity,
    open: Arc<
        dyn Fn() -> Result<Arc<super::history_store::HistoryStore>, HistoryError> + Send + Sync,
    >,
    refresh_owner: Option<fn() -> Option<OwnerIdentity>>,
}

impl Clone for PendingBegin {
    fn clone(&self) -> Self {
        Self {
            session_key: self.session_key.clone(),
            park_id: self.park_id.clone(),
            peer_id: self.peer_id.clone(),
            peer_name: self.peer_name.clone(),
            connection_type: self.connection_type.clone(),
            owner: self.owner,
            open: Arc::clone(&self.open),
            refresh_owner: self.refresh_owner,
        }
    }
}

pub fn set_history_status_hook(hook: fn(&str, bool, &str, &str)) {
    *STATUS_HOOK.lock().unwrap_or_else(|err| err.into_inner()) = Some(hook);
}

pub fn history_save_warning(session_key: &str) -> Option<HistorySaveWarning> {
    warnings()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .get(session_key)
        .cloned()
}

pub fn clear_history_save_warning(session_key: &str) {
    clear_failure(session_key);
}

fn retry_existing(interval: &HistoryInterval) -> Result<(), HistoryError> {
    if interval.inner.close_requested.load(Ordering::SeqCst) {
        interval.finish()
    } else {
        interval.checkpoint()
    }
}

pub fn retry_history_save(session_key: &str) -> Result<(), HistoryError> {
    // Pre-park ids first. A sibling that already has an interval is not pending,
    // so this press also retries every uninserted row, every failed checkpoint,
    // and every failed finish. A healthy open interval stays unfinished.
    let mut failure = None;
    for pending in pending_for_session(session_key) {
        if let Err(err) = retry_one_pending(pending) {
            if failure.is_none() {
                failure = Some(err);
            }
        }
    }
    for interval in intervals_for_session(session_key) {
        if !save_still_open(&interval) {
            continue;
        }
        if let Err(err) = retry_existing(&interval) {
            if failure.is_none() {
                failure = Some(err);
            }
        }
    }
    match failure {
        Some(err) => Err(err),
        None => Ok(()),
    }
}

fn retry_one_pending(pending: PendingBegin) -> Result<(), HistoryError> {
    let park_id = pending.park_id.clone();
    if let Some(interval) = interval_for_park(&park_id) {
        return retry_existing(&interval);
    }
    let mut owner = pending.owner;
    if let Some(refresh) = pending.refresh_owner {
        if let Some(next) = refresh() {
            owner = next;
        }
    }
    match begin_for_park(
        &pending.session_key,
        &park_id,
        pending.peer_id,
        pending.peer_name,
        pending.connection_type,
        owner,
        pending.open,
        pending.refresh_owner,
    ) {
        Ok(Some(interval)) => {
            // Park under this connection's id. A sibling id stays where it is.
            let park_id = interval.inner.park_key.clone();
            park_unadopted(&park_id, interval);
            Ok(())
        }
        Ok(None) => Ok(()),
        Err(err) => Err(err),
    }
}

/// Open the store before publishing it. A failed open leaves the cell empty.
pub(crate) fn open_history_store(
    slot: &OnceLock<Arc<super::history_store::HistoryStore>>,
    session_key: &str,
    path_empty: bool,
    open: impl FnOnce() -> Result<Arc<super::history_store::HistoryStore>, HistoryError>,
) -> Result<Arc<super::history_store::HistoryStore>, HistoryError> {
    if let Some(existing) = slot.get() {
        return Ok(existing.clone());
    }
    if path_empty {
        report_failure(session_key, "", HistoryError::Io);
        return Err(HistoryError::Io);
    }
    match open() {
        Ok(store) => Ok(slot.get_or_init(|| store).clone()),
        Err(err) => {
            report_failure(session_key, "", err);
            Err(err)
        }
    }
}

pub(crate) fn begin_for_session(
    session_key: &str,
    peer_id: String,
    peer_name: String,
    connection_type: String,
    owner: OwnerIdentity,
    open: Arc<
        dyn Fn() -> Result<Arc<super::history_store::HistoryStore>, HistoryError> + Send + Sync,
    >,
    refresh_owner: Option<fn() -> Option<OwnerIdentity>>,
) -> Result<Option<HistoryInterval>, HistoryError> {
    begin_for_park(
        session_key,
        session_key,
        peer_id,
        peer_name,
        connection_type,
        owner,
        open,
        refresh_owner,
    )
}

/// `park_id` is the slot adopt, guard drop, and finish may take.
/// Desktop, file, camera, and terminal pass the Flutter session key.
/// A port-forward or RDP connection passes its own id.
pub(crate) fn begin_for_park(
    session_key: &str,
    park_id: &str,
    peer_id: String,
    peer_name: String,
    connection_type: String,
    owner: OwnerIdentity,
    open: Arc<
        dyn Fn() -> Result<Arc<super::history_store::HistoryStore>, HistoryError> + Send + Sync,
    >,
    refresh_owner: Option<fn() -> Option<OwnerIdentity>>,
) -> Result<Option<HistoryInterval>, HistoryError> {
    let park_id = if park_id.is_empty() {
        session_key
    } else {
        park_id
    };
    remember_pending(PendingBegin {
        session_key: session_key.to_owned(),
        park_id: park_id.to_owned(),
        peer_id: peer_id.clone(),
        peer_name: peer_name.clone(),
        connection_type: connection_type.clone(),
        owner,
        open: Arc::clone(&open),
        refresh_owner,
    });
    if owner.started_at == 0 {
        report_failure(session_key, "", HistoryError::Io);
        return Err(HistoryError::Io);
    }
    if validate_peer_id(&peer_id).is_err() || !CONNECTION_TYPES.contains(&connection_type.as_str())
    {
        report_failure(session_key, "", HistoryError::InvalidInput);
        return Err(HistoryError::InvalidInput);
    }
    let store = match open() {
        Ok(store) => store,
        Err(err) => {
            report_failure(session_key, "", err);
            return Err(err);
        }
    };
    match HistoryInterval::start_in_session(
        session_key,
        park_id,
        store,
        peer_id,
        peer_name,
        connection_type,
        owner,
    ) {
        Ok(interval) => {
            forget_pending(park_id);
            Ok(Some(interval))
        }
        Err(err) => Err(err),
    }
}

pub(crate) fn finish_session(session_key: &str) -> Result<(), HistoryError> {
    let Some(interval) = find_interval(session_key) else {
        return Ok(());
    };
    interval.finish()
}

#[cfg(test)]
pub(crate) fn reset_history_sessions() {
    warnings()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .clear();
    pending_begins()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .clear();
    LIVE_INTERVALS
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .clear();
    let mut active = active_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner());
    for interval in active.values() {
        interval.inner.finished.store(true, Ordering::SeqCst);
    }
    active.clear();
    drop(active);
    let mut parked = unadopted_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner());
    for interval in parked.values() {
        interval.inner.finished.store(true, Ordering::SeqCst);
    }
    parked.clear();
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

/// Move a retry-created interval into an empty round slot.
/// The UUID, start, and `Instant` stay the ones retry created.
pub(crate) fn adopt_retried_round(
    slot: &mut Option<(u32, HistoryInterval)>,
    round: u32,
    session_key: &str,
) {
    if slot.is_some() {
        return;
    }
    if let Some(interval) = take_unadopted(session_key) {
        *slot = Some((round, interval));
    }
}

pub(crate) fn new_forward_park_id() -> String {
    format!("fwd:{}", Uuid::new_v4().hyphenated())
}

#[cfg(test)]
pub(crate) fn parked_forward_identity(park_id: &str) -> Option<(String, i64, usize)> {
    unadopted_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .get(park_id)
        .map(|interval| {
            (
                interval.record_id().to_owned(),
                interval.inner.started_at_utc_ms,
                Arc::as_ptr(&interval.inner) as usize,
            )
        })
}

#[cfg(test)]
pub(crate) fn interval_allocation(interval: &HistoryInterval) -> usize {
    Arc::as_ptr(&interval.inner) as usize
}

/// Move the interval parked under `park_id` into an empty forward slot.
/// Any other id stays parked.
pub(crate) fn adopt_retried_forward(slot: &mut Option<HistoryInterval>, park_id: &str) {
    if slot.is_some() {
        return;
    }
    if let Some(interval) = take_unadopted(park_id) {
        *slot = Some(interval);
    }
}

/// Held by one spawned port-forward or RDP task.
/// Drop takes only this connection's parked interval. That owner's `Drop` finishes the same record.
/// If this id is empty, or the forward already adopted it, this drop writes nothing.
#[cfg_attr(any(target_os = "android", target_os = "ios"), allow(dead_code))]
pub(crate) struct ParkedForwardGuard {
    park_id: String,
}

#[cfg_attr(any(target_os = "android", target_os = "ios"), allow(dead_code))]
impl ParkedForwardGuard {
    pub(crate) fn new(park_id: impl Into<String>) -> Self {
        Self {
            park_id: park_id.into(),
        }
    }
}

impl Drop for ParkedForwardGuard {
    fn drop(&mut self) {
        // `HistoryInterval::Drop` finishes this record. Outside tests that write
        // runs on `raatik-history-finish`, not on the async thread that aborts the task.
        if let Some(interval) = take_unadopted(&self.park_id) {
            drop(interval);
        }
    }
}

/// Finish only the interval that belongs to `round`.
/// A failed write puts the same interval back so retry keeps its id and start.
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
    let (stored, interval) = slot.take().expect("history interval present");
    match interval.finish() {
        Ok(()) => Ok(()),
        Err(err) => {
            *slot = Some((stored, interval));
            Err(err)
        }
    }
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
fn current_owner() -> Option<OwnerIdentity> {
    let pid = std::process::id();
    super::history_store::process_creation_filetime(pid)
        .map(|started_at| OwnerIdentity { pid, started_at })
}

#[cfg(all(windows, not(raatik_history_harness)))]
fn interactive_open(
    session_key: &str,
) -> Result<Arc<super::history_store::HistoryStore>, HistoryError> {
    static SLOT: OnceLock<Arc<super::history_store::HistoryStore>> = OnceLock::new();
    let path = hbb_common::config::Config::path("history/v1");
    let path_empty = path.as_os_str().is_empty();
    open_history_store(&SLOT, session_key, path_empty, || {
        super::history_store::HistoryStore::open(path).map(Arc::new)
    })
}

#[cfg(all(windows, not(raatik_history_harness)))]
pub(crate) fn begin_current_interval(
    session_key: String,
    peer_id: String,
    peer_name: String,
    connection_type: String,
) -> Result<Option<HistoryInterval>, HistoryError> {
    let park_id = session_key.clone();
    begin_interactive(session_key, park_id, peer_id, peer_name, connection_type)
}

#[cfg(all(windows, not(raatik_history_harness)))]
fn begin_interactive(
    session_key: String,
    park_id: String,
    peer_id: String,
    peer_name: String,
    connection_type: String,
) -> Result<Option<HistoryInterval>, HistoryError> {
    if crate::platform::is_root() {
        return Ok(None);
    }
    let session_key = if session_key.is_empty() {
        Uuid::new_v4().hyphenated().to_string()
    } else {
        session_key
    };
    let park_id = if park_id.is_empty() {
        session_key.clone()
    } else {
        park_id
    };
    let open_key = session_key.clone();
    let open: Arc<
        dyn Fn() -> Result<Arc<super::history_store::HistoryStore>, HistoryError> + Send + Sync,
    > = Arc::new(move || interactive_open(&open_key));
    let owner = current_owner().unwrap_or(OwnerIdentity {
        pid: std::process::id(),
        started_at: 0,
    });
    begin_for_park(
        &session_key,
        &park_id,
        peer_id,
        peer_name,
        connection_type,
        owner,
        open,
        Some(current_owner),
    )
}

#[cfg(all(windows, not(raatik_history_harness)))]
pub(crate) fn begin_forward_interval(
    session_key: String,
    park_id: String,
    peer_id: String,
    peer_name: String,
    connection_type: String,
) -> Result<Option<HistoryInterval>, HistoryError> {
    begin_interactive(session_key, park_id, peer_id, peer_name, connection_type)
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
    session_key: String,
    park_key: String,
    record_id: String,
    peer_id: String,
    peer_name: String,
    connection_type: String,
    owner: OwnerIdentity,
    started_at_utc_ms: i64,
    time: TimeBase,
    inserted: AtomicBool,
    finished: AtomicBool,
    close_requested: AtomicBool,
    checkpoint_failed: AtomicBool,
    pending_finish: Mutex<Option<(u64, i64)>>,
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
            String::new(),
            String::new(),
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
            String::new(),
            String::new(),
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

    pub fn session_key(&self) -> &str {
        &self.inner.session_key
    }

    pub(crate) fn start_in_session(
        session_key: &str,
        park_key: &str,
        store: Arc<super::history_store::HistoryStore>,
        peer_id: String,
        peer_name: String,
        connection_type: String,
        owner: OwnerIdentity,
    ) -> Result<Self, HistoryError> {
        Self::open(
            session_key.to_owned(),
            park_key.to_owned(),
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

    pub fn checkpoint(&self) -> Result<(), HistoryError> {
        self.inner.checkpoint()
    }

    pub fn finish(&self) -> Result<(), HistoryError> {
        self.inner.finish()
    }

    fn open(
        session_key: String,
        park_key: String,
        store: Arc<super::history_store::HistoryStore>,
        peer_id: String,
        peer_name: String,
        connection_type: String,
        owner: OwnerIdentity,
        time: TimeBase,
    ) -> Result<Self, HistoryError> {
        if let Err(err) = validate_peer_id(&peer_id) {
            report_failure(&session_key, "", err);
            return Err(err);
        }
        if !CONNECTION_TYPES.contains(&connection_type.as_str()) {
            report_failure(&session_key, "", HistoryError::InvalidInput);
            return Err(HistoryError::InvalidInput);
        }
        if owner.started_at == 0 {
            report_failure(&session_key, "", HistoryError::Io);
            return Err(HistoryError::Io);
        }
        let peer_name = if peer_name.is_empty() {
            truncate_scalars(&peer_id, MAX_PEER_NAME_SCALARS)
        } else {
            truncate_scalars(&peer_name, MAX_PEER_NAME_SCALARS)
        };
        let record_id = Uuid::new_v4().hyphenated().to_string();
        let session_key = if session_key.is_empty() {
            record_id.clone()
        } else {
            session_key
        };
        let park_key = if park_key.is_empty() {
            session_key.clone()
        } else {
            park_key
        };
        let started_at_utc_ms = wall_from_base(&time);
        let inner = Arc::new(IntervalInner {
            store,
            session_key: session_key.clone(),
            park_key,
            record_id,
            peer_id,
            peer_name,
            connection_type,
            owner,
            started_at_utc_ms,
            time,
            inserted: AtomicBool::new(false),
            finished: AtomicBool::new(false),
            close_requested: AtomicBool::new(false),
            checkpoint_failed: AtomicBool::new(false),
            pending_finish: Mutex::new(None),
            pending: AtomicUsize::new(0),
            pending_lock: Mutex::new(()),
            pending_cv: Condvar::new(),
            op: Mutex::new(()),
        });
        register_live(&session_key, &inner);
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
            report_failure(&interval.inner.session_key, &interval.inner.record_id, err);
            if matches!(err, HistoryError::Io | HistoryError::Busy) {
                return Ok(interval);
            }
            return Err(err);
        }
        interval.inner.note_write_ok();
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
            report_failure(&self.session_key, &self.record_id, err);
            return Err(err);
        }
        match self.store.checkpoint(&self.record_id, elapsed, wall) {
            Ok(()) => {
                self.checkpoint_failed.store(false, Ordering::SeqCst);
                self.note_write_ok();
                Ok(())
            }
            Err(err) => {
                self.checkpoint_failed.store(true, Ordering::SeqCst);
                report_failure(&self.session_key, &self.record_id, err);
                Err(err)
            }
        }
    }

    fn finish_body(&self) -> Result<(), HistoryError> {
        let _op = self.op.lock().unwrap_or_else(|err| err.into_inner());
        if self.finished.load(Ordering::SeqCst) {
            return Ok(());
        }
        self.close_requested.store(true, Ordering::SeqCst);
        let (elapsed, wall) = {
            let mut pending = self
                .pending_finish
                .lock()
                .unwrap_or_else(|err| err.into_inner());
            if pending.is_none() {
                *pending = Some((self.elapsed_ms(), self.wall_now()));
            }
            pending.as_ref().copied().expect("finish snapshot")
        };
        if let Err(err) = self.ensure_inserted(elapsed, wall) {
            report_failure(&self.session_key, &self.record_id, err);
            return Err(err);
        }
        match self.store.finish(&self.record_id, elapsed, wall) {
            Ok(()) => {
                self.finished.store(true, Ordering::SeqCst);
                self.note_write_ok();
                forget_active(&self.session_key);
                forget_unadopted(&self.park_key);
                Ok(())
            }
            Err(err) => {
                report_failure(&self.session_key, &self.record_id, err);
                Err(err)
            }
        }
    }

    fn note_write_ok(&self) {
        if self.close_requested.load(Ordering::SeqCst) && !self.finished.load(Ordering::SeqCst) {
            return;
        }
        // Keep the warning until every sibling is inserted, any failed checkpoint
        // of that same interval has later returned Ok, and any requested finish
        // has returned Ok. A healthy open sibling does not count.
        if session_has_other_pending(&self.session_key, &self.park_key)
            || session_has_unresolved_sibling(&self.session_key, &self.record_id)
        {
            return;
        }
        clear_failure(&self.session_key);
    }

    fn ensure_inserted(&self, elapsed_ms: u64, wall_ms: i64) -> Result<(), HistoryError> {
        if self.inserted.load(Ordering::SeqCst) {
            return Ok(());
        }
        let record = self.active_record(elapsed_ms, wall_ms);
        match self.store.insert(&record) {
            Ok(()) => {
                self.inserted.store(true, Ordering::SeqCst);
                self.note_write_ok();
                Ok(())
            }
            Err(HistoryError::InvalidInput) => match self.store.get(&self.record_id) {
                Ok(_) => {
                    self.inserted.store(true, Ordering::SeqCst);
                    self.note_write_ok();
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

impl Drop for HistoryInterval {
    fn drop(&mut self) {
        if self.inner.finished.load(Ordering::SeqCst) {
            return;
        }
        if Arc::strong_count(&self.inner) > 1 {
            return;
        }
        let inner = Arc::clone(&self.inner);
        let run = move || {
            let interval = HistoryInterval { inner };
            if interval.finish().is_err() {
                remember_active(interval.session_key(), &interval);
            }
        };
        if cfg!(test) {
            run();
        } else {
            let _ = std::thread::Builder::new()
                .name("raatik-history-finish".to_owned())
                .spawn(run);
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

fn register_live(session_key: &str, inner: &Arc<IntervalInner>) {
    let mut live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
    live.retain(|item| item.interval.strong_count() > 0);
    live.push(LiveRef {
        session_key: session_key.to_owned(),
        interval: Arc::downgrade(inner),
    });
}

#[cfg(test)]
pub(crate) fn session_index_holds_live_interval(session_key: &str) -> bool {
    let live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
    live.iter()
        .any(|item| item.session_key == session_key && item.interval.strong_count() > 0)
}

#[cfg(test)]
pub(crate) fn session_index_holds_strong_owner(session_key: &str) -> bool {
    active_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .contains_key(session_key)
}

fn interval_for_park(park_id: &str) -> Option<HistoryInterval> {
    if let Some(interval) = unadopted_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .get(park_id)
        .cloned()
    {
        return Some(interval);
    }
    if let Some(interval) = active_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .values()
        .find(|interval| interval.inner.park_key == park_id)
        .cloned()
    {
        return Some(interval);
    }
    let mut live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
    live.retain(|item| item.interval.strong_count() > 0);
    live.iter().find_map(|item| {
        let inner = item.interval.upgrade()?;
        (inner.park_key == park_id).then_some(HistoryInterval { inner })
    })
}

fn save_still_open(interval: &HistoryInterval) -> bool {
    let inner = &interval.inner;
    !inner.inserted.load(Ordering::SeqCst)
        || (inner.close_requested.load(Ordering::SeqCst) && !inner.finished.load(Ordering::SeqCst))
        || (inner.checkpoint_failed.load(Ordering::SeqCst)
            && !inner.finished.load(Ordering::SeqCst))
}

fn session_has_unresolved_sibling(session_key: &str, except_record_id: &str) -> bool {
    if session_key.is_empty() {
        return false;
    }
    intervals_for_session(session_key)
        .into_iter()
        .any(|interval| interval.record_id() != except_record_id && save_still_open(&interval))
}

fn intervals_for_session(session_key: &str) -> Vec<HistoryInterval> {
    if session_key.is_empty() {
        return Vec::new();
    }
    let mut found = Vec::new();
    let mut push = |interval: &HistoryInterval| {
        if interval.inner.session_key != session_key {
            return;
        }
        if found
            .iter()
            .any(|item: &HistoryInterval| item.record_id() == interval.record_id())
        {
            return;
        }
        found.push(interval.clone());
    };
    {
        let active = active_intervals()
            .lock()
            .unwrap_or_else(|err| err.into_inner());
        for interval in active.values() {
            push(interval);
        }
    }
    {
        let parked = unadopted_intervals()
            .lock()
            .unwrap_or_else(|err| err.into_inner());
        for interval in parked.values() {
            push(interval);
        }
    }
    {
        let mut live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
        live.retain(|item| item.interval.strong_count() > 0);
        for item in live.iter() {
            if item.session_key != session_key {
                continue;
            }
            if let Some(inner) = item.interval.upgrade() {
                let interval = HistoryInterval { inner };
                push(&interval);
            }
        }
    }
    found.sort_by(|left, right| {
        left.inner
            .park_key
            .cmp(&right.inner.park_key)
            .then(left.inner.record_id.cmp(&right.inner.record_id))
    });
    found
}

fn find_interval(session_key: &str) -> Option<HistoryInterval> {
    if let Some(interval) = active_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .get(session_key)
        .cloned()
    {
        return Some(interval);
    }
    if let Some(interval) = unadopted_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .get(session_key)
        .cloned()
    {
        return Some(interval);
    }
    let mut live = LIVE_INTERVALS.lock().unwrap_or_else(|err| err.into_inner());
    live.retain(|item| item.interval.strong_count() > 0);
    live.iter().find_map(|item| {
        let inner = item.interval.upgrade()?;
        (item.session_key == session_key).then_some(HistoryInterval { inner })
    })
}

fn remember_active(session_key: &str, interval: &HistoryInterval) {
    active_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .insert(session_key.to_owned(), interval.clone());
}

fn unadopted_intervals() -> &'static Mutex<HashMap<String, HistoryInterval>> {
    static SLOT: OnceLock<Mutex<HashMap<String, HistoryInterval>>> = OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(HashMap::new()))
}

fn park_unadopted(session_key: &str, interval: HistoryInterval) {
    unadopted_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .insert(session_key.to_owned(), interval);
}

fn take_unadopted(session_key: &str) -> Option<HistoryInterval> {
    unadopted_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .remove(session_key)
}

fn forget_unadopted(session_key: &str) {
    let _ = take_unadopted(session_key);
}

fn forget_active(session_key: &str) {
    active_intervals()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .remove(session_key);
}

fn remember_pending(pending: PendingBegin) {
    let park_id = pending.park_id.clone();
    pending_begins()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .insert(park_id, pending);
}

fn forget_pending(park_id: &str) {
    pending_begins()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .remove(park_id);
}

fn pending_for_session(session_key: &str) -> Vec<PendingBegin> {
    let mut pending: Vec<PendingBegin> = pending_begins()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .values()
        .filter(|item| item.session_key == session_key)
        .cloned()
        .collect();
    pending.sort_by(|left, right| left.park_id.cmp(&right.park_id));
    pending
}

fn session_has_other_pending(session_key: &str, park_id: &str) -> bool {
    if session_key.is_empty() {
        return false;
    }
    pending_begins()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .values()
        .any(|item| item.session_key == session_key && item.park_id != park_id)
}

fn report_failure(session_key: &str, record_id: &str, err: HistoryError) {
    if session_key.is_empty() {
        history_warn(format!("history save failed: {err}"));
        return;
    }
    warnings()
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
        .insert(
            session_key.to_owned(),
            HistorySaveWarning {
                text: HISTORY_SAVE_WARNING_TEXT.to_owned(),
                action: HISTORY_SAVE_WARNING_ACTION.to_owned(),
                record_id: record_id.to_owned(),
            },
        );
    history_warn(format!("history save failed: {err}"));
    emit_status(session_key);
}

fn clear_failure(session_key: &str) {
    if session_key.is_empty() {
        return;
    }
    let removed = warnings()
        .lock()
        .unwrap_or_else(|err| err.into_inner())
        .remove(session_key)
        .is_some();
    if removed {
        emit_status(session_key);
    }
}

fn emit_status(session_key: &str) {
    let hook = *STATUS_HOOK.lock().unwrap_or_else(|err| err.into_inner());
    let Some(hook) = hook else {
        return;
    };
    match history_save_warning(session_key) {
        Some(warning) => hook(session_key, true, &warning.text, &warning.action),
        None => hook(session_key, false, "", ""),
    }
}

fn history_warn(message: impl std::fmt::Display) {
    #[cfg(not(raatik_history_harness))]
    hbb_common::log::warn!("{}", message);
    #[cfg(raatik_history_harness)]
    let _ = message;
}
