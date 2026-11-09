import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which chat control owns the key.
enum RaatikChatFocus { composer, send, other }

/// Composer key result. [swallow] consumes Enter without sending.
enum RaatikChatComposerEffect { send, newline, swallow, ignore }

bool raatikIsComposing(TextEditingValue value) {
  final range = value.composing;
  return range.isValid && !range.isCollapsed;
}

bool _isEnter(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;

/// Shift+Enter inserts a newline. Enter sends only from the composer or the
/// send action, and only when the text is non-empty and not composing.
RaatikChatComposerEffect raatikChatComposerEffect({
  required RaatikChatFocus focus,
  required bool isEnter,
  required bool isKeyDown,
  required bool shift,
  required bool composing,
  required String text,
}) {
  if (!isKeyDown || !isEnter) return RaatikChatComposerEffect.ignore;
  if (composing) return RaatikChatComposerEffect.ignore;
  if (focus == RaatikChatFocus.composer && shift) {
    return RaatikChatComposerEffect.newline;
  }
  final empty = text.trim().isEmpty;
  if (focus == RaatikChatFocus.composer) {
    return empty
        ? RaatikChatComposerEffect.swallow
        : RaatikChatComposerEffect.send;
  }
  if (focus == RaatikChatFocus.send && !empty) {
    return RaatikChatComposerEffect.send;
  }
  return RaatikChatComposerEffect.ignore;
}

void raatikInsertNewline(TextEditingController controller) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.start >= 0 ? selection.start : value.text.length;
  final end = selection.end >= 0 ? selection.end : value.text.length;
  final text = value.text.replaceRange(start, end, '\n');
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start + 1),
  );
}

/// Attaches the composer policy to an existing chat field.
void raatikBindChatInput({
  required FocusNode node,
  required TextEditingController controller,
  required ValueChanged<String> onSend,
}) {
  node.onKey = (focus, event) {
    if (event is! RawKeyDownEvent || event.repeat) {
      return event is RawKeyUpEvent &&
              (_isEnter(event.logicalKey) ||
                  event.logicalKey == LogicalKeyboardKey.escape)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    final effect = raatikChatComposerEffect(
      focus: RaatikChatFocus.composer,
      isEnter: _isEnter(event.logicalKey),
      isKeyDown: true,
      shift: event.isShiftPressed,
      composing: raatikIsComposing(controller.value),
      text: controller.text,
    );
    switch (effect) {
      case RaatikChatComposerEffect.send:
        onSend(controller.text);
        controller.clear();
        return KeyEventResult.handled;
      case RaatikChatComposerEffect.newline:
        raatikInsertNewline(controller);
        return KeyEventResult.handled;
      case RaatikChatComposerEffect.swallow:
        return KeyEventResult.handled;
      case RaatikChatComposerEffect.ignore:
        return KeyEventResult.ignored;
    }
  };
}

/// Chat transcript plus composer. Messages keep the order they are given.
class RaatikChatComposer extends StatefulWidget {
  const RaatikChatComposer({
    super.key,
    required this.messages,
    required this.onSend,
    required this.onOther,
    this.controller,
    this.unread = 0,
    this.sendFocus,
    this.otherFocus,
  });

  final List<String> messages;
  final ValueChanged<String> onSend;
  final VoidCallback onOther;
  final TextEditingController? controller;
  final int unread;
  final FocusNode? sendFocus;
  final FocusNode? otherFocus;

  @override
  State<RaatikChatComposer> createState() => _RaatikChatComposerState();
}

class _RaatikChatComposerState extends State<RaatikChatComposer> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final _composerFocus = FocusNode();
  final _ownedController = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownedController.add(_controller);
  }

  @override
  void dispose() {
    _composerFocus.dispose();
    for (final controller in _ownedController) {
      controller.dispose();
    }
    super.dispose();
  }

  RaatikChatFocus _focus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return RaatikChatFocus.other;
    if (primary == _composerFocus ||
        primary.ancestors.contains(_composerFocus)) {
      return RaatikChatFocus.composer;
    }
    if (widget.sendFocus != null &&
        (primary == widget.sendFocus ||
            primary.ancestors.contains(widget.sendFocus))) {
      return RaatikChatFocus.send;
    }
    return RaatikChatFocus.other;
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final effect = raatikChatComposerEffect(
      focus: _focus(),
      isEnter: _isEnter(event.logicalKey),
      isKeyDown: true,
      shift: HardwareKeyboard.instance.isShiftPressed,
      composing: raatikIsComposing(_controller.value),
      text: _controller.text,
    );
    switch (effect) {
      case RaatikChatComposerEffect.send:
        if (_focus() == RaatikChatFocus.send) return KeyEventResult.ignored;
        _send();
        return KeyEventResult.handled;
      case RaatikChatComposerEffect.newline:
        raatikInsertNewline(_controller);
        return KeyEventResult.handled;
      case RaatikChatComposerEffect.swallow:
        return KeyEventResult.handled;
      case RaatikChatComposerEffect.ignore:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        children: [
          if (widget.unread > 0)
            Text('${widget.unread}', key: const Key('chat-unread')),
          Expanded(
            child: ListView(
              children: [
                for (final message in widget.messages) Text(message),
              ],
            ),
          ),
          TextField(
            key: const Key('chat-composer'),
            focusNode: _composerFocus,
            controller: _controller,
            maxLines: 4,
            minLines: 1,
          ),
          Row(
            children: [
              TextButton(
                key: const Key('chat-other'),
                focusNode: widget.otherFocus,
                onPressed: widget.onOther,
                child: const Text('Other'),
              ),
              TextButton(
                key: const Key('chat-send'),
                focusNode: widget.sendFocus,
                onPressed: _send,
                child: const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
