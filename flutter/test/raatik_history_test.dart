import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/history/history_page.dart';
import 'package:flutter_hbb/raatik/history/history_repository.dart';
import 'package:flutter_hbb/raatik/navigation/app_shell.dart';

import 'raatik_test_app.dart';

const _completedId = '11111111-1111-4111-8111-111111111111';
const _activeId = '22222222-2222-4222-8222-222222222222';
const _interruptedId = '33333333-3333-4333-8333-333333333333';
const _otherId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

HistoryRecord sample({
  String id = _completedId,
  String name = 'شرکت نمونه',
  String peerId = '123456789',
  String status = 'completed',
  int started = 1794117600000,
  int? ended = 1794118650000,
  int elapsed = 1050000,
  String note = '',
  int revision = 0,
  String type = 'desktop',
}) {
  return HistoryRecord(
    schema: 1,
    recordId: id,
    connectionType: type,
    peerId: peerId,
    peerName: name,
    startedAtUtcMs: started,
    endedAtUtcMs: ended,
    elapsedMs: elapsed,
    checkpointAtUtcMs: started,
    status: status,
    ownerPid: 4242,
    ownerStartedAt: 134123456789000000,
    note: note,
    noteRevision: revision,
  );
}

HistoryPage pageOf(List<HistoryRecord> records, {int? total, List<String> warnings = const []}) {
  return HistoryPage(records: records, total: total ?? records.length, warnings: warnings);
}

class RecordingHistoryRepository implements HistoryRepository {
  RecordingHistoryRepository({this.onQuery, this.onSave, this.onGet});

  final List<HistoryQuery> queries = [];
  final List<({String id, int revision, String note})> saves = [];
  final List<String> gets = [];
  Future<HistoryPage> Function(HistoryQuery query)? onQuery;
  Future<HistoryRecord> Function(String id, int revision, String note)? onSave;
  Future<HistoryRecord> Function(String id)? onGet;
  HistoryPage page = pageOf(const []);

  @override
  Future<HistoryPage> query(HistoryQuery query) {
    queries.add(query);
    final handler = onQuery;
    if (handler != null) return handler(query);
    return Future<HistoryPage>.value(page);
  }

  @override
  Future<HistoryRecord> get(String recordId) {
    gets.add(recordId);
    final handler = onGet;
    if (handler != null) return handler(recordId);
    throw const HistoryFailure('not_found');
  }

  @override
  Future<HistoryRecord> saveNote(String recordId, int expectedRevision, String note) {
    saves.add((id: recordId, revision: expectedRevision, note: note));
    final handler = onSave;
    if (handler != null) return handler(recordId, expectedRevision, note);
    throw const HistoryFailure('history_io');
  }
}

class ThrowingBridge implements HistoryRawBridge {
  ThrowingBridge(this.error);

  final Object error;

  @override
  Future<String> query(String queryJson) async => throw error;

  @override
  Future<String> getRecord(String recordId) async => throw error;

  @override
  Future<String> saveNote(String recordId, int expectedRevision, String note) async =>
      throw error;
}

class ScriptedBridge implements HistoryRawBridge {
  ScriptedBridge({this.body = '{"records":[],"total":0,"warnings":[]}', this.failure});

  String body;
  String? failure;
  String? lastQuery;
  int saves = 0;

  @override
  Future<String> query(String queryJson) async {
    lastQuery = queryJson;
    if (failure != null) throw HistoryFailure(failure!);
    return body;
  }

  @override
  Future<String> getRecord(String recordId) async {
    if (failure != null) throw HistoryFailure(failure!);
    return body;
  }

  @override
  Future<String> saveNote(String recordId, int expectedRevision, String note) async {
    saves += 1;
    if (failure != null) throw HistoryFailure(failure!);
    return body;
  }
}

Future<void> pumpPage(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1200, 800),
  Locale locale = const Locale('fa'),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(testApp(child, size: size, locale: locale, themeMode: themeMode));
  await tester.pump();
}

Future<void> openNote(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(historyNoteKey(id)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('history follows the existing incoming-only gate', () {
    expect(raatikHistoryEnabled(incomingOnly: true), isFalse);
    expect(raatikHistoryEnabled(incomingOnly: false), isTrue);
  });

  test('ffi repository decodes fixture json and never invents a saved note', () async {
    const record = '''
{"schema":1,"record_id":"11111111-1111-4111-8111-111111111111","connection_type":"desktop","peer_id":"123456789","peer_name":"شرکت نمونه","started_at_utc_ms":1794117600000,"ended_at_utc_ms":1794118650000,"elapsed_ms":1050000,"checkpoint_at_utc_ms":1794118650000,"status":"completed","owner_pid":4242,"owner_started_at":0,"note":"پیگیری فردا","note_revision":1}
''';
    final bridge = ScriptedBridge(
      body:
          '{"records":[$record],"total":1,"warnings":["unreadable_records","future_schema"]}',
    );
    final repo = FfiHistoryRepository(bridge: bridge);
    final page = await repo.query(const HistoryQuery(
      search: '۱۲۳',
      fromUtcMs: null,
      toUtcMs: null,
      offset: 0,
      limit: 20,
    ));
    final sent = jsonDecode(bridge.lastQuery!) as Map<String, dynamic>;
    expect(sent.keys.toSet(), {'search', 'from_utc_ms', 'to_utc_ms', 'offset', 'limit'});
    expect(sent['search'], '۱۲۳');
    expect(sent['limit'], 20);
    expect(sent['offset'], 0);
    expect(sent['from_utc_ms'], isNull);
    expect(page.total, 1);
    expect(page.warnings, ['unreadable_records', 'future_schema']);
    expect(page.records.single.peerName, 'شرکت نمونه');
    expect(page.records.single.note, 'پیگیری فردا');
    expect(page.records.single.elapsedMs, 1050000);

    bridge.body = record;
    final saved = await repo.saveNote(_completedId, 0, 'پیگیری فردا');
    expect(saved.noteRevision, 1);
    expect(bridge.saves, 1);

    bridge.failure = 'note_conflict';
    expect(
      () => repo.saveNote(_completedId, 0, 'قدیمی'),
      throwsA(isA<HistoryFailure>().having((error) => error.code, 'code', 'note_conflict')),
    );
    bridge.body = 'not-json';
    bridge.failure = null;
    expect(
      () => repo.saveNote(_completedId, 1, 'x'),
      throwsA(isA<HistoryFailure>().having((error) => error.code, 'code', 'history_io')),
    );

    final unavailable = FfiHistoryRepository();
    expect(
      () => unavailable.saveNote(_completedId, 0, 'x'),
      throwsA(
        isA<HistoryFailure>().having((error) => error.code, 'code', 'history_unavailable'),
      ),
    );
    expect(
      () => unavailable.query(const HistoryQuery(
        search: '',
        fromUtcMs: null,
        toUtcMs: null,
        offset: 0,
        limit: 20,
      )),
      throwsA(
        isA<HistoryFailure>().having((error) => error.code, 'code', 'history_unavailable'),
      ),
    );
  });

  test('known bridge error strings survive when they are not HistoryFailure', () async {
    for (final code in ['note_conflict', 'invalid_note', 'not_found', 'history_busy']) {
      final fromString = FfiHistoryRepository(bridge: ThrowingBridge(code));
      expect(
        () => fromString.saveNote(_completedId, 0, 'x'),
        throwsA(isA<HistoryFailure>().having((error) => error.code, 'code', code)),
      );
      final fromBridge = FfiHistoryRepository(
        bridge: ThrowingBridge(FfiException('RESULT_ERROR', code)),
      );
      expect(
        () => fromBridge.get(_completedId),
        throwsA(isA<HistoryFailure>().having((error) => error.code, 'code', code)),
      );
    }
  });

  test('Windows newline folds before the 2000-scalar note check', () {
    expect(validateHistoryNote('a\r\nb'), isNull);
    expect(validateHistoryNote('a\rb'), isNull);
    expect(validateHistoryNote('${'😀' * 1999}\r\n'), isNull);
    expect(validateHistoryNote('${'😀' * 2000}\r\n'), 'invalid_note');
    expect(validateHistoryNote('ok\r\u0001'), 'invalid_note');
  });

  testWidgets('persian digit search stays raw, limit is 20, and newest is first', (tester) async {
    final repo = RecordingHistoryRepository();
    final newer = sample(id: _activeId, name: 'جدید', started: 3000, ended: null, status: 'completed');
    final older = sample(id: _completedId, name: 'قدیم', started: 1000);
    repo.onQuery = (query) async {
      final digits = query.search.replaceAll('۱', '1').replaceAll('۲', '2').replaceAll('۳', '3');
      if (digits.contains('123')) {
        return pageOf([sample(peerId: '123456789')]);
      }
      return pageOf([newer, older]);
    };
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    expect(repo.queries.single.limit, 20);
    expect(repo.queries.single.offset, 0);
    expect(tester.getTopLeft(find.text('جدید')).dy, lessThan(tester.getTopLeft(find.text('قدیم')).dy));

    await tester.enterText(find.byKey(historySearchKey), '۱۲۳');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repo.queries.where((query) => query.search == '۱۲۳'), isEmpty);
    await tester.pump(const Duration(milliseconds: 20));
    expect(repo.queries.last.search, '۱۲۳');
    expect(repo.queries.last.limit, 20);
    expect(repo.queries.last.offset, 0);
    expect(find.text('شرکت نمونه'), findsOneWidget);
    expect(find.text('جدید'), findsNothing);

    await tester.tap(find.byKey(historyRefreshKey));
    await tester.pump();
    expect(find.byKey(historyRowKey(_completedId)), findsOneWidget);
    expect(repo.queries.last.offset, 0);
  });

  testWidgets('a slow search cannot replace a newer query', (tester) async {
    final pending = <Completer<HistoryPage>>[];
    final repo = RecordingHistoryRepository(onQuery: (query) {
      final completer = Completer<HistoryPage>();
      pending.add(completer);
      return completer.future;
    });
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    expect(find.byKey(historyLoadingKey), findsOneWidget);
    pending[0].complete(pageOf(const []));
    await tester.pump();

    await tester.enterText(find.byKey(historySearchKey), '۱۲۳');
    await tester.pump(const Duration(milliseconds: 300));
    expect(pending, hasLength(2));
    await tester.enterText(find.byKey(historySearchKey), '999');
    await tester.pump(const Duration(milliseconds: 300));
    expect(pending, hasLength(3));
    pending[1].complete(pageOf([sample(name: 'قدیمی')]));
    await tester.pump();
    expect(find.text('قدیمی'), findsNothing);
    pending[2].complete(pageOf([sample(name: 'تازه', id: _otherId)]));
    await tester.pump();
    expect(find.text('تازه'), findsOneWidget);
    expect(find.text('قدیمی'), findsNothing);
  });

  testWidgets('empty, error, and partial warnings stay distinct', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf(const []);
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    expect(find.byKey(historyEmptyKey), findsOneWidget);
    expect(find.text('جلسه‌ای پیدا نشد'), findsOneWidget);
    expect(find.byKey(historyErrorKey), findsNothing);

    repo.onQuery = (_) async => pageOf(
          [sample()],
          warnings: const ['unreadable_records', 'future_schema', 'disk_full'],
        );
    await tester.tap(find.byKey(historyRefreshKey));
    await tester.pump();
    expect(find.text('بعضی از سابقه‌ها قابل خواندن نیستند؛ فایل‌ها حفظ شده‌اند.'), findsOneWidget);
    expect(find.text('این تاریخچه با نسخهٔ جدیدتری ساخته شده است.'), findsOneWidget);
    expect(find.text('شرکت نمونه'), findsOneWidget);
    expect(find.text('disk_full'), findsNothing);

    repo.onQuery = (_) async => throw const HistoryFailure('invalid_query');
    await tester.tap(find.byKey(historyRefreshKey));
    await tester.pump();
    expect(find.text('فیلتر تاریخچه معتبر نیست.'), findsOneWidget);
    expect(find.text('شرکت نمونه'), findsOneWidget);

    repo.onQuery = (_) async => throw const HistoryFailure('history_io');
    await tester.tap(find.byKey(historyRefreshKey));
    await tester.pump();
    expect(find.text('خواندن یا ذخیرهٔ تاریخچه انجام نشد.'), findsOneWidget);
    expect(find.text('شرکت نمونه'), findsOneWidget);
  });

  testWidgets('history_unavailable disables refresh and does not claim an empty history', (tester) async {
    final repo = RecordingHistoryRepository(
      onQuery: (_) async => throw const HistoryFailure('history_unavailable'),
    );
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    expect(find.text('تاریخچه در این حالت در دسترس نیست.'), findsOneWidget);
    expect(find.byKey(historyEmptyKey), findsNothing);
    final refresh = tester.widget<IconButton>(find.byKey(historyRefreshKey));
    expect(refresh.onPressed, isNull);
  });

  testWidgets('date filter resets the page and keeps the search text', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.onQuery = (query) async {
      if (query.offset == 0) return pageOf([sample(name: 'صفحه اول')], total: 41);
      return pageOf([sample(name: 'صفحه دوم', id: _otherId)], total: 41);
    };
    await pumpPage(
      tester,
      RaatikHistoryPage(
        repository: repo,
        clock: () => DateTime(2026, 11, 8, 12),
      ),
    );
    await tester.enterText(find.byKey(historySearchKey), 'نمونه');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(historyNextKey));
    await tester.pump();
    expect(repo.queries.last.offset, 20);
    expect(find.text('صفحه دوم'), findsOneWidget);
    expect(find.text('صفحه اول'), findsNothing);

    await tester.tap(find.byKey(historyDateKey));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(historyDateTodayKey));
    await tester.pump(const Duration(milliseconds: 400));
    final today = localDateRange(HistoryDateFilter.today, DateTime(2026, 11, 8, 12));
    expect(repo.queries.last.offset, 0);
    expect(repo.queries.last.search, 'نمونه');
    expect(repo.queries.last.fromUtcMs, today.fromUtc!.millisecondsSinceEpoch);
    expect(repo.queries.last.toUtcMs, today.toUtc!.millisecondsSinceEpoch);
    expect(find.text('صفحه اول'), findsOneWidget);

    await tester.tap(find.byKey(historyClearKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.queries.last.search, '');
    expect(repo.queries.last.fromUtcMs, isNull);
    expect(repo.queries.last.toUtcMs, isNull);
    expect(repo.queries.last.offset, 0);
  });

  testWidgets('shows jalali date, lower-bound duration, and clock rollback copy', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([
      sample(type: 'file_transfer', elapsed: 1050000),
      sample(
        id: _interruptedId,
        name: 'قطع شده',
        status: 'interrupted',
        ended: null,
        elapsed: 30000,
        started: 1794061800000,
      ),
      sample(
        id: _otherId,
        name: 'ساعت برگشته',
        started: 5000,
        ended: 1000,
        elapsed: 1050000,
      ),
    ]);
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    final started = DateTime.fromMillisecondsSinceEpoch(1794117600000, isUtc: true);
    expect(find.text(formatHistoryDate(started, jalali: true)), findsOneWidget);
    expect(find.text('00:17:30'), findsWidgets);
    expect(find.text('انتقال فایل'), findsOneWidget);
    expect(find.text('حداقل 00:00:30'), findsOneWidget);
    expect(find.text('نامشخص'), findsOneWidget);
    expect(find.text('ساعت سیستم تغییر کرده است.'), findsOneWidget);
    expect(find.textContaining('desktop'), findsNothing);
  });

  testWidgets('english locale uses gregorian dates and english duration copy', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([
      sample(
        id: _interruptedId,
        status: 'interrupted',
        ended: null,
        elapsed: 30000,
        type: 'terminal',
      ),
    ]);
    await pumpPage(
      tester,
      RaatikHistoryPage(repository: repo),
      locale: const Locale('en'),
    );
    final started = DateTime.fromMillisecondsSinceEpoch(1794117600000, isUtc: true);
    expect(find.text(formatHistoryDate(started, jalali: false)), findsOneWidget);
    expect(find.text(formatHistoryDate(started, jalali: true)), findsNothing);
    expect(find.text('at least 00:00:30'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
  });

  testWidgets('active row refreshes every 30 seconds only while visible', (tester) async {
    final visible = ValueNotifier(true);
    final repo = RecordingHistoryRepository();
    repo.page = pageOf(
      [sample(id: _activeId, status: 'active', ended: null, elapsed: 30000)],
      total: 41,
    );
    await pumpPage(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, value, _) {
          return RaatikPageVisibility(
            visible: value,
            child: RaatikHistoryPage(repository: repo),
          );
        },
      ),
    );
    expect(repo.queries, hasLength(1));
    await tester.tap(find.byKey(historyNextKey));
    await tester.pump();
    expect(repo.queries.last.offset, 20);
    await tester.pump(const Duration(seconds: 29));
    expect(repo.queries, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(repo.queries, hasLength(3));
    expect(repo.queries.last.offset, 20);
    expect(repo.queries.last.limit, 20);

    visible.value = false;
    await tester.pump();
    final hiddenCount = repo.queries.length;
    await tester.pump(const Duration(seconds: 30));
    expect(repo.queries, hasLength(hiddenCount));

    visible.value = true;
    await tester.pump();
    expect(repo.queries.length, hiddenCount + 1);
    expect(repo.queries.last.offset, 20);

    await tester.pumpWidget(testApp(const SizedBox.shrink(), size: const Size(1200, 800)));
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
    expect(repo.queries.length, hiddenCount + 1);
  });

  testWidgets('manual refresh returns to the first page', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.onQuery = (query) async => pageOf(
          [sample(name: query.offset == 0 ? 'اول' : 'بعد', id: query.offset == 0 ? _completedId : _otherId)],
          total: 41,
        );
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    await tester.tap(find.byKey(historyNextKey));
    await tester.pump();
    expect(repo.queries.last.offset, 20);
    await tester.tap(find.byKey(historyRefreshKey));
    await tester.pump();
    expect(repo.queries.last.offset, 0);
    expect(find.text('اول'), findsOneWidget);
    expect(find.text('بعد'), findsNothing);
  });

  testWidgets('cancel does not save and a failed save stays open', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([sample(note: 'قبلی')]);
    repo.onSave = (_, __, ___) async => throw const HistoryFailure('history_io');
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    await openNote(tester, _completedId);
    expect(find.byKey(historyNoteDialogKey), findsOneWidget);
    await tester.enterText(find.byKey(historyNoteFieldKey), '   ');
    await tester.tap(find.byKey(historyNoteCancelKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(historyNoteDialogKey), findsNothing);
    expect(repo.saves, isEmpty);

    await openNote(tester, _completedId);
    await tester.enterText(find.byKey(historyNoteFieldKey), '   ');
    await tester.tap(find.byKey(historyNoteSaveKey));
    await tester.pump();
    expect(repo.saves.single.note, '   ');
    expect(find.byKey(historyNoteDialogKey), findsOneWidget);
    expect(find.text('خواندن یا ذخیرهٔ تاریخچه انجام نشد.'), findsOneWidget);
    expect(find.text('قبلی'), findsWidgets);
  });

  testWidgets('note length uses unicode scalars and keeps focus on invalid text', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([sample()]);
    var saved = false;
    repo.onSave = (id, revision, note) async {
      saved = true;
      return sample(note: note, revision: revision + 1);
    };
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    await openNote(tester, _completedId);
    await tester.enterText(find.byKey(historyNoteFieldKey), '${'😀' * 2001}\u0001');
    await tester.tap(find.byKey(historyNoteSaveKey));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.byKey(historyNoteDialogKey), findsOneWidget);
    expect(find.text('یادداشت باید حداکثر ۲۰۰۰ نویسه و متن ساده باشد.'), findsOneWidget);
    final editable = tester.widget<EditableText>(find.descendant(
      of: find.byKey(historyNoteFieldKey),
      matching: find.byType(EditableText),
    ));
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.enterText(find.byKey(historyNoteFieldKey), '😀' * 2000);
    await tester.tap(find.byKey(historyNoteSaveKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(saved, isTrue);
    expect(repo.saves.single.note.runes.length, 2000);
    expect(find.byKey(historyNoteDialogKey), findsNothing);
  });

  testWidgets('a pasted Windows newline reaches the store as LF', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([sample()]);
    repo.onSave = (id, revision, note) async => sample(note: note, revision: revision + 1);
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    await openNote(tester, _completedId);
    final editable = tester.widget<EditableText>(find.descendant(
      of: find.byKey(historyNoteFieldKey),
      matching: find.byType(EditableText),
    ));
    editable.controller.text = 'خط اول\r\nخط دوم';
    await tester.pump();
    await tester.tap(find.byKey(historyNoteSaveKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('یادداشت باید حداکثر ۲۰۰۰ نویسه و متن ساده باشد.'), findsNothing);
    expect(repo.saves.single.note, 'خط اول\nخط دوم');
    expect(find.byKey(historyNoteDialogKey), findsNothing);
  });

  testWidgets('revision conflict keeps the draft and does not save again', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([sample(note: '', revision: 0)]);
    repo.onSave = (id, revision, note) async {
      if (revision == 0) throw const HistoryFailure('note_conflict');
      return sample(note: note, revision: revision + 1);
    };
    repo.onGet = (id) async => sample(note: 'ذخیره شده', revision: 4);
    await pumpPage(tester, RaatikHistoryPage(repository: repo));
    await openNote(tester, _completedId);
    await tester.enterText(find.byKey(historyNoteFieldKey), 'متن من');
    await tester.tap(find.byKey(historyNoteSaveKey));
    await tester.pump();
    expect(repo.saves, hasLength(1));
    expect(repo.saves.single.revision, 0);
    expect(repo.gets, [_completedId]);
    expect(find.text('یادداشت در پنجرهٔ دیگری تغییر کرده است.'), findsOneWidget);
    expect(find.byKey(historyNoteLatestKey), findsOneWidget);
    expect(find.text('ذخیره شده'), findsOneWidget);
    final draft = tester.widget<EditableText>(find.descendant(
      of: find.byKey(historyNoteFieldKey),
      matching: find.byType(EditableText),
    ));
    expect(draft.controller.text, 'متن من');

    await tester.tap(find.byKey(historyNoteLoadKey));
    await tester.pump();
    expect(repo.saves, hasLength(1));
    expect(draft.controller.text, 'ذخیره شده');

    await tester.tap(find.byKey(historyNoteSaveMineKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.saves, hasLength(2));
    expect(repo.saves.last.revision, 4);
    expect(repo.saves.last.note, 'ذخیره شده');
    expect(find.byKey(historyNoteDialogKey), findsNothing);

    await openNote(tester, _completedId);
    final reopened = tester.widget<EditableText>(find.descendant(
      of: find.byKey(historyNoteFieldKey),
      matching: find.byType(EditableText),
    ));
    expect(reopened.controller.text, 'ذخیره شده');
  });

  testWidgets('compact width still shows the session and dark theme builds', (tester) async {
    final repo = RecordingHistoryRepository();
    repo.page = pageOf([sample()]);
    await pumpPage(
      tester,
      RaatikHistoryPage(repository: repo),
      size: const Size(480, 800),
      themeMode: ThemeMode.dark,
    );
    expect(find.text('شرکت نمونه'), findsOneWidget);
    expect(find.byKey(historyNoteKey(_completedId)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
