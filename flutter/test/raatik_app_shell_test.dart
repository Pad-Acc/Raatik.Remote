import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/flags.dart';
import 'package:flutter_hbb/raatik/home/connect_overflow_button.dart';
import 'package:flutter_hbb/raatik/home/home_layout.dart';
import 'package:flutter_hbb/raatik/navigation/app_shell.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

import 'raatik_test_app.dart';

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

const _receiveKey = ValueKey('receive-panel');
const _connectKey = ValueKey('connect-panel');
const _connectActionKey = ValueKey('connect-action');
const _historyPageKey = ValueKey('history-page');
const _navKey = ValueKey('raatik-navigation');

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  Locale locale = const Locale('fa'),
  TextScaler textScaler = const TextScaler.linear(1),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(testApp(
    child,
    size: size,
    locale: locale,
    textScaler: textScaler,
  ));
  await tester.pump();
}

Widget _shell({
  required ValueNotifier<RaatikDestination> destination,
  Widget? home,
  Widget? history = const Text('HISTORY'),
  Widget? settings = const Text('SETTINGS'),
  bool blocked = false,
  bool showConnectPanel = true,
  bool showReceivePanel = true,
  Widget? recent,
  VoidCallback? onOpenHistory,
}) {
  return RaatikAppShell(
    destination: destination,
    home: home ??
        RaatikHomeLayout(
          serviceGate: Text(blocked ? 'service-offline' : 'service-ready'),
          receivePanel: const SizedBox(key: _receiveKey, height: 80),
          connectPanel: const SizedBox(
            key: _connectKey,
            height: 80,
            child: ElevatedButton(
              key: _connectActionKey,
              onPressed: null,
              child: Text('Connect'),
            ),
          ),
          showConnectPanel: showConnectPanel,
          showReceivePanel: showReceivePanel,
          blocked: blocked,
          recent: recent,
          onOpenHistory: onOpenHistory,
        ),
    history: history,
    settings: settings,
  );
}

void _expectNavFrame(
  WidgetTester tester,
  Size size,
  TextDirection direction,
) {
  final nav = tester.getRect(find.byKey(_navKey));
  final shell = tester.getRect(find.byType(RaatikAppShell));
  if (size.width < RaatikTokens.compactMax) {
    expect(nav.height, 64);
    expect(nav.left, closeTo(shell.left, 0.5));
    expect(nav.right, closeTo(shell.right, 0.5));
    expect(nav.bottom, closeTo(shell.bottom, 0.5));
    return;
  }
  final width = size.width < RaatikTokens.mediumMax
      ? RaatikTokens.rail
      : RaatikTokens.sidebar;
  expect(nav.width, width);
  expect(nav.top, closeTo(shell.top, 0.5));
  expect(nav.bottom, closeTo(shell.bottom, 0.5));
  if (direction == TextDirection.rtl) {
    expect(nav.right, closeTo(shell.right, 0.5));
  } else {
    expect(nav.left, closeTo(shell.left, 0.5));
  }
}

void main() {
  testWidgets('UI-C06 destination switch shows the history page',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await tester.binding.setSurfaceSize(const Size(640, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp(
      RaatikAppShell(
        home: const Text('HOME'),
        history: const Text('HISTORY'),
        settings: const Text('SETTINGS'),
        destination: destination,
      ),
      size: const Size(640, 720),
      locale: const Locale('fa'),
    ));
    expect(find.text('HISTORY'), findsNothing);
    destination.value = RaatikDestination.history;
    await tester.pump();
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null history is absent and an invalid destination shows home',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.history);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(
        destination: destination,
        home: const Text('HOME'),
        history: null,
        settings: const Text('SETTINGS'),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    expect(find.text('History'), findsNothing);
    expect(find.byKey(const ValueKey('nav-history')), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect(destination.value, RaatikDestination.history);
  });

  testWidgets('incoming-only home omits connect and history', (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(
        destination: destination,
        history: null,
        showConnectPanel: false,
        recent: const Text('recent-devices'),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    expect(find.text('History'), findsNothing);
    expect(find.byKey(_connectActionKey), findsNothing);
    expect(find.byKey(_receiveKey), findsOneWidget);
    expect(find.text('recent-devices'), findsNothing);
  });

  testWidgets('outgoing-only home omits receive and keeps connect',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(
        destination: destination,
        showReceivePanel: false,
        recent: const Text('recent-devices'),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    expect(find.byKey(_receiveKey), findsNothing);
    expect(find.byKey(_connectActionKey), findsOneWidget);
    expect(find.text('recent-devices'), findsOneWidget);
  });

  testWidgets('service offline still permits history and settings navigation',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(
        destination: destination,
        blocked: true,
        history: const KeyedSubtree(
          key: _historyPageKey,
          child: Text('History'),
        ),
        onOpenHistory: () => destination.value = RaatikDestination.history,
        recent: TextButton(
          key: const ValueKey('recent-connect'),
          onPressed: () {},
          child: const Text('recent-connect'),
        ),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    expect(find.text('service-offline'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('recent-connect')));
    expect(find.byKey(const ValueKey('recent-connect')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recent-connect')).hitTestable(),
      findsNothing,
    );
    final recentGate = tester.widget<AbsorbPointer>(
      find.byKey(const ValueKey('raatik-recent-gate')),
    );
    expect(recentGate.absorbing, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('raatik-recent-gate')),
        matching: find.byKey(const ValueKey('open-history')),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('open-history')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('open-history')));
    await tester.pump();
    expect(find.byKey(_historyPageKey), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pump();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready recent connect stays hittable in the shell',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(
        destination: destination,
        recent: TextButton(
          key: const ValueKey('recent-connect'),
          onPressed: () {},
          child: const Text('recent-connect'),
        ),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('recent-connect')));
    expect(
      find.byKey(const ValueKey('recent-connect')).hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AbsorbPointer>(
              find.byKey(const ValueKey('raatik-recent-gate')))
          .absorbing,
      isFalse,
    );
  });

  testWidgets('recent devices use the home page scroll', (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(
        destination: destination,
        recent: Column(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(
                key: i == 0 ? const ValueKey('recent-row') : null,
                height: 48,
                child: Text('peer $i'),
              ),
          ],
        ),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    final vertical = tester
        .widgetList<Scrollable>(find.descendant(
      of: find.byType(RaatikHomeLayout),
      matching: find.byType(Scrollable),
    ))
        .where((scrollable) {
      final axis = scrollable.axisDirection == AxisDirection.down ||
          scrollable.axisDirection == AxisDirection.up;
      return axis && scrollable.physics is! NeverScrollableScrollPhysics;
    }).length;
    expect(vertical, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('raatik-home-recent'))).height,
      greaterThan(360),
    );
    final before = tester.getTopLeft(find.byKey(const ValueKey('recent-row')));
    await tester.drag(
      find.byKey(const ValueKey('recent-row')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(const ValueKey('recent-row')));
    expect(after.dy, lessThan(before.dy - 40));
    final scrollable = tester.state<ScrollableState>(find.descendant(
      of: find.byKey(const ValueKey('raatik-home-content')),
      matching: find.byType(Scrollable),
    ));
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('connect overflow hit target is 44', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(
        body: Center(
          child: RaatikConnectOverflowButton(
            onTap: () => taps += 1,
            icon: const Icon(Icons.more_horiz, size: 14),
          ),
        ),
      ),
    ));

    final rect = tester.getRect(find.byKey(const ValueKey('connect-overflow')));
    expect(
      rect.size,
      const Size(RaatikTokens.minTarget, RaatikTokens.minTarget),
    );
    await tester.tapAt(rect.topLeft + const Offset(1, 1));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden page timer stops when visible is false', (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    final ticks = ValueNotifier<int>(0);
    addTearDown(destination.dispose);
    addTearDown(ticks.dispose);
    await _pump(
      tester,
      RaatikAppShell(
        destination: destination,
        home: const Text('HOME'),
        history: _VisibilityTimerProbe(ticks: ticks),
        settings: const Text('SETTINGS'),
      ),
      size: const Size(800, 600),
      locale: const Locale('en'),
    );

    destination.value = RaatikDestination.history;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(ticks.value, greaterThan(0));
    final frozen = ticks.value;

    destination.value = RaatikDestination.home;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(ticks.value, frozen);
    expect(find.byKey(_historyPageKey), findsNothing);
    expect(
      find.byKey(_historyPageKey, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('resize keeps the selected destination', (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    final shell = RaatikAppShell(
      destination: destination,
      home: const Text('HOME'),
      history: const Text('HISTORY'),
      settings: const Text('SETTINGS'),
    );
    await _pump(tester, shell,
        size: const Size(800, 600), locale: const Locale('fa'));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pump();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(destination.value, RaatikDestination.settings);

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    await tester.pumpWidget(testApp(
      shell,
      size: const Size(1366, 768),
      locale: const Locale('fa'),
    ));
    await tester.pump();
    expect(destination.value, RaatikDestination.settings);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(tester.getSize(find.byKey(_navKey)).width, RaatikTokens.sidebar);

    await tester.binding.setSurfaceSize(const Size(480, 680));
    await tester.pumpWidget(testApp(
      shell,
      size: const Size(480, 680),
      locale: const Locale('fa'),
      textScaler: const TextScaler.linear(2),
    ));
    await tester.pump();
    expect(destination.value, RaatikDestination.settings);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.getSize(find.byKey(_navKey)).height, 64);
    expect(tester.takeException(), isNull);
  });

  for (final size in _sizes) {
    for (final localeEntry in _locales) {
      testWidgets(
        'shell ${size.width.toInt()}x${size.height.toInt()} '
        '${localeEntry.locale.languageCode}',
        (tester) async {
          final destination = ValueNotifier(RaatikDestination.home);
          addTearDown(destination.dispose);
          await _pump(
            tester,
            _shell(destination: destination),
            size: size,
            locale: localeEntry.locale,
          );
          _expectNavFrame(tester, size, localeEntry.direction);
          expect(find.text(RaatikHomeCopy.of(localeEntry.locale).pageTitle),
              findsWidgets);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(const ValueKey('nav-history')));
          await tester.pump();
          expect(find.text('HISTORY'), findsOneWidget);
          expect(destination.value, RaatikDestination.history);
          _expectNavFrame(tester, size, localeEntry.direction);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('480x680 at text scale 2 wraps long labels without overflow',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    const longLabel =
        'اتصال و پشتیبانی برای دریافت کمک از تیم پشتیبانی راتیک با یک برچسب بسیار طولانی که باید بپیچد و خوانا بماند';
    await _pump(
      tester,
      RaatikAppShell(
        destination: destination,
        home: const Text(longLabel),
        history: const Text(
          'تاریخچهٔ جلسات با توضیح طولانی برای مقیاس متن دویست درصد',
        ),
        settings: const Text(
          'تنظیمات برنامه با برچسب‌های طولانی امنیت شبکه و درباره',
        ),
      ),
      size: const Size(480, 680),
      locale: const Locale('fa'),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text(longLabel), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(_navKey)).height, 64);
  });

  testWidgets('home cards stack when each card would be narrower than 280',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(destination: destination),
      size: const Size(640, 720),
      locale: const Locale('en'),
    );

    final receive = tester.getTopLeft(find.byKey(_receiveKey));
    final connect = tester.getTopLeft(find.byKey(_connectKey));
    expect(connect.dy, greaterThan(receive.dy + 40));
  });

  testWidgets('home cards sit side by side once each card is at least 280',
      (tester) async {
    final destination = ValueNotifier(RaatikDestination.home);
    addTearDown(destination.dispose);
    await _pump(
      tester,
      _shell(destination: destination),
      size: const Size(1366, 768),
      locale: const Locale('en'),
    );

    final receive = tester.getRect(find.byKey(_receiveKey));
    final connect = tester.getRect(find.byKey(_connectKey));
    expect((receive.top - connect.top).abs(), lessThan(1));
    expect(receive.width, greaterThanOrEqualTo(280));
    expect(connect.width, greaterThanOrEqualTo(280));
    final content =
        tester.getSize(find.byKey(const ValueKey('raatik-home-content')));
    expect(content.width, lessThanOrEqualTo(RaatikTokens.contentMaxWidth));
  });

  test('home display names follow UI-C03', () {
    final fa = RaatikHomeCopy.of(const Locale('fa'));
    final en = RaatikHomeCopy.of(const Locale('en'));
    expect(fa.pageTitle, 'اتصال و پشتیبانی');
    expect(fa.receiveTitle, 'دریافت پشتیبانی');
    expect(fa.connectTitle, 'اتصال به مشتری');
    expect(fa.recentTitle, 'دستگاه‌های اخیر');
    expect(en.pageTitle, 'Connection & Support');
    expect(en.receiveTitle, 'Receive Support');
    expect(en.connectTitle, 'Connect to Customer');
    expect(en.recentTitle, 'Recent Devices');
  });

  test('kRaatikApiEnabled stays off', () {
    expect(kRaatikApiEnabled, isFalse);
  });

  test('settings allowlist keeps General and About when security is hidden',
      () {
    const restricted = RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: false,
      disableSettings: true,
      hideSecurity: true,
      hideNetwork: true,
      pluginFeatureEnabled: true,
      apiEnabled: false,
      disableAccount: false,
      isWindows: true,
      hideRemotePrinter: false,
    );
    expect(restricted.sections, contains(RaatikSettingsSection.general));
    expect(restricted.sections, contains(RaatikSettingsSection.about));
    expect(restricted.sections, isNot(contains(RaatikSettingsSection.safety)));
    expect(restricted.sections, isNot(contains(RaatikSettingsSection.network)));
    expect(restricted.sections.first, RaatikSettingsSection.general);

    const open = RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: false,
      disableSettings: false,
      hideSecurity: false,
      hideNetwork: false,
      pluginFeatureEnabled: true,
      apiEnabled: true,
      disableAccount: false,
      isWindows: true,
      hideRemotePrinter: false,
    );
    expect(open.sections, const [
      RaatikSettingsSection.general,
      RaatikSettingsSection.safety,
      RaatikSettingsSection.display,
      RaatikSettingsSection.network,
      RaatikSettingsSection.plugin,
      RaatikSettingsSection.account,
      RaatikSettingsSection.printer,
      RaatikSettingsSection.about,
    ]);

    const incoming = RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: true,
      disableSettings: false,
      hideSecurity: false,
      hideNetwork: false,
      pluginFeatureEnabled: true,
      apiEnabled: kRaatikApiEnabled,
      disableAccount: false,
      isWindows: false,
      hideRemotePrinter: true,
    );
    expect(incoming.sections, isNot(contains(RaatikSettingsSection.display)));
    expect(incoming.sections, isNot(contains(RaatikSettingsSection.plugin)));
    expect(incoming.sections, contains(RaatikSettingsSection.safety));
    expect(incoming.sections, contains(RaatikSettingsSection.general));
    expect(incoming.sections, contains(RaatikSettingsSection.about));
    expect(incoming.sections, isNot(contains(RaatikSettingsSection.account)));
  });

  testWidgets('hidden Security and Network deep links cannot bypass the gate',
      (tester) async {
    const access = RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: false,
      disableSettings: true,
      hideSecurity: true,
      hideNetwork: true,
      pluginFeatureEnabled: false,
      apiEnabled: false,
      disableAccount: true,
      isWindows: true,
      hideRemotePrinter: true,
    );
    final hiddenCalls = ValueNotifier<int>(0);
    final destination = ValueNotifier(RaatikDestination.settings);
    addTearDown(hiddenCalls.dispose);
    addTearDown(destination.dispose);

    await _pump(
      tester,
      RaatikAppShell(
        destination: destination,
        home: const Text('HOME'),
        settings: _SettingsDeepLinkFixture(
          access: access,
          hiddenCalls: hiddenCalls,
        ),
      ),
      size: const Size(1024, 600),
      locale: const Locale('en'),
    );

    expect(find.text('section-general'), findsOneWidget);
    expect(find.text('section-about'), findsOneWidget);
    expect(find.text('section-safety-body'), findsNothing);
    expect(find.text('section-network-body'), findsNothing);

    await tester.tap(find.text('open-safety'));
    await tester.pump();
    expect(find.text('section-safety-body'), findsNothing);
    expect(find.text('shown-general'), findsOneWidget);
    expect(hiddenCalls.value, 0);

    await tester.tap(find.text('open-network'));
    await tester.pump();
    expect(find.text('section-network-body'), findsNothing);
    expect(find.text('shown-general'), findsOneWidget);
    expect(hiddenCalls.value, 0);

    await tester.tap(find.text('open-about'));
    await tester.pump();
    expect(find.text('shown-about'), findsOneWidget);
    expect(find.text('section-about'), findsOneWidget);
    expect(hiddenCalls.value, 0);
    expect(tester.takeException(), isNull);
  });
}

class _VisibilityTimerProbe extends StatefulWidget {
  const _VisibilityTimerProbe({required this.ticks});

  final ValueNotifier<int> ticks;

  @override
  State<_VisibilityTimerProbe> createState() => _VisibilityTimerProbeState();
}

class _VisibilityTimerProbeState extends State<_VisibilityTimerProbe> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync(bool visible) {
    if (!visible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
      widget.ticks.value++;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(RaatikPageVisibility.of(context));
  }

  @override
  Widget build(BuildContext context) {
    _sync(RaatikPageVisibility.of(context));
    return const SizedBox(
      key: _historyPageKey,
      child: Text('History'),
    );
  }
}

class _SettingsDeepLinkFixture extends StatefulWidget {
  const _SettingsDeepLinkFixture({
    required this.access,
    required this.hiddenCalls,
  });

  final RaatikSettingsAccess access;
  final ValueNotifier<int> hiddenCalls;

  @override
  State<_SettingsDeepLinkFixture> createState() =>
      _SettingsDeepLinkFixtureState();
}

class _SettingsDeepLinkFixtureState extends State<_SettingsDeepLinkFixture> {
  late RaatikSettingsSection _shown = widget.access.sections.first;

  void _open(RaatikSettingsSection requested) {
    openRaatikSettingsSection(
      requested: requested,
      allowed: widget.access.sections,
      openSection: (section) => setState(() => _shown = section),
      openHiddenSection: (_) => widget.hiddenCalls.value++,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.access.sections;
    return Column(
      children: [
        Text('shown-${_shown.name}'),
        TextButton(
          onPressed: () => _open(RaatikSettingsSection.safety),
          child: const Text('open-safety'),
        ),
        TextButton(
          onPressed: () => _open(RaatikSettingsSection.network),
          child: const Text('open-network'),
        ),
        TextButton(
          onPressed: () => _open(RaatikSettingsSection.about),
          child: const Text('open-about'),
        ),
        if (allowed.contains(RaatikSettingsSection.general))
          const Text('section-general'),
        if (allowed.contains(RaatikSettingsSection.about))
          const Text('section-about'),
        if (_shown == RaatikSettingsSection.safety)
          const Text('section-safety-body'),
        if (_shown == RaatikSettingsSection.network)
          const Text('section-network-body'),
      ],
    );
  }
}
