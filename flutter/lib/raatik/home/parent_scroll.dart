import 'package:flutter/material.dart';

/// Home recent peers lay out in the page [ListView].
///
/// Descendants skip their own vertical viewport while [enabled] is true.
class RaatikParentScroll extends InheritedWidget {
  const RaatikParentScroll({
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RaatikParentScroll>();
    return scope?.enabled ?? false;
  }

  @override
  bool updateShouldNotify(RaatikParentScroll oldWidget) =>
      enabled != oldWidget.enabled;
}
