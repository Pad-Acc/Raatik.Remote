mod history;
mod history_store;

#[cfg(all(test, windows))]
mod history_tests;

#[cfg(all(windows, not(raatik_history_harness)))]
pub(crate) use history::begin_current_interval;
pub(crate) use history::{
    admit_peer_info, finish_round, note_approval_canceled, note_login_failure, snapshot_peer_name,
};
pub use history::{
    clear_history_save_warning, history_save_warning, retry_history_save, set_history_status_hook,
    HistoryError, HistoryInterval, HistoryPage, HistoryQuery, HistoryRecord, HistorySaveWarning,
    OwnerIdentity, OwnerProbe, OwnerState,
};
pub use history_store::{HistoryStore, WindowsOwnerProbe};
