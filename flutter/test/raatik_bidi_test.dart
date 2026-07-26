import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/preview/fake_home.dart';
import 'package:flutter_hbb/preview_main.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

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

  testWidgets('My ID TextFormField is wrapped in LTR Directionality',
      (tester) async {
    // Pump a minimal replica: Directionality.rtl > ltrTextDirection > TextField
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ltrTextDirection(
              child: const TextField(
                decoration: InputDecoration(border: InputBorder.none),
                controller: null,
              ),
            ),
          ),
        ),
      ),
    );
    final dirs = tester.widgetList<Directionality>(find.byType(Directionality));
    expect(
      dirs.any((d) => d.textDirection == TextDirection.ltr),
      isTrue,
    );
  });

  testWidgets('FakeHomePage credential ID uses formatIDForDisplay under fa',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const locale = Locale('fa');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRaatikLightTheme(),
        locale: locale,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: FakeHomePage(
            phase: RaatikServicePhase.ready,
            copy: previewServiceGateCopy(locale),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expectedId = formatIDForDisplay('123456789');
    expect(find.text(expectedId), findsWidgets);

    // Credential value Text must sit under an LTR Directionality ancestor.
    final idText = find.text(expectedId).first;
    final dirs = tester.widgetList<Directionality>(
      find.ancestor(of: idText, matching: find.byType(Directionality)),
    );
    expect(
      dirs.any((d) => d.textDirection == TextDirection.ltr),
      isTrue,
    );
  });
}
