import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

/// Test-only app wrapper. UI-C06: current Raatik theme, locale, direction,
/// and a parameterized [MediaQuery]. Does not load the Rust library.
Widget testApp(
  Widget child, {
  Size size = const Size(800, 600),
  Locale locale = const Locale('fa'),
  TextScaler textScaler = const TextScaler.linear(1),
  ThemeMode themeMode = ThemeMode.light,
}) {
  final direction = _directionFor(locale);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: buildRaatikLightTheme(),
    darkTheme: buildRaatikDarkTheme(),
    locale: locale,
    supportedLocales: const [
      Locale('fa'),
      Locale('en'),
      Locale('ar'),
    ],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, appChild) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          size: size,
          textScaler: textScaler,
        ),
        child: Directionality(
          textDirection: direction,
          child: appChild ?? const SizedBox.shrink(),
        ),
      );
    },
    home: Scaffold(
      body: SizedBox.fromSize(size: size, child: child),
    ),
  );
}

TextDirection _directionFor(Locale locale) {
  switch (locale.languageCode) {
    case 'fa':
    case 'ar':
      return TextDirection.rtl;
    default:
      return TextDirection.ltr;
  }
}
