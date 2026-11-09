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
    sync::{Mutex, MutexGuard},
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
