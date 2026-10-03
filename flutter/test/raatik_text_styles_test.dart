import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';

Future<BuildContext> _contextWith(WidgetTester tester, ThemeData theme) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    }),
  ));
  return captured;
}

void main() {
  testWidgets('identifier uses a Latin-digit face with tabular figures',
      (tester) async {
    final context = await _contextWith(tester, buildRaatikLightTheme());
    final style = RaatikTextStyles.identifier(context);
    expect(style.fontFamily, kRaatikIdentifierFontFamily);
    expect(style.fontFamily, isNot('IRANSansXFaNum'));
    expect(style.fontFamilyFallback, kRaatikIdentifierFontFallback);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w500);
  });

  testWidgets('displayId is 26/500 with 1.5 letter spacing', (tester) async {
    final context = await _contextWith(tester, buildRaatikDarkTheme());
    final style = RaatikTextStyles.displayId(context);
    expect(style.fontSize, 26);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.letterSpacing, 1.5);
    expect(style.height, 1.2);
    expect(style.fontFamily, kRaatikIdentifierFontFamily);
  });

  testWidgets('prose styles keep the theme (FaNum) font', (tester) async {
    final context = await _contextWith(tester, buildRaatikLightTheme());
    expect(RaatikTextStyles.titleLg(context).fontSize, 18);
    expect(RaatikTextStyles.titleLg(context).fontWeight, FontWeight.w700);
    expect(RaatikTextStyles.titleMd(context).fontSize, 16);
    expect(RaatikTextStyles.body(context).fontSize, 14);
    expect(RaatikTextStyles.body(context).height, 1.6);
    expect(RaatikTextStyles.label(context).fontSize, 13);
    expect(RaatikTextStyles.caption(context).fontSize, 12);
    // Inherits IRANSansXFaNum from the theme's bodyMedium.
    expect(RaatikTextStyles.body(context).fontFamily, 'IRANSansXFaNum');
  });

  testWidgets('mono uses the mono family', (tester) async {
    final context = await _contextWith(tester, buildRaatikLightTheme());
    expect(RaatikTextStyles.mono(context).fontFamily, kRaatikMonoFontFamily);
    expect(RaatikTextStyles.mono(context).fontFeatures,
        contains(const FontFeature.tabularFigures()));
  });
}
