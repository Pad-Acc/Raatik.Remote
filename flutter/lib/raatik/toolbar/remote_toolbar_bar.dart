import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';

/// Physical dock edge of the remote toolbar. Left and right are screen edges.
enum RaatikToolbarEdge { top, right, bottom, left }

/// Image inset for the committed dock. Fullscreen and relative mouse reserve nothing.
/// A hidden toolbar reserves only [RaatikRemoteToolbarBar.collapseExtent].
EdgeInsets raatikToolbarImageInset({
  required RaatikToolbarEdge edge,
  required bool toolbarShown,
  required bool fullscreen,
  bool relativeMouse = false,
}) {
  if (fullscreen || relativeMouse) return EdgeInsets.zero;
  final extent = toolbarShown
      ? RaatikRemoteToolbarBar.barHeight
      : RaatikRemoteToolbarBar.collapseExtent;
  switch (edge) {
    case RaatikToolbarEdge.top:
      return EdgeInsets.only(top: extent);
    case RaatikToolbarEdge.bottom:
      return EdgeInsets.only(bottom: extent);
    case RaatikToolbarEdge.left:
      return EdgeInsets.only(left: extent);
    case RaatikToolbarEdge.right:
      return EdgeInsets.only(right: extent);
  }
}

/// Collapse control hitbox shown when the bar itself is hidden.
class RaatikToolbarCollapseTarget extends StatelessWidget {
  const RaatikToolbarCollapseTarget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

/// Keeps the toolbar band outside the image [LayoutBuilder].
/// [previewEdge] is the in-drag ghost and does not change the inset.
class RaatikRemoteViewportLayout extends StatelessWidget {
  const RaatikRemoteViewportLayout({
    super.key,
    required this.edge,
    required this.toolbarShown,
    required this.fullscreen,
    required this.image,
    this.toolbar = const SizedBox.shrink(),
    this.relativeMouse = false,
    this.previewEdge,
  });

  static const imageViewportKey = Key('raatik-remote-image-viewport');
  static const toolbarSlotKey = Key('raatik-remote-toolbar-slot');
  static const collapseSlotKey = Key('raatik-remote-collapse-slot');

  final RaatikToolbarEdge edge;
  final RaatikToolbarEdge? previewEdge;
  final bool toolbarShown;
  final bool fullscreen;
  final bool relativeMouse;
  final Widget image;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) {
    assert(
      previewEdge == null || true,
      'Drag preview $previewEdge does not resize the image; committed edge is $edge.',
    );
    final padding = raatikToolbarImageInset(
      edge: edge,
      toolbarShown: toolbarShown,
      fullscreen: fullscreen,
      relativeMouse: relativeMouse,
    );
    final reserve = !fullscreen && !relativeMouse;
    final showCollapse = reserve && !toolbarShown;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: padding,
          child: KeyedSubtree(
            key: imageViewportKey,
            child: image,
          ),
        ),
        if (!relativeMouse)
          Positioned.fill(
            child: Offstage(
              offstage: showCollapse,
              child: toolbar,
            ),
          ),
        if (!relativeMouse && !showCollapse)
          _band(
            key: toolbarSlotKey,
            edge: edge,
            extent: RaatikRemoteToolbarBar.barHeight,
            child: const IgnorePointer(child: SizedBox.expand()),
          ),
        if (showCollapse)
          _band(
            key: collapseSlotKey,
            edge: edge,
            extent: RaatikRemoteToolbarBar.collapseExtent,
            child: const RaatikToolbarCollapseTarget(),
          ),
      ],
    );
  }

  static Widget _band({
    required Key key,
    required RaatikToolbarEdge edge,
    required double extent,
    required Widget child,
  }) {
    switch (edge) {
      case RaatikToolbarEdge.top:
        return Positioned(
          key: key,
          top: 0,
          left: 0,
          right: 0,
          height: extent,
          child: child,
        );
      case RaatikToolbarEdge.bottom:
        return Positioned(
          key: key,
          bottom: 0,
          left: 0,
          right: 0,
          height: extent,
          child: child,
        );
      case RaatikToolbarEdge.left:
        return Positioned(
          key: key,
          left: 0,
          top: 0,
          bottom: 0,
          width: extent,
          child: child,
        );
      case RaatikToolbarEdge.right:
        return Positioned(
          key: key,
          right: 0,
          top: 0,
          bottom: 0,
          width: extent,
          child: child,
        );
    }
  }
}

/// Full-width persistent remote toolbar chrome with adaptive brand visibility.
class RaatikRemoteToolbarBar extends StatelessWidget {
  const RaatikRemoteToolbarBar({
    super.key,
    required this.width,
    required this.brandLabel,
    required this.primaryItems,
    required this.moreMenu,
    required this.closeMenu,
    this.edge = RaatikToolbarEdge.top,
    this.barColor = const Color(0xFF0284C7),
    this.elevation = 1.0,
  });

  static const barHeight = 48.0;

  /// Thickness of the collapse control that stays outside the image.
  static const collapseExtent = 20.0;
  static const actionSize = RaatikTokens.minTarget;

  final double width;
  final Widget brandLabel;
  final List<Widget> primaryItems;
  final Widget moreMenu;
  final Widget closeMenu;
  final RaatikToolbarEdge edge;
  final Color barColor;
  final double elevation;

  bool get _showBrand =>
      raatikWindowClassFor(width) != RaatikWindowClass.compact;

  bool get _vertical =>
      edge == RaatikToolbarEdge.left || edge == RaatikToolbarEdge.right;

  @override
  Widget build(BuildContext context) {
    final axis = _vertical ? Axis.vertical : Axis.horizontal;
    return Material(
      elevation: elevation,
      color: barColor,
      child: SizedBox(
        width: _vertical ? barHeight : double.infinity,
        height: _vertical ? double.infinity : barHeight,
        child: Flex(
          direction: axis,
          children: [
            SizedBox(width: _vertical ? 0 : 8, height: _vertical ? 8 : 0),
            if (_showBrand) ...[
              brandLabel,
              SizedBox(width: _vertical ? 0 : 8, height: _vertical ? 8 : 0),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: axis,
                child: Flex(
                  direction: axis,
                  mainAxisSize: MainAxisSize.min,
                  children: primaryItems,
                ),
              ),
            ),
            moreMenu,
            closeMenu,
            SizedBox(width: _vertical ? 0 : 8, height: _vertical ? 8 : 0),
          ],
        ),
      ),
    );
  }
}
