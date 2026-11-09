mod history;
mod history_store;

#[cfg(all(test, windows))]
mod history_tests;

pub(crate) use history::new_forward_park_id;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub(crate) use history::ParkedForwardGuard;
pub(crate) use history::{
    admit_peer_info, adopt_retried_forward, adopt_retried_round, finish_round,
    note_approval_canceled, note_login_failure, snapshot_peer_name,
};
#[cfg(all(windows, not(raatik_history_harness)))]
pub(crate) use history::{begin_current_interval, begin_forward_interval};
pub use history::{
    clear_history_save_warning, history_save_warning, retry_history_save, set_history_status_hook,
    HistoryError, HistoryInterval, HistoryPage, HistoryQuery, HistoryRecord, HistorySaveWarning,
    OwnerIdentity, OwnerProbe, OwnerState,
};
#[cfg(not(raatik_history_harness))]
pub use history::{get_history_for_ui, query_history_for_ui, save_history_note_for_ui};
pub use history_store::{HistoryStore, WindowsOwnerProbe};
