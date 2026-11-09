use super::{
    canonical_record_id, normalize_note, validate_query, HistoryError, HistoryQuery, OwnerProbe,
};
use crate::raatik::history_store::HistoryStore;
use serde::Deserialize;

pub const CODE_INVALID_QUERY: &str = "invalid_query";
pub const CODE_INVALID_NOTE: &str = "invalid_note";
pub const CODE_NOT_FOUND: &str = "not_found";
pub const CODE_NOTE_CONFLICT: &str = "note_conflict";
pub const CODE_BUSY: &str = "history_busy";
pub const CODE_IO: &str = "history_io";
pub const CODE_FUTURE: &str = "future_schema";
pub const CODE_UNAVAILABLE: &str = "history_unavailable";

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct QueryWire {
    search: String,
    from_utc_ms: Option<i64>,
    to_utc_ms: Option<i64>,
    offset: u32,
    limit: u32,
}

pub fn history_access(windows: bool, service: bool) -> Result<(), &'static str> {
    if !windows || service {
        Err(CODE_UNAVAILABLE)
    } else {
        Ok(())
    }
}

pub fn store_failure_code(err: HistoryError) -> &'static str {
    match err {
        HistoryError::Io => CODE_IO,
        HistoryError::Busy => CODE_BUSY,
        HistoryError::InvalidInput => CODE_INVALID_QUERY,
        HistoryError::NotFound => CODE_NOT_FOUND,
        HistoryError::NoteConflict => CODE_NOTE_CONFLICT,
        HistoryError::FutureSchema => CODE_FUTURE,
    }
}

pub fn parse_query_json(json: &str) -> Result<HistoryQuery, &'static str> {
    let wire: QueryWire = serde_json::from_str(json).map_err(|_| CODE_INVALID_QUERY)?;
    let query = HistoryQuery {
        search: wire.search,
        from_utc_ms: wire.from_utc_ms,
        to_utc_ms: wire.to_utc_ms,
        offset: wire.offset,
        limit: wire.limit,
    };
    validate_query(&query).map_err(|_| CODE_INVALID_QUERY)?;
    Ok(query)
}

pub fn note_for_wire(note: &str) -> Result<String, &'static str> {
    normalize_note(note).map_err(|_| CODE_INVALID_NOTE)
}

pub fn query_with(store: &HistoryStore, json: &str) -> Result<String, String> {
    let query = parse_query_json(json).map_err(ToOwned::to_owned)?;
    let page = store
        .query(&query)
        .map_err(|err| code_for(err, CODE_INVALID_QUERY))?;
    encode(&page)
}

pub fn get_with(store: &HistoryStore, id: &str) -> Result<String, String> {
    canonical_record_id(id).map_err(|_| CODE_INVALID_QUERY.to_string())?;
    let record = store
        .get(id)
        .map_err(|err| code_for(err, CODE_INVALID_QUERY))?;
    encode(&record)
}

pub fn save_note_with(
    store: &HistoryStore,
    id: &str,
    expected_revision: u64,
    note: &str,
) -> Result<String, String> {
    let note = note_for_wire(note).map_err(ToOwned::to_owned)?;
    canonical_record_id(id).map_err(|_| CODE_INVALID_QUERY.to_string())?;
    let record = store
        .save_note(id, expected_revision, &note)
        .map_err(|err| code_for(err, CODE_INVALID_NOTE))?;
    encode(&record)
}

pub fn query_refresh(
    store: &HistoryStore,
    probe: &dyn OwnerProbe,
    json: &str,
) -> Result<String, String> {
    store
        .recover_abandoned(probe)
        .map_err(|err| code_for(err, CODE_INVALID_QUERY))?;
    query_with(store, json)
}

fn code_for(err: HistoryError, invalid: &'static str) -> String {
    match err {
        HistoryError::InvalidInput => invalid,
        other => store_failure_code(other),
    }
    .to_string()
}

fn encode(value: &impl serde::Serialize) -> Result<String, String> {
    serde_json::to_string(value).map_err(|_| CODE_IO.to_string())
}
