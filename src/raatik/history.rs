use serde::{Deserialize, Serialize};
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
