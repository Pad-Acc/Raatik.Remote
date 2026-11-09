import 'package:flutter/material.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/layout/breakpoints.dart';
import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';
import 'package:flutter_hbb/raatik/toolbar/session_toolbar.dart';

/// Runs [action] only when the current permission allows it.
bool raatikInvokePermitted(bool permitted, VoidCallback action) {
  if (!permitted) return false;
  action();
  return true;
}

bool raatikFilePanelsSideBySide(double width) =>
    raatikWindowClassFor(width) != RaatikWindowClass.compact;

class RaatikFileEntry {
  const RaatikFileEntry({required this.name, required this.id});

  final String name;
  final String id;
}

/// File name as an LTR island so digits and paths do not reorder in Persian.
class RaatikFileNameText extends StatelessWidget {
  const RaatikFileNameText(
    this.name, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String name;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      ltrIsolate(name),
      maxLines: maxLines,
      overflow: overflow,
      style: RaatikTextStyles.identifier(context).merge(style),
    );
  }
}

/// Selectable error that wraps instead of clipping to one line.
class RaatikWrappingError extends StatelessWidget {
  const RaatikWrappingError({
    super.key,
    required this.message,
    this.maxLines,
    this.textKey,
  });

  final String message;
  final int? maxLines;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      key: textKey,
      message,
      maxLines: maxLines,
    );
  }
}

/// Two file panes at medium and wide widths. Compact keeps the same panes
/// behind a this-computer / remote-computer choice.
class RaatikFileTransferSurface extends StatefulWidget {
  const RaatikFileTransferSurface({
    super.key,
    required this.width,
    required this.localLabel,
    required this.remoteLabel,
    required this.overflowLabel,
    this.localFiles = const <RaatikFileEntry>[],
    this.remoteFiles = const <RaatikFileEntry>[],
    this.local,
    this.remote,
    this.status,
    this.transferPermitted = true,
    this.disabledReason,
    this.transferLabel = 'Transfer',
    this.onTransfer,
    this.progress,
    this.onCancel,
    this.error,
  });

  final double width;
  final String localLabel;
  final String remoteLabel;
  final String overflowLabel;
  final List<RaatikFileEntry> localFiles;
  final List<RaatikFileEntry> remoteFiles;
  final Widget? local;
  final Widget? remote;
  final Widget? status;
  final bool transferPermitted;
  final String? disabledReason;
  final String transferLabel;
  final VoidCallback? onTransfer;
  final double? progress;
  final VoidCallback? onCancel;
  final String? error;

  @override
  State<RaatikFileTransferSurface> createState() =>
      _RaatikFileTransferSurfaceState();
}

class _RaatikFileTransferSurfaceState extends State<RaatikFileTransferSurface> {
  bool _showLocal = true;

  bool get _hasLocal => widget.local != null || widget.localFiles.isNotEmpty;

  bool get _hasRemote => widget.remote != null || widget.remoteFiles.isNotEmpty;

  Widget _entries(List<RaatikFileEntry> entries) {
    return ListView(
      children: [
        for (final entry in entries)
          Row(
            children: [
              Expanded(child: RaatikFileNameText(entry.name)),
              RaatikIdentifierText(entry.id),
            ],
          ),
      ],
    );
  }

  Widget _panel({required bool local}) {
    final child = local
        ? (widget.local ?? _entries(widget.localFiles))
        : (widget.remote ?? _entries(widget.remoteFiles));
    return KeyedSubtree(
      key: Key(local ? 'file-panel-local' : 'file-panel-remote'),
      child: child,
    );
  }

  void _transfer() {
    raatikInvokePermitted(widget.transferPermitted, widget.onTransfer ?? () {});
  }

  @override
  Widget build(BuildContext context) {
    final sideBySide = raatikFilePanelsSideBySide(widget.width);
    final panels = sideBySide
        ? Row(
            children: [
              if (_hasLocal) Expanded(flex: 3, child: _panel(local: true)),
              if (_hasRemote) Expanded(flex: 3, child: _panel(local: false)),
              if (widget.status != null)
                Expanded(flex: 2, child: widget.status!),
            ],
          )
        : Column(
            children: [
              if (_hasLocal && _hasRemote)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('file-side-local'),
                      onPressed: () => setState(() => _showLocal = true),
                      child: Text(widget.localLabel),
                    ),
                    TextButton(
                      key: const Key('file-side-remote'),
                      onPressed: () => setState(() => _showLocal = false),
                      child: Text(widget.remoteLabel),
                    ),
                  ],
                ),
              Expanded(
                child: _panel(
                  local: _hasLocal && (_showLocal || !_hasRemote),
                ),
              ),
              if (widget.status != null)
                Flexible(child: widget.status!),
            ],
          );

    return Column(
      children: [
        if (widget.onTransfer != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaatikLabelledOverflow(
              label: widget.overflowLabel,
              children: [
                TextButton(
                  key: const Key('file-overflow-transfer'),
                  onPressed: _transfer,
                  child: Text(
                    widget.transferPermitted
                        ? widget.transferLabel
                        : (widget.disabledReason ?? widget.transferLabel),
                  ),
                ),
              ],
            ),
          ),
        if (widget.progress != null)
          LinearProgressIndicator(
            key: const Key('file-progress'),
            value: widget.progress,
          ),
        if (widget.onCancel != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('file-cancel'),
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ),
        if (widget.error != null)
          Flexible(
            child: SingleChildScrollView(
              child: RaatikWrappingError(
                textKey: const Key('raatik-wrapping-error'),
                message: widget.error!,
              ),
            ),
          ),
        Expanded(child: panels),
      ],
    );
  }
}
