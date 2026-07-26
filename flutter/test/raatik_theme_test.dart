import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/my_theme_merge.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

void main() {
  group('RaatikTokens', () {
    test('defines brand colors and layout constants', () {
      expect(RaatikTokens.primary, const Color(0xFF0284C7));
      expect(RaatikTokens.accent, const Color(0xFF0891B2));
      expect(RaatikTokens.success, const Color(0xFF059669));
      expect(RaatikTokens.danger, const Color(0xFFDC2626));
      expect(RaatikTokens.lightCanvas, const Color(0xFFF4F7FB));
      expect(RaatikTokens.darkCanvas, const Color(0xFF111827));
      expect(RaatikTokens.minTarget, 44.0);
      expect(RaatikTokens.contentMaxWidth, 1440.0);
    });
  });

  group('buildRaatikLightTheme', () {
    test('uses IRANSansXFaNum and Raatik colors', () {
      final theme = buildRaatikLightTheme();

      expect(theme.textTheme.bodyMedium?.fontFamily, 'IRANSansXFaNum');
      expect(theme.colorScheme.primary, RaatikTokens.primary);
      expect(theme.colorScheme.secondary, RaatikTokens.accent);
      expect(theme.scaffoldBackgroundColor, RaatikTokens.lightCanvas);
    });

    test('buttons meet minimum touch target and use 12-16px radii', () {
      final theme = buildRaatikLightTheme();
      final style = theme.elevatedButtonTheme?.style;

      expect(style?.minimumSize?.resolve({}), const Size(0, RaatikTokens.minTarget));

      final shape = style?.shape?.resolve({}) as RoundedRectangleBorder?;
      final radius = shape?.borderRadius.resolve(TextDirection.ltr);
      expect(radius, isNotNull);
      expect(radius!.topLeft.x, inInclusiveRange(12.0, 16.0));
    });

    test('has visible focus styling', () {
      final theme = buildRaatikLightTheme();

      expect(theme.focusColor, isNotNull);
      expect(theme.focusColor, isNot(equals(Colors.transparent)));

      final focusedBorder = theme.inputDecorationTheme.focusedBorder;
      expect(focusedBorder, isNotNull);
      expect(focusedBorder, isA<OutlineInputBorder>());
    });
  });

  group('buildRaatikDarkTheme', () {
    test('uses IRANSansXFaNum and dark canvas', () {
      final theme = buildRaatikDarkTheme();

      expect(theme.textTheme.bodyMedium?.fontFamily, 'IRANSansXFaNum');
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, RaatikTokens.darkCanvas);
      expect(theme.colorScheme.primary, RaatikTokens.primary);
    });

    test('buttons meet minimum touch target', () {
      final theme = buildRaatikDarkTheme();
      final style = theme.elevatedButtonTheme?.style;

      expect(style?.minimumSize?.resolve({}), const Size(0, RaatikTokens.minTarget));
    });
  });

  group('MyTheme live path', () {
    test('lightTheme and darkTheme text buttons keep 44px minimum height', () {
      for (final builder in [buildRaatikLightTheme, buildRaatikDarkTheme]) {
        final theme = applyMyThemeButtonLayers(builder());
        final style = theme.textButtonTheme?.style;
        expect(style?.minimumSize?.resolve({}),
            const Size(0, RaatikTokens.minTarget));
      }
    });
  });
}
