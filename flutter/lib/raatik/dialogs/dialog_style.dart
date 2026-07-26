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

double get _dialogPadding => RaatikDialogStyle.padding.left;

EdgeInsets raatikDesktopDialogTitlePadding({bool content = true}) {
  final p = _dialogPadding;
  return EdgeInsets.fromLTRB(p, p, p, content ? 0 : p);
}

EdgeInsets raatikDesktopDialogContentPadding({bool actions = true}) {
  final p = _dialogPadding;
  return EdgeInsets.fromLTRB(p, p, p, actions ? (p - 4) : p);
}

EdgeInsets raatikDesktopDialogActionsPadding() {
  final p = _dialogPadding;
  return EdgeInsets.fromLTRB(p, 0, p, p - 4);
}

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
