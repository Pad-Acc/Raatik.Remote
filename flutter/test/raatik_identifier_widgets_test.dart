import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';

Widget _rtlApp(Widget child) => MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('RaatikIdentifierText groups, isolates and uses the Latin face',
      (tester) async {
    await tester.pumpWidget(_rtlApp(const RaatikIdentifierText('107292347')));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, '\u2066107 292 347\u2069');
    expect(text.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(text.maxLines, 1);
  });

  testWidgets('RaatikIdentifierText(group: false) keeps secrets ungrouped',
      (tester) async {
    await tester.pumpWidget(
        _rtlApp(const RaatikIdentifierText('842915', group: false)));
    expect(tester.widget<Text>(find.byType(Text)).data, '\u2066842915\u2069');
  });

  testWidgets(
      'RaatikIdentifierText keeps the Latin face when the caller passes a theme text style',
      (tester) async {
    late TextStyle themeTitleSmall;
    await tester.pumpWidget(_rtlApp(Builder(builder: (context) {
      themeTitleSmall = Theme.of(context).textTheme.titleSmall!;
      return RaatikIdentifierText(
        '107292347',
        style: themeTitleSmall,
      );
    })));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(text.style?.fontFamilyFallback, kRaatikIdentifierFontFallback);
    expect(text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()));
  });

  testWidgets(
      'RaatikIdentifierField keeps the Latin face when the caller passes a theme text style',
      (tester) async {
    late TextStyle themeTitleSmall;
    final controller = IDTextEditingController();
    await tester.pumpWidget(_rtlApp(Builder(builder: (context) {
      themeTitleSmall = Theme.of(context).textTheme.titleSmall!;
      return RaatikIdentifierField(
        controller: controller,
        style: themeTitleSmall,
      );
    })));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(field.style?.fontFamilyFallback, kRaatikIdentifierFontFallback);
    expect(field.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()));
  });

  testWidgets('RaatikIdentifierField is an LTR island with an RTL hint',
      (tester) async {
    final controller = IDTextEditingController();
    await tester.pumpWidget(_rtlApp(RaatikIdentifierField(
      controller: controller,
      hintText: 'شناسه راه دور',
      inputFormatters: [IDTextInputFormatter()],
    )));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintTextDirection, TextDirection.rtl);
    expect(field.textAlign, TextAlign.center);
    expect(field.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(field.autocorrect, isFalse);
    expect(Directionality.of(tester.element(find.byType(TextField))),
        TextDirection.ltr);
  });

  testWidgets('typing Persian digits yields grouped Latin digits',
      (tester) async {
    final controller = IDTextEditingController();
    await tester.pumpWidget(_rtlApp(RaatikIdentifierField(
      controller: controller,
      inputFormatters: [IDTextInputFormatter()],
    )));
    await tester.enterText(find.byType(TextField), '۱۰۷۲۹۲۳۴۷');
    await tester.pump();
    expect(controller.text, '107 292 347');
    expect(controller.id, '107292347');
  });

  testWidgets('hint follows the app direction when the app is LTR',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(
        body: RaatikIdentifierField(
          controller: TextEditingController(),
          hintText: 'Enter Remote ID',
        ),
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintTextDirection, TextDirection.ltr);
  });

  // Direct ancestor between the LTR Directionality island this widget creates
  // and its TextField: Material's own internals may contain unrelated
  // ExcludeSemantics widgets elsewhere in the tree, so this narrows to the one
  // our wrapper would introduce.
  Finder wrapperExcludeSemantics(WidgetTester tester) {
    final directionality = find.ancestor(
      of: find.byType(TextField),
      matching: find.byType(Directionality),
    );
    final ltrIsland = tester
        .widgetList<Directionality>(directionality)
        .where((d) => d.textDirection == TextDirection.ltr);
    expect(ltrIsland, isNotEmpty);
    return find.descendant(
      of: find.byWidget(ltrIsland.first),
      matching: find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(ExcludeSemantics),
      ),
    );
  }

  testWidgets(
      'RaatikIdentifierField excludes TextField semantics on Linux (Mint freeze workaround)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    try {
      await tester.pumpWidget(_rtlApp(RaatikIdentifierField(
        controller: TextEditingController(),
      )));
      expect(wrapperExcludeSemantics(tester), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'RaatikIdentifierField does not exclude TextField semantics on the default test platform',
      (tester) async {
    await tester.pumpWidget(_rtlApp(RaatikIdentifierField(
      controller: TextEditingController(),
    )));
    expect(wrapperExcludeSemantics(tester), findsNothing);
  });
}
