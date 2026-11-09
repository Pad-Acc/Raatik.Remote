import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';
import 'remote_toolbar_bar.dart';

/// Session tools in the order wide and medium toolbars show them.
enum RaatikSessionTool {
  display,
  image,
  control,
  keyboard,
  chat,
  record,
  audio,
  fileTransfer,
  print,
  extra,
}

const _primaryWide = <RaatikSessionTool>[
  RaatikSessionTool.display,
  RaatikSessionTool.image,
  RaatikSessionTool.control,
  RaatikSessionTool.keyboard,
  RaatikSessionTool.chat,
];

const _primaryCompact = <RaatikSessionTool>[
  RaatikSessionTool.image,
  RaatikSessionTool.chat,
];

class RaatikToolbarTool {
  const RaatikToolbarTool({
    required this.id,
    required this.label,
    required this.child,
    this.hidden = false,
    this.enabled = true,
    this.disabledReason,
  });

  final RaatikSessionTool id;
  final String label;
  final Widget child;
  final bool hidden;
  final bool enabled;
  final String? disabledReason;
}

class RaatikToolbarPartition {
  const RaatikToolbarPartition({
    required this.primary,
    required this.overflow,
  });

  final List<Widget> primary;
  final List<Widget> overflow;
}

Widget _presentTool(RaatikToolbarTool tool) {
  if (tool.enabled) return tool.child;
  final reason = tool.disabledReason ?? tool.label;
  return Tooltip(
    message: reason,
    child: Semantics(
      label: reason,
      enabled: false,
      child: ExcludeFocus(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              child: Opacity(opacity: 0.45, child: tool.child),
            ),
            Text(reason),
          ],
        ),
      ),
    ),
  );
}

/// Hidden tools are dropped from both the bar and the overflow.
/// Disabled tools stay visible, with their callback blocked.
RaatikToolbarPartition raatikPartitionToolbar({
  required RaatikWindowClass windowClass,
  required List<RaatikToolbarTool> tools,
}) {
  final primaryIds = windowClass == RaatikWindowClass.compact
      ? _primaryCompact
      : _primaryWide;
  final primary = <Widget>[];
  final overflow = <Widget>[];
  for (final tool in tools) {
    if (tool.hidden) continue;
    final child = _presentTool(tool);
    if (primaryIds.contains(tool.id)) {
      primary.add(child);
    } else {
      overflow.add(child);
    }
  }
  return RaatikToolbarPartition(primary: primary, overflow: overflow);
}

/// Ancestor of an open labelled-overflow menu.
///
/// Menu-bar tools read this so they can offer a focusable entry while the
/// menu is open. A closed [MenuBar] keeps its own button out of focus.
class RaatikOverflowScope extends InheritedWidget {
  const RaatikOverflowScope({super.key, required super.child});

  static bool contains(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RaatikOverflowScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(RaatikOverflowScope oldWidget) => false;
}

/// One overflow row. The focusable control is this entry.
///
/// [child] may be a closed menu bar, which excludes its own button. Enter and
/// a pointer on this entry call [onPressed].
class RaatikOverflowEntry extends StatefulWidget {
  const RaatikOverflowEntry({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<RaatikOverflowEntry> createState() => _RaatikOverflowEntryState();
}

class _RaatikOverflowEntryState extends State<RaatikOverflowEntry> {
  final FocusNode _node = FocusNode(debugLabel: 'raatik-overflow-entry');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      focusNode: _node,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: AlignmentDirectional.centerStart,
      ),
      onPressed: widget.onPressed,
      child: ExcludeFocus(
        excluding: true,
        child: widget.child,
      ),
    );
  }
}

/// Overflow control that always exposes [label], including on a narrow bar.
class RaatikLabelledOverflow extends StatefulWidget {
  const RaatikLabelledOverflow({
    super.key,
    required this.label,
    required this.children,
    this.iconOnly = false,
    this.focusNode,
  });

  static const buttonKey = Key('raatik-labelled-overflow');

  final String label;
  final List<Widget> children;
  final bool iconOnly;
  final FocusNode? focusNode;

  @override
  State<RaatikLabelledOverflow> createState() => _RaatikLabelledOverflowState();
}

class _RaatikLabelledOverflowState extends State<RaatikLabelledOverflow> {
  OverlayEntry? _entry;
  final FocusScopeNode _menuScope =
      FocusScopeNode(debugLabel: 'raatik-overflow-menu');
  bool _listening = false;
  late final KeyEventCallback _keyHandler = _onHardwareKey;
  late final PointerRoute _pointerRoute = _onPointer;

  @override
  void dispose() {
    _stopListening();
    _entry?.remove();
    _entry = null;
    _menuScope.dispose();
    super.dispose();
  }

  void _startListening() {
    if (_listening) return;
    _listening = true;
    HardwareKeyboard.instance.addHandler(_keyHandler);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointerRoute);
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointerRoute);
  }

  void _remove() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    _stopListening();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _scheduleLeafClose();
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerUpEvent) _scheduleLeafClose();
  }

  void _scheduleClose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _entry != null) _remove();
    });
  }

  void _scheduleLeafClose() {
    final before = _menuPanelCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null) return;
      if (_menuPanelCount() > before) return;
      _remove();
    });
  }

  int _menuPanelCount() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return 0;
    var count = 0;
    void visit(Element element) {
      if (element.widget.runtimeType.toString() == '_MenuPanel') count++;
      element.visitChildren(visit);
    }
    visit(root);
    return count;
  }

  KeyEventResult _onMenuKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _scheduleClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusFirstItem() {
    if (!mounted || _entry == null) return;
    if (_menuScope.context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _entry != null) _focusFirstItem();
      });
      return;
    }
    final node = _firstOrderedFocus() ??
        ReadingOrderTraversalPolicy()
            .findFirstFocus(_menuScope, ignoreCurrentFocus: true);
    if (node != null && node != _menuScope && node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    _menuScope.requestFocus();
  }

  /// First traversable control in menu order. A closed menu bar contributes
  /// none, so the entry wrapped around it is the one that runs.
  FocusNode? _firstOrderedFocus() {
    final root = _menuScope.context;
    if (root is! Element) return null;
    Element? column;
    void findColumn(Element element) {
      if (column != null) return;
      if (element.widget is Column) {
        column = element;
        return;
      }
      element.visitChildren(findColumn);
    }

    findColumn(root);
    final host = column;
    if (host == null) return null;
    FocusNode? found;
    void consider(FocusNode? node) {
      if (found != null || node == null) return;
      if (!node.canRequestFocus || node.skipTraversal) return;
      found = node;
    }

    void scan(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is TextButton) {
        consider(widget.focusNode);
      } else if (widget is Focus) {
        consider(widget.focusNode);
      }
      element.visitChildren(scan);
    }

    host.visitChildren((child) {
      if (found != null) return;
      scan(child);
    });
    return found;
  }

  void _toggle() {
    if (_entry != null) {
      _remove();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (box == null || !box.hasSize || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final menuWidth = 280.0;
    var left = rtl ? origin.dx + box.size.width - menuWidth : origin.dx;
    if (left < 8) left = 8;
    _entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          top: origin.dy + box.size.height,
          width: menuWidth,
          child: FocusScope(
            node: _menuScope,
            autofocus: true,
            onKeyEvent: _onMenuKey,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: RaatikOverflowScope(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children.isEmpty
                        ? [Text(widget.label)]
                        : widget.children,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _startListening();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null) return;
      _focusFirstItem();
    });
  }

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      key: RaatikLabelledOverflow.buttonKey,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(0, RaatikTokens.toolbarBtn),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.more_horiz, size: 20),
          if (!widget.iconOnly) ...[
            const SizedBox(width: 4),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    return Semantics(
      label: widget.label,
      button: true,
      container: true,
      child: SizedBox(
        height: RaatikTokens.toolbarBtn,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Focus(
            focusNode: widget.focusNode,
            descendantsAreFocusable: false,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                _toggle();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: button,
          ),
        ),
      ),
    );
  }
}

/// Wide/medium bar: display, image, control, keyboard, chat, overflow, disconnect.
/// Compact bar: image, chat, labelled overflow, disconnect.
class RaatikSessionToolbar extends StatelessWidget {
  const RaatikSessionToolbar({
    super.key,
    required this.windowWidth,
    required this.brandLabel,
    required this.tools,
    required this.close,
    this.edge = RaatikToolbarEdge.top,
    this.overflowExtras = const <Widget>[],
    this.overflowLabel = 'More',
    this.iconOnlyOverflow = false,
    this.overflowFocus,
  });

  final double windowWidth;
  final Widget brandLabel;
  final List<RaatikToolbarTool> tools;
  final List<Widget> overflowExtras;
  final Widget close;
  final RaatikToolbarEdge edge;
  final String overflowLabel;
  final bool iconOnlyOverflow;
  final FocusNode? overflowFocus;

  @override
  Widget build(BuildContext context) {
    final partition = raatikPartitionToolbar(
      windowClass: raatikWindowClassFor(windowWidth),
      tools: tools,
    );
    return RaatikRemoteToolbarBar(
      width: windowWidth,
      edge: edge,
      brandLabel: brandLabel,
      primaryItems: partition.primary,
      moreMenu: RaatikLabelledOverflow(
        label: overflowLabel,
        iconOnly: iconOnlyOverflow,
        focusNode: overflowFocus,
        children: [...partition.overflow, ...overflowExtras],
      ),
      closeMenu: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: close,
      ),
    );
  }
}
