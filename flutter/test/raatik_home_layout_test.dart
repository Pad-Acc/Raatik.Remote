import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/home/home_layout.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

const _receiveKey = Key('receive-panel');
const _connectKey = Key('connect-panel');
const _gateKey = Key('service-gate');

Widget _homeAtSize(double width, double height, {bool blocked = false}) =>
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
            blocked: blocked,
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
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_homeAtSize(width, height, blocked: blocked));
  await tester.pumpAndSettle();
}

void main() {
  group('RaatikHomeLayout viewport', () {
    testWidgets('800x600 uses compact stacked layout', (tester) async {
      await _pumpHome(tester, 800, 600);

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
        find.descendant(
          of: find.byType(RaatikHomeLayout),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, 0.48);

      final absorb = tester.widget<AbsorbPointer>(
        find.descendant(
          of: find.byType(RaatikHomeLayout),
          matching: find.byType(AbsorbPointer),
        ),
      );
      expect(absorb.absorbing, isTrue);
    });
  });
}
