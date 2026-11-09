import 'package:flutter/material.dart';

import '../dialogs/dialog_style.dart';
import '../theme/tokens.dart';
import 'history_repository.dart';

const historyNoteDialogKey = Key('raatik-history-note-dialog');
const historyNoteFieldKey = Key('raatik-history-note-field');
const historyNoteCancelKey = Key('raatik-history-note-cancel');
const historyNoteSaveKey = Key('raatik-history-note-save');
const historyNoteLatestKey = Key('raatik-history-note-latest');
const historyNoteLoadKey = Key('raatik-history-note-load');
const historyNoteSaveMineKey = Key('raatik-history-note-save-mine');

class HistoryNoteDialog extends StatefulWidget {
  const HistoryNoteDialog({
    super.key,
    required this.record,
    required this.repository,
    required this.copy,
    this.onRecordMissing,
  });

  final HistoryRecord record;
  final HistoryRepository repository;
  final HistoryCopy copy;
  final VoidCallback? onRecordMissing;

  @override
  State<HistoryNoteDialog> createState() => _HistoryNoteDialogState();
}

class _HistoryNoteDialogState extends State<HistoryNoteDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.record.note);
  late final FocusNode _focus = FocusNode();
  HistoryRecord? _latest;
  String? _errorCode;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save({int? revision}) async {
    final note = foldHistoryNewlines(_text.text);
    final problem = validateHistoryNote(note);
    if (problem != null) {
      setState(() => _errorCode = problem);
      _refocus();
      return;
    }
    final expected = revision ?? _latest?.noteRevision ?? widget.record.noteRevision;
    setState(() {
      _saving = true;
      _errorCode = null;
    });
    try {
      final saved = await widget.repository.saveNote(widget.record.recordId, expected, note);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on HistoryFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'note_conflict') {
        await _showConflict(error.code);
        return;
      }
      if (error.code == 'not_found') widget.onRecordMissing?.call();
      setState(() {
        _errorCode = error.code;
        _saving = false;
      });
      _refocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorCode = 'history_io';
        _saving = false;
      });
      _refocus();
    }
  }

  Future<void> _showConflict(String code) async {
    try {
      final fresh = await widget.repository.get(widget.record.recordId);
      if (!mounted) return;
      setState(() {
        _latest = fresh;
        _errorCode = code;
        _saving = false;
      });
    } on HistoryFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'not_found') widget.onRecordMissing?.call();
      setState(() {
        _errorCode = error.code;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorCode = code;
        _saving = false;
      });
    }
    _refocus();
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _loadStored() {
    final latest = _latest;
    if (latest == null) return;
    _text.text = latest.note;
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final conflict = _latest != null;
    final actions = <Widget>[
      TextButton(
        key: historyNoteCancelKey,
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
        child: Text(copy.cancel),
      ),
      if (conflict)
        TextButton(
          key: historyNoteLoadKey,
          onPressed: _saving ? null : _loadStored,
          style: TextButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
          child: Text(copy.loadStored),
        ),
      if (conflict)
        ElevatedButton(
          key: historyNoteSaveMineKey,
          onPressed: _saving ? null : () => _save(revision: _latest!.noteRevision),
          style: ElevatedButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
          child: Text(copy.saveMine),
        )
      else
        ElevatedButton(
          key: historyNoteSaveKey,
          onPressed: _saving ? null : () => _save(),
          style: ElevatedButton.styleFrom(minimumSize: raatikDialogButtonMinSize),
          child: Text(copy.saveNote),
        ),
    ];
    return Dialog(
      key: historyNoteDialogKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: RaatikDialogStyle.maxWidth),
        child: Padding(
          padding: RaatikDialogStyle.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.noteTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: RaatikTokens.space2),
              Text(
                '${widget.record.peerName} · ${widget.record.peerId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: RaatikTokens.space4),
              Text('${copy.noteLabel} (${copy.optional})'),
              const SizedBox(height: RaatikTokens.space2),
              TextField(
                key: historyNoteFieldKey,
                controller: _text,
                focusNode: _focus,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: RaatikTokens.space1),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${foldHistoryNewlines(_text.text).runes.length} / 2000',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (conflict) ...[
                const SizedBox(height: RaatikTokens.space3),
                Text(copy.savedNote),
                const SizedBox(height: RaatikTokens.space1),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(RaatikTokens.space3),
                    child: Text(_latest!.note, key: historyNoteLatestKey),
                  ),
                ),
              ],
              if (_errorCode != null) ...[
                const SizedBox(height: RaatikTokens.space3),
                Text(
                  copy.error(_errorCode!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: RaatikTokens.space4),
              ...?raatikDialogActions(actions),
            ],
          ),
        ),
      ),
    );
  }
}
