import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';

void main() {
  test('formatID keeps logical groups', () {
    expect(formatID('1662867586'), '1 662 867 586');
  });

  test('ltrIsolate wraps with LRI/PDI', () {
    final s = ltrIsolate('1 662 867 586');
    expect(s.codeUnitAt(0), 0x2066);
    expect(s.codeUnitAt(s.length - 1), 0x2069);
    expect(s.substring(1, s.length - 1), '1 662 867 586');
  });

  testWidgets('spaced ID does not reverse under RTL Directionality',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Text(formatIDForDisplay('1662867586')),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, contains('1 662 867 586'));
    // Rendered paragraph must keep LTR isolate — first visible run is '1'
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).first,
    );
    expect(paragraph.text.toPlainText(), contains('1 662 867 586'));
  });
}
