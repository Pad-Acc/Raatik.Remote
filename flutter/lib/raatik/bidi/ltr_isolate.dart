import 'package:flutter/widgets.dart';

const int _lri = 0x2066; // LEFT-TO-RIGHT ISOLATE
const int _pdi = 0x2069; // POP DIRECTIONAL ISOLATE

String ltrIsolate(String text) {
  if (text.isEmpty) return text;
  if (text.codeUnitAt(0) == _lri) return text;
  return String.fromCharCodes([_lri, ...text.codeUnits, _pdi]);
}

Widget ltrTextDirection({Key? key, required Widget child}) {
  return Directionality(
    key: key,
    textDirection: TextDirection.ltr,
    child: child,
  );
}
