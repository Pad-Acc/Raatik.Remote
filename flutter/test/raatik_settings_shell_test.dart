import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/settings/settings_shell.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

import 'raatik_test_app.dart';

enum _TestKey { general, safety, display, about }

const _selectorKey = ValueKey('raatik-settings-section-selector');
const _contentKey = ValueKey('raatik-settings-content');

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
    selectedIcon: Icons.enhanced_encryption,
  ),
  RaatikSettingsDestination<_TestKey>(
    keyValue: _TestKey.display,
    label: 'Display',
    group: 'برای پشتیبان',
    icon: Icons.desktop_windows_outlined,
    selectedIcon: Icons.desktop_windows,
  ),
  RaatikSettingsDestination<_TestKey>(
    keyValue: _TestKey.about,
    label: 'About',
    group: 'درباره',
    icon: Icons.info_outline,
    selectedIcon: Icons.info,
  ),
];

Future<void> _pumpShell(
  WidgetTester tester,
  double width,
  double height, {
  required _TestKey selected,
  required ValueChanged<_TestKey> onSelected,
  Locale locale = const Locale('fa'),
  TextScaler textScaler = const TextScaler.linear(1),
  Widget? content,
}) async {
  final size = Size(width, height);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testApp(
      RaatikSettingsShell<_TestKey>(
        destinations: _destinations,
        selected: selected,
        onSelected: onSelected,
        content: content ?? const SizedBox(key: Key('settings-content')),
      ),
      size: size,
      locale: locale,
      textScaler: textScaler,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RaatikSettingsShell layout', () {
    testWidgets('compact dropdown is 44 logical pixels', (tester) async {
      await _pumpShell(
        tester,
        480,
        680,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(RaatikSettingsShell.compactHeaderHeight, 44);
      expect(find.byType(PopupMenuButton<_TestKey>), findsOneWidget);
      expect(find.byKey(_selectorKey), findsOneWidget);
      expect(tester.getSize(find.byKey(_selectorKey)).height, 44);
      expect(find.text('عمومی'), findsNothing);
      expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('600px keeps the compact section dropdown', (tester) async {
      await _pumpShell(
        tester,
        600,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(find.byType(PopupMenuButton<_TestKey>), findsOneWidget);
      expect(tester.getSize(find.byKey(_selectorKey)).height, 44);
      expect(find.text('برای پشتیبان'), findsNothing);
    });

    testWidgets('medium width uses a 64px icon rail', (tester) async {
      await _pumpShell(
        tester,
        900,
        600,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(find.byType(PopupMenuButton<_TestKey>), findsNothing);
      expect(find.text('عمومی'), findsNothing);
      expect(find.text('برای پشتیبان'), findsNothing);
      expect(find.text('درباره'), findsNothing);
      expect(find.byKey(_selectorKey), findsOneWidget);
      expect(tester.getSize(find.byKey(_selectorKey)).width, 64);
      expect(find.text('General'), findsWidgets);
    });

    testWidgets('1199px stays on the icon rail', (tester) async {
      await _pumpShell(
        tester,
        1199,
        700,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(tester.getSize(find.byKey(_selectorKey)).width, 64);
      expect(find.text('عمومی'), findsNothing);
    });

    testWidgets('wide section list is 200 and content is capped at 900',
        (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
        selected: _TestKey.general,
        onSelected: (_) {},
        locale: const Locale('en'),
      );

      expect(find.byType(PopupMenuButton<_TestKey>), findsNothing);
      expect(find.byKey(_selectorKey), findsOneWidget);
      expect(tester.getSize(find.byKey(_selectorKey)).width, 200);
      expect(find.text('عمومی'), findsOneWidget);
      expect(find.text('برای پشتیبان'), findsOneWidget);
      expect(find.text('درباره'), findsOneWidget);
      expect(find.byKey(_contentKey), findsOneWidget);
      expect(tester.getSize(find.byKey(_contentKey)).width, 900);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1200px starts the wide section list', (tester) async {
      await _pumpShell(
        tester,
        1200,
        700,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      expect(tester.getSize(find.byKey(_selectorKey)).width, 200);
      expect(find.text('عمومی'), findsOneWidget);
    });

    testWidgets('selecting compact dropdown invokes callback', (tester) async {
      _TestKey? picked;
      await _pumpShell(
        tester,
        600,
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

    testWidgets('selecting a wide section invokes callback', (tester) async {
      _TestKey? picked;
      await _pumpShell(
        tester,
        1366,
        768,
        selected: _TestKey.general,
        onSelected: (key) => picked = key,
      );

      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();

      expect(picked, _TestKey.display);
    });

    testWidgets('selecting a medium rail item invokes callback',
        (tester) async {
      _TestKey? picked;
      await _pumpShell(
        tester,
        900,
        600,
        selected: _TestKey.general,
        onSelected: (key) => picked = key,
      );

      await tester.tap(find.byKey(const ValueKey(_TestKey.display)));
      await tester.pumpAndSettle();

      expect(picked, _TestKey.display);
    });

    testWidgets('wide rows meet the minimum touch target', (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
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

    testWidgets('selected wide item uses the selected icon', (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
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

    testWidgets('wide icon-label gap uses RaatikTokens', (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
        selected: _TestKey.general,
        onSelected: (_) {},
        locale: const Locale('en'),
      );

      final generalInkWell = find.ancestor(
        of: find.text('General'),
        matching: find.byType(InkWell),
      );
      final gaps = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: generalInkWell,
              matching: find.byType(SizedBox),
            ),
          )
          .where((box) => box.width != null && box.width! > 0)
          .map((box) => box.width)
          .toList();

      expect(gaps, contains(RaatikTokens.iconLabelGap));
      expect(gaps, contains(RaatikTokens.spaceMd));
    });

    testWidgets('wide RTL keeps at least 12px between icon and label',
        (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      final generalInkWell = find.ancestor(
        of: find.text('General'),
        matching: find.byType(InkWell),
      );
      final icon = find.descendant(
        of: generalInkWell,
        matching: find.byType(Icon),
      );
      final label = find.descendant(
        of: generalInkWell,
        matching: find.text('General'),
      );
      final iconRect = tester.getRect(icon);
      final labelRect = tester.getRect(label);
      final gap = (iconRect.left - labelRect.right).abs();
      expect(gap, greaterThanOrEqualTo(RaatikTokens.iconLabelGap));
    });

    testWidgets('selector sits on the start edge', (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
        selected: _TestKey.general,
        onSelected: (_) {},
      );

      final shell = tester.getRect(find.byType(RaatikSettingsShell<_TestKey>));
      final selector = tester.getRect(find.byKey(_selectorKey));
      expect(selector.right, closeTo(shell.right, 0.5));
      expect(selector.width, 200);
    });

    testWidgets('content stays centered beside the wide list', (tester) async {
      await _pumpShell(
        tester,
        1366,
        768,
        selected: _TestKey.general,
        onSelected: (_) {},
        locale: const Locale('en'),
      );

      final shell = tester.getRect(find.byType(RaatikSettingsShell<_TestKey>));
      final selector = tester.getRect(find.byKey(_selectorKey));
      final content = tester.getRect(find.byKey(_contentKey));
      final regionCenter = (selector.right + shell.right) / 2;
      expect(selector.left, closeTo(shell.left, 0.5));
      expect(content.center.dx, closeTo(regionCenter, 1));
      expect(content.width, 900);
    });

    testWidgets('no horizontal overflow at 480, 800, or 1366', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const longLabel = 'تنظیمات عمومی و ظاهر برنامه با توضیح بسیار طولانی';
      final destinations = [
        RaatikSettingsDestination<_TestKey>(
          keyValue: _TestKey.general,
          label: longLabel,
          group: 'عمومی',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
        ),
        ..._destinations.skip(1),
      ];

      for (final size in const [
        Size(480, 680),
        Size(800, 600),
        Size(1366, 768),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          testApp(
            RaatikSettingsShell<_TestKey>(
              destinations: destinations,
              selected: _TestKey.general,
              onSelected: (_) {},
              content: const Text(
                'مقدار واردشده برای سرور پروکسی معتبر نیست و باید یک نام میزبان '
                'یا نشانی عددی باشد؛ این پیام طولانی برای بررسی چیدمان فشرده است.',
              ),
            ),
            size: size,
            locale: const Locale('fa'),
            textScaler: size.width < 640
                ? const TextScaler.linear(2)
                : const TextScaler.linear(1),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
