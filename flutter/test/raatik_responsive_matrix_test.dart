import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/preview/fake_home.dart';
import 'package:flutter_hbb/preview/fake_settings.dart';
import 'package:flutter_hbb/preview/fake_toolbar.dart';
import 'package:flutter_hbb/preview_main.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

const _sizes = <Size>[
  Size(800, 600),
  Size(1024, 600),
  Size(1366, 768),
  Size(1920, 1080),
];

const _locales = <({Locale locale, TextDirection direction})>[
  (locale: Locale('fa'), direction: TextDirection.rtl),
  (locale: Locale('en'), direction: TextDirection.ltr),
];

const _themeModes = <ThemeMode>[
  ThemeMode.light,
  ThemeMode.dark,
  ThemeMode.system,
];

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget widget, {
  Brightness? platformBrightness,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  if (platformBrightness != null) {
    final original = tester.platformDispatcher.platformBrightness;
    tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
    addTearDown(
      () => tester.platformDispatcher.platformBrightnessTestValue = original,
    );
  }

  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
}

Widget _homeWidget({
  required Locale locale,
  required TextDirection direction,
  required ThemeMode themeMode,
  required RaatikServicePhase phase,
}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: buildRaatikLightTheme(),
    darkTheme: buildRaatikDarkTheme(),
    locale: locale,
    builder: (context, child) => Directionality(
      textDirection: direction,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: SizedBox.expand(
        child: FakeHomePage(
          phase: phase,
          copy: previewServiceGateCopy(locale),
        ),
      ),
    ),
  );
}

Widget _settingsWidget({
  required Locale locale,
  required TextDirection direction,
  required ThemeMode themeMode,
}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: buildRaatikLightTheme(),
    darkTheme: buildRaatikDarkTheme(),
    locale: locale,
    builder: (context, child) => Directionality(
      textDirection: direction,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: SizedBox.expand(
        child: FakeSettingsPage(locale: locale),
      ),
    ),
  );
}

Widget _toolbarWidget({
  required Locale locale,
  required TextDirection direction,
  required ThemeMode themeMode,
}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: buildRaatikLightTheme(),
    darkTheme: buildRaatikDarkTheme(),
    locale: locale,
    builder: (context, child) => Directionality(
      textDirection: direction,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: SizedBox.expand(
        child: FakeToolbarPage(locale: locale),
      ),
    ),
  );
}

Brightness? _platformBrightnessFor(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return Brightness.dark;
  }
}

void main() {
  group('Raatik responsive matrix — home', () {
    for (final size in _sizes) {
      for (final localeEntry in _locales) {
        for (final themeMode in _themeModes) {
          for (final phase in RaatikServicePhase.values) {
            testWidgets(
              'home ${size.width.toInt()}x${size.height.toInt()} '
              '${localeEntry.locale.languageCode} $themeMode $phase',
              (tester) async {
                await _pumpAtSize(
                  tester,
                  size,
                  _homeWidget(
                    locale: localeEntry.locale,
                    direction: localeEntry.direction,
                    themeMode: themeMode,
                    phase: phase,
                  ),
                  platformBrightness: _platformBrightnessFor(themeMode),
                );
              },
            );
          }
        }
      }
    }
  });

  group('Raatik responsive matrix — settings', () {
    for (final size in _sizes) {
      for (final localeEntry in _locales) {
        for (final themeMode in _themeModes) {
          testWidgets(
            'settings ${size.width.toInt()}x${size.height.toInt()} '
            '${localeEntry.locale.languageCode} $themeMode',
            (tester) async {
              await _pumpAtSize(
                tester,
                size,
                _settingsWidget(
                  locale: localeEntry.locale,
                  direction: localeEntry.direction,
                  themeMode: themeMode,
                ),
                platformBrightness: _platformBrightnessFor(themeMode),
              );
            },
          );
        }
      }
    }
  });

  group('Raatik responsive matrix — toolbar', () {
    for (final size in _sizes) {
      for (final localeEntry in _locales) {
        for (final themeMode in _themeModes) {
          testWidgets(
            'toolbar ${size.width.toInt()}x${size.height.toInt()} '
            '${localeEntry.locale.languageCode} $themeMode',
            (tester) async {
              await _pumpAtSize(
                tester,
                size,
                _toolbarWidget(
                  locale: localeEntry.locale,
                  direction: localeEntry.direction,
                  themeMode: themeMode,
                ),
                platformBrightness: _platformBrightnessFor(themeMode),
              );
            },
          );
        }
      }
    }
  });

  group('Raatik responsive matrix — preview app', () {
    for (final size in _sizes) {
      for (final localeEntry in _locales) {
        for (final themeMode in _themeModes) {
          testWidgets(
            'preview app ${size.width.toInt()}x${size.height.toInt()} '
            '${localeEntry.locale.languageCode} $themeMode',
            (tester) async {
              await _pumpAtSize(
                tester,
                size,
                RaatikPreviewApp(
                  initialThemeMode: themeMode,
                  initialLocale: localeEntry.locale,
                  initialServicePhase: RaatikServicePhase.stopped,
                ),
                platformBrightness: _platformBrightnessFor(themeMode),
              );
            },
          );
        }
      }
    }
  });
}
