use super::history::{
    canonical_record_id, decode_stored, encode_record, matches_search, normalize_note,
    started_in_window, validate_query, validate_record, Decoded, HistoryError, HistoryPage,
    HistoryQuery, HistoryRecord, OwnerProbe, OwnerState, MAX_RECORD_BYTES,
};
// Set only by the local compile harness. Product builds leave this unset and log through hbb_common.
fn history_warn(message: impl std::fmt::Display) {
    #[cfg(not(raatik_history_harness))]
    hbb_common::log::warn!("{}", message);
    #[cfg(raatik_history_harness)]
    let _ = message;
}
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
    thread,
    time::{Duration, Instant},
};
use uuid::Uuid;

#[cfg(all(test, windows))]
use std::sync::atomic::{AtomicU8, Ordering};

#[cfg(windows)]
use std::os::windows::{
    ffi::OsStrExt,
    io::{FromRawHandle, RawHandle},
};
#[cfg(windows)]
use windows::{
    core::PCWSTR,
    Win32::{
        Foundation::{CloseHandle, FILETIME, HANDLE},
        Storage::FileSystem::{
            CreateFileW, LockFileEx, MoveFileExW, ReplaceFileW, UnlockFileEx,
            FILE_ATTRIBUTE_NORMAL, FILE_GENERIC_READ, FILE_GENERIC_WRITE, FILE_SHARE_DELETE,
            FILE_SHARE_READ, FILE_SHARE_WRITE, LOCKFILE_EXCLUSIVE_LOCK, LOCKFILE_FAIL_IMMEDIATELY,
            MOVEFILE_WRITE_THROUGH, OPEN_ALWAYS, OPEN_EXISTING, REPLACEFILE_WRITE_THROUGH,
        },
        System::{
            Threading::{
                GetProcessTimes, OpenProcess, PROCESS_QUERY_LIMITED_INFORMATION,
                PROCESS_SYNCHRONIZE,
            },
            IO::OVERLAPPED,
        },
    },
};

const LOCK_RETRY: Duration = Duration::from_secs(2);
const LOCK_PAUSE: Duration = Duration::from_millis(25);
const ERROR_FILE_NOT_FOUND: u32 = 2;
const ERROR_PATH_NOT_FOUND: u32 = 3;
const ERROR_ACCESS_DENIED: u32 = 5;
const ERROR_INVALID_PARAMETER: u32 = 87;
const ERROR_SHARING_VIOLATION: u32 = 32;
const ERROR_LOCK_VIOLATION: u32 = 33;

const FAULT_CREATE: u8 = 1;
const FAULT_WRITE: u8 = 2;
const FAULT_FLUSH: u8 = 3;
const FAULT_REPLACE: u8 = 4;

#[cfg(all(test, windows))]
pub(crate) const CHECKPOINT_HOLDING_FILE: &str = "checkpoint.holding";
#[cfg(all(test, windows))]
pub(crate) const CHECKPOINT_RELEASE_FILE: &str = "checkpoint.release";

#[cfg(all(test, windows))]
static HISTORY_FAULT: AtomicU8 = AtomicU8::new(0);

#[cfg(all(test, windows))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum HistoryFault {
    CreateTemp,
    Write,
    Flush,
    Replace,
}

#[cfg(all(test, windows))]
pub(crate) fn set_history_fault(fault: Option<HistoryFault>) {
    let slot = match fault {
        None => 0,
        Some(HistoryFault::CreateTemp) => FAULT_CREATE,
        Some(HistoryFault::Write) => FAULT_WRITE,
        Some(HistoryFault::Flush) => FAULT_FLUSH,
        Some(HistoryFault::Replace) => FAULT_REPLACE,
    };
    HISTORY_FAULT.store(slot, Ordering::SeqCst);
}

/// Synchronous directory of one JSON file per session.
/// Callers run these methods on a blocking worker; this type does not start a runtime.
#[derive(Debug)]
pub struct HistoryStore {
    root: PathBuf,
}

#[derive(Debug, Default, Clone, Copy)]
pub struct WindowsOwnerProbe;

impl OwnerProbe for WindowsOwnerProbe {
    fn state(&self, pid: u32, started_at: u64) -> OwnerState {
        #[cfg(windows)]
        {
            windows_owner_state(pid, started_at)
        }
        #[cfg(not(windows))]
        {
            let _ = (pid, started_at);
            OwnerState::Unknown
        }
    }
}

#[cfg(windows)]
pub(crate) fn process_creation_filetime(pid: u32) -> Option<u64> {
    match read_creation_ticks(pid) {
        Ok(ticks) => Some(ticks),
        Err(_) => None,
    }
}

impl HistoryStore {
    pub fn open(root: PathBuf) -> Result<Self, HistoryError> {
        fs::create_dir_all(&root).map_err(|err| {
            warn_io(&err);
            HistoryError::Io
        })?;
        if !root.is_dir() {
            return Err(HistoryError::Io);
        }
        Ok(Self { root })
    }

    pub fn insert(&self, record: &HistoryRecord) -> Result<(), HistoryError> {
        validate_record(record)?;
        let id = record.record_id.clone();
        self.with_lock(&id, |txn| {
            let path = json_path(txn.root, &id);
            if path.exists() {
                return Err(HistoryError::InvalidInput);
            }
            let bytes = encode_record(record)?;
            write_atomic(txn.root, &id, &path, &bytes, false)
        })
    }

    pub fn checkpoint(
        &self,
        id: &str,
        elapsed_ms: u64,
        at_utc_ms: i64,
    ) -> Result<(), HistoryError> {
        let id = canonical_record_id(id)?;
        self.with_lock(&id, |txn| apply_checkpoint(txn, &id, elapsed_ms, at_utc_ms))
    }

    pub fn finish(&self, id: &str, elapsed_ms: u64, end_utc_ms: i64) -> Result<(), HistoryError> {
        let id = canonical_record_id(id)?;
        self.with_lock(&id, |txn| apply_finish(txn, &id, elapsed_ms, end_utc_ms))
    }

    pub fn get(&self, id: &str) -> Result<HistoryRecord, HistoryError> {
        let id = canonical_record_id(id)?;
        self.with_lock(&id, |txn| match load_record(txn.root, &id)? {
            Loaded::Missing => Err(HistoryError::NotFound),
            Loaded::FutureSchema => Err(HistoryError::FutureSchema),
            Loaded::Unreadable => Err(HistoryError::Io),
            Loaded::Record(record) => Ok(record),
        })
    }

    pub fn save_note(
        &self,
        id: &str,
        expected_revision: u64,
        note: &str,
    ) -> Result<HistoryRecord, HistoryError> {
        let id = canonical_record_id(id)?;
        let note = normalize_note(note)?;
        self.with_lock(&id, |txn| apply_note(txn, &id, expected_revision, note))
    }

    pub fn query(&self, query: &HistoryQuery) -> Result<HistoryPage, HistoryError> {
        validate_query(query)?;
        let paths = list_json(&self.root)?;
        let mut records = Vec::new();
        let mut unreadable = false;
        let mut future = false;
        for path in paths {
            match self.load_query_entry(&path)? {
                QueryEntry::Include(record) => {
                    if started_in_window(&record, query) && matches_search(&record, &query.search) {
                        records.push(record);
                    }
                }
                QueryEntry::Future => future = true,
                QueryEntry::Unreadable => unreadable = true,
                QueryEntry::Skip => {}
            }
        }
        records.sort_by(|left, right| {
            right
                .started_at_utc_ms
                .cmp(&left.started_at_utc_ms)
                .then_with(|| left.record_id.cmp(&right.record_id))
        });
        let total = records.len() as u64;
        let offset = query.offset as usize;
        let records = if offset >= records.len() {
            Vec::new()
        } else {
            records
                .into_iter()
                .skip(offset)
                .take(query.limit as usize)
                .collect()
        };
        let mut warnings = Vec::new();
        if unreadable {
            warnings.push("unreadable_records".to_string());
        }
        if future {
            warnings.push("future_schema".to_string());
        }
        Ok(HistoryPage {
            records,
            total,
            warnings,
        })
    }

    pub fn recover_abandoned(&self, probe: &dyn OwnerProbe) -> Result<usize, HistoryError> {
        let paths = list_json(&self.root)?;
        let mut changed = 0usize;
        for path in paths {
            let Some(id) = json_record_id(&path) else {
                continue;
            };
            let updated = self.with_lock(&id, |txn| {
                let Loaded::Record(mut record) = load_record(txn.root, &id)? else {
                    return Ok(false);
                };
                if record.status != "active" {
                    return Ok(false);
                }
                if probe.state(record.owner_pid, record.owner_started_at) != OwnerState::Dead {
                    return Ok(false);
                }
                record.status = "interrupted".to_string();
                record.ended_at_utc_ms = None;
                let bytes = encode_record(&record)?;
                write_atomic(txn.root, &id, &json_path(txn.root, &id), &bytes, true)?;
                Ok(true)
            })?;
            if updated {
                changed += 1;
            }
        }
        Ok(changed)
    }

    fn with_lock<T>(
        &self,
        id: &str,
        body: impl FnOnce(&Txn<'_>) -> Result<T, HistoryError>,
    ) -> Result<T, HistoryError> {
        let _lock = acquire_record_lock(&self.root, id)?;
        body(&Txn { root: &self.root })
    }

    fn load_query_entry(&self, path: &Path) -> Result<QueryEntry, HistoryError> {
        let Some(id) = json_record_id(path) else {
            history_warn("omitting unreadable history record");
            return Ok(QueryEntry::Unreadable);
        };
        self.with_lock(&id, |txn| {
            Ok(match load_record(txn.root, &id)? {
                Loaded::Record(record) => QueryEntry::Include(record),
                Loaded::FutureSchema => {
                    history_warn("omitting future-schema history record");
                    QueryEntry::Future
                }
                Loaded::Unreadable => {
                    history_warn("omitting unreadable history record");
                    QueryEntry::Unreadable
                }
                Loaded::Missing => QueryEntry::Skip,
            })
        })
    }
}

#[cfg(all(test, windows))]
pub(crate) fn checkpoint_after_barrier(
    store: &HistoryStore,
    id: &str,
    elapsed_ms: u64,
    at_utc_ms: i64,
) -> Result<(), HistoryError> {
    let id = canonical_record_id(id)?;
    store.with_lock(&id, |txn| {
        let holding = txn.root.join(CHECKPOINT_HOLDING_FILE);
        let release = txn.root.join(CHECKPOINT_RELEASE_FILE);
        fs::write(&holding, b"1").map_err(|err| {
            warn_io(&err);
            HistoryError::Io
        })?;
        let started = Instant::now();
        while started.elapsed() < Duration::from_secs(8) {
            let released = release.exists();
            let held_long_enough = started.elapsed() >= Duration::from_millis(1_000);
            if released && held_long_enough {
                break;
            }
            thread::sleep(Duration::from_millis(20));
        }
        apply_checkpoint(txn, &id, elapsed_ms, at_utc_ms)
    })
}

struct Txn<'a> {
    root: &'a Path,
}

enum Loaded {
    Missing,
    FutureSchema,
    Unreadable,
    Record(HistoryRecord),
}

enum QueryEntry {
    Include(HistoryRecord),
    Future,
    Unreadable,
    Skip,
}

enum FileBytes {
    Missing,
    Unreadable,
    Data(Vec<u8>),
}

fn apply_checkpoint(
    txn: &Txn<'_>,
    id: &str,
    elapsed_ms: u64,
    at_utc_ms: i64,
) -> Result<(), HistoryError> {
    let mut record = mutable_record(load_record(txn.root, id)?)?;
    if record.status != "active" {
        return Ok(());
    }
    let elapsed = record.elapsed_ms.max(elapsed_ms);
    if elapsed == record.elapsed_ms && record.checkpoint_at_utc_ms == at_utc_ms {
        return Ok(());
    }
    record.elapsed_ms = elapsed;
    record.checkpoint_at_utc_ms = at_utc_ms;
    let bytes = encode_record(&record)?;
    write_atomic(txn.root, id, &json_path(txn.root, id), &bytes, true)
}

fn apply_finish(
    txn: &Txn<'_>,
    id: &str,
    elapsed_ms: u64,
    end_utc_ms: i64,
) -> Result<(), HistoryError> {
    let mut record = mutable_record(load_record(txn.root, id)?)?;
    // Completed and interrupted records keep their end state. A second finish must not
    // invent a new end time, and recovery's null end stays null.
    if record.status != "active" {
        return Ok(());
    }
    record.status = "completed".to_string();
    record.ended_at_utc_ms = Some(end_utc_ms);
    record.elapsed_ms = record.elapsed_ms.max(elapsed_ms);
    record.checkpoint_at_utc_ms = end_utc_ms;
    let bytes = encode_record(&record)?;
    write_atomic(txn.root, id, &json_path(txn.root, id), &bytes, true)
}

fn apply_note(
    txn: &Txn<'_>,
    id: &str,
    expected_revision: u64,
    note: String,
) -> Result<HistoryRecord, HistoryError> {
    let mut record = mutable_record(load_record(txn.root, id)?)?;
    if record.note_revision != expected_revision {
        return Err(HistoryError::NoteConflict);
    }
    if record.note == note {
        return Ok(record);
    }
    record.note = note;
    record.note_revision = record
        .note_revision
        .checked_add(1)
        .ok_or(HistoryError::InvalidInput)?;
    let bytes = encode_record(&record)?;
    write_atomic(txn.root, id, &json_path(txn.root, id), &bytes, true)?;
    Ok(record)
}

fn mutable_record(loaded: Loaded) -> Result<HistoryRecord, HistoryError> {
    match loaded {
        Loaded::Missing => Err(HistoryError::NotFound),
        Loaded::FutureSchema => Err(HistoryError::FutureSchema),
        Loaded::Unreadable => Err(HistoryError::Io),
        Loaded::Record(record) => Ok(record),
    }
}

fn load_record(root: &Path, id: &str) -> Result<Loaded, HistoryError> {
    let loaded = match read_record_bytes(&json_path(root, id))? {
        FileBytes::Missing => return Ok(Loaded::Missing),
        FileBytes::Unreadable => return Ok(Loaded::Unreadable),
        FileBytes::Data(bytes) => decode_stored(&bytes),
    };
    Ok(match loaded {
        Decoded::FutureSchema => Loaded::FutureSchema,
        Decoded::Unreadable => Loaded::Unreadable,
        Decoded::Record(record) if record.record_id == id => Loaded::Record(record),
        Decoded::Record(_) => Loaded::Unreadable,
    })
}

fn list_json(root: &Path) -> Result<Vec<PathBuf>, HistoryError> {
    let entries = fs::read_dir(root).map_err(|err| {
        warn_io(&err);
        HistoryError::Io
    })?;
    let mut paths = Vec::new();
    for entry in entries {
        let entry = entry.map_err(|err| {
            warn_io(&err);
            HistoryError::Io
        })?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if name.starts_with('.') || !name.to_ascii_lowercase().ends_with(".json") {
            continue;
        }
        paths.push(path);
    }
    Ok(paths)
}

fn json_record_id(path: &Path) -> Option<String> {
    let name = path.file_name()?.to_str()?;
    if name.len() <= 5 || !name[name.len() - 5..].eq_ignore_ascii_case(".json") {
        return None;
    }
    canonical_record_id(&name[..name.len() - 5]).ok()
}

fn json_path(root: &Path, id: &str) -> PathBuf {
    root.join(format!("{id}.json"))
}

fn lock_path(root: &Path, id: &str) -> PathBuf {
    root.join(format!("{id}.lock"))
}

fn write_atomic(
    root: &Path,
    id: &str,
    dest: &Path,
    bytes: &[u8],
    dest_exists: bool,
) -> Result<(), HistoryError> {
    if faulted(FAULT_CREATE) {
        return Err(HistoryError::Io);
    }
    let tmp = root.join(format!(".{id}.{}.tmp", Uuid::new_v4()));
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&tmp)
        .map_err(|err| {
            warn_io(&err);
            HistoryError::Io
        })?;
    let write_result = (|| -> Result<(), HistoryError> {
        if faulted(FAULT_WRITE) {
            return Err(HistoryError::Io);
        }
        file.write_all(bytes).map_err(|err| {
            warn_io(&err);
            HistoryError::Io
        })?;
        if faulted(FAULT_FLUSH) {
            return Err(HistoryError::Io);
        }
        file.sync_all().map_err(|err| {
            warn_io(&err);
            HistoryError::Io
        })?;
        Ok(())
    })();
    drop(file);
    if let Err(err) = write_result {
        let _ = fs::remove_file(&tmp);
        return Err(err);
    }
    if faulted(FAULT_REPLACE) {
        let _ = fs::remove_file(&tmp);
        return Err(HistoryError::Io);
    }
    // The previous record stays in place until the replacement itself succeeds.
    let replaced = if dest_exists {
        replace_existing(dest, &tmp)
    } else {
        move_new(&tmp, dest)
    };
    if let Err(err) = replaced {
        let _ = fs::remove_file(&tmp);
        return Err(err);
    }
    Ok(())
}

fn faulted(slot: u8) -> bool {
    #[cfg(all(test, windows))]
    {
        HISTORY_FAULT.load(Ordering::SeqCst) == slot
    }
    #[cfg(not(all(test, windows)))]
    {
        let _ = slot;
        false
    }
}

fn read_record_bytes(path: &Path) -> Result<FileBytes, HistoryError> {
    #[cfg(windows)]
    {
        read_record_bytes_windows(path)
    }
    #[cfg(not(windows))]
    {
        let _ = path;
        Err(HistoryError::Io)
    }
}

fn acquire_record_lock(root: &Path, id: &str) -> Result<RecordLock, HistoryError> {
    #[cfg(windows)]
    {
        acquire_record_lock_windows(root, id)
    }
    #[cfg(not(windows))]
    {
        let _ = (root, id);
        Err(HistoryError::Io)
    }
}

fn replace_existing(dest: &Path, tmp: &Path) -> Result<(), HistoryError> {
    #[cfg(windows)]
    {
        let dest_wide = wide_path(dest);
        let tmp_wide = wide_path(tmp);
        unsafe {
            ReplaceFileW(
                PCWSTR::from_raw(dest_wide.as_ptr()),
                PCWSTR::from_raw(tmp_wide.as_ptr()),
                PCWSTR::null(),
                REPLACEFILE_WRITE_THROUGH,
                None,
                None,
            )
        }
        .map_err(|err| {
            warn_os(&err);
            HistoryError::Io
        })
    }
    #[cfg(not(windows))]
    {
        let _ = (dest, tmp);
        Err(HistoryError::Io)
    }
}

fn move_new(tmp: &Path, dest: &Path) -> Result<(), HistoryError> {
    #[cfg(windows)]
    {
        let tmp_wide = wide_path(tmp);
        let dest_wide = wide_path(dest);
        unsafe {
            MoveFileExW(
                PCWSTR::from_raw(tmp_wide.as_ptr()),
                PCWSTR::from_raw(dest_wide.as_ptr()),
                MOVEFILE_WRITE_THROUGH,
            )
        }
        .map_err(|err| {
            warn_os(&err);
            HistoryError::Io
        })
    }
    #[cfg(not(windows))]
    {
        let _ = (tmp, dest);
        Err(HistoryError::Io)
    }
}

struct RecordLock {
    #[cfg(windows)]
    handle: HANDLE,
}

impl Drop for RecordLock {
    fn drop(&mut self) {
        #[cfg(windows)]
        unsafe {
            let mut overlapped = OVERLAPPED::default();
            let _ = UnlockFileEx(self.handle, None, 1, 0, &mut overlapped);
            let _ = CloseHandle(self.handle);
        }
    }
}

#[cfg(windows)]
fn acquire_record_lock_windows(root: &Path, id: &str) -> Result<RecordLock, HistoryError> {
    let path = lock_path(root, id);
    let wide = wide_path(&path);
    let handle = unsafe {
        CreateFileW(
            PCWSTR::from_raw(wide.as_ptr()),
            FILE_GENERIC_READ.0 | FILE_GENERIC_WRITE.0,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            None,
            OPEN_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            None,
        )
    }
    .map_err(|err| {
        warn_os(&err);
        HistoryError::Io
    })?;
    let started = Instant::now();
    loop {
        let mut overlapped = OVERLAPPED::default();
        let locked = unsafe {
            LockFileEx(
                handle,
                LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
                None,
                1,
                0,
                &mut overlapped,
            )
        };
        match locked {
            Ok(()) => return Ok(RecordLock { handle }),
            Err(err) if is_busy(&err) => {
                if started.elapsed() >= LOCK_RETRY {
                    unsafe {
                        let _ = CloseHandle(handle);
                    }
                    return Err(HistoryError::Busy);
                }
                thread::sleep(LOCK_PAUSE);
            }
            Err(err) => {
                warn_os(&err);
                unsafe {
                    let _ = CloseHandle(handle);
                }
                return Err(HistoryError::Io);
            }
        }
    }
}

#[cfg(windows)]
fn read_record_bytes_windows(path: &Path) -> Result<FileBytes, HistoryError> {
    let wide = wide_path(path);
    let opened = unsafe {
        CreateFileW(
            PCWSTR::from_raw(wide.as_ptr()),
            FILE_GENERIC_READ.0,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            None,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL,
            None,
        )
    };
    let handle = match opened {
        Ok(handle) => handle,
        Err(err)
            if is_win32(&err, ERROR_FILE_NOT_FOUND) || is_win32(&err, ERROR_PATH_NOT_FOUND) =>
        {
            return Ok(FileBytes::Missing);
        }
        Err(err) => {
            warn_os(&err);
            return Err(HistoryError::Io);
        }
    };
    let mut file = unsafe { File::from_raw_handle(handle.0 as RawHandle) };
    let len = match file.metadata() {
        Ok(metadata) => metadata.len(),
        Err(err) => {
            warn_io(&err);
            return Err(HistoryError::Io);
        }
    };
    if len > MAX_RECORD_BYTES as u64 {
        return Ok(FileBytes::Unreadable);
    }
    let mut bytes = Vec::new();
    if let Err(err) = file.read_to_end(&mut bytes) {
        warn_io(&err);
        return Err(HistoryError::Io);
    }
    if bytes.len() > MAX_RECORD_BYTES {
        return Ok(FileBytes::Unreadable);
    }
    Ok(FileBytes::Data(bytes))
}

#[cfg(windows)]
fn wide_path(path: &Path) -> Vec<u16> {
    path.as_os_str()
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

#[cfg(windows)]
fn windows_owner_state(pid: u32, started_at: u64) -> OwnerState {
    match read_creation_ticks(pid) {
        Ok(ticks) if ticks == started_at => OwnerState::Alive,
        Ok(_) => OwnerState::Dead,
        Err(state) => state,
    }
}

#[cfg(windows)]
fn read_creation_ticks(pid: u32) -> Result<u64, OwnerState> {
    let handle = match unsafe {
        OpenProcess(
            PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_SYNCHRONIZE,
            false,
            pid,
        )
    } {
        Ok(handle) => handle,
        Err(err) if is_win32(&err, ERROR_INVALID_PARAMETER) => return Err(OwnerState::Dead),
        Err(err) if is_win32(&err, ERROR_ACCESS_DENIED) => return Err(OwnerState::Unknown),
        Err(_) => return Err(OwnerState::Unknown),
    };
    let mut creation = FILETIME::default();
    let mut exit_time = FILETIME::default();
    let mut kernel = FILETIME::default();
    let mut user = FILETIME::default();
    let times = unsafe {
        GetProcessTimes(
            handle,
            &mut creation,
            &mut exit_time,
            &mut kernel,
            &mut user,
        )
    };
    unsafe {
        let _ = CloseHandle(handle);
    }
    match times {
        Ok(()) => {
            Ok((u64::from(creation.dwHighDateTime) << 32) | u64::from(creation.dwLowDateTime))
        }
        Err(_) => Err(OwnerState::Unknown),
    }
}

#[cfg(windows)]
fn is_win32(err: &windows::core::Error, code: u32) -> bool {
    err.code() == windows::core::HRESULT::from_win32(code)
}

#[cfg(windows)]
fn is_busy(err: &windows::core::Error) -> bool {
    is_win32(err, ERROR_LOCK_VIOLATION) || is_win32(err, ERROR_SHARING_VIOLATION)
}

#[cfg(windows)]
fn warn_os(err: &windows::core::Error) {
    history_warn(format!(
        "history file operation failed (code {})",
        err.code().0
    ));
}

fn warn_io(err: &std::io::Error) {
    history_warn(format!(
        "history file operation failed (os error {})",
        err.raw_os_error().unwrap_or(0)
    ));
}
