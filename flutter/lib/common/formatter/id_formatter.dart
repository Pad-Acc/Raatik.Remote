import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/text/digits.dart';

class IDTextEditingController extends TextEditingController {
  IDTextEditingController({String? text}) : super(text: text);

  String get id => trimID(value.text);

  set id(String newID) => text = formatID(normalizeIdentifierInput(newID));
}

/// Normalises Persian/Arabic-Indic digits, strips pasted separators, then
/// applies 3-3-3 grouping. Hostnames and ip:port pass through untouched.
class IDTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }
    final fromRight = newValue.text.length - newValue.selection.extentOffset;
    final newID = formatID(normalizeIdentifierInput(newValue.text));
    final sameLength = newID.length == newValue.text.length;
    return TextEditingValue(
      text: newID,
      selection: TextSelection.collapsed(
        offset: (newID.length - fromRight).clamp(0, newID.length),
      ),
      // https://github.com/flutter/flutter/issues/78066#issuecomment-797869906
      composing: sameLength ? newValue.composing : TextRange.empty,
    );
  }
}

String formatID(String id) {
  String id2 = id.replaceAll(' ', '');
  String suffix = '';
  if (id2.endsWith(r'\r') || id2.endsWith(r'/r')) {
    suffix = id2.substring(id2.length - 2, id2.length);
    id2 = id2.substring(0, id2.length - 2);
  }
  if (int.tryParse(id2) == null) return id;
  String newID = '';
  if (id2.length <= 3) {
    newID = id2;
  } else {
    var n = id2.length;
    var a = n % 3 != 0 ? n % 3 : 3;
    newID = id2.substring(0, a);
    for (var i = a; i < n; i += 3) {
      newID += " ${id2.substring(i, i + 3)}";
    }
  }
  return newID + suffix;
}

String trimID(String id) {
  return id.replaceAll(' ', '');
}

String formatIDForDisplay(String id) => ltrIsolate(formatID(id));

/// What goes on the clipboard when a user copies an identifier: raw digits,
/// no grouping spaces, no bidi controls.
String identifierClipboardText(String displayText) =>
    trimID(stripBidiControls(normalizeDigits(displayText)));
