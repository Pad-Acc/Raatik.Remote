import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum HistoryDateFilter { all, today, yesterday, lastSevenDays }

class HistoryQuery {
  const HistoryQuery({
    required this.search,
    required this.fromUtcMs,
    required this.toUtcMs,
    required this.offset,
    required this.limit,
  });

  final String search;
  final int? fromUtcMs;
  final int? toUtcMs;
  final int offset;
  final int limit;

  String toWireJson() => jsonEncode(<String, Object?>{
        'search': search,
        'from_utc_ms': fromUtcMs,
        'to_utc_ms': toUtcMs,
        'offset': offset,
        'limit': limit,
      });
}

class HistoryRecord {
  const HistoryRecord({
    required this.schema,
    required this.recordId,
    required this.connectionType,
    required this.peerId,
    required this.peerName,
    required this.startedAtUtcMs,
    required this.endedAtUtcMs,
    required this.elapsedMs,
    required this.checkpointAtUtcMs,
    required this.status,
    required this.ownerPid,
    required this.ownerStartedAt,
    required this.note,
    required this.noteRevision,
  });

  final int schema;
  final String recordId;
  final String connectionType;
  final String peerId;
  final String peerName;
  final int startedAtUtcMs;
  final int? endedAtUtcMs;
  final int elapsedMs;
  final int checkpointAtUtcMs;
  final String status;
  final int ownerPid;
  final int ownerStartedAt;
  final String note;
  final int noteRevision;

  bool get clockChanged =>
      historyClockChanged(startedAtUtcMs: startedAtUtcMs, endedAtUtcMs: endedAtUtcMs);

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      schema: _jsonInt(json['schema']),
      recordId: _jsonString(json['record_id']),
      connectionType: _jsonString(json['connection_type']),
      peerId: _jsonString(json['peer_id']),
      peerName: _jsonString(json['peer_name']),
      startedAtUtcMs: _jsonInt(json['started_at_utc_ms']),
      endedAtUtcMs: json['ended_at_utc_ms'] == null ? null : _jsonInt(json['ended_at_utc_ms']),
      elapsedMs: _jsonInt(json['elapsed_ms']),
      checkpointAtUtcMs: _jsonInt(json['checkpoint_at_utc_ms']),
      status: _jsonString(json['status']),
      ownerPid: _jsonInt(json['owner_pid']),
      ownerStartedAt: _jsonInt(json['owner_started_at']),
      note: _jsonString(json['note']),
      noteRevision: _jsonInt(json['note_revision']),
    );
  }
}

class HistoryPage {
  const HistoryPage({
    required this.records,
    required this.total,
    required this.warnings,
  });

  final List<HistoryRecord> records;
  final int total;
  final List<String> warnings;

  factory HistoryPage.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'];
    final rawWarnings = json['warnings'];
    if (rawRecords is! List || rawWarnings is! List || json['total'] == null) {
      throw const HistoryFailure('history_io');
    }
    return HistoryPage(
      records: rawRecords.map((item) {
        if (item is! Map) throw const HistoryFailure('history_io');
        return HistoryRecord.fromJson(Map<String, dynamic>.from(item));
      }).toList(growable: false),
      total: _jsonInt(json['total']),
      warnings: rawWarnings.map(_jsonString).toList(growable: false),
    );
  }
}

class HistoryFailure implements Exception {
  const HistoryFailure(this.code);

  final String code;

  @override
  String toString() => code;
}

abstract class HistoryRepository {
  const HistoryRepository();

  Future<HistoryPage> query(HistoryQuery query);
  Future<HistoryRecord> get(String recordId);
  Future<HistoryRecord> saveNote(String recordId, int expectedRevision, String note);
}

abstract class HistoryRawBridge {
  const HistoryRawBridge();

  Future<String> query(String queryJson);
  Future<String> getRecord(String recordId);
  Future<String> saveNote(String recordId, int expectedRevision, String note);
}

/// Used when the generated FRB bindings are not linked. Throws instead of
/// pretending a note was saved.
class UnavailableHistoryBridge implements HistoryRawBridge {
  const UnavailableHistoryBridge();

  @override
  Future<String> query(String queryJson) async =>
      throw const HistoryFailure('history_unavailable');

  @override
  Future<String> getRecord(String recordId) async =>
      throw const HistoryFailure('history_unavailable');

  @override
  Future<String> saveNote(String recordId, int expectedRevision, String note) async =>
      throw const HistoryFailure('history_unavailable');
}

class FfiHistoryRepository implements HistoryRepository {
  const FfiHistoryRepository({this.bridge = const UnavailableHistoryBridge()});

  final HistoryRawBridge bridge;

  @override
  Future<HistoryPage> query(HistoryQuery query) {
    return _decode(() => bridge.query(query.toWireJson()), HistoryPage.fromJson);
  }

  @override
  Future<HistoryRecord> get(String recordId) {
    return _decode(() => bridge.getRecord(recordId), HistoryRecord.fromJson);
  }

  @override
  Future<HistoryRecord> saveNote(String recordId, int expectedRevision, String note) {
    return _decode(
      () => bridge.saveNote(recordId, expectedRevision, note),
      HistoryRecord.fromJson,
    );
  }
}

typedef HistoryUtcRange = ({DateTime? fromUtc, DateTime? toUtc});

HistoryUtcRange localDateRange(HistoryDateFilter filter, DateTime now) {
  final local = now.toLocal();
  DateTime day(int delta) => DateTime(local.year, local.month, local.day + delta);
  switch (filter) {
    case HistoryDateFilter.all:
      return (fromUtc: null, toUtc: null);
    case HistoryDateFilter.today:
      return (fromUtc: day(0).toUtc(), toUtc: day(1).toUtc());
    case HistoryDateFilter.yesterday:
      return (fromUtc: day(-1).toUtc(), toUtc: day(0).toUtc());
    case HistoryDateFilter.lastSevenDays:
      return (fromUtc: day(-6).toUtc(), toUtc: day(1).toUtc());
  }
}

String formatHistoryDate(DateTime instant, {required bool jalali}) {
  final local = instant.toLocal();
  if (!jalali) {
    return '${_four(local.year)}/${_two(local.month)}/${_two(local.day)}';
  }
  final date = Jalali.fromDateTime(local);
  return '${_four(date.year)}/${_two(date.month)}/${_two(date.day)}';
}

String formatHistoryClock(DateTime instant) {
  final local = instant.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
}

String formatHistoryDuration({
  required int elapsedMs,
  required String status,
  String activePrefix = 'در حال اتصال —',
  String atLeastPrefix = 'حداقل',
}) {
  final safe = elapsedMs < 0 ? 0 : elapsedMs;
  final totalSeconds = safe ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final clock = '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  switch (status) {
    case 'active':
      return '$activePrefix $clock';
    case 'interrupted':
      return '$atLeastPrefix $clock';
    default:
      return clock;
  }
}

bool historyClockChanged({required int startedAtUtcMs, int? endedAtUtcMs}) {
  final ended = endedAtUtcMs;
  if (ended == null) return false;
  return ended < startedAtUtcMs;
}

/// Rejects notes the store would refuse. Counts Unicode scalar values.
String? validateHistoryNote(String note) {
  if (note.runes.length > 2000) return 'invalid_note';
  for (final rune in note.runes) {
    if (rune == 0x09 || rune == 0x0A) continue;
    if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) return 'invalid_note';
  }
  return null;
}

class HistoryCopy {
  const HistoryCopy({
    required this.title,
    required this.subtitle,
    required this.onThisComputer,
    required this.searchLabel,
    required this.searchHint,
    required this.dateLabel,
    required this.allDates,
    required this.today,
    required this.yesterday,
    required this.lastSevenDays,
    required this.newestFirst,
    required this.peerColumn,
    required this.whenColumn,
    required this.durationColumn,
    required this.noteColumn,
    required this.emptyTitle,
    required this.emptyBody,
    required this.clearFilters,
    required this.footer,
    required this.noteTitle,
    required this.noteLabel,
    required this.optional,
    required this.cancel,
    required this.saveNote,
    required this.addNote,
    required this.loadStored,
    required this.saveMine,
    required this.savedNote,
    required this.previous,
    required this.next,
    required this.untilWord,
    required this.unknownEnd,
    required this.atLeast,
    required this.connecting,
    required this.clockChanged,
    required this.sessions,
    required this.invalidQuery,
    required this.invalidNote,
    required this.notFound,
    required this.noteConflict,
    required this.historyBusy,
    required this.historyIo,
    required this.futureSchema,
    required this.historyUnavailable,
    required this.unreadable,
    required this.fileTransfer,
    required this.tunnel,
    required this.rdp,
    required this.camera,
    required this.terminal,
  });

  final String title;
  final String subtitle;
  final String onThisComputer;
  final String searchLabel;
  final String searchHint;
  final String dateLabel;
  final String allDates;
  final String today;
  final String yesterday;
  final String lastSevenDays;
  final String newestFirst;
  final String peerColumn;
  final String whenColumn;
  final String durationColumn;
  final String noteColumn;
  final String emptyTitle;
  final String emptyBody;
  final String clearFilters;
  final String footer;
  final String noteTitle;
  final String noteLabel;
  final String optional;
  final String cancel;
  final String saveNote;
  final String addNote;
  final String loadStored;
  final String saveMine;
  final String savedNote;
  final String previous;
  final String next;
  final String untilWord;
  final String unknownEnd;
  final String atLeast;
  final String connecting;
  final String clockChanged;
  final String sessions;
  final String invalidQuery;
  final String invalidNote;
  final String notFound;
  final String noteConflict;
  final String historyBusy;
  final String historyIo;
  final String futureSchema;
  final String historyUnavailable;
  final String unreadable;
  final String fileTransfer;
  final String tunnel;
  final String rdp;
  final String camera;
  final String terminal;

  static HistoryCopy of(Locale locale) {
    if (locale.languageCode == 'fa') return fa;
    return en;
  }

  String error(String code) {
    switch (code) {
      case 'invalid_query':
        return invalidQuery;
      case 'invalid_note':
        return invalidNote;
      case 'not_found':
        return notFound;
      case 'note_conflict':
        return noteConflict;
      case 'history_busy':
        return historyBusy;
      case 'history_io':
        return historyIo;
      case 'future_schema':
        return futureSchema;
      case 'history_unavailable':
        return historyUnavailable;
      default:
        return historyIo;
    }
  }

  String? warning(String code) {
    switch (code) {
      case 'unreadable_records':
        return unreadable;
      case 'future_schema':
        return futureSchema;
      default:
        return null;
    }
  }

  String? typeLabel(String connectionType) {
    switch (connectionType) {
      case 'file_transfer':
        return fileTransfer;
      case 'port_forward':
        return tunnel;
      case 'rdp':
        return rdp;
      case 'camera':
        return camera;
      case 'terminal':
        return terminal;
      default:
        return null;
    }
  }

  String durationFor(HistoryRecord record) {
    return formatHistoryDuration(
      elapsedMs: record.elapsedMs,
      status: record.status,
      activePrefix: connecting,
      atLeastPrefix: atLeast,
    );
  }

  static const fa = HistoryCopy(
    title: 'تاریخچهٔ جلسات',
    subtitle: 'اتصال‌های قبلی و یادداشت‌های کار پشتیبانی',
    onThisComputer: 'روی همین کامپیوتر',
    searchLabel: 'جست‌وجوی مشتری',
    searchHint: 'نام یا شناسهٔ دستگاه',
    dateLabel: 'تاریخ اتصال',
    allDates: 'همهٔ تاریخ‌ها',
    today: 'امروز',
    yesterday: 'دیروز',
    lastSevenDays: '۷ روز اخیر',
    newestFirst: 'جدیدترین اتصال‌ها در ابتدا',
    peerColumn: 'مشتری / دستگاه',
    whenColumn: 'تاریخ و ساعت اتصال',
    durationColumn: 'مدت اتصال',
    noteColumn: 'یادداشت',
    emptyTitle: 'جلسه‌ای پیدا نشد',
    emptyBody: 'نام یا شناسه را بررسی کن یا تاریخ دیگری را انتخاب کن.',
    clearFilters: 'پاک‌کردن فیلترها',
    footer: 'تاریخچه و یادداشت‌ها فقط روی همین کامپیوتر نگهداری می‌شوند.',
    noteTitle: 'یادداشت جلسه',
    noteLabel: 'شرح کار انجام‌شده',
    optional: 'اختیاری',
    cancel: 'انصراف',
    saveNote: 'ذخیرهٔ یادداشت',
    addNote: 'افزودن یادداشت',
    loadStored: 'بارگذاری یادداشت ذخیره‌شده',
    saveMine: 'ذخیرهٔ متن من',
    savedNote: 'یادداشت ذخیره‌شده',
    previous: 'قبلی',
    next: 'بعدی',
    untilWord: 'تا',
    unknownEnd: 'نامشخص',
    atLeast: 'حداقل',
    connecting: 'در حال اتصال —',
    clockChanged: 'ساعت سیستم تغییر کرده است.',
    sessions: 'جلسه',
    invalidQuery: 'فیلتر تاریخچه معتبر نیست.',
    invalidNote: 'یادداشت باید حداکثر ۲۰۰۰ نویسه و متن ساده باشد.',
    notFound: 'این جلسه در تاریخچه پیدا نشد.',
    noteConflict: 'یادداشت در پنجرهٔ دیگری تغییر کرده است.',
    historyBusy: 'تاریخچه در حال ذخیره است؛ دوباره تلاش کنید.',
    historyIo: 'خواندن یا ذخیرهٔ تاریخچه انجام نشد.',
    futureSchema: 'این تاریخچه با نسخهٔ جدیدتری ساخته شده است.',
    historyUnavailable: 'تاریخچه در این حالت در دسترس نیست.',
    unreadable: 'بعضی از سابقه‌ها قابل خواندن نیستند؛ فایل‌ها حفظ شده‌اند.',
    fileTransfer: 'انتقال فایل',
    tunnel: 'تونل',
    rdp: 'RDP',
    camera: 'دوربین',
    terminal: 'ترمینال',
  );

  static const en = HistoryCopy(
    title: 'Session History',
    subtitle: 'Previous connections and support notes',
    onThisComputer: 'On this computer',
    searchLabel: 'Customer search',
    searchHint: 'Name or device ID',
    dateLabel: 'Connection date',
    allDates: 'All dates',
    today: 'Today',
    yesterday: 'Yesterday',
    lastSevenDays: 'Last 7 days',
    newestFirst: 'Newest connections first',
    peerColumn: 'Customer / device',
    whenColumn: 'Connection date and time',
    durationColumn: 'Duration',
    noteColumn: 'Note',
    emptyTitle: 'No session found',
    emptyBody: 'Check the name or ID, or choose another date.',
    clearFilters: 'Clear filters',
    footer: 'History and notes stay only on this computer.',
    noteTitle: 'Session note',
    noteLabel: 'Work performed',
    optional: 'optional',
    cancel: 'Cancel',
    saveNote: 'Save note',
    addNote: 'Add note',
    loadStored: 'Load saved note',
    saveMine: 'Save my text',
    savedNote: 'Saved note',
    previous: 'Previous',
    next: 'Next',
    untilWord: 'to',
    unknownEnd: 'Unknown',
    atLeast: 'at least',
    connecting: 'Connecting —',
    clockChanged: 'The system clock has changed.',
    sessions: 'sessions',
    invalidQuery: 'History filter is invalid.',
    invalidNote: 'A note must be plain text of at most 2000 characters.',
    notFound: 'This session was not found in history.',
    noteConflict: 'The note was changed in another window.',
    historyBusy: 'History is being saved; try again.',
    historyIo: 'History could not be read or saved.',
    futureSchema: 'This history was created by a newer version.',
    historyUnavailable: 'History is not available in this mode.',
    unreadable: 'Some history records could not be read; the files were kept.',
    fileTransfer: 'File transfer',
    tunnel: 'Tunnel',
    rdp: 'RDP',
    camera: 'Camera',
    terminal: 'Terminal',
  );
}

/// Same outgoing-UI gate as the home connect panel: hidden for incoming-only.
bool raatikHistoryEnabled({required bool incomingOnly}) => !incomingOnly;

Future<T> _decode<T>(Future<String> Function() read, T Function(Map<String, dynamic>) parse) async {
  try {
    final raw = await read();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const HistoryFailure('history_io');
    return parse(Map<String, dynamic>.from(decoded));
  } on HistoryFailure {
    rethrow;
  } catch (_) {
    throw const HistoryFailure('history_io');
  }
}

int _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw const HistoryFailure('history_io');
}

String _jsonString(Object? value) {
  if (value is String) return value;
  throw const HistoryFailure('history_io');
}

String _two(int value) => value.toString().padLeft(2, '0');

String _four(int value) => value.toString().padLeft(4, '0');
