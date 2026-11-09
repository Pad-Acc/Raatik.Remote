import 'dart:async';

import 'package:flutter/material.dart';

import '../dialogs/dialog_style.dart';
import '../layout/breakpoints.dart';
import '../navigation/app_shell.dart';
import '../text/identifier_widgets.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'history_note_dialog.dart';
import 'history_repository.dart';

export 'history_note_dialog.dart'
    show
        historyNoteCancelKey,
        historyNoteDialogKey,
        historyNoteFieldKey,
        historyNoteLatestKey,
        historyNoteLoadKey,
        historyNoteSaveKey,
        historyNoteSaveMineKey;
export 'history_repository.dart' show raatikHistoryEnabled;

const historySearchKey = Key('raatik-history-search');
const historyDateKey = Key('raatik-history-date');
const historyDateAllKey = Key('raatik-history-date-all');
const historyDateTodayKey = Key('raatik-history-date-today');
const historyDateYesterdayKey = Key('raatik-history-date-yesterday');
const historyDateWeekKey = Key('raatik-history-date-week');
const historyEmptyKey = Key('raatik-history-empty');
const historyErrorKey = Key('raatik-history-error');
const historyWarningKey = Key('raatik-history-warning');
const historyLoadingKey = Key('raatik-history-loading');
const historyRefreshKey = Key('raatik-history-refresh');
const historyPrevKey = Key('raatik-history-prev');
const historyNextKey = Key('raatik-history-next');
const historyClearKey = Key('raatik-history-clear');
const historyClockKey = Key('raatik-history-clock-changed');

Key historyRowKey(String id) => Key('raatik-history-row-$id');

Key historyNoteKey(String id) => Key('raatik-history-note-$id');

const _pageSize = 20;

class HistoryUiController extends ChangeNotifier {
  HistoryUiController({
    required this.repository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final HistoryRepository repository;
  final DateTime Function() clock;

  String search = '';
  HistoryDateFilter filter = HistoryDateFilter.all;
  int pageIndex = 0;
  List<HistoryRecord> records = const [];
  int total = 0;
  List<String> warnings = const [];
  String? errorCode;
  bool loading = false;
  bool visible = false;

  bool _started = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _searchTimer;
  Timer? _pollTimer;

  bool get canGoBack => pageIndex > 0;

  bool get canGoForward => (pageIndex + 1) * _pageSize < total;

  bool get actionsEnabled => errorCode != 'history_unavailable';

  void setVisible(bool next) {
    if (_disposed) return;
    if (_started && visible == next) return;
    visible = next;
    _started = true;
    _stopPoll();
    if (!next) {
      notifyListeners();
      return;
    }
    _load(manual: false);
  }

  void setSearch(String value) {
    if (_disposed || value == search) return;
    search = value;
    _searchTimer?.cancel();
    _generation += 1;
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (_disposed) return;
      pageIndex = 0;
      _load(manual: false);
    });
    notifyListeners();
  }

  void setFilter(HistoryDateFilter next) {
    if (_disposed || next == filter) return;
    _searchTimer?.cancel();
    filter = next;
    pageIndex = 0;
    _load(manual: false);
  }

  Future<void> refresh() {
    _searchTimer?.cancel();
    return _load(manual: true);
  }

  /// Re-reads the current page without clearing search or moving to page 0.
  Future<void> reload() {
    _searchTimer?.cancel();
    return _load(manual: false);
  }

  Future<void> goToPage(int zeroBased) {
    if (_disposed || zeroBased < 0 || zeroBased == pageIndex) return Future<void>.value();
    _searchTimer?.cancel();
    pageIndex = zeroBased;
    return _load(manual: false);
  }

  void clearFilters() {
    if (_disposed) return;
    _searchTimer?.cancel();
    search = '';
    filter = HistoryDateFilter.all;
    pageIndex = 0;
    _load(manual: false);
  }

  void replaceRecord(HistoryRecord record) {
    if (_disposed) return;
    final index = records.indexWhere((item) => item.recordId == record.recordId);
    if (index < 0) return;
    final next = [...records];
    next[index] = record;
    records = next;
    _armPoll();
    notifyListeners();
  }

  Future<void> _load({required bool manual}) async {
    if (_disposed) return;
    if (manual) pageIndex = 0;
    final generation = ++_generation;
    loading = true;
    notifyListeners();
    final range = localDateRange(filter, clock());
    final query = HistoryQuery(
      search: search,
      fromUtcMs: range.fromUtc?.millisecondsSinceEpoch,
      toUtcMs: range.toUtc?.millisecondsSinceEpoch,
      offset: pageIndex * _pageSize,
      limit: _pageSize,
    );
    try {
      final page = await repository.query(query);
      if (_disposed || generation != _generation) return;
      final lastPage = page.total == 0 ? 0 : (page.total - 1) ~/ _pageSize;
      if (pageIndex > lastPage) {
        pageIndex = lastPage;
        await _load(manual: false);
        return;
      }
      records = page.records;
      total = page.total;
      warnings = page.warnings;
      errorCode = null;
    } on HistoryFailure catch (error) {
      if (_disposed || generation != _generation) return;
      errorCode = error.code;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      errorCode = 'history_io';
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    _armPoll();
    notifyListeners();
  }

  void _armPoll() {
    _stopPoll();
    if (_disposed || !visible) return;
    if (!records.any((record) => record.status == 'active')) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed || !visible) return;
      _load(manual: false);
    });
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _searchTimer?.cancel();
    _stopPoll();
    super.dispose();
  }
}

class RaatikHistoryPage extends StatefulWidget {
  const RaatikHistoryPage({
    super.key,
    required this.repository,
    this.clock,
  });

  final HistoryRepository repository;
  final DateTime Function()? clock;

  @override
  State<RaatikHistoryPage> createState() => _RaatikHistoryPageState();
}

class _RaatikHistoryPageState extends State<RaatikHistoryPage> {
  late final HistoryUiController _controller = HistoryUiController(
    repository: widget.repository,
    clock: widget.clock,
  );
  late final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onController);
  }

  void _onController() {
    if (!mounted) return;
    if (_search.text != _controller.search) {
      _search.value = TextEditingValue(
        text: _controller.search,
        selection: TextSelection.collapsed(offset: _controller.search.length),
      );
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.setVisible(RaatikPageVisibility.of(context));
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openNote(HistoryRecord record, HistoryCopy copy) async {
    final updated = await showGeneralDialog<HistoryRecord>(
      context: context,
      barrierDismissible: false,
      barrierLabel: copy.cancel,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return HistoryNoteDialog(
          record: record,
          repository: widget.repository,
          copy: copy,
          onRecordMissing: () {
            _controller.reload();
          },
        );
      },
    );
    if (updated != null) _controller.replaceRecord(updated);
  }

  @override
  Widget build(BuildContext context) {
    final copy = HistoryCopy.of(Localizations.localeOf(context));
    final jalali = Localizations.localeOf(context).languageCode == 'fa';
    final controller = _controller;
    final unavailable = !controller.actionsEnabled;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = raatikWindowClassFor(constraints.maxWidth) == RaatikWindowClass.compact;
        return Padding(
          padding: EdgeInsets.all(compact ? RaatikTokens.space4 : RaatikTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copy.title, style: RaatikTextStyles.titleLg(context)),
                        const SizedBox(height: RaatikTokens.space1),
                        Text(copy.subtitle, style: RaatikTextStyles.caption(context)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: historyRefreshKey,
                    tooltip: copy.previous,
                    onPressed: unavailable ? null : () => controller.refresh(),
                    icon: const Icon(Icons.refresh),
                    constraints: const BoxConstraints(
                      minWidth: RaatikTokens.minTarget,
                      minHeight: RaatikTokens.minTarget,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaatikTokens.space4),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _searchField(copy),
                    const SizedBox(height: RaatikTokens.space3),
                    _dateField(copy, controller),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 3, child: _searchField(copy)),
                    const SizedBox(width: RaatikTokens.space3),
                    Expanded(flex: 2, child: _dateField(copy, controller)),
                  ],
                ),
              const SizedBox(height: RaatikTokens.space3),
              Row(
                children: [
                  Expanded(child: Text(copy.newestFirst, style: RaatikTextStyles.caption(context))),
                  TextButton(
                    key: historyClearKey,
                    onPressed: controller.clearFilters,
                    style: TextButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
                    child: Text(copy.clearFilters),
                  ),
                ],
              ),
              if (controller.warnings.isNotEmpty)
                Padding(
                  key: historyWarningKey,
                  padding: const EdgeInsets.only(bottom: RaatikTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final code in controller.warnings)
                        if (copy.warning(code) != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: RaatikTokens.space2),
                            child: Text(copy.warning(code)!),
                          ),
                    ],
                  ),
                ),
              if (controller.errorCode != null)
                Padding(
                  key: historyErrorKey,
                  padding: const EdgeInsets.only(bottom: RaatikTokens.space3),
                  child: Text(
                    copy.error(controller.errorCode!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(child: _body(context, copy, jalali, compact)),
              const SizedBox(height: RaatikTokens.space3),
              Row(
                children: [
                  TextButton(
                    key: historyPrevKey,
                    onPressed: controller.canGoBack
                        ? () => controller.goToPage(controller.pageIndex - 1)
                        : null,
                    style: TextButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
                    child: Text(copy.previous),
                  ),
                  const SizedBox(width: RaatikTokens.space2),
                  TextButton(
                    key: historyNextKey,
                    onPressed: controller.canGoForward
                        ? () => controller.goToPage(controller.pageIndex + 1)
                        : null,
                    style: TextButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
                    child: Text(copy.next),
                  ),
                ],
              ),
              const SizedBox(height: RaatikTokens.space2),
              Text(copy.footer, style: RaatikTextStyles.caption(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _searchField(HistoryCopy copy) {
    return TextField(
      key: historySearchKey,
      controller: _search,
      onChanged: _controller.setSearch,
      decoration: InputDecoration(
        labelText: copy.searchLabel,
        hintText: copy.searchHint,
      ),
    );
  }

  Widget _dateField(HistoryCopy copy, HistoryUiController controller) {
    return DropdownButtonFormField<HistoryDateFilter>(
      key: historyDateKey,
      isExpanded: true,
      value: controller.filter,
      decoration: InputDecoration(labelText: copy.dateLabel),
      items: [
        DropdownMenuItem(
          key: historyDateAllKey,
          value: HistoryDateFilter.all,
          child: Text(copy.allDates),
        ),
        DropdownMenuItem(
          key: historyDateTodayKey,
          value: HistoryDateFilter.today,
          child: Text(copy.today),
        ),
        DropdownMenuItem(
          key: historyDateYesterdayKey,
          value: HistoryDateFilter.yesterday,
          child: Text(copy.yesterday),
        ),
        DropdownMenuItem(
          key: historyDateWeekKey,
          value: HistoryDateFilter.lastSevenDays,
          child: Text(copy.lastSevenDays),
        ),
      ],
      onChanged: (value) {
        if (value != null) controller.setFilter(value);
      },
    );
  }

  Widget _body(BuildContext context, HistoryCopy copy, bool jalali, bool compact) {
    final controller = _controller;
    if (controller.loading && controller.records.isEmpty) {
      return const Center(
        key: historyLoadingKey,
        child: SizedBox(
          width: RaatikTokens.iconLg,
          height: RaatikTokens.iconLg,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (controller.records.isEmpty && controller.errorCode == null) {
      return Center(
        key: historyEmptyKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(copy.emptyTitle, style: RaatikTextStyles.titleMd(context)),
            const SizedBox(height: RaatikTokens.space2),
            Text(copy.emptyBody, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (controller.records.isEmpty) return const SizedBox.shrink();
    return ListView(
      children: [
        for (final record in controller.records)
          _HistoryRow(
            record: record,
            copy: copy,
            jalali: jalali,
            compact: compact,
            onNote: controller.actionsEnabled ? () => _openNote(record, copy) : null,
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.copy,
    required this.jalali,
    required this.compact,
    required this.onNote,
  });

  final HistoryRecord record;
  final HistoryCopy copy;
  final bool jalali;
  final bool compact;
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final started = DateTime.fromMillisecondsSinceEpoch(record.startedAtUtcMs, isUtc: true);
    final ended = record.endedAtUtcMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(record.endedAtUtcMs!, isUtc: true);
    final type = copy.typeLabel(record.connectionType);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record.peerName, style: RaatikTextStyles.titleMd(context)),
        RaatikIdentifierText(record.peerId),
        if (type != null) Text(type, style: RaatikTextStyles.caption(context)),
      ],
    );
    final when = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatHistoryDate(started, jalali: jalali)),
        Text(formatHistoryClock(started), style: RaatikTextStyles.identifier(context)),
        if (record.status == 'interrupted' && ended == null)
          Text(copy.unknownEnd)
        else if (ended != null)
          Text(
            '${copy.untilWord} ${formatHistoryClock(ended)}',
            style: RaatikTextStyles.identifier(context),
          ),
        if (record.clockChanged)
          Text(copy.clockChanged, key: historyClockKey, style: RaatikTextStyles.caption(context)),
      ],
    );
    final duration = Text(copy.durationFor(record), style: RaatikTextStyles.identifier(context));
    final note = TextButton(
      key: historyNoteKey(record.recordId),
      onPressed: onNote,
      style: TextButton.styleFrom(
        minimumSize: raatikDialogButtonMinSize,
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Text(
        record.note.isEmpty ? copy.addNote : record.note,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final body = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: RaatikTokens.space2), when, duration, note],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 4, child: details),
              Expanded(flex: 3, child: when),
              Expanded(flex: 2, child: duration),
              Expanded(flex: 3, child: note),
            ],
          );
    return Container(
      key: historyRowKey(record.recordId),
      margin: const EdgeInsets.only(bottom: RaatikTokens.space3),
      padding: const EdgeInsets.all(RaatikTokens.space4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RaatikTokens.radiusLg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: body,
    );
  }
}
