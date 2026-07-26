// RaatikDesk UI preview harness — run without Rust/FFI:
//   cd flutter && flutter run -d chrome -t lib/preview_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

import 'preview/fake_home.dart';
import 'preview/fake_settings.dart';
import 'preview/fake_toolbar.dart';

RaatikServiceGateCopy previewServiceGateCopy(Locale locale) {
  if (locale.languageCode == 'fa') {
    return const RaatikServiceGateCopy(
      stoppedTitle: 'سرویس اجرا نشده',
      startLabel: 'اجرای سرویس',
      startingLabel: '...در حال برقراری ارتباط با سرور',
      readyLabel: 'آماده به کار',
      stoppedBody: 'ارتباط برقرار نشد. لطفا شبکه خود را بررسی کنید',
      failedTitle: 'ناموفق',
      retryBody: 'تلاش مجدد',
    );
  }
  return const RaatikServiceGateCopy(
    stoppedTitle: 'Service is not running',
    startLabel: 'Start service',
    startingLabel: 'Connecting to server...',
    readyLabel: 'Ready',
    stoppedBody: 'Connection failed. Please check your network.',
    failedTitle: 'Failed',
    retryBody: 'Retry',
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaatikPreviewApp());
}

class RaatikPreviewApp extends StatefulWidget {
  const RaatikPreviewApp({
    super.key,
    this.initialThemeMode = ThemeMode.light,
    this.initialLocale = const Locale('fa'),
    this.initialTab = 0,
    this.initialServicePhase = RaatikServicePhase.stopped,
    this.showChrome = true,
  });

  final ThemeMode initialThemeMode;
  final Locale initialLocale;
  final int initialTab;
  final RaatikServicePhase initialServicePhase;
  final bool showChrome;

  @override
  State<RaatikPreviewApp> createState() => _RaatikPreviewAppState();
}

class _RaatikPreviewAppState extends State<RaatikPreviewApp> {
  late ThemeMode mode = widget.initialThemeMode;
  late Locale locale = widget.initialLocale;
  late int tab = widget.initialTab;
  late RaatikServicePhase servicePhase = widget.initialServicePhase;

  TextDirection get _textDirection =>
      locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: tab,
      children: [
        FakeHomePage(
          phase: servicePhase,
          copy: previewServiceGateCopy(locale),
        ),
        FakeSettingsPage(locale: locale),
        FakeToolbarPage(locale: locale),
      ],
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildRaatikLightTheme(),
      darkTheme: buildRaatikDarkTheme(),
      locale: locale,
      builder: (context, child) => Directionality(
        textDirection: _textDirection,
        child: child ?? const SizedBox.shrink(),
      ),
      home: widget.showChrome
          ? Scaffold(
              appBar: AppBar(
                title: const Text('RaatikDesk Preview'),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PreviewControls(
                    mode: mode,
                    locale: locale,
                    tab: tab,
                    servicePhase: servicePhase,
                    onThemeModeChanged: (value) => setState(() => mode = value),
                    onLocaleChanged: (value) => setState(() => locale = value),
                    onServicePhaseChanged: (value) =>
                        setState(() => servicePhase = value),
                  ),
                  const Divider(height: 1),
                  Expanded(child: body),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home),
                    label: locale.languageCode == 'fa' ? 'خانه' : 'Home',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings),
                    label: locale.languageCode == 'fa' ? 'تنظیمات' : 'Settings',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.desktop_windows),
                    label: locale.languageCode == 'fa'
                        ? 'نوار ریموت'
                        : 'Remote bar',
                  ),
                ],
              ),
            )
          : Scaffold(body: body),
    );
  }
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls({
    required this.mode,
    required this.locale,
    required this.tab,
    required this.servicePhase,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.onServicePhaseChanged,
  });

  final ThemeMode mode;
  final Locale locale;
  final int tab;
  final RaatikServicePhase servicePhase;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<RaatikServicePhase> onServicePhaseChanged;

  @override
  Widget build(BuildContext context) {
    final isFa = locale.languageCode == 'fa';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
        child: Row(
          children: [
            SegmentedButton<ThemeMode>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(isFa ? 'روشن' : 'Light'),
                  icon: const Icon(Icons.light_mode, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(isFa ? 'تیره' : 'Dark'),
                  icon: const Icon(Icons.dark_mode, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(isFa ? 'سیستم' : 'System'),
                  icon: const Icon(Icons.settings_brightness, size: 16),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (values) => onThemeModeChanged(values.first),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                ButtonSegment(
                  value: 'fa',
                  label: Text(isFa ? 'فارسی' : 'Farsi'),
                ),
                ButtonSegment(
                  value: 'en',
                  label: const Text('English'),
                ),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (values) =>
                  onLocaleChanged(Locale(values.first)),
            ),
            if (tab == 0) ...[
              const SizedBox(width: 12),
              DropdownButton<RaatikServicePhase>(
                value: servicePhase,
                onChanged: (value) {
                  if (value != null) onServicePhaseChanged(value);
                },
                items: [
                  for (final phase in RaatikServicePhase.values)
                    DropdownMenuItem(
                      value: phase,
                      child: Text(_phaseLabel(phase, isFa)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _phaseLabel(RaatikServicePhase phase, bool isFa) {
    if (isFa) {
      switch (phase) {
        case RaatikServicePhase.stopped:
          return 'متوقف';
        case RaatikServicePhase.starting:
          return 'در حال شروع';
        case RaatikServicePhase.connecting:
          return 'در حال اتصال';
        case RaatikServicePhase.ready:
          return 'آماده';
        case RaatikServicePhase.failed:
          return 'ناموفق';
      }
    }
    switch (phase) {
      case RaatikServicePhase.stopped:
        return 'Stopped';
      case RaatikServicePhase.starting:
        return 'Starting';
      case RaatikServicePhase.connecting:
        return 'Connecting';
      case RaatikServicePhase.ready:
        return 'Ready';
      case RaatikServicePhase.failed:
        return 'Failed';
    }
  }
}
