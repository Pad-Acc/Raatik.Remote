import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';

/// Full-width persistent remote toolbar chrome with adaptive brand visibility.
class RaatikRemoteToolbarBar extends StatelessWidget {
  const RaatikRemoteToolbarBar({
    super.key,
    required this.width,
    required this.brandLabel,
    required this.primaryItems,
    required this.moreMenu,
    required this.closeMenu,
    this.barColor = const Color(0xFF0284C7),
    this.elevation = 1.0,
  });

  static const barHeight = 48.0;
  static const actionSize = RaatikTokens.minTarget;

  final double width;
  final Widget brandLabel;
  final List<Widget> primaryItems;
  final Widget moreMenu;
  final Widget closeMenu;
  final Color barColor;
  final double elevation;

  bool get _showBrand =>
      raatikWindowClassFor(width) != RaatikWindowClass.compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: barColor,
      child: SizedBox(
        width: double.infinity,
        height: barHeight,
        child: Row(
          children: [
            const SizedBox(width: 8),
            if (_showBrand) ...[
              brandLabel,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: primaryItems,
                ),
              ),
            ),
            moreMenu,
            closeMenu,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
