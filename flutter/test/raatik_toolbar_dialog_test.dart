import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/dialogs/dialog_style.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';
import 'package:flutter_hbb/raatik/toolbar/remote_toolbar_bar.dart';
import 'package:flutter_hbb/raatik/toolbar/session_toolbar.dart';
import 'package:flutter_hbb/raatik/toolbar/toolbar_action.dart';

import 'raatik_test_app.dart';

Widget _toolbarAtWidth(double width) => MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: RaatikRemoteToolbarBar(
            width: width,
            brandLabel: Semantics(
              label: 'RaatikDesk',
              header: true,
              child: const Text('RaatikDesk'),
            ),
            primaryItems: List.generate(
              8,
              (index) => SizedBox(
                key: Key('toolbar-action-$index'),
                width: RaatikRemoteToolbarBar.actionSize,
                height: RaatikRemoteToolbarBar.actionSize,
                child: const ColoredBox(color: Color(0x33FFFFFF)),
              ),
            ),
            moreMenu: Semantics(
              label: 'More',
              button: true,
              child: const Text('More', key: Key('toolbar-more')),
            ),
            closeMenu: Semantics(
              label: 'Disconnect',
              button: true,
              child: const Text('Disconnect', key: Key('toolbar-close')),
            ),
          ),
        ),
      ),
    );

Future<void> _pumpToolbar(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_toolbarAtWidth(width));
  await tester.pumpAndSettle();
}

void main() {
  group('RaatikDialogStyle', () {
    test('defines shared dialog layout constants', () {
      expect(RaatikDialogStyle.maxWidth, 560.0);
      expect(RaatikDialogStyle.padding, const EdgeInsets.all(24));
    });

    test('desktop constraints cap dialog width at 560px', () {
      final constraints = raatikDesktopDialogConstraints(
        const BoxConstraints(maxWidth: 800),
      );
      expect(constraints.maxWidth, RaatikDialogStyle.maxWidth);
    });

    test('desktop dialog content padding derives from RaatikDialogStyle.padding',
        () {
      final padding =
          raatikDesktopDialogContentPadding(actions: true);
      expect(padding.left, RaatikDialogStyle.padding.left);
      expect(padding.top, RaatikDialogStyle.padding.top);
      expect(padding.right, RaatikDialogStyle.padding.right);
      expect(padding.bottom, RaatikDialogStyle.padding.bottom - 4);
    });

    test('dialog actions wrap with OverflowBar on desktop helper', () {
      final actions = raatikDialogActions([
        const Text('Cancel'),
        const Text('OK'),
      ]);
      expect(actions, isNotNull);
      expect(actions!.single, isA<OverflowBar>());
    });

    test('dialog buttons use 44px minimum height', () {
      expect(raatikDialogButtonMinSize.height, RaatikTokens.minTarget);
    });
  });

  group('RaatikToolbarFocusRing', () {
    test('focus border uses shared white 2px ring', () {
      final border = raatikToolbarFocusBorder(true);
      expect(border?.top.color, raatikToolbarFocusRingColor);
      expect(border?.top.width, raatikToolbarFocusRingWidth);
      expect(raatikToolbarFocusBorder(false), isNull);
    });

    test('icon decoration applies focus border when focused', () {
      final decoration = raatikToolbarIconDecoration(
        focused: true,
        hover: false,
        color: Colors.blue,
        hoverColor: Colors.lightBlue,
        borderRadius: 4,
      );
      expect(decoration.border?.top.color, raatikToolbarFocusRingColor);
      expect(decoration.border?.top.width, raatikToolbarFocusRingWidth);
    });
  });

  group('RaatikRemoteToolbarBar', () {
    testWidgets('toolbar actions are 44px targets', (tester) async {
      await _pumpToolbar(tester, 900);

      final action = tester.getSize(find.byKey(const Key('toolbar-action-0')));
      expect(action.width, RaatikRemoteToolbarBar.actionSize);
      expect(action.height, RaatikRemoteToolbarBar.actionSize);
    });

    testWidgets('600px hides brand and keeps More/Disconnect outside scroll',
        (tester) async {
      await _pumpToolbar(tester, 600);

      expect(find.text('RaatikDesk'), findsNothing);
      expect(find.byKey(const Key('toolbar-more')), findsOneWidget);
      expect(find.byKey(const Key('toolbar-close')), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.scrollDirection, Axis.horizontal);

      final moreBox = tester.getRect(find.byKey(const Key('toolbar-more')));
      final closeBox = tester.getRect(find.byKey(const Key('toolbar-close')));
      final scrollBox =
          tester.getRect(find.byType(SingleChildScrollView).first);
      expect(moreBox.right, greaterThan(scrollBox.right - 1));
      expect(closeBox.right, greaterThan(moreBox.right));
    });

    testWidgets('side dock stays inside the 48px strip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(48, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRaatikLightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: RaatikRemoteToolbarBar.barHeight,
              height: 720,
              child: RaatikRemoteToolbarBar(
                width: 720,
                edge: RaatikToolbarEdge.left,
                brandLabel: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('RaatikDesk'),
                    SizedBox(width: 6),
                    Text('peer-with-a-long-name'),
                  ],
                ),
                primaryItems: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 32),
                    ),
                    onPressed: () {},
                    child: const Text('Menu'),
                  ),
                  for (var i = 0; i < 12; i++)
                    SizedBox(
                      key: Key('side-action-$i'),
                      width: 64,
                      height: 32,
                      child: const ColoredBox(color: Color(0x33FFFFFF)),
                    ),
                ],
                moreMenu: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz, color: Colors.white),
                    SizedBox(width: 4),
                    Text('More'),
                  ],
                ),
                closeMenu: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Disconnect'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final bar = tester.getRect(find.byType(RaatikRemoteToolbarBar));
      expect(bar.width, lessThanOrEqualTo(RaatikRemoteToolbarBar.barHeight + 0.01));
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.scrollDirection, Axis.vertical);

      void visit(RenderObject object) {
        if (object is RenderBox && object.hasSize && object.attached) {
          var paint = MatrixUtils.transformRect(
            object.getTransformTo(null),
            Offset.zero & object.size,
          );
          RenderObject? ancestor = object.parent;
          while (ancestor != null) {
            if (ancestor is RenderClipRect &&
                ancestor.hasSize &&
                ancestor.attached) {
              final clip = MatrixUtils.transformRect(
                ancestor.getTransformTo(null),
                Offset.zero & ancestor.size,
              );
              paint = paint.intersect(clip);
            }
            ancestor = ancestor.parent;
          }
          if (!paint.isEmpty) {
            expect(paint.left, greaterThanOrEqualTo(bar.left - 0.5));
            expect(paint.right, lessThanOrEqualTo(bar.right + 0.5));
          }
        }
        object.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(RaatikRemoteToolbarBar)));
    });

    testWidgets('side dock keeps a tall hit target', (tester) async {
      await tester.binding.setSurfaceSize(const Size(48, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRaatikLightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: RaatikRemoteToolbarBar.barHeight,
              height: 720,
              child: RaatikRemoteToolbarBar(
                width: 720,
                edge: RaatikToolbarEdge.left,
                brandLabel: const SizedBox.shrink(),
                primaryItems: const [
                  SizedBox(
                    key: Key('side-hit'),
                    width: 64,
                    height: 36,
                    child: ColoredBox(color: Color(0x33FFFFFF)),
                  ),
                ],
                moreMenu: SizedBox(width: 36, height: 36),
                closeMenu: SizedBox(width: 36, height: 36),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final box = tester.renderObject<RenderBox>(find.byKey(const Key('side-hit')));
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      expect(rect.height, greaterThan(24));
      expect(rect.height, greaterThanOrEqualTo(36));
    });

    testWidgets('900px shows RaatikDesk brand label', (tester) async {
      await _pumpToolbar(tester, 900);

      expect(find.text('RaatikDesk'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.header == true &&
              (widget.properties.label ?? '').contains('RaatikDesk'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('toolbar overflow controls expose semantic labels',
        (tester) async {
      await _pumpToolbar(tester, 800);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == 'More',
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == 'Disconnect',
        ),
        findsWidgets,
      );
    });

    testWidgets('production icon decoration shows visible focus ring',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRaatikLightTheme(),
          home: Scaffold(
            body: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: raatikToolbarIconDecoration(
                  focused: true,
                  hover: false,
                  color: const Color(0xFF0284C7),
                  hoverColor: const Color(0xFF0369A1),
                  borderRadius: 4,
                ),
                child: const SizedBox(
                  width: RaatikRemoteToolbarBar.actionSize,
                  height: RaatikRemoteToolbarBar.actionSize,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ink = tester.widget<Ink>(find.byType(Ink));
      final border =
          (ink.decoration as BoxDecoration?)?.border as Border?;
      expect(border?.top.color, raatikToolbarFocusRingColor);
      expect(border?.top.width, raatikToolbarFocusRingWidth);
    });
  });

  group('RaatikSessionToolbar', () {
    Future<void> pumpSession(
      WidgetTester tester, {
      required double width,
      required Locale locale,
      required List<RaatikToolbarTool> tools,
      FocusNode? overflowFocus,
    }) async {
      final size = Size(width, 680);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(testApp(
        RaatikSessionToolbar(
          windowWidth: width,
          overflowFocus: overflowFocus,
          brandLabel: const Text('RaatikDesk'),
          close: const ColoredBox(
            key: Key('session-disconnect'),
            color: RaatikTokens.danger,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Text('Disconnect'),
            ),
          ),
          tools: tools,
        ),
        size: size,
        locale: locale,
        textScaler: locale.languageCode == 'fa'
            ? const TextScaler.linear(2)
            : const TextScaler.linear(1),
      ));
      await tester.pump();
    }

    List<RaatikToolbarTool> sampleTools({required VoidCallback onTransfer}) {
      return [
        const RaatikToolbarTool(
          id: RaatikSessionTool.display,
          label: 'Display',
          child: Text('Display', key: Key('tool-display')),
        ),
        const RaatikToolbarTool(
          id: RaatikSessionTool.image,
          label: 'Image',
          child: Text('Image', key: Key('tool-image')),
        ),
        const RaatikToolbarTool(
          id: RaatikSessionTool.control,
          label: 'Control',
          child: Text('Control', key: Key('tool-control')),
        ),
        const RaatikToolbarTool(
          id: RaatikSessionTool.keyboard,
          label: 'Keyboard',
          child: Text('Keyboard', key: Key('tool-keyboard')),
        ),
        const RaatikToolbarTool(
          id: RaatikSessionTool.chat,
          label: 'Chat',
          child: Text('Chat', key: Key('tool-chat')),
        ),
        const RaatikToolbarTool(
          id: RaatikSessionTool.record,
          label: 'Record',
          hidden: true,
          child: Text('Record', key: Key('tool-record')),
        ),
        RaatikToolbarTool(
          id: RaatikSessionTool.fileTransfer,
          label: 'Transfer',
          enabled: false,
          disabledReason: 'File transfer is denied',
          child: TextButton(
            key: const Key('tool-transfer'),
            onPressed: onTransfer,
            child: const Text('Transfer'),
          ),
        ),
      ];
    }

    testWidgets('narrow toolbar uses a labelled overflow and keeps disconnect last',
        (tester) async {
      var transferCalls = 0;
      final overflowFocus = FocusNode();
      addTearDown(overflowFocus.dispose);
      await pumpSession(
        tester,
        width: 480,
        locale: const Locale('fa'),
        overflowFocus: overflowFocus,
        tools: sampleTools(onTransfer: () => transferCalls++),
      );

      expect(find.text('RaatikDesk'), findsNothing);
      expect(find.text('More'), findsOneWidget);
      expect(find.byKey(const Key('tool-image')), findsOneWidget);
      expect(find.byKey(const Key('tool-chat')), findsOneWidget);
      expect(find.byKey(const Key('tool-control')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == 'More',
        ),
        findsWidgets,
      );

      overflowFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-control')), findsOneWidget);
      expect(find.byKey(const Key('tool-display')), findsOneWidget);
      expect(find.byKey(const Key('tool-record')), findsNothing);
      expect(find.text('File transfer is denied'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('tool-transfer')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(transferCalls, 0);

      final more = tester.getRect(find.byKey(RaatikLabelledOverflow.buttonKey));
      final close = tester.getRect(find.byKey(const Key('session-disconnect')));
      expect(close.right, lessThanOrEqualTo(more.left));
      expect(more.left - close.right, greaterThanOrEqualTo(8));
      final disconnect = tester
          .widget<ColoredBox>(find.byKey(const Key('session-disconnect')));
      expect(disconnect.color, RaatikTokens.danger);
      expect(tester.takeException(), isNull);
    });

    List<RaatikToolbarTool> focusTools({
      required VoidCallback onDisplay,
      VoidCallback? onDisabled,
      bool disableImage = false,
    }) {
      return [
        RaatikToolbarTool(
          id: RaatikSessionTool.display,
          label: 'Display',
          child: TextButton(
            key: const Key('tool-display-action'),
            onPressed: onDisplay,
            child: const Text('Display'),
          ),
        ),
        RaatikToolbarTool(
          id: RaatikSessionTool.image,
          label: 'Image',
          enabled: !disableImage,
          disabledReason: disableImage ? 'Image is denied' : null,
          child: TextButton(
            key: const Key('tool-image-action'),
            onPressed: onDisabled ?? () {},
            child: const Text('Image'),
          ),
        ),
        const RaatikToolbarTool(
          id: RaatikSessionTool.chat,
          label: 'Chat',
          child: Text('Chat', key: Key('tool-chat')),
        ),
      ];
    }

    Future<void> openOverflow(WidgetTester tester) async {
      await tester.tap(find.byKey(RaatikLabelledOverflow.buttonKey));
      await tester.pumpAndSettle();
    }

    testWidgets('disabled tool ignores Enter and an enabled tool fires once',
        (tester) async {
      var disabledCalls = 0;
      var enabledCalls = 0;
      await pumpSession(
        tester,
        width: 900,
        locale: const Locale('en'),
        tools: focusTools(
          onDisplay: () => enabledCalls++,
          onDisabled: () => disabledCalls++,
          disableImage: true,
        ),
      );

      expect(find.text('Image is denied'), findsOneWidget);
      expect(find.byKey(const Key('tool-image-action')), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final imageLabel = find.descendant(
        of: find.byKey(const Key('tool-image-action')),
        matching: find.text('Image'),
      );
      final imageFocus = Focus.of(tester.element(imageLabel));
      imageFocus.requestFocus();
      await tester.pump();
      expect(imageFocus.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(disabledCalls, 0);

      await tester.tap(find.byKey(const Key('tool-display-action')));
      await tester.pump();
      expect(enabledCalls, 1);
      expect(disabledCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overflow menu takes focus and Enter runs the first item',
        (tester) async {
      var calls = 0;
      await pumpSession(
        tester,
        width: 480,
        locale: const Locale('en'),
        tools: focusTools(onDisplay: () => calls++),
      );

      expect(find.byKey(const Key('tool-display-action')), findsNothing);
      await openOverflow(tester);
      final display = find.byKey(const Key('tool-display-action'));
      expect(display, findsOneWidget);
      final itemFocus = Focus.of(tester.element(find.descendant(
        of: display,
        matching: find.text('Display'),
      )));
      expect(itemFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byKey(const Key('tool-display-action')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('escape closes the overflow menu without running an item',
        (tester) async {
      var calls = 0;
      await pumpSession(
        tester,
        width: 480,
        locale: const Locale('en'),
        tools: focusTools(onDisplay: () => calls++),
      );

      await openOverflow(tester);
      expect(find.byKey(const Key('tool-display-action')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byKey(const Key('tool-display-action')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pointer activation runs an overflow item and closes the menu',
        (tester) async {
      var calls = 0;
      await pumpSession(
        tester,
        width: 480,
        locale: const Locale('en'),
        tools: focusTools(onDisplay: () => calls++),
      );

      await openOverflow(tester);
      await tester.tap(find.byKey(const Key('tool-display-action')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byKey(const Key('tool-display-action')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
