import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double myThemeMobileTextButtonPaddingLR = 20;

bool isDesktopOrWebDesktopForTheme() {
  if (kIsWeb) {
    return true;
  }
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

TextButtonThemeData mergeTextButtonTheme(
  TextButtonThemeData? base, {
  required bool desktop,
}) {
  final baseStyle = base?.style;
  if (desktop) {
    return TextButtonThemeData(
      style: (baseStyle ?? const ButtonStyle()).merge(
        TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
      ),
    );
  }
  return TextButtonThemeData(
    style: (baseStyle ?? const ButtonStyle()).merge(
      TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: myThemeMobileTextButtonPaddingLR,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
  );
}

CheckboxThemeData mergeCheckboxTheme(
  CheckboxThemeData? base, {
  double splashRadius = 0,
}) {
  return (base ?? const CheckboxThemeData()).copyWith(
    splashRadius: splashRadius,
  );
}

/// Applies the same text/checkbox theme layers as [MyTheme.lightTheme] /
/// [MyTheme.darkTheme] in `common.dart`.
ThemeData applyMyThemeButtonLayers(ThemeData base, {bool? desktop}) {
  final isDesktop = desktop ?? isDesktopOrWebDesktopForTheme();
  return base.copyWith(
    textButtonTheme: mergeTextButtonTheme(base.textButtonTheme, desktop: isDesktop),
    checkboxTheme: mergeCheckboxTheme(base.checkboxTheme),
  );
}
