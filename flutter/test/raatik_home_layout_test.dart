import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/home/connect_overflow_button.dart';
import 'package:flutter_hbb/raatik/home/home_layout.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

const _receiveKey = Key('receive-panel');
const _connectKey = Key('connect-panel');
const _gateKey = Key('service-gate');

Widget _homeAtSize(
  double width,
  double height, {
  bool blocked = false,
  bool showConnectPanel = true,
  Widget? recent,
  VoidCallback? onOpenHistory,
}) =>
    MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: RaatikHomeLayout(
            serviceGate: const SizedBox(key: _gateKey, height: 40),
            receivePanel: const SizedBox(key: _receiveKey, height: 120),
            connectPanel: const SizedBox(key: _connectKey, height: 100),
            showConnectPanel: showConnectPanel,
            blocked: blocked,
            recent: recent,
            onOpenHistory: onOpenHistory,
          ),
        ),
      ),
    );

bool _isCompactLayout(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.descendant(
      of: find.byType(RaatikHomeLayout),
      matching: find.byType(AnimatedOpacity),
    ),
  );
  return opacity.child is Column;
}

bool _isTwoColumnLayout(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.descendant(
      of: find.byType(RaatikHomeLayout),
      matching: find.byType(AnimatedOpacity),
    ),
  );
  return opacity.child is Row;
}

Future<void> _pumpHome(
  WidgetTester tester,
  double width,
  double height, {
  bool blocked = false,
  bool showConnectPanel = true,
  Widget? recent,
  VoidCallback? onOpenHistory,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _homeAtSize(
      width,
      height,
      blocked: blocked,
      showConnectPanel: showConnectPanel,
      recent: recent,
      onOpenHistory: onOpenHistory,
    ),
  );
  await tester.pumpAndSettle();
}

const _recentConnectKey = ValueKey('recent-connect');

Widget _recentConnectButton() => TextButton(
      key: _recentConnectKey,
      onPressed: () {},
      child: const Text('recent-connect'),
    );

Widget _tallRecentList() => Column(
      children: [
        for (var i = 0; i < 40; i++)
          SizedBox(
            key: i == 0 ? const ValueKey('recent-row') : null,
            height: 48,
            child: Text('peer $i'),
          ),
      ],
    );

int _verticalScrollOwners(WidgetTester tester) {
  return tester
      .widgetList<Scrollable>(find.descendant(
    of: find.byType(RaatikHomeLayout),
    matching: find.byType(Scrollable),
  ))
      .where((scrollable) {
    final vertical = scrollable.axisDirection == AxisDirection.down ||
        scrollable.axisDirection == AxisDirection.up;
    return vertical && scrollable.physics is! NeverScrollableScrollPhysics;
  }).length;
}

void main() {
  group('RaatikHomeLayout viewport', () {
    testWidgets('600x600 uses compact stacked layout', (tester) async {
      await _pumpHome(tester, 600, 600);

      expect(_isCompactLayout(tester), isTrue);
      expect(_isTwoColumnLayout(tester), isFalse);
    });

    testWidgets('1024x600 uses two-column layout', (tester) async {
      await _pumpHome(tester, 1024, 600);

      expect(_isTwoColumnLayout(tester), isTrue);
      expect(_isCompactLayout(tester), isFalse);
    });

    testWidgets('1366x768 uses two-column layout', (tester) async {
      await _pumpHome(tester, 1366, 768);

      expect(_isTwoColumnLayout(tester), isTrue);
      expect(_isCompactLayout(tester), isFalse);
    });

    testWidgets('1920x1080 uses two-column layout', (tester) async {
      await _pumpHome(tester, 1920, 1080);

      expect(_isTwoColumnLayout(tester), isTrue);
      expect(_isCompactLayout(tester), isFalse);
    });
  });

  group('RaatikHomeLayout incoming-only', () {
    testWidgets('omits connect panel and receive fills width at 1024',
        (tester) async {
      await _pumpHome(tester, 1024, 600, showConnectPanel: false);

      expect(find.byKey(_connectKey), findsNothing);
      expect(_isTwoColumnLayout(tester), isFalse);

      final receive = tester.getRect(find.byKey(_receiveKey));
      final layout = tester.getRect(find.byType(RaatikHomeLayout));
      // Medium page margin is 24 on each side (UI-C02).
      expect(receive.width, closeTo(layout.width - 48, 1));
    });

    testWidgets('omits connect panel in compact layout at 600', (tester) async {
      await _pumpHome(tester, 600, 600, showConnectPanel: false);

      expect(find.byKey(_connectKey), findsNothing);
      expect(_isCompactLayout(tester), isFalse);
      expect(find.byKey(_receiveKey), findsOneWidget);
    });
  });

  group('RaatikHomeLayout service gate', () {
    testWidgets('shows service gate above panels', (tester) async {
      await _pumpHome(tester, 1024, 600);

      final gate = tester.getRect(find.byKey(_gateKey));
      final receive = tester.getRect(find.byKey(_receiveKey));
      expect(receive.top, greaterThan(gate.bottom));
    });

    testWidgets('blocked dims panels and absorbs pointer', (tester) async {
      await _pumpHome(tester, 1024, 600, blocked: true);

      final opacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('raatik-panels-opacity')),
      );
      expect(opacity.opacity, 0.48);

      final absorb = tester.widget<AbsorbPointer>(
        find.byKey(const ValueKey('raatik-panels-gate')),
      );
      expect(absorb.absorbing, isTrue);
    });

    testWidgets('blocked recent connect is not hittable', (tester) async {
      var openedHistory = false;
      await _pumpHome(
        tester,
        1024,
        600,
        blocked: true,
        recent: _recentConnectButton(),
        onOpenHistory: () => openedHistory = true,
      );

      await tester.ensureVisible(find.byKey(_recentConnectKey));
      expect(find.byKey(_recentConnectKey), findsOneWidget);
      expect(find.byKey(_recentConnectKey).hitTestable(), findsNothing);
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
      expect(openedHistory, isTrue);
    });

    testWidgets('ready recent connect stays hittable', (tester) async {
      await _pumpHome(
        tester,
        1024,
        600,
        recent: _recentConnectButton(),
      );

      await tester.ensureVisible(find.byKey(_recentConnectKey));
      expect(find.byKey(_recentConnectKey).hitTestable(), findsOneWidget);
      final recentGate = tester.widget<AbsorbPointer>(
        find.byKey(const ValueKey('raatik-recent-gate')),
      );
      expect(recentGate.absorbing, isFalse);
    });
  });

  testWidgets('recent devices use the home page scroll', (tester) async {
    await _pumpHome(tester, 1024, 600, recent: _tallRecentList());

    expect(_verticalScrollOwners(tester), 1);
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
}
