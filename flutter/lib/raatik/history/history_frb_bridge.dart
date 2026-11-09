import 'package:flutter_hbb/models/platform_model.dart';

import 'history_repository.dart';

/// Generated FRB entry for the history screen. Widget tests do not import this
/// file, so they still compile while `generated_bridge.dart` is absent.
class FrbHistoryBridge implements HistoryRawBridge {
  const FrbHistoryBridge();

  @override
  Future<String> query(String queryJson) {
    return bind.raatikHistoryQuery(queryJson: queryJson);
  }

  @override
  Future<String> getRecord(String recordId) {
    return bind.raatikHistoryGet(recordId: recordId);
  }

  @override
  Future<String> saveNote(String recordId, int expectedRevision, String note) {
    return bind.raatikHistorySaveNote(
      recordId: recordId,
      expectedRevision: expectedRevision,
      note: note,
    );
  }
}
