import 'package:flutter/material.dart';

import '../theme/tokens.dart';

abstract final class RaatikDialogStyle {
  static const maxWidth = 560.0;
  static const padding = EdgeInsets.all(24);
}

BoxConstraints raatikDesktopDialogConstraints(
  BoxConstraints contentBoxConstraints,
) =>
    contentBoxConstraints.copyWith(maxWidth: RaatikDialogStyle.maxWidth);

List<Widget>? raatikDialogActions(List<Widget>? actions) {
  if (actions == null) {
    return null;
  }
  return [
    OverflowBar(
      spacing: 8,
      overflowSpacing: 8,
      alignment: MainAxisAlignment.end,
      children: actions,
    ),
  ];
}

const Size raatikDialogButtonMinSize = Size(0, RaatikTokens.minTarget);
