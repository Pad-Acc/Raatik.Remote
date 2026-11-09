use super::history::{
    admit_peer_info, finish_round, history_save_warning, note_approval_canceled,
    note_login_failure, retry_history_save, snapshot_peer_name, HistoryInterval, OwnerIdentity,
    HISTORY_SAVE_WARNING_ACTION, HISTORY_SAVE_WARNING_TEXT,
};
use super::history_store::{
    checkpoint_after_barrier, process_creation_filetime, set_history_fault, HistoryFault,
    CHECKPOINT_HOLDING_FILE, CHECKPOINT_RELEASE_FILE,
};
use super::{
    HistoryError, HistoryQuery, HistoryRecord, HistoryStore, OwnerProbe, OwnerState,
    WindowsOwnerProbe,
};
use serde::Deserialize;
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicBool, AtomicI64, AtomicU64, Ordering},
        Arc, Mutex, MutexGuard, OnceLock,
    },
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

const FIXTURES_JSON: &str = include_str!(
    "../../docs/superpowers/plans/2026-11-08-raatikdesk-examples/history-fixtures.json"
);
const ACTIVE_ID: &str = "22222222-2222-4222-8222-222222222222";
const COMPLETED_ID: &str = "11111111-1111-4111-8111-111111111111";

#[derive(Debug, Deserialize)]
struct FixtureFile {
    records: Vec<HistoryRecord>,
    queries: Vec<FixtureQuery>,
    note_steps: Vec<FixtureNoteStep>,
}

#[derive(Debug, Deserialize)]
struct FixtureQuery {
    id: String,
    input: HistoryQuery,
    expected_ids: Vec<String>,
    expected_total: u64,
}

#[derive(Debug, Deserialize)]
struct FixtureNoteStep {
    record_id: String,
    expected_revision: u64,
    note: String,
    result_revision: Option<u64>,
    error: Option<String>,
}

fn lock_tests() -> MutexGuard<'static, ()> {
    static LOCK: Mutex<()> = Mutex::new(());
    LOCK.lock().unwrap_or_else(|err| err.into_inner())
}

struct TempRoot(PathBuf);

impl TempRoot {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let n = NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "raatikdesk-history-{}-{}-{}",
            std::process::id(),
            n,
            nanos
        ));
        fs::create_dir_all(&path).unwrap();
        Self(path)
    }

    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempRoot {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

struct KillOnDrop(Option<std::process::Child>);

impl Drop for KillOnDrop {
    fn drop(&mut self) {
        if let Some(child) = self.0.as_mut() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

struct FaultGuard;

impl FaultGuard {
    fn arm(fault: HistoryFault) -> Self {
        set_history_fault(Some(fault));
        Self
    }
}

impl Drop for FaultGuard {
    fn drop(&mut self) {
        set_history_fault(None);
    }
}

fn fixtures() -> FixtureFile {
    serde_json::from_str(FIXTURES_JSON).expect("history fixtures decode")
}

fn open_store(root: &Path) -> HistoryStore {
    HistoryStore::open(root.to_path_buf()).expect("open history root")
}

fn record_by_id(file: &FixtureFile, id: &str) -> HistoryRecord {
    file.records
        .iter()
        .find(|record| record.record_id == id)
        .unwrap_or_else(|| panic!("missing fixture {id}"))
        .clone()
}

fn record_file(root: &Path, id: &str) -> PathBuf {
    root.join(format!("{id}.json"))
}

fn assert_no_temp_files(root: &Path) {
    for entry in fs::read_dir(root).unwrap() {
        let name = entry.unwrap().file_name();
        let name = name.to_string_lossy();
        assert!(
            !name.ends_with(".tmp"),
            "temporary history file left behind: {name}"
        );
    }
}

#[test]
fn note_survives_checkpoint() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let record = record_by_id(&fixtures(), ACTIVE_ID);
    store.insert(&record).unwrap();

    let saved = store
        .save_note(ACTIVE_ID, 0, "پیگیری فردا")
        .expect("save note");
    assert_eq!(saved.note, "پیگیری فردا");
    assert_eq!(saved.elapsed_ms, 30_000);
    assert_eq!(saved.note_revision, 1);

    store
        .checkpoint(ACTIVE_ID, 60_000, record.checkpoint_at_utc_ms + 30_000)
        .unwrap();
    let after = store.get(ACTIVE_ID).unwrap();
    assert_eq!(after.note, "پیگیری فردا");
    assert_eq!(after.elapsed_ms, 60_000);
    assert_eq!(after.note_revision, 1);
    assert_eq!(after.status, "active");
    assert_eq!(after.ended_at_utc_ms, None);

    store
        .checkpoint(ACTIVE_ID, 1_000, after.checkpoint_at_utc_ms)
        .unwrap();
    let kept = store.get(ACTIVE_ID).unwrap();
    assert_eq!(kept.elapsed_ms, 60_000);
    assert_eq!(kept.note, "پیگیری فردا");
    assert!(root.path().join(format!("{ACTIVE_ID}.lock")).is_file());
    assert_no_temp_files(root.path());
}

#[test]
fn note_revision_conflict() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let record = record_by_id(&fixtures(), COMPLETED_ID);
    store.insert(&record).unwrap();
    let saved = store.save_note(COMPLETED_ID, 0, "پیگیری فردا").unwrap();
    assert_eq!(saved.note_revision, 1);
    let before = fs::read(record_file(root.path(), COMPLETED_ID)).unwrap();

    let stale_save = store.save_note(COMPLETED_ID, 0, "متن قدیمی");
    assert!(matches!(stale_save, Err(HistoryError::NoteConflict)));
    assert_eq!(
        fs::read(record_file(root.path(), COMPLETED_ID)).unwrap(),
        before
    );
    assert_eq!(store.get(COMPLETED_ID).unwrap().note, "پیگیری فردا");
}

#[test]
fn two_process_writers() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    store.insert(&record_by_id(&fixtures(), ACTIVE_ID)).unwrap();

    let exe = std::env::current_exe().expect("test executable");
    let mut child = KillOnDrop(Some(
        Command::new(exe)
            .args(["--exact", "raatik::history_tests::writer_process_helper"])
            .env("RAATIK_HISTORY_TEST_ROOT", root.path())
            .env("RAATIK_HISTORY_TEST_MODE", "checkpoint")
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .expect("spawn history writer"),
    ));

    let holding = root.path().join(CHECKPOINT_HOLDING_FILE);
    let release = root.path().join(CHECKPOINT_RELEASE_FILE);
    let started = Instant::now();
    while !holding.exists() {
        if started.elapsed() > Duration::from_secs(90) {
            let mut writer = child.0.take().expect("writer");
            let _ = writer.kill();
            let output = writer.wait_with_output().unwrap();
            panic!(
                "writer did not acquire the history lock\nstdout:\n{}\nstderr:\n{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
        }
        thread::sleep(Duration::from_millis(20));
    }

    let (sender, receiver) = std::sync::mpsc::channel();
    let note_store = open_store(root.path());
    thread::spawn(move || {
        let result = note_store.save_note(ACTIVE_ID, 0, "پیگیری فردا");
        let _ = sender.send(result);
    });
    assert!(
        receiver.recv_timeout(Duration::from_millis(500)).is_err(),
        "save_note finished while the other process held the record lock"
    );
    fs::write(&release, b"1").unwrap();
    let saved = receiver
        .recv_timeout(Duration::from_secs(15))
        .expect("save_note did not finish after the writer released the lock")
        .expect("save note");
    assert_eq!(saved.note, "پیگیری فردا");
    assert_eq!(saved.note_revision, 1);
    assert_eq!(saved.elapsed_ms, 60_000);

    let output = child
        .0
        .take()
        .expect("writer")
        .wait_with_output()
        .expect("wait writer");
    assert!(
        output.status.success(),
        "writer failed\nstdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let stored = store.get(ACTIVE_ID).unwrap();
    assert_eq!(stored.note, "پیگیری فردا");
    assert_eq!(stored.elapsed_ms, 60_000);
    assert_eq!(stored.note_revision, 1);
    assert_eq!(stored.checkpoint_at_utc_ms, 1_794_120_360_000);
}

#[test]
fn writer_process_helper() {
    let Ok(root) = std::env::var("RAATIK_HISTORY_TEST_ROOT") else {
        return;
    };
    if root.is_empty() {
        return;
    }
    let Ok(mode) = std::env::var("RAATIK_HISTORY_TEST_MODE") else {
        return;
    };
    if mode.is_empty() {
        return;
    }
    let store = HistoryStore::open(PathBuf::from(root)).expect("history test root");
    match mode.as_str() {
        "checkpoint" => checkpoint_after_barrier(&store, ACTIVE_ID, 60_000, 1_794_120_360_000)
            .expect("checkpoint"),
        other => panic!("unsupported RAATIK_HISTORY_TEST_MODE: {other}"),
    }
}

struct FixedProbe {
    state: OwnerState,
    seen: Mutex<Vec<(u32, u64)>>,
}

impl OwnerProbe for FixedProbe {
    fn state(&self, pid: u32, started_at: u64) -> OwnerState {
        self.seen.lock().unwrap().push((pid, started_at));
        self.state
    }
}

#[test]
fn dead_owner_keeps_lower_bound() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let file = fixtures();
    for record in &file.records {
        store.insert(record).unwrap();
    }
    let completed_before = fs::read(record_file(root.path(), COMPLETED_ID)).unwrap();
    let probe = FixedProbe {
        state: OwnerState::Dead,
        seen: Mutex::new(Vec::new()),
    };

    let changed = store.recover_abandoned(&probe).unwrap();
    assert_eq!(changed, 1);
    let recovered = store.get(ACTIVE_ID).unwrap();
    assert_eq!(recovered.status, "interrupted");
    assert_eq!(recovered.ended_at_utc_ms, None);
    assert_eq!(recovered.elapsed_ms, 30_000);
    assert_eq!(
        probe.seen.lock().unwrap().as_slice(),
        &[(4242, 134_123_456_789_000_000)]
    );

    store
        .checkpoint(ACTIVE_ID, 90_000, recovered.checkpoint_at_utc_ms)
        .unwrap();
    let after = store.get(ACTIVE_ID).unwrap();
    assert_eq!(after.status, "interrupted");
    assert_eq!(after.ended_at_utc_ms, None);
    assert_eq!(after.elapsed_ms, 30_000);
    assert_eq!(store.get(COMPLETED_ID).unwrap().status, "completed");
    assert_eq!(
        fs::read(record_file(root.path(), COMPLETED_ID)).unwrap(),
        completed_before
    );
}

#[test]
fn unknown_owner_is_not_dead() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let record = record_by_id(&fixtures(), ACTIVE_ID);
    store.insert(&record).unwrap();
    let before = fs::read(record_file(root.path(), ACTIVE_ID)).unwrap();
    let probe = FixedProbe {
        state: OwnerState::Unknown,
        seen: Mutex::new(Vec::new()),
    };

    assert_eq!(store.recover_abandoned(&probe).unwrap(), 0);
    let kept = store.get(ACTIVE_ID).unwrap();
    assert_eq!(kept.status, "active");
    assert_eq!(kept.ended_at_utc_ms, None);
    assert_eq!(
        fs::read(record_file(root.path(), ACTIVE_ID)).unwrap(),
        before
    );

    let alive = FixedProbe {
        state: OwnerState::Alive,
        seen: Mutex::new(Vec::new()),
    };
    assert_eq!(store.recover_abandoned(&alive).unwrap(), 0);
    assert_eq!(store.get(ACTIVE_ID).unwrap().status, "active");
}

#[test]
fn future_schema_preserved() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let good = record_by_id(&fixtures(), COMPLETED_ID);
    store.insert(&good).unwrap();
    let future_id = "44444444-4444-4444-8444-444444444444";
    let future_path = record_file(root.path(), future_id);
    let future_bytes = b"{\n  \"schema\": 2,\n  \"record_id\": \"44444444-4444-4444-8444-444444444444\",\n  \"extra\": true\n}\n";
    fs::write(&future_path, future_bytes).unwrap();

    let page = store
        .query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(page.total, 1);
    assert_eq!(page.records[0].record_id, COMPLETED_ID);
    assert_eq!(page.warnings, vec!["future_schema".to_string()]);
    assert_eq!(fs::read(&future_path).unwrap(), future_bytes);

    assert!(matches!(
        store.save_note(future_id, 0, "پیگیری فردا"),
        Err(HistoryError::FutureSchema)
    ));
    assert!(matches!(
        store.checkpoint(future_id, 1, 1),
        Err(HistoryError::FutureSchema)
    ));
    assert!(matches!(
        store.finish(future_id, 1, 1),
        Err(HistoryError::FutureSchema)
    ));
    assert!(matches!(
        store.get(future_id),
        Err(HistoryError::FutureSchema)
    ));
    assert_eq!(fs::read(&future_path).unwrap(), future_bytes);

    let mut duplicate = good.clone();
    duplicate.record_id = future_id.to_string();
    assert!(matches!(
        store.insert(&duplicate),
        Err(HistoryError::InvalidInput)
    ));
    assert_eq!(fs::read(&future_path).unwrap(), future_bytes);
    assert_no_temp_files(root.path());
}

#[test]
fn corrupt_sibling_does_not_hide_good_record() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let good = record_by_id(&fixtures(), COMPLETED_ID);
    store.insert(&good).unwrap();
    let good_bytes = fs::read(record_file(root.path(), COMPLETED_ID)).unwrap();

    let garbage_path = root.path().join("not-a-uuid.json");
    let garbage = b"\xff\xfe{";
    fs::write(&garbage_path, garbage).unwrap();
    let mismatch_id = "55555555-5555-4555-8555-555555555555";
    let mismatch_path = record_file(root.path(), mismatch_id);
    let mismatch = b"{\"schema\":1,\"record_id\":\"11111111-1111-4111-8111-111111111111\"}\n";
    fs::write(&mismatch_path, mismatch).unwrap();

    let page = store
        .query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(page.total, 1);
    assert_eq!(page.records[0].record_id, COMPLETED_ID);
    assert_eq!(page.records[0].note, good.note);
    assert_eq!(page.warnings, vec!["unreadable_records".to_string()]);
    assert_eq!(
        fs::read(record_file(root.path(), COMPLETED_ID)).unwrap(),
        good_bytes
    );
    assert_eq!(fs::read(&garbage_path).unwrap(), garbage);
    assert_eq!(fs::read(&mismatch_path).unwrap(), mismatch);
}

#[test]
fn failed_replace_keeps_previous_record() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let file = fixtures();
    let primary = record_by_id(&file, COMPLETED_ID);
    let sibling = record_by_id(&file, ACTIVE_ID);
    store.insert(&primary).unwrap();
    store.insert(&sibling).unwrap();
    store.save_note(COMPLETED_ID, 0, "پیگیری فردا").unwrap();
    let primary_bytes = fs::read(record_file(root.path(), COMPLETED_ID)).unwrap();
    let sibling_bytes = fs::read(record_file(root.path(), ACTIVE_ID)).unwrap();

    for fault in [
        HistoryFault::CreateTemp,
        HistoryFault::Write,
        HistoryFault::Flush,
        HistoryFault::Replace,
    ] {
        let _fault = FaultGuard::arm(fault);
        let err = store.checkpoint(ACTIVE_ID, 90_000, sibling.checkpoint_at_utc_ms + 1);
        assert!(matches!(err, Err(HistoryError::Io)), "{fault:?}");
        let mut extra = primary.clone();
        extra.record_id = "66666666-6666-4666-8666-666666666666".to_string();
        assert!(matches!(store.insert(&extra), Err(HistoryError::Io)));
        assert!(!record_file(root.path(), &extra.record_id).exists());
        assert_eq!(
            fs::read(record_file(root.path(), COMPLETED_ID)).unwrap(),
            primary_bytes
        );
        assert_eq!(
            fs::read(record_file(root.path(), ACTIVE_ID)).unwrap(),
            sibling_bytes
        );
        assert_no_temp_files(root.path());
    }

    let page = store
        .query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(page.total, 2);
    assert!(page.warnings.is_empty());
    assert_eq!(store.get(COMPLETED_ID).unwrap().note, "پیگیری فردا");
    assert_eq!(store.get(ACTIVE_ID).unwrap().elapsed_ms, 30_000);
}

#[test]
fn note_scalar_limits_and_blank_clearing() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    store
        .insert(&record_by_id(&fixtures(), COMPLETED_ID))
        .unwrap();

    let accepted = "\u{1F600}".repeat(2000);
    assert_eq!(accepted.chars().count(), 2000);
    let saved = store.save_note(COMPLETED_ID, 0, &accepted).unwrap();
    assert_eq!(saved.note.chars().count(), 2000);
    assert_eq!(saved.note, accepted);
    assert_eq!(saved.note_revision, 1);

    let rejected = "\u{1F600}".repeat(2001);
    assert_eq!(rejected.chars().count(), 2001);
    assert!(matches!(
        store.save_note(COMPLETED_ID, 1, &rejected),
        Err(HistoryError::InvalidInput)
    ));
    assert_eq!(store.get(COMPLETED_ID).unwrap().note, accepted);
    assert_eq!(store.get(COMPLETED_ID).unwrap().note_revision, 1);

    let cleared = store.save_note(COMPLETED_ID, 1, "").unwrap();
    assert_eq!(cleared.note, "");
    assert_eq!(cleared.note_revision, 2);
    let blank = store.save_note(COMPLETED_ID, 2, " \r\n\t ").unwrap();
    assert_eq!(blank.note, "");
    assert_eq!(blank.note_revision, 2);
    assert!(matches!(
        store.save_note(COMPLETED_ID, 2, "bad\u{0001}text"),
        Err(HistoryError::InvalidInput)
    ));
    let normalized = store.save_note(COMPLETED_ID, 2, "a\r\nb").unwrap();
    assert_eq!(normalized.note, "a\nb");
    assert_eq!(normalized.note_revision, 3);
    let same = store.save_note(COMPLETED_ID, 3, "a\nb").unwrap();
    assert_eq!(same.note, "a\nb");
    assert_eq!(same.note_revision, 3);
    let spaced = store.save_note(COMPLETED_ID, 3, " سلام").unwrap();
    assert_eq!(spaced.note, " سلام");
    assert_eq!(spaced.note_revision, 4);
}

#[test]
fn fixtures_round_trip() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let file = fixtures();
    for record in &file.records {
        store.insert(record).unwrap();
        assert_eq!(store.get(&record.record_id).unwrap(), *record);
    }

    for query in &file.queries {
        let page = store.query(&query.input).unwrap();
        assert_eq!(page.total, query.expected_total, "{}", query.id);
        let ids: Vec<_> = page
            .records
            .iter()
            .map(|record| record.record_id.as_str())
            .collect();
        assert_eq!(ids, query.expected_ids, "{}", query.id);
        assert!(page.warnings.is_empty(), "{}", query.id);
    }

    let today = file
        .queries
        .iter()
        .find(|query| query.id == "today")
        .unwrap();
    let page = store.query(&today.input).unwrap();
    assert_eq!(page.total, 2);
    assert_eq!(page.records[0].connection_type, "file_transfer");
    let mut second_page = today.input.clone();
    second_page.offset = 1;
    second_page.limit = 1;
    let page = store.query(&second_page).unwrap();
    assert_eq!(page.total, 2);
    assert_eq!(page.records.len(), 1);
    assert_eq!(page.records[0].record_id, COMPLETED_ID);

    for step in &file.note_steps {
        let result = store.save_note(&step.record_id, step.expected_revision, &step.note);
        if step.error.as_deref() == Some("note_conflict") {
            assert!(matches!(result, Err(HistoryError::NoteConflict)));
        } else {
            let saved = result.expect("fixture note step");
            assert_eq!(saved.note_revision, step.result_revision.unwrap());
            assert_eq!(saved.note, step.note);
        }
    }
    assert_eq!(store.get(COMPLETED_ID).unwrap().note, "");
    assert_eq!(store.get(COMPLETED_ID).unwrap().note_revision, 2);
}

#[test]
fn search_normalizes_digits_and_arabic_letters_without_changing_display() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let mut record = record_by_id(&fixtures(), COMPLETED_ID);
    record.peer_name = "یک شرکت".to_string();
    record.note = "unique-note-token".to_string();
    store.insert(&record).unwrap();

    let arabic_query = "\u{064A}\u{0643} \u{0634}\u{0631}\u{0643}\u{062A}";
    let page = store
        .query(&HistoryQuery {
            search: arabic_query.to_string(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(page.total, 1);
    assert_eq!(page.records[0].peer_name, "یک شرکت");

    let maksura = store
        .query(&HistoryQuery {
            search: "\u{0649}\u{06A9}".to_string(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(maksura.total, 1);

    let digits = store
        .query(&HistoryQuery {
            search: "\u{0661}\u{0662}\u{0663} \u{0664}\u{0665}\u{0666}".to_string(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(digits.total, 1);
    assert_eq!(digits.records[0].peer_id, "123456789");

    let note_only = store
        .query(&HistoryQuery {
            search: "unique-note-token".to_string(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(note_only.total, 0);
    assert_eq!(store.get(COMPLETED_ID).unwrap().peer_name, "یک شرکت");
    assert_eq!(store.get(COMPLETED_ID).unwrap().note, "unique-note-token");
}

#[test]
fn finish_is_idempotent_and_keeps_note() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let record = record_by_id(&fixtures(), ACTIVE_ID);
    store.insert(&record).unwrap();
    store.save_note(ACTIVE_ID, 0, "پیگیری فردا").unwrap();

    store
        .finish(ACTIVE_ID, 45_000, record.started_at_utc_ms - 5_000)
        .unwrap();
    let finished = store.get(ACTIVE_ID).unwrap();
    assert_eq!(finished.status, "completed");
    assert_eq!(
        finished.ended_at_utc_ms,
        Some(record.started_at_utc_ms - 5_000)
    );
    assert_eq!(finished.elapsed_ms, 45_000);
    assert_eq!(finished.note, "پیگیری فردا");
    assert_eq!(finished.note_revision, 1);
    let bytes = fs::read(record_file(root.path(), ACTIVE_ID)).unwrap();

    store
        .finish(ACTIVE_ID, 1, record.started_at_utc_ms + 9_000)
        .unwrap();
    store
        .checkpoint(ACTIVE_ID, 99_000, record.started_at_utc_ms + 9_000)
        .unwrap();
    assert_eq!(
        fs::read(record_file(root.path(), ACTIVE_ID)).unwrap(),
        bytes
    );
    let kept = store.get(ACTIVE_ID).unwrap();
    assert_eq!(kept.note, "پیگیری فردا");
    assert_eq!(kept.elapsed_ms, 45_000);
    assert_eq!(kept.ended_at_utc_ms, Some(record.started_at_utc_ms - 5_000));
}

#[test]
fn insert_validates_record_and_query_limits() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let mut record = record_by_id(&fixtures(), ACTIVE_ID);
    store.insert(&record).unwrap();
    assert!(matches!(
        store.insert(&record),
        Err(HistoryError::InvalidInput)
    ));

    record.record_id = "22222222-2222-4222-8222-222222222222".to_uppercase();
    assert!(matches!(
        store.insert(&record),
        Err(HistoryError::InvalidInput)
    ));
    record.record_id = "22222222-2222-1222-8222-222222222222".to_string();
    assert!(matches!(
        store.insert(&record),
        Err(HistoryError::InvalidInput)
    ));

    let mut created = record_by_id(&fixtures(), COMPLETED_ID);
    created.ended_at_utc_ms = Some(created.started_at_utc_ms - 1);
    store.insert(&created).unwrap();
    assert_eq!(
        store.get(COMPLETED_ID).unwrap().ended_at_utc_ms,
        Some(created.started_at_utc_ms - 1)
    );

    for kind in [
        "desktop",
        "file_transfer",
        "port_forward",
        "rdp",
        "camera",
        "terminal",
    ] {
        let mut typed = record_by_id(&fixtures(), ACTIVE_ID);
        typed.connection_type = kind.to_string();
        typed.record_id = match kind {
            "desktop" => "77777777-7777-4777-8777-777777777771",
            "file_transfer" => "77777777-7777-4777-8777-777777777772",
            "port_forward" => "77777777-7777-4777-8777-777777777773",
            "rdp" => "77777777-7777-4777-8777-777777777774",
            "camera" => "77777777-7777-4777-8777-777777777775",
            "terminal" => "77777777-7777-4777-8777-777777777776",
            _ => unreachable!(),
        }
        .to_string();
        typed.ended_at_utc_ms = None;
        typed.status = "active".to_string();
        store.insert(&typed).unwrap();
        assert_eq!(store.get(&typed.record_id).unwrap().connection_type, kind);
    }

    let mut bounds = record_by_id(&fixtures(), "33333333-3333-4333-8333-333333333333");
    bounds.record_id = "88888888-8888-4888-8888-888888888888".to_string();
    bounds.peer_id = "a".repeat(1024);
    bounds.peer_name = "ب".repeat(512);
    store.insert(&bounds).unwrap();
    bounds.record_id = "88888888-8888-4888-8888-888888888889".to_string();
    bounds.peer_id = "a".repeat(1025);
    assert!(matches!(
        store.insert(&bounds),
        Err(HistoryError::InvalidInput)
    ));
    bounds.peer_id = "id".to_string();
    bounds.peer_name = "ب".repeat(513);
    assert!(matches!(
        store.insert(&bounds),
        Err(HistoryError::InvalidInput)
    ));
    bounds.peer_name.clear();
    bounds.peer_id.clear();
    assert!(matches!(
        store.insert(&bounds),
        Err(HistoryError::InvalidInput)
    ));
    bounds.peer_id = "id".to_string();
    bounds.status = "active".to_string();
    bounds.ended_at_utc_ms = Some(1);
    assert!(matches!(
        store.insert(&bounds),
        Err(HistoryError::InvalidInput)
    ));

    assert!(matches!(
        store.query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: Some(20),
            to_utc_ms: Some(20),
            offset: 0,
            limit: 20,
        }),
        Err(HistoryError::InvalidInput)
    ));
    assert!(matches!(
        store.query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: Some(30),
            to_utc_ms: Some(10),
            offset: 0,
            limit: 20,
        }),
        Err(HistoryError::InvalidInput)
    ));
    assert!(matches!(
        store.query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 0,
        }),
        Err(HistoryError::InvalidInput)
    ));
    assert!(matches!(
        store.query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 101,
        }),
        Err(HistoryError::InvalidInput)
    ));
    assert!(matches!(
        store.query(&HistoryQuery {
            search: "ن".repeat(257),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        }),
        Err(HistoryError::InvalidInput)
    ));
    assert!(store
        .query(&HistoryQuery {
            search: "ن".repeat(256),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 100,
        })
        .is_ok());

    let file_root = root.path().join("not-a-directory");
    fs::write(&file_root, b"x").unwrap();
    assert!(matches!(
        HistoryStore::open(file_root),
        Err(HistoryError::Io)
    ));
}

#[test]
fn windows_owner_probe_creation_time() {
    let _guard = lock_tests();
    let probe = WindowsOwnerProbe;
    let pid = std::process::id();
    let ticks = process_creation_filetime(pid).expect("current process creation time");
    assert_eq!(probe.state(pid, ticks), OwnerState::Alive);
    assert_eq!(probe.state(pid, ticks.wrapping_add(1)), OwnerState::Dead);

    let mut child = Command::new(std::env::var("COMSPEC").unwrap_or_else(|_| "cmd.exe".into()))
        .args(["/C", "exit"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("spawn exited process");
    let exited = child.id();
    child.wait().unwrap();
    assert_eq!(probe.state(exited, 1), OwnerState::Dead);
}

#[test]
fn same_start_sorts_by_record_id() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = open_store(root.path());
    let mut newer = record_by_id(&fixtures(), ACTIVE_ID);
    let mut older_id = newer.clone();
    older_id.record_id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa".to_string();
    newer.record_id = "ffffffff-ffff-4fff-8fff-ffffffffffff".to_string();
    newer.started_at_utc_ms = 50;
    older_id.started_at_utc_ms = 50;
    store.insert(&newer).unwrap();
    store.insert(&older_id).unwrap();
    let page = store
        .query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .unwrap();
    assert_eq!(
        page.records
            .iter()
            .map(|record| record.record_id.as_str())
            .collect::<Vec<_>>(),
        vec![
            "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            "ffffffff-ffff-4fff-8fff-ffffffffffff"
        ]
    );
}

fn test_owner() -> OwnerIdentity {
    OwnerIdentity {
        pid: 424_242,
        started_at: 64,
    }
}

fn page_records(store: &HistoryStore) -> Vec<HistoryRecord> {
    store
        .query(&HistoryQuery {
            search: String::new(),
            from_utc_ms: None,
            to_utc_ms: None,
            offset: 0,
            limit: 20,
        })
        .expect("query history")
        .records
}

fn manual_clocks(wall_ms: i64, monotonic_ms: u64) -> (Arc<AtomicI64>, Arc<AtomicU64>) {
    (
        Arc::new(AtomicI64::new(wall_ms)),
        Arc::new(AtomicU64::new(monotonic_ms)),
    )
}

fn start_at(
    store: &Arc<HistoryStore>,
    peer_id: &str,
    peer_name: &str,
    connection_type: &str,
    wall_ms: &Arc<AtomicI64>,
    monotonic_ms: &Arc<AtomicU64>,
) -> Result<HistoryInterval, HistoryError> {
    HistoryInterval::start_with_clock(
        store.clone(),
        peer_id.to_owned(),
        peer_name.to_owned(),
        connection_type.to_owned(),
        test_owner(),
        wall_ms.clone(),
        monotonic_ms.clone(),
    )
}

#[test]
fn unauthenticated_transport_has_no_history() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let slot = None;
    assert!(page_records(&store).is_empty());
    note_login_failure(&slot);
    note_approval_canceled(&slot);
    assert!(slot.is_none());
    assert!(page_records(&store).is_empty());
}

#[test]
fn duplicate_peer_info_one_record() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(1_700_000_000_000, 0);
    let mut slot = None;
    assert!(page_records(&store).is_empty());
    let mut creates = 0u32;
    admit_peer_info(&mut slot, 4, || {
        creates += 1;
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    admit_peer_info(&mut slot, 4, || {
        creates += 1;
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    assert_eq!(creates, 1);
    let records = page_records(&store);
    assert_eq!(records.len(), 1);
    assert_eq!(records[0].status, "active");
    assert_eq!(records[0].record_id, slot.as_ref().unwrap().1.record_id());
    assert_eq!(slot.as_ref().unwrap().0, 4);
}

#[test]
fn stale_disconnect_leaves_new_round_active() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(1_700_000_000_000, 0);
    let mut old_round = None;
    let mut new_round = None;
    admit_peer_info(&mut old_round, 1, || {
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    mono.store(5_000, Ordering::SeqCst);
    wall.fetch_add(5_000, Ordering::SeqCst);
    admit_peer_info(&mut new_round, 2, || {
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    let old_id = old_round.as_ref().unwrap().1.record_id().to_owned();
    let new_id = new_round.as_ref().unwrap().1.record_id().to_owned();
    finish_round(&mut new_round, 1).unwrap();
    assert!(new_round.is_some());
    assert_eq!(store.get(&new_id).unwrap().status, "active");
    finish_round(&mut old_round, 1).unwrap();
    assert!(old_round.is_none());
    assert_eq!(store.get(&old_id).unwrap().status, "completed");
    assert_eq!(store.get(&new_id).unwrap().status, "active");
    assert_ne!(old_id, new_id);
}

#[test]
fn reconnect_excludes_wait_time() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(1_700_000_000_000, 0);
    let mut first = None;
    admit_peer_info(&mut first, 1, || {
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    mono.store(30_000, Ordering::SeqCst);
    wall.fetch_add(30_000, Ordering::SeqCst);
    finish_round(&mut first, 1).unwrap();

    mono.store(90_000, Ordering::SeqCst);
    wall.fetch_add(60_000, Ordering::SeqCst);
    let mut second = None;
    admit_peer_info(&mut second, 2, || {
        start_at(&store, "123456", "Desk", "file_transfer", &wall, &mono)
    })
    .unwrap();
    mono.store(110_000, Ordering::SeqCst);
    wall.fetch_add(20_000, Ordering::SeqCst);
    finish_round(&mut second, 2).unwrap();

    let records = page_records(&store);
    assert_eq!(records.len(), 2);
    let durations: Vec<u64> = records.iter().map(|record| record.elapsed_ms).collect();
    assert_eq!(durations, vec![20_000, 30_000]);
    assert!(durations.iter().all(|elapsed| *elapsed != 110_000));
}

#[test]
fn port_forward_logs_each_authenticated_transport() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(1_700_000_000_000, 0);
    let listener = None::<(u32, HistoryInterval)>;
    assert!(listener.is_none());
    assert!(page_records(&store).is_empty());
    let mut first = None;
    let mut second = None;
    admit_peer_info(&mut first, 1, || {
        start_at(
            &store,
            "123456",
            &snapshot_peer_name("Alias", "host", "123456"),
            "port_forward",
            &wall,
            &mono,
        )
    })
    .unwrap();
    admit_peer_info(&mut second, 2, || {
        start_at(
            &store,
            "123456",
            &snapshot_peer_name("", "host-b", "123456"),
            "port_forward",
            &wall,
            &mono,
        )
    })
    .unwrap();
    let left = store.get(first.as_ref().unwrap().1.record_id()).unwrap();
    let right = store.get(second.as_ref().unwrap().1.record_id()).unwrap();
    assert_ne!(left.record_id, right.record_id);
    assert_eq!(left.peer_id, "123456");
    assert_eq!(right.peer_id, "123456");
    assert_eq!(left.connection_type, "port_forward");
    assert_eq!(right.connection_type, "port_forward");
    assert_eq!(left.peer_name, "Alias");
    assert_eq!(right.peer_name, "host-b");
    assert_eq!(snapshot_peer_name("", "", "123456"), "123456");
    assert_eq!(page_records(&store).len(), 2);
}

#[test]
fn drop_or_error_finalizes_interval() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(1_700_000_000_000, 0);
    let error_id = {
        let mut slot = None;
        admit_peer_info(&mut slot, 8, || {
            start_at(&store, "123456", "Desk", "terminal", &wall, &mono)
        })
        .unwrap();
        let id = slot.as_ref().unwrap().1.record_id().to_owned();
        mono.store(4_000, Ordering::SeqCst);
        finish_round(&mut slot, 8).unwrap();
        finish_round(&mut slot, 8).unwrap();
        id
    };
    let errored = store.get(&error_id).unwrap();
    assert_eq!(errored.status, "completed");
    assert_eq!(errored.elapsed_ms, 4_000);
    assert!(errored.ended_at_utc_ms.is_some());

    mono.store(10_000, Ordering::SeqCst);
    let dropped_id = {
        let mut slot = None;
        admit_peer_info(&mut slot, 9, || {
            start_at(&store, "123456", "Desk", "camera", &wall, &mono)
        })
        .unwrap();
        let id = slot.as_ref().unwrap().1.record_id().to_owned();
        mono.store(12_000, Ordering::SeqCst);
        drop(slot);
        id
    };
    let dropped = store.get(&dropped_id).unwrap();
    assert_eq!(dropped.status, "completed");
    assert_eq!(dropped.elapsed_ms, 2_000);

    let system = HistoryInterval::start(
        store.clone(),
        "123456".to_owned(),
        String::new(),
        "desktop".to_owned(),
        test_owner(),
    )
    .unwrap();
    let system_id = system.record_id().to_owned();
    system.finish().unwrap();
    let system_record = store.get(&system_id).unwrap();
    assert_eq!(system_record.peer_name, "123456");
    assert_eq!(system_record.status, "completed");
}

#[test]
fn wall_clock_rollback_keeps_elapsed() {
    let _guard = lock_tests();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(50_000, 0);
    let mut slot = None;
    admit_peer_info(&mut slot, 1, || {
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    mono.store(20_000, Ordering::SeqCst);
    slot.as_ref().unwrap().1.checkpoint().unwrap();
    assert_eq!(
        store
            .get(slot.as_ref().unwrap().1.record_id())
            .unwrap()
            .elapsed_ms,
        20_000
    );

    wall.store(1_000, Ordering::SeqCst);
    mono.store(25_000, Ordering::SeqCst);
    slot.as_ref().unwrap().1.checkpoint().unwrap();
    let rolled = store.get(slot.as_ref().unwrap().1.record_id()).unwrap();
    assert_eq!(rolled.started_at_utc_ms, 50_000);
    assert_eq!(rolled.elapsed_ms, 25_000);
    assert!(rolled.elapsed_ms >= 20_000);

    wall.store(500, Ordering::SeqCst);
    finish_round(&mut slot, 1).unwrap();
    let finished = page_records(&store);
    assert_eq!(finished.len(), 1);
    assert_eq!(finished[0].elapsed_ms, 25_000);
    assert_eq!(finished[0].status, "completed");
    assert_eq!(finished[0].ended_at_utc_ms, Some(500));
    assert!(finished[0].ended_at_utc_ms.unwrap() < finished[0].started_at_utc_ms);
}

#[test]
fn failed_insert_retries_same_record() {
    let _guard = lock_tests();
    clear_history_warning();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(80_000, 0);
    let interval = {
        let _fault = FaultGuard::arm(HistoryFault::CreateTemp);
        let started = HistoryInterval::start_with_clock(
            store.clone(),
            "123456".to_owned(),
            "Desk".to_owned(),
            "rdp".to_owned(),
            test_owner(),
            wall.clone(),
            mono.clone(),
        )
        .expect("interval stays in memory when the first insert fails");
        assert!(matches!(
            store.get(started.record_id()),
            Err(HistoryError::NotFound)
        ));
        started
    };
    let id = interval.record_id().to_owned();
    let warning = history_save_warning(&id).expect("save warning");
    assert_eq!(warning.text, HISTORY_SAVE_WARNING_TEXT);
    assert_eq!(warning.action, HISTORY_SAVE_WARNING_ACTION);
    assert_eq!(warning.record_id, id);
    mono.store(3_000, Ordering::SeqCst);
    retry_history_save(&id).unwrap();
    let stored = store.get(&id).unwrap();
    assert_eq!(stored.record_id, id);
    assert_eq!(stored.started_at_utc_ms, 80_000);
    assert_eq!(stored.elapsed_ms, 3_000);
    assert_eq!(stored.status, "active");
    assert_eq!(stored.connection_type, "rdp");
    assert!(history_save_warning(&id).is_none());
}

fn clear_history_warning() {
    super::history::set_history_status_hook(record_status);
    STATUS_LOG.lock().unwrap().clear();
    super::history::reset_history_sessions();
}

fn record_status(key: &str, show: bool, text: &str, action: &str) {
    STATUS_LOG
        .lock()
        .unwrap()
        .push((key.to_owned(), show, text.to_owned(), action.to_owned()));
}

static STATUS_LOG: Mutex<Vec<(String, bool, String, String)>> = Mutex::new(Vec::new());

#[test]
fn failed_open_does_not_publish_cell_and_later_open_does() {
    let _guard = lock_tests();
    clear_history_warning();
    let source = include_str!("history.rs");
    assert!(
        !source.contains("get_or_try_init"),
        "OnceLock::get_or_try_init is not in Rust 1.75"
    );
    assert!(
        source.contains("get_or_init("),
        "publish the opened store with get_or_init"
    );

    let slot = OnceLock::new();
    let root = TempRoot::new();
    let empty = super::history::open_history_store(&slot, "open-empty", true, || {
        Ok(Arc::new(open_store(root.path())))
    });
    assert!(matches!(empty, Err(HistoryError::Io)));
    assert!(slot.get().is_none());
    let warning = history_save_warning("open-empty").expect("empty path warns");
    assert_eq!(warning.text, HISTORY_SAVE_WARNING_TEXT);
    assert_eq!(warning.action, HISTORY_SAVE_WARNING_ACTION);
    assert!(warning.record_id.is_empty());

    let blocked = root.path().join("not-a-directory");
    fs::write(&blocked, b"x").unwrap();
    let failed = super::history::open_history_store(&slot, "open-a", false, || {
        HistoryStore::open(blocked.clone()).map(Arc::new)
    });
    assert!(matches!(failed, Err(HistoryError::Io)));
    assert!(slot.get().is_none());
    assert!(history_save_warning("open-empty").is_some());
    assert!(history_save_warning("open-a").is_some());

    let opened = super::history::open_history_store(&slot, "open-a", false, || {
        Ok(Arc::new(open_store(root.path())))
    })
    .expect("later open publishes");
    assert!(slot.get().is_some());
    let again =
        super::history::open_history_store(&slot, "open-b", false, || Err(HistoryError::Io))
            .expect("filled cell does not reopen");
    assert!(Arc::ptr_eq(&opened, &again));
    assert!(history_save_warning("open-b").is_none());
    assert!(history_save_warning("open-a").is_some());
    assert!(STATUS_LOG.lock().unwrap().iter().any(|event| {
        event.0 == "open-empty"
            && event.1
            && event.2 == HISTORY_SAVE_WARNING_TEXT
            && event.3 == HISTORY_SAVE_WARNING_ACTION
    }));
    super::history::clear_history_save_warning("open-a");
    assert!(history_save_warning("open-a").is_none());
    assert!(history_save_warning("open-empty").is_some());
    assert!(STATUS_LOG
        .lock()
        .unwrap()
        .iter()
        .any(|event| { event.0 == "open-a" && !event.1 && event.2.is_empty() }));
}

#[test]
fn failed_finish_stays_retryable_with_same_record() {
    let _guard = lock_tests();
    clear_history_warning();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let (wall, mono) = manual_clocks(90_000, 0);
    let mut slot = None;
    admit_peer_info(&mut slot, 3, || {
        start_at(&store, "123456", "Desk", "desktop", &wall, &mono)
    })
    .unwrap();
    let id = slot.as_ref().unwrap().1.record_id().to_owned();
    let key = slot.as_ref().unwrap().1.session_key().to_owned();
    mono.store(5_000, Ordering::SeqCst);
    {
        let _fault = FaultGuard::arm(HistoryFault::Replace);
        let err = finish_round(&mut slot, 3);
        assert!(err.is_err(), "finish failure stays with the interval");
    }
    assert!(slot.is_some(), "failed finish does not drop the interval");
    assert_eq!(slot.as_ref().unwrap().1.record_id(), id);
    let still = store.get(&id).unwrap();
    assert_eq!(still.status, "active");
    assert_eq!(still.started_at_utc_ms, 90_000);
    assert_eq!(still.record_id, id);

    mono.store(50_000, Ordering::SeqCst);
    wall.store(1, Ordering::SeqCst);
    retry_history_save(&key).expect("same interval can finish again");
    let done = store.get(&id).unwrap();
    assert_eq!(done.record_id, id);
    assert_eq!(done.started_at_utc_ms, 90_000);
    assert_eq!(done.status, "completed");
    assert_eq!(done.elapsed_ms, 5_000);
    assert!(history_save_warning(&key).is_none());
}

#[test]
fn warning_is_per_session_and_retry_reopens() {
    let _guard = lock_tests();
    clear_history_warning();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let cell = Arc::new(OnceLock::new());
    let fail_open = Arc::new(AtomicBool::new(true));
    let cell_open = cell.clone();
    let fail_flag = fail_open.clone();
    let store_open = store.clone();
    let open: Arc<dyn Fn() -> Result<Arc<HistoryStore>, HistoryError> + Send + Sync> =
        Arc::new(move || {
            let cell_open = cell_open.clone();
            let fail_flag = fail_flag.clone();
            let store_open = store_open.clone();
            super::history::open_history_store(&cell_open, "sess-a", false, || {
                if fail_flag.swap(false, Ordering::SeqCst) {
                    Err(HistoryError::Io)
                } else {
                    Ok(store_open.clone())
                }
            })
        });
    let started = super::history::begin_for_session(
        "sess-a",
        "123456".to_owned(),
        "Desk".to_owned(),
        "desktop".to_owned(),
        test_owner(),
        open.clone(),
        None,
    );
    assert!(started.is_err());
    assert!(cell.get().is_none());
    let warning = history_save_warning("sess-a").expect("open failure warns");
    assert!(warning.record_id.is_empty());
    assert_eq!(warning.text, HISTORY_SAVE_WARNING_TEXT);

    let missing = super::history::begin_for_session(
        "sess-missing",
        "123456".to_owned(),
        "Desk".to_owned(),
        "desktop".to_owned(),
        OwnerIdentity {
            pid: 7,
            started_at: 0,
        },
        open.clone(),
        None,
    );
    assert!(matches!(missing, Err(HistoryError::Io)));
    assert!(history_save_warning("sess-a").is_some());
    assert!(history_save_warning("sess-missing").is_some());
    let missing_retry = retry_history_save("sess-missing");
    assert!(matches!(missing_retry, Err(HistoryError::Io)));
    assert!(!matches!(missing_retry, Err(HistoryError::InvalidInput)));

    let bad = super::history::begin_for_session(
        "sess-bad",
        String::new(),
        "Desk".to_owned(),
        "desktop".to_owned(),
        test_owner(),
        open.clone(),
        None,
    );
    assert!(matches!(bad, Err(HistoryError::InvalidInput)));
    assert!(cell.get().is_none());
    assert!(history_save_warning("sess-a").is_some());
    assert!(history_save_warning("sess-bad").is_some());
    assert!(history_save_warning("sess-missing").is_some());

    retry_history_save("sess-a").expect("retry opens and starts");
    assert!(cell.get().is_some());
    assert!(history_save_warning("sess-a").is_none());
    assert!(history_save_warning("sess-bad").is_some());
    assert!(history_save_warning("sess-missing").is_some());
    let bad_again = retry_history_save("sess-bad");
    assert!(matches!(bad_again, Err(HistoryError::InvalidInput)));
    assert!(history_save_warning("sess-bad").is_some());

    let store_ok = store.clone();
    let open_ok: Arc<dyn Fn() -> Result<Arc<HistoryStore>, HistoryError> + Send + Sync> =
        Arc::new(move || Ok(store_ok.clone()));
    let created = super::history::begin_for_session(
        "sess-ok",
        "123456".to_owned(),
        "Desk".to_owned(),
        "file_transfer".to_owned(),
        test_owner(),
        open_ok.clone(),
        None,
    )
    .expect("clean start");
    assert!(created.is_some());
    assert!(history_save_warning("sess-ok").is_none());
    assert!(history_save_warning("sess-bad").is_some());

    let saved_c = {
        let _fault = FaultGuard::arm(HistoryFault::CreateTemp);
        super::history::begin_for_session(
            "sess-c",
            "123456".to_owned(),
            "Desk".to_owned(),
            "camera".to_owned(),
            test_owner(),
            open_ok.clone(),
            None,
        )
        .expect("interval stays after a failed insert")
    };
    let saved_d = {
        let _fault = FaultGuard::arm(HistoryFault::CreateTemp);
        super::history::begin_for_session(
            "sess-d",
            "654321".to_owned(),
            "Other".to_owned(),
            "terminal".to_owned(),
            test_owner(),
            open_ok,
            None,
        )
        .expect("second session keeps its own failure")
    };
    let id_c = saved_c.as_ref().unwrap().record_id().to_owned();
    let id_d = saved_d.as_ref().unwrap().record_id().to_owned();
    assert!(history_save_warning("sess-c").is_some());
    assert_eq!(history_save_warning("sess-d").unwrap().record_id, id_d);
    retry_history_save("sess-c").unwrap();
    assert!(history_save_warning("sess-c").is_none());
    assert_eq!(history_save_warning("sess-d").unwrap().record_id, id_d);
    assert_eq!(store.get(&id_c).unwrap().status, "active");
    assert!(matches!(store.get(&id_d), Err(HistoryError::NotFound)));
    assert!(history_save_warning("sess-bad").is_some());
    super::history::finish_session("sess-a").unwrap();
    super::history::finish_session("sess-ok").unwrap();
    super::history::finish_session("sess-c").unwrap();
    super::history::finish_session("sess-d").unwrap();
}

fn open_after_one_failure(
    session_key: &str,
    store: Arc<HistoryStore>,
) -> Arc<dyn Fn() -> Result<Arc<HistoryStore>, HistoryError> + Send + Sync> {
    let cell = Arc::new(OnceLock::new());
    let fail_once = Arc::new(AtomicBool::new(true));
    let key = session_key.to_owned();
    Arc::new(move || {
        let cell = cell.clone();
        let fail_once = fail_once.clone();
        let store = store.clone();
        let key = key.clone();
        super::history::open_history_store(&cell, &key, false, || {
            if fail_once.swap(false, Ordering::SeqCst) {
                Err(HistoryError::Io)
            } else {
                Ok(store.clone())
            }
        })
    })
}

fn retry_after_failed_open(
    session_key: &str,
    peer_id: &str,
    connection_type: &str,
) -> (TempRoot, Arc<HistoryStore>, HistoryRecord) {
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let open = open_after_one_failure(session_key, store.clone());
    let failed = super::history::begin_for_session(
        session_key,
        peer_id.to_owned(),
        "Desk".to_owned(),
        connection_type.to_owned(),
        test_owner(),
        open,
        None,
    );
    assert!(failed.is_err(), "first open fails before a record exists");
    assert!(page_records(&store).is_empty());
    retry_history_save(session_key).expect("retry creates one interval");
    let records = page_records(&store);
    assert_eq!(records.len(), 1, "retry inserts one record");
    assert_eq!(records[0].status, "active");
    assert_eq!(records[0].peer_id, peer_id);
    assert_eq!(records[0].connection_type, connection_type);
    assert!(history_save_warning(session_key).is_none());
    let inserted = records.into_iter().next().unwrap();
    (root, store, inserted)
}

#[test]
fn retried_interval_adopts_into_empty_transport_slot() {
    let _guard = lock_tests();
    clear_history_warning();
    let (round_root, round_store, inserted) =
        retry_after_failed_open("sess-round", "123456", "desktop");
    assert!(super::history::session_index_holds_live_interval(
        "sess-round"
    ));
    assert!(!super::history::session_index_holds_strong_owner(
        "sess-round"
    ));
    let mut round_slot: Option<(u32, HistoryInterval)> = None;
    super::history::adopt_retried_round(&mut round_slot, 4, "sess-round");
    let adopted = round_slot
        .as_ref()
        .map(|(_, interval)| interval.record_id().to_owned());
    assert_eq!(adopted.as_deref(), Some(inserted.record_id.as_str()));
    assert_eq!(page_records(&round_store).len(), 1);
    assert_eq!(
        round_slot.as_ref().unwrap().1.record_id(),
        inserted.record_id
    );
    thread::sleep(Duration::from_millis(50));
    round_slot
        .as_ref()
        .unwrap()
        .1
        .checkpoint()
        .expect("adopted interval checkpoints");
    let checkpointed = round_store.get(&inserted.record_id).unwrap();
    assert_eq!(checkpointed.record_id, inserted.record_id);
    assert_eq!(checkpointed.started_at_utc_ms, inserted.started_at_utc_ms);
    assert_eq!(checkpointed.status, "active");
    assert!(
        checkpointed.elapsed_ms > inserted.elapsed_ms,
        "checkpoint must advance the retried record"
    );
    finish_round(&mut round_slot, 4).unwrap();
    let finished = round_store.get(&inserted.record_id).unwrap();
    assert_eq!(finished.status, "completed");
    assert_eq!(finished.record_id, inserted.record_id);
    assert_eq!(finished.started_at_utc_ms, inserted.started_at_utc_ms);
    assert!(finished.ended_at_utc_ms.is_some());
    assert!(finished.elapsed_ms >= checkpointed.elapsed_ms);
    assert_eq!(page_records(&round_store).len(), 1);
    drop(round_root);

    let (forward_root, forward_store, inserted) =
        retry_after_failed_open("sess-forward", "246810", "port_forward");
    let mut forward_slot: Option<HistoryInterval> = None;
    super::history::adopt_retried_forward(&mut forward_slot, "sess-forward");
    let adopted = forward_slot
        .as_ref()
        .map(|interval| interval.record_id().to_owned());
    assert_eq!(adopted.as_deref(), Some(inserted.record_id.as_str()));
    thread::sleep(Duration::from_millis(50));
    forward_slot
        .as_ref()
        .unwrap()
        .checkpoint()
        .expect("forward slot checkpoints the retried record");
    let checkpointed = forward_store.get(&inserted.record_id).unwrap();
    assert_eq!(checkpointed.status, "active");
    assert!(checkpointed.elapsed_ms > inserted.elapsed_ms);
    assert_eq!(checkpointed.started_at_utc_ms, inserted.started_at_utc_ms);
    forward_slot.take().unwrap().finish().unwrap();
    let finished = forward_store.get(&inserted.record_id).unwrap();
    assert_eq!(finished.status, "completed");
    assert_eq!(finished.record_id, inserted.record_id);
    assert!(finished.ended_at_utc_ms.is_some());
    assert_eq!(page_records(&forward_store).len(), 1);
    drop(forward_root);
}

#[test]
fn drop_finalizes_when_session_index_is_weak() {
    let _guard = lock_tests();
    clear_history_warning();
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let open: Arc<dyn Fn() -> Result<Arc<HistoryStore>, HistoryError> + Send + Sync> = Arc::new({
        let store = store.clone();
        move || Ok(store.clone())
    });
    let owner = super::history::begin_for_session(
        "sess-drop",
        "123456".to_owned(),
        "Desk".to_owned(),
        "rdp".to_owned(),
        test_owner(),
        open,
        None,
    )
    .expect("start")
    .expect("interval");
    let indexed = super::history::session_index_holds_live_interval("sess-drop");
    let strong = super::history::session_index_holds_strong_owner("sess-drop");
    let id = owner.record_id().to_owned();
    assert_eq!(store.get(&id).unwrap().status, "active");
    drop(owner);
    let status = store.get(&id).unwrap().status;
    assert!(
        indexed && !strong && status == "completed",
        "indexed={indexed} strong={strong} status={status}"
    );
    let finished = store.get(&id).unwrap();
    assert!(finished.ended_at_utc_ms.is_some());
    assert_eq!(finished.connection_type, "rdp");
    drop(root);
}

#[test]
fn dropped_forward_guard_finishes_parked_interval() {
    let _guard = lock_tests();
    clear_history_warning();
    let (root, store, inserted) =
        retry_after_failed_open("sess-dropped-forward", "135790", "port_forward");
    assert_eq!(inserted.status, "active");
    assert_eq!(page_records(&store).len(), 1);
    drop(super::history::ParkedForwardGuard::new(
        "sess-dropped-forward",
    ));
    let finished = store.get(&inserted.record_id).unwrap();
    assert_eq!(finished.record_id, inserted.record_id);
    assert_eq!(finished.started_at_utc_ms, inserted.started_at_utc_ms);
    assert_eq!(
        finished.status, "completed",
        "dropping the forward guard must finish the parked record"
    );
    assert!(finished.ended_at_utc_ms.is_some());
    assert_eq!(finished.connection_type, "port_forward");
    assert_eq!(page_records(&store).len(), 1);

    let (taken_root, taken_store, taken) =
        retry_after_failed_open("sess-taken-forward", "135791", "rdp");
    let mut slot: Option<HistoryInterval> = None;
    super::history::adopt_retried_forward(&mut slot, "sess-taken-forward");
    slot.take().unwrap().finish().unwrap();
    assert_eq!(page_records(&taken_store).len(), 1);
    assert_eq!(
        taken_store.get(&taken.record_id).unwrap().status,
        "completed"
    );
    drop(super::history::ParkedForwardGuard::new(
        "sess-taken-forward",
    ));
    let after = taken_store.get(&taken.record_id).unwrap();
    assert_eq!(after.record_id, taken.record_id);
    assert_eq!(after.started_at_utc_ms, taken.started_at_utc_ms);
    assert_eq!(after.status, "completed");
    assert_eq!(
        page_records(&taken_store).len(),
        1,
        "guard drop after adopt and finish must not insert another record"
    );
    drop(root);
    drop(taken_root);
}

fn park_retried_forward(
    session_key: &str,
    park_id: &str,
    peer_id: &str,
    connection_type: &str,
    store: &Arc<HistoryStore>,
) -> HistoryRecord {
    let open = open_after_one_failure(session_key, store.clone());
    let failed = super::history::begin_for_park(
        session_key,
        park_id,
        peer_id.to_owned(),
        "Desk".to_owned(),
        connection_type.to_owned(),
        test_owner(),
        open,
        None,
    );
    assert!(failed.is_err(), "first open fails before a record exists");
    retry_history_save(session_key).expect("retry parks this forward");
    page_records(store)
        .into_iter()
        .find(|record| record.peer_id == peer_id)
        .unwrap_or_else(|| panic!("retry did not park {peer_id} under {park_id}"))
}

#[test]
fn sibling_forward_park_ids_stay_independent() {
    let _guard = lock_tests();
    clear_history_warning();
    let session = "flutter-forward-sess";
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let desktop_open = open_after_one_failure(session, store.clone());
    assert!(super::history::begin_for_session(
        session,
        "100000".to_owned(),
        "Desk".to_owned(),
        "desktop".to_owned(),
        test_owner(),
        desktop_open,
        None,
    )
    .is_err());
    retry_history_save(session).expect("desktop retry parks under the session key");
    let desktop = page_records(&store)
        .into_iter()
        .find(|record| record.peer_id == "100000")
        .expect("desktop record");
    let desktop_id = desktop.record_id.clone();
    let desktop_start = desktop.started_at_utc_ms;
    let desktop_parked = super::history::parked_forward_identity(session).expect("desktop parked");
    assert_eq!(desktop_parked.0, desktop_id);
    assert_eq!(desktop_parked.1, desktop_start);

    let park_a = super::history::new_forward_park_id();
    let park_b = super::history::new_forward_park_id();
    assert_ne!(park_a, session);
    assert_ne!(park_b, session);
    assert_ne!(park_a, park_b);
    let rec_a = park_retried_forward(session, &park_a, "100001", "port_forward", &store);
    let rec_b = park_retried_forward(session, &park_b, "100002", "rdp", &store);
    let id_a = rec_a.record_id.clone();
    let start_a = rec_a.started_at_utc_ms;
    let id_b = rec_b.record_id.clone();
    let start_b = rec_b.started_at_utc_ms;
    let parked_b = super::history::parked_forward_identity(&park_b).expect("B parked");
    assert_eq!(parked_b.0, id_b);
    assert_eq!(parked_b.1, start_b);
    assert_eq!(store.get(&id_b).unwrap().status, "active");
    let parked_desktop = super::history::parked_forward_identity(session).expect("desktop stays");
    assert_eq!(parked_desktop.0, desktop_id);
    assert_eq!(parked_desktop.1, desktop_start);
    assert_eq!(parked_desktop.2, desktop_parked.2);
    assert_eq!(store.get(&desktop_id).unwrap().status, "active");
    assert_eq!(page_records(&store).len(), 3);

    drop(super::history::ParkedForwardGuard::new(park_a.clone()));
    let finished_a = store.get(&id_a).unwrap();
    assert_eq!(finished_a.record_id, id_a);
    assert_eq!(finished_a.started_at_utc_ms, start_a);
    assert_eq!(finished_a.status, "completed");
    assert!(finished_a.ended_at_utc_ms.is_some());
    assert!(super::history::parked_forward_identity(&park_a).is_none());
    let still_b = super::history::parked_forward_identity(&park_b).expect("B stays parked");
    assert_eq!(still_b.0, id_b, "same UUID");
    assert_eq!(still_b.1, start_b, "same start");
    assert_eq!(still_b.2, parked_b.2, "same Instant");
    assert_eq!(store.get(&id_b).unwrap().status, "active");
    assert_eq!(store.get(&desktop_id).unwrap().status, "active");
    assert_eq!(
        super::history::parked_forward_identity(session)
            .expect("desktop park")
            .2,
        desktop_parked.2
    );
    assert_eq!(page_records(&store).len(), 3);

    let park_c = super::history::new_forward_park_id();
    let park_d = super::history::new_forward_park_id();
    let rec_c = park_retried_forward(session, &park_c, "100003", "port_forward", &store);
    let rec_d = park_retried_forward(session, &park_d, "100004", "rdp", &store);
    let id_c = rec_c.record_id.clone();
    let start_c = rec_c.started_at_utc_ms;
    let id_d = rec_d.record_id.clone();
    let start_d = rec_d.started_at_utc_ms;
    let parked_d = super::history::parked_forward_identity(&park_d).expect("D parked");
    assert_eq!(parked_d.0, id_d);
    assert_eq!(parked_d.1, start_d);
    let mut slot_c: Option<HistoryInterval> = None;
    super::history::adopt_retried_forward(&mut slot_c, &park_c);
    let adopted_c = slot_c
        .as_ref()
        .map(|interval| interval.record_id().to_owned());
    assert_eq!(adopted_c.as_deref(), Some(id_c.as_str()));
    assert_eq!(
        super::history::parked_forward_identity(&park_d)
            .expect("adopt C leaves D")
            .2,
        parked_d.2
    );
    slot_c.take().unwrap().finish().unwrap();
    assert_eq!(store.get(&id_c).unwrap().status, "completed");
    assert_eq!(store.get(&id_c).unwrap().started_at_utc_ms, start_c);
    let still_d = super::history::parked_forward_identity(&park_d).expect("finish C leaves D");
    assert_eq!(still_d.0, id_d);
    assert_eq!(still_d.1, start_d);
    assert_eq!(still_d.2, parked_d.2);
    assert_eq!(store.get(&id_d).unwrap().status, "active");
    assert_eq!(store.get(&id_b).unwrap().status, "active");
    assert_eq!(
        super::history::parked_forward_identity(&park_b)
            .expect("B still parked")
            .2,
        parked_b.2
    );
    assert_eq!(store.get(&desktop_id).unwrap().status, "active");
    assert_eq!(
        store.get(&desktop_id).unwrap().started_at_utc_ms,
        desktop_start
    );
    let mut slot_d: Option<HistoryInterval> = None;
    super::history::adopt_retried_forward(&mut slot_d, &park_d);
    let adopted_d = slot_d.as_ref().expect("D still adopted from its park id");
    assert_eq!(adopted_d.record_id(), id_d);
    assert_eq!(super::history::interval_allocation(adopted_d), parked_d.2);
    drop(super::history::ParkedForwardGuard::new(park_c));
    assert_eq!(page_records(&store).len(), 5);
    assert_eq!(store.get(&id_c).unwrap().status, "completed");
    drop(slot_d);
    super::history::reset_history_sessions();
    drop(root);
}

#[test]
fn one_retry_parks_each_failed_forward_start() {
    let _guard = lock_tests();
    clear_history_warning();
    let session = "flutter-two-failed-forwards";
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let park_a = super::history::new_forward_park_id();
    let park_b = super::history::new_forward_park_id();
    assert_ne!(park_a, session);
    assert_ne!(park_b, session);
    assert_ne!(park_a, park_b);
    let open_a = open_after_one_failure(session, store.clone());
    let open_b = open_after_one_failure(session, store.clone());
    assert!(
        super::history::begin_for_park(
            session,
            &park_a,
            "200001".to_owned(),
            "Desk".to_owned(),
            "port_forward".to_owned(),
            test_owner(),
            open_a,
            None,
        )
        .is_err(),
        "A fails before an interval is parked"
    );
    assert!(
        super::history::begin_for_park(
            session,
            &park_b,
            "200002".to_owned(),
            "Desk".to_owned(),
            "rdp".to_owned(),
            test_owner(),
            open_b,
            None,
        )
        .is_err(),
        "B fails before an interval is parked"
    );
    assert!(page_records(&store).is_empty());
    assert!(history_save_warning(session).is_some());
    retry_history_save(session).expect("one retry parks both forward ids");
    let records = page_records(&store);
    assert_eq!(records.len(), 2, "each failed start becomes its own record");
    let rec_a = records
        .iter()
        .find(|record| record.peer_id == "200001")
        .expect("A parked");
    let rec_b = records
        .iter()
        .find(|record| record.peer_id == "200002")
        .expect("B parked");
    assert_ne!(rec_a.record_id, rec_b.record_id);
    let id_a = rec_a.record_id.clone();
    let start_a = rec_a.started_at_utc_ms;
    let id_b = rec_b.record_id.clone();
    let start_b = rec_b.started_at_utc_ms;
    let parked_a = super::history::parked_forward_identity(&park_a).expect("A under its id");
    let parked_b = super::history::parked_forward_identity(&park_b).expect("B under its id");
    assert_eq!(parked_a.0, id_a);
    assert_eq!(parked_a.1, start_a);
    assert_eq!(parked_b.0, id_b);
    assert_eq!(parked_b.1, start_b);
    assert!(super::history::parked_forward_identity(session).is_none());
    assert_eq!(store.get(&id_a).unwrap().status, "active");
    assert_eq!(store.get(&id_b).unwrap().status, "active");
    assert_eq!(store.get(&id_a).unwrap().connection_type, "port_forward");
    assert_eq!(store.get(&id_b).unwrap().connection_type, "rdp");

    drop(super::history::ParkedForwardGuard::new(park_a.clone()));
    let finished_a = store.get(&id_a).unwrap();
    assert_eq!(finished_a.record_id, id_a);
    assert_eq!(finished_a.started_at_utc_ms, start_a);
    assert_eq!(finished_a.status, "completed");
    assert!(finished_a.ended_at_utc_ms.is_some());
    assert!(super::history::parked_forward_identity(&park_a).is_none());
    let still_b = super::history::parked_forward_identity(&park_b).expect("B stays parked");
    assert_eq!(still_b.0, id_b, "same UUID");
    assert_eq!(still_b.1, start_b, "same start");
    assert_eq!(still_b.2, parked_b.2, "same Instant");
    assert_eq!(store.get(&id_b).unwrap().status, "active");
    assert_eq!(page_records(&store).len(), 2);
    drop(super::history::ParkedForwardGuard::new(park_b.clone()));
    super::history::reset_history_sessions();
    drop(root);
}

#[test]
fn successful_sibling_keeps_failed_forward_pending() {
    let _guard = lock_tests();
    clear_history_warning();
    let session = "flutter-mixed-forward";
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let park_a = super::history::new_forward_park_id();
    let park_b = super::history::new_forward_park_id();
    assert_ne!(park_a, park_b);
    assert_ne!(park_a, session);
    let open_a = open_after_one_failure(session, store.clone());
    let open_b: Arc<dyn Fn() -> Result<Arc<HistoryStore>, HistoryError> + Send + Sync> =
        Arc::new({
            let store = store.clone();
            move || Ok(store.clone())
        });
    assert!(
        super::history::begin_for_park(
            session,
            &park_a,
            "300001".to_owned(),
            "A".to_owned(),
            "port_forward".to_owned(),
            test_owner(),
            open_a,
            None,
        )
        .is_err(),
        "A fails before an interval exists"
    );
    assert!(page_records(&store).is_empty());
    let started_b = super::history::begin_for_park(
        session,
        &park_b,
        "300002".to_owned(),
        "B".to_owned(),
        "rdp".to_owned(),
        test_owner(),
        open_b,
        None,
    )
    .expect("B starts")
    .expect("B interval");
    let id_b = started_b.record_id().to_owned();
    let alloc_b = super::history::interval_allocation(&started_b);
    let before_b = store.get(&id_b).unwrap();
    assert_eq!(before_b.peer_id, "300002");
    assert_eq!(before_b.connection_type, "rdp");
    assert_eq!(before_b.status, "active");
    assert!(before_b.ended_at_utc_ms.is_none());
    let start_b = before_b.started_at_utc_ms;
    assert!(
        history_save_warning(session).is_some(),
        "A is still pending, so the session warning stays"
    );
    assert!(super::history::parked_forward_identity(&park_a).is_none());
    assert_eq!(page_records(&store).len(), 1);

    retry_history_save(session).expect("retry parks only A's interval");
    let records = page_records(&store);
    assert_eq!(records.len(), 2);
    let rec_a = records
        .iter()
        .find(|record| record.peer_id == "300001")
        .expect("retry parks A");
    assert_eq!(
        records
            .iter()
            .filter(|record| record.peer_id == "300002")
            .count(),
        1,
        "retry does not replace B"
    );
    let id_a = rec_a.record_id.clone();
    let start_a = rec_a.started_at_utc_ms;
    assert_ne!(id_a, id_b);
    let parked_a = super::history::parked_forward_identity(&park_a).expect("A under its id");
    assert_eq!(parked_a.0, id_a);
    assert_eq!(parked_a.1, start_a);
    assert!(super::history::parked_forward_identity(&park_b).is_none());
    let after_b = store.get(&id_b).unwrap();
    assert_eq!(after_b.record_id, id_b);
    assert_eq!(after_b.started_at_utc_ms, start_b);
    assert_eq!(after_b.status, "active");
    assert!(after_b.ended_at_utc_ms.is_none());
    assert_eq!(after_b.connection_type, "rdp");
    assert_eq!(started_b.record_id(), id_b);
    assert_eq!(super::history::interval_allocation(&started_b), alloc_b);
    assert_eq!(store.get(&id_a).unwrap().status, "active");

    drop(started_b);
    assert_eq!(store.get(&id_b).unwrap().status, "completed");
    assert_eq!(store.get(&id_b).unwrap().record_id, id_b);
    assert_eq!(store.get(&id_b).unwrap().started_at_utc_ms, start_b);
    let still_a = super::history::parked_forward_identity(&park_a).expect("dropping B leaves A");
    assert_eq!(still_a.0, id_a);
    assert_eq!(still_a.1, start_a);
    assert_eq!(still_a.2, parked_a.2);
    assert_eq!(store.get(&id_a).unwrap().status, "active");
    drop(super::history::ParkedForwardGuard::new(park_a.clone()));
    super::history::reset_history_sessions();
    drop(root);
}

fn open_ready(
    store: Arc<HistoryStore>,
) -> Arc<dyn Fn() -> Result<Arc<HistoryStore>, HistoryError> + Send + Sync> {
    Arc::new(move || Ok(store.clone()))
}

#[test]
fn sibling_insert_failure_keeps_warning_until_retry() {
    let _guard = lock_tests();
    clear_history_warning();
    let session = "flutter-sibling-insert";
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let open = open_ready(store.clone());
    let park_a = super::history::new_forward_park_id();
    let park_b = super::history::new_forward_park_id();
    assert_ne!(park_a, park_b);
    let interval_a = {
        let _fault = FaultGuard::arm(HistoryFault::CreateTemp);
        let started = super::history::begin_for_park(
            session,
            &park_a,
            "410001".to_owned(),
            "A".to_owned(),
            "port_forward".to_owned(),
            test_owner(),
            open.clone(),
            None,
        )
        .expect("Io keeps A's interval")
        .expect("A exists without a row");
        assert!(matches!(
            store.get(started.record_id()),
            Err(HistoryError::NotFound)
        ));
        started
    };
    let id_a = interval_a.record_id().to_owned();
    assert!(history_save_warning(session).is_some());
    let interval_b = super::history::begin_for_park(
        session,
        &park_b,
        "410002".to_owned(),
        "B".to_owned(),
        "rdp".to_owned(),
        test_owner(),
        open,
        None,
    )
    .expect("B inserts")
    .expect("B interval");
    let id_b = interval_b.record_id().to_owned();
    let alloc_b = super::history::interval_allocation(&interval_b);
    assert_ne!(id_a, id_b);
    let warning = history_save_warning(session)
        .expect("A is not inserted, so the session warning stays after B's insert");
    assert_eq!(warning.text, HISTORY_SAVE_WARNING_TEXT);
    assert_eq!(warning.action, HISTORY_SAVE_WARNING_ACTION);
    assert!(matches!(store.get(&id_a), Err(HistoryError::NotFound)));
    let before_b = store.get(&id_b).unwrap();
    assert_eq!(before_b.status, "active");
    assert!(before_b.ended_at_utc_ms.is_none());
    assert_eq!(page_records(&store).len(), 1);

    retry_history_save(session).expect("one retry inserts A's same record");
    let stored_a = store.get(&id_a).expect("retry inserts A's original UUID");
    assert_eq!(stored_a.record_id, id_a);
    assert_eq!(stored_a.peer_id, "410001");
    assert_eq!(stored_a.connection_type, "port_forward");
    assert_eq!(stored_a.status, "active");
    assert!(stored_a.ended_at_utc_ms.is_none());
    assert_eq!(interval_a.record_id(), id_a);
    let after_b = store.get(&id_b).unwrap();
    assert_eq!(
        after_b, before_b,
        "retry must not finish or rewrite healthy B"
    );
    assert_eq!(after_b.status, "active");
    assert!(after_b.ended_at_utc_ms.is_none());
    assert_eq!(super::history::interval_allocation(&interval_b), alloc_b);
    assert_eq!(page_records(&store).len(), 2);
    assert!(history_save_warning(session).is_none());

    // B is first in this session, so one press must still reach A's failed insert.
    let later = "flutter-sibling-insert-next";
    let open_later = open_ready(store.clone());
    let later_b = super::history::begin_for_park(
        later,
        &super::history::new_forward_park_id(),
        "410012".to_owned(),
        "B".to_owned(),
        "rdp".to_owned(),
        test_owner(),
        open_later.clone(),
        None,
    )
    .expect("later B starts")
    .expect("later B interval");
    let later_id_b = later_b.record_id().to_owned();
    let later_a = {
        let _fault = FaultGuard::arm(HistoryFault::CreateTemp);
        super::history::begin_for_park(
            later,
            &super::history::new_forward_park_id(),
            "410011".to_owned(),
            "A".to_owned(),
            "port_forward".to_owned(),
            test_owner(),
            open_later,
            None,
        )
        .expect("Io keeps the later interval")
        .expect("later A exists without a row")
    };
    let later_id_a = later_a.record_id().to_owned();
    later_b.checkpoint().expect("later B write");
    assert!(
        history_save_warning(later).is_some(),
        "a non-first failed insert keeps the warning"
    );
    let later_before_b = store.get(&later_id_b).unwrap();
    retry_history_save(later).expect("one retry inserts the non-first interval");
    let later_stored = store
        .get(&later_id_a)
        .expect("same UUID for the non-first interval");
    assert_eq!(later_stored.record_id, later_id_a);
    assert_eq!(later_stored.status, "active");
    assert!(later_stored.ended_at_utc_ms.is_none());
    assert_eq!(store.get(&later_id_b).unwrap(), later_before_b);
    assert_eq!(store.get(&later_id_b).unwrap().status, "active");
    assert!(history_save_warning(session).is_none());
    assert!(history_save_warning(later).is_none());
    drop(later_a);
    drop(later_b);
    drop(interval_a);
    drop(interval_b);
    super::history::reset_history_sessions();
    drop(root);
}

#[test]
fn sibling_finish_failure_keeps_warning_until_retry() {
    let _guard = lock_tests();
    clear_history_warning();
    let session = "flutter-sibling-finish";
    let root = TempRoot::new();
    let store = Arc::new(open_store(root.path()));
    let open = open_ready(store.clone());
    // B is the first live interval, so find_interval returns the healthy connection.
    let interval_b = super::history::begin_for_park(
        session,
        &super::history::new_forward_park_id(),
        "420002".to_owned(),
        "B".to_owned(),
        "rdp".to_owned(),
        test_owner(),
        open.clone(),
        None,
    )
    .expect("B starts")
    .expect("B interval");
    let id_b = interval_b.record_id().to_owned();
    let alloc_b = super::history::interval_allocation(&interval_b);
    let interval_a = super::history::begin_for_park(
        session,
        &super::history::new_forward_park_id(),
        "420001".to_owned(),
        "A".to_owned(),
        "port_forward".to_owned(),
        test_owner(),
        open,
        None,
    )
    .expect("A starts")
    .expect("A interval");
    let id_a = interval_a.record_id().to_owned();
    let start_a = store.get(&id_a).unwrap().started_at_utc_ms;
    assert_eq!(store.get(&id_a).unwrap().status, "active");
    assert_ne!(id_a, id_b);
    {
        let _fault = FaultGuard::arm(HistoryFault::Replace);
        let err = interval_a.finish();
        assert!(err.is_err(), "A's finish stays retryable");
    }
    let unfinished = store.get(&id_a).unwrap();
    assert_eq!(unfinished.record_id, id_a);
    assert_eq!(unfinished.status, "active");
    assert!(unfinished.ended_at_utc_ms.is_none());
    assert_eq!(unfinished.started_at_utc_ms, start_a);
    // B's later successful write must not hide A's failed finish.
    interval_b.checkpoint().expect("B checkpoint");
    let warning = history_save_warning(session).expect(
        "A's finish is still failed, so the session warning stays after B's successful write",
    );
    assert_eq!(warning.text, HISTORY_SAVE_WARNING_TEXT);
    assert_eq!(warning.action, HISTORY_SAVE_WARNING_ACTION);
    let before_b = store.get(&id_b).unwrap();
    assert_eq!(before_b.status, "active");
    assert!(before_b.ended_at_utc_ms.is_none());

    retry_history_save(session).expect("one retry finishes A");
    let done_a = store.get(&id_a).unwrap();
    assert_eq!(done_a.record_id, id_a);
    assert_eq!(done_a.started_at_utc_ms, start_a);
    assert_eq!(done_a.status, "completed");
    assert!(done_a.ended_at_utc_ms.is_some());
    assert_eq!(done_a.peer_id, "420001");
    assert_eq!(done_a.connection_type, "port_forward");
    let after_b = store.get(&id_b).unwrap();
    assert_eq!(after_b, before_b, "retry must not finish healthy B");
    assert_eq!(after_b.status, "active");
    assert!(after_b.ended_at_utc_ms.is_none());
    assert_eq!(super::history::interval_allocation(&interval_b), alloc_b);
    assert_eq!(page_records(&store).len(), 2);
    assert!(history_save_warning(session).is_none());
    drop(interval_a);
    drop(interval_b);
    super::history::reset_history_sessions();
    drop(root);
}
