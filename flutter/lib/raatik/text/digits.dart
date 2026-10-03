/// Digit and bidi normalisation for machine tokens (IDs, codes, ports).
/// See DESIGN-SYSTEM.md section 1.11.
library raatik_digits;

import 'package:flutter/services.dart';

const int _persianZero = 0x06F0;
const int _arabicIndicZero = 0x0660;
const int _asciiZero = 0x30;

/// Maps Persian (U+06F0..U+06F9) and Arabic-Indic (U+0660..U+0669) digits to
/// ASCII. Everything else is returned unchanged.
String normalizeDigits(String input) {
  if (input.isEmpty) return input;
  final out = StringBuffer();
  for (final cu in input.codeUnits) {
    if (cu >= _persianZero && cu <= _persianZero + 9) {
      out.writeCharCode(_asciiZero + (cu - _persianZero));
    } else if (cu >= _arabicIndicZero && cu <= _arabicIndicZero + 9) {
      out.writeCharCode(_asciiZero + (cu - _arabicIndicZero));
    } else {
      out.writeCharCode(cu);
    }
  }
  return out.toString();
}

const Set<int> _bidiControls = {
  0x2066, 0x2067, 0x2068, 0x2069, // LRI RLI FSI PDI
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // LRE RLE PDF LRO RLO
  0x200E, 0x200F, 0x061C, // LRM RLM ALM
};

/// Removes Unicode bidi isolate, embedding, override and mark characters.
String stripBidiControls(String input) {
  if (input.isEmpty) return input;
  return String.fromCharCodes(
      input.codeUnits.where((c) => !_bidiControls.contains(c)));
}

final RegExp _idSeparators = RegExp(r'[\s\u00A0\u202F\u2009\-]');
final RegExp _numericIdWithSuffix = RegExp(r'^\d+([\\/]r)?$');

/// Prepares typed or pasted text for the remote-ID field.
///
/// Digits are normalised and bidi controls removed. Grouping spaces and
/// hyphens are stripped only when what remains is a purely numeric ID
/// (optionally followed by the relay suffix `/r` or `\r`). Hostnames and
/// `ip:port` strings pass through with only digit normalisation applied.
String normalizeIdentifierInput(String input) {
  final cleaned = stripBidiControls(normalizeDigits(input));
  final candidate = cleaned.replaceAll(_idSeparators, '');
  if (_numericIdWithSuffix.hasMatch(candidate)) return candidate;
  return cleaned;
}

/// Accepts only ASCII digits after normalising Persian and Arabic-Indic ones.
/// Use for 2FA codes, ports, resolutions and other short numeric fields.
/// Order matters: this must be the first formatter in the list.
class RaatikDigitsInputFormatter extends TextInputFormatter {
  RaatikDigitsInputFormatter({this.maxLength, this.maxValue});

  final int? maxLength;
  final int? maxValue;

  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = normalizeDigits(newValue.text).replaceAll(_nonDigit, '');
    if (maxLength != null && text.length > maxLength!) {
      text = text.substring(0, maxLength!);
    }
    if (maxValue != null && text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed == null || parsed > maxValue!) return oldValue;
    }
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
