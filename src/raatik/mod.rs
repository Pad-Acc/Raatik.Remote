mod history;
mod history_store;

#[cfg(all(test, windows))]
mod history_tests;

pub use history::{HistoryError, HistoryPage, HistoryQuery, HistoryRecord, OwnerProbe, OwnerState};
pub use history_store::{HistoryStore, WindowsOwnerProbe};
