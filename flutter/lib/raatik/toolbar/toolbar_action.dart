import 'package:flutter/material.dart';

/// Shared focus-ring styling for remote toolbar icon controls.
const Color raatikToolbarFocusRingColor = Colors.white;
const double raatikToolbarFocusRingWidth = 2;

Border? raatikToolbarFocusBorder(bool focused) {
  return focused
      ? Border.all(
          color: raatikToolbarFocusRingColor,
          width: raatikToolbarFocusRingWidth,
        )
      : null;
}

BoxDecoration raatikToolbarIconDecoration({
  required bool focused,
  required bool hover,
  required Color color,
  required Color hoverColor,
  required double borderRadius,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    color: hover ? hoverColor : color,
    border: raatikToolbarFocusBorder(focused),
  );
}

/// Applies the shared toolbar focus ring around [child] when focused.
class RaatikToolbarFocusRing extends StatelessWidget {
  const RaatikToolbarFocusRing({
    super.key,
    required this.child,
    this.borderRadius = 4,
    this.backgroundColor,
  });

  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: backgroundColor,
              border: raatikToolbarFocusBorder(focused),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
