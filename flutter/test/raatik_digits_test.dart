import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/text/digits.dart';

void main() {
  group('normalizeDigits', () {
    test('maps Persian digits to ASCII', () {
      expect(normalizeDigits('۱۰۷۲۹۲۳۴۷'), '107292347');
    });
    test('maps Arabic-Indic digits to ASCII', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });
    test('leaves letters and ASCII digits alone', () {
      expect(normalizeDigits('host-12.local:21118'), 'host-12.local:21118');
      expect(normalizeDigits(''), '');
    });
  });

  group('stripBidiControls', () {
    test('removes isolates, embeddings and marks', () {
      expect(stripBidiControls('\u2066107 292 347\u2069'), '107 292 347');
      expect(stripBidiControls('\u202Aabc\u202C\u200E\u200F\u061C'), 'abc');
    });
  });

  group('normalizeIdentifierInput', () {
    test('strips hyphens and spaces when the rest is a numeric ID', () {
      expect(normalizeIdentifierInput('107-292-347'), '107292347');
      expect(normalizeIdentifierInput('107 292 347\n'), '107292347');
      expect(normalizeIdentifierInput('\u2066107\u00A0292\u202F347\u2069'),
          '107292347');
    });
    test('normalises Persian digits', () {
      expect(normalizeIdentifierInput('۱۰۷ ۲۹۲ ۳۴۷'), '107292347');
    });
    test('keeps the relay suffix', () {
      expect(normalizeIdentifierInput('123 456 789/r'), '123456789/r');
      expect(normalizeIdentifierInput(r'123456789\r'), r'123456789\r');
    });
    test('passes hostnames and ip:port through untouched', () {
      expect(normalizeIdentifierInput('192.168.1.5:21118'), '192.168.1.5:21118');
      expect(normalizeIdentifierInput('my-host.local'), 'my-host.local');
      expect(normalizeIdentifierInput('remote.raatik.ir'), 'remote.raatik.ir');
    });
  });

  group('IDTextInputFormatter', () {
    TextEditingValue apply(String oldText, String newText) =>
        IDTextInputFormatter().formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        );

    test('groups Persian-typed digits as Latin 3-3-3', () {
      final v = apply('', '۱۰۷۲۹۲۳۴۷');
      expect(v.text, '107 292 347');
      expect(v.selection.extentOffset, 11);
    });
    test('groups a pasted hyphenated ID', () {
      expect(apply('', '107-292-347').text, '107 292 347');
    });
    test('keeps caret at the end after grouping', () {
      final v = apply('107 29', '107 292');
      expect(v.text, '107 292');
      expect(v.selection.extentOffset, 7);
    });
    test('does not touch an ip:port', () {
      expect(apply('', '192.168.1.5:21118').text, '192.168.1.5:21118');
    });
    test('clears to empty', () {
      expect(apply('107', '').text, '');
    });
  });

  group('IDTextEditingController', () {
    test('id setter normalises and groups, getter returns raw digits', () {
      final c = IDTextEditingController();
      c.id = '۱۰۷-۲۹۲-۳۴۷';
      expect(c.text, '107 292 347');
      expect(c.id, '107292347');
    });
  });

  group('identifierClipboardText', () {
    test('returns raw digits without space or isolates', () {
      expect(identifierClipboardText('\u2066231 339 258\u2069'), '231339258');
      expect(identifierClipboardText('۲۳۱ ۳۳۹ ۲۵۸'), '231339258');
    });
    test('keeps non-ID text intact apart from bidi controls', () {
      expect(identifierClipboardText('\u2066remote.raatik.ir\u2069'),
          'remote.raatik.ir');
    });
  });
}
