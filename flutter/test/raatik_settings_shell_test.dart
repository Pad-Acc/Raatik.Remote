import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/settings/settings_shell.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

enum _TestKey { general, safety, display, about }

const _destinations = [
  RaatikSettingsDestination<_TestKey>(
    keyValue: _TestKey.general,
    label: 'General',
    group: 'عمومی',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
  RaatikSettingsDestination<_TestKey>(
    keyValue: _TestKey.safety,
    label: 'Security',
    group: 'عمومی',
    icon: Icons.enhanced_encryption_outlined,
  ),
  RaatikSettingsDestination<_TestKey>(
    keyValue: _TestKey.display,
    label: 'Display',
    group: 'برای پشتیبان',
    icon: Icons.desktop_windows_outlined,
  ),
  RaatikSettingsDestination<_TestKey>(
    keyValue: _TestKey.about,
    label: 'About',
    group: 'درباره',
    icon: Icons.info_outline,
  ),
];

Widget _shellAtSize(
  double width,
  double height, {
  required _TestKey selected,
  required ValueChanged<_TestKey> onSelected,
}) =>
    MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: RaatikSettingsShell<_TestKey>(
            destinations: _destinations,
            selected: selected,
            onSelected: onSelected,
            content: const SizedBox(key: Key('settings-content')),
          ),
        ),
      ),
    );

Future<void> _pumpShell(
  WidgetTester tester,
  double width,
  double height, {
  required _TestKey selected,
  required ValueChanged<_TestKey> onSelected,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _shellAtSize(width, height, selected: selected, onSelected: onSelected),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RaatikSettingsShell layout', () {
    testWidgets('800px uses compact dropdown header', (tester) async {
      await _pumpShell(
        tester,
        800,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(find.byType(PopupMenuButton<_TestKey>), findsOneWidget);
      expect(find.text('عمومی'), findsNothing);
      expect(
        tester.getSize(find.byType(PopupMenuButton<_TestKey>)).height,
        lessThanOrEqualTo(RaatikSettingsShell.compactHeaderHeight),
      );
    });

    testWidgets('900px+ uses grouped sidebar', (tester) async {
      await _pumpShell(
        tester,
        900,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(find.byType(PopupMenuButton<_TestKey>), findsNothing);
      expect(find.text('عمومی'), findsOneWidget);
      expect(find.text('برای پشتیبان'), findsOneWidget);
      expect(find.text('درباره'), findsOneWidget);
    });

    testWidgets('selecting compact dropdown invokes callback', (tester) async {
      _TestKey? picked;
      await _pumpShell(
        tester,
        800,
        600,
        selected: _TestKey.general,
        onSelected: (key) => picked = key,
      );

      await tester.tap(find.byType(PopupMenuButton<_TestKey>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Display').last);
      await tester.pumpAndSettle();

      expect(picked, _TestKey.display);
    });

    testWidgets('selecting sidebar item invokes callback', (tester) async {
      _TestKey? picked;
      await _pumpShell(
        tester,
        1024,
        600,
        selected: _TestKey.general,
        onSelected: (key) => picked = key,
      );

      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();

      expect(picked, _TestKey.display);
    });

    testWidgets('sidebar rows meet min touch target height', (tester) async {
      await _pumpShell(
        tester,
        1024,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      final generalInkWell = find.ancestor(
        of: find.text('General'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(generalInkWell).height,
        RaatikTokens.minTarget,
      );
    });

    testWidgets('selected sidebar item uses selected icon', (tester) async {
      await _pumpShell(
        tester,
        1024,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      final generalInkWell = find.ancestor(
        of: find.text('General'),
        matching: find.byType(InkWell),
      );
      final generalIcon = tester.widgetList<Icon>(
        find.descendant(of: generalInkWell, matching: find.byType(Icon)),
      ).first;
      expect(generalIcon.icon, Icons.settings);
    });

    testWidgets('sidebar icon-label gap uses RaatikTokens', (tester) async {
      await _pumpShell(
        tester,
        1024,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      final generalInkWell = find.ancestor(
        of: find.text('General'),
        matching: find.byType(InkWell),
      );
      final gaps = tester
          .widgetList<SizedBox>(
            find.descendant(of: generalInkWell, matching: find.byType(SizedBox)),
          )
          .where((box) => box.width != null && box.width! > 0)
          .map((box) => box.width)
          .toList();

      expect(gaps, contains(RaatikTokens.iconLabelGap));
      expect(gaps, contains(RaatikTokens.spaceMd));
    });

    testWidgets('no horizontal overflow at 800px', (tester) async {
      await _pumpShell(
        tester,
        800,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(tester.takeException(), isNull);
      final shell = tester.getRect(find.byType(RaatikSettingsShell<_TestKey>));
      expect(shell.width, 800);
    });
  });
}
