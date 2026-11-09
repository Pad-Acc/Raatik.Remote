import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/chat/composer_keys.dart';
import 'package:flutter_hbb/raatik/dialogs/modal_keys.dart';
import 'package:flutter_hbb/raatik/files/transfer_surface.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';
import 'package:flutter_hbb/raatik/toolbar/session_toolbar.dart';

import 'raatik_test_app.dart';

const _compact = Size(480, 680);
const _secret = 's3cret-Value-99';
const _longError =
    'The login failed because the account is locked and the administrator must reset access before another attempt can succeed on this workstation today.';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = _compact,
  Locale locale = const Locale('fa'),
  double scale = 2,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(testApp(
    child,
    size: size,
    locale: locale,
    textScaler: TextScaler.linear(scale),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'compact RTL at 200% rejects once, blocks a denied transfer, and stays exception-free',
      (tester) async {
    final calls = <String>[];
    var transferCalls = 0;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showRaatikApprovalDialog(
            context: context,
            requesterName: 'Mina',
            requesterId: '123456789',
            permissions: const [
              RaatikPermissionChoice(
                id: 'keyboard',
                label: 'Keyboard',
                enabled: true,
              ),
            ],
            onPermission: (_) {},
            onAccept: () => calls.add('accept'),
            onReject: () => calls.add('reject'),
          ),
          child: const Text('open-approval'),
        ),
      ),
    );
    await tester.tap(find.text('open-approval'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(calls, ['reject']);

    await _pump(
      tester,
      RaatikFileTransferSurface(
        width: _compact.width,
        localLabel: 'این رایانه',
        remoteLabel: 'رایانهٔ مقابل',
        overflowLabel: 'More',
        disabledReason: 'File transfer is denied',
        transferPermitted: false,
        onTransfer: () => transferCalls++,
        localFiles: const [
          RaatikFileEntry(
            name: 'quarterly-plan.txt',
            id: '123456789',
          ),
        ],
        remoteFiles: const [
          RaatikFileEntry(name: 'remote-note.txt', id: '987654321'),
        ],
        error: _longError,
        progress: 0.4,
        onCancel: () => calls.add('cancel-transfer'),
      ),
    );
    expect(find.byKey(const Key('file-panel-local')), findsOneWidget);
    expect(find.byKey(const Key('file-panel-remote')), findsNothing);
    await tester.tap(find.byKey(RaatikLabelledOverflow.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('file-overflow-transfer')));
    await tester.pump();
    expect(transferCalls, 0);
    expect(calls, ['reject']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accept and reject each fire once and Enter follows focus',
      (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showRaatikApprovalDialog(
            context: context,
            requesterName: 'Mina',
            requesterId: '123456789',
            permissions: const [
              RaatikPermissionChoice(
                id: 'keyboard',
                label: 'Keyboard',
                enabled: true,
              ),
            ],
            onPermission: (choice) =>
                calls.add('perm:${choice.id}:${choice.enabled}'),
            onAccept: () => calls.add('accept'),
            onReject: () => calls.add('reject'),
          ),
          child: const Text('open-approval'),
        ),
      ),
    );
    await tester.tap(find.text('open-approval'));
    await tester.pumpAndSettle();

    final id = tester.widget<Text>(find.byWidgetPredicate((widget) =>
        widget is Text &&
        (widget.data ?? '').contains('\u2066') &&
        (widget.data ?? '').contains('123')));
    expect(id.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(find.text('Mina'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approval-perm-keyboard')));
    await tester.pump();
    expect(calls, ['perm:keyboard:false']);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['perm:keyboard:false']);

    await tester.tap(find.byKey(const Key('approval-reject')));
    await tester.pumpAndSettle();
    expect(calls, ['perm:keyboard:false', 'reject']);

    calls.clear();
    await tester.tap(find.text('open-approval'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['accept']);
  });

  testWidgets('tab stays inside the approval dialog', (tester) async {
    final outside = FocusNode();
    addTearDown(outside.dispose);
    var outsideTaps = 0;
    await _pump(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              focusNode: outside,
              onPressed: () => outsideTaps++,
              child: const Text('outside'),
            ),
            TextButton(
              onPressed: () => showRaatikApprovalDialog(
                context: context,
                requesterName: 'Mina',
                requesterId: '123456789',
                permissions: const [
                  RaatikPermissionChoice(
                    id: 'keyboard',
                    label: 'Keyboard',
                    enabled: true,
                  ),
                ],
                onPermission: (_) {},
                onAccept: () {},
                onReject: () {},
              ),
              child: const Text('open-approval'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open-approval'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(outside.hasFocus, isFalse);
    expect(outsideTaps, 0);
    expect(find.byKey(const Key('approval-reject')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Escape cancels credentials without connecting and a long error wraps without the password',
      (tester) async {
    final calls = <String>[];
    final password = TextEditingController(text: _secret);
    addTearDown(password.dispose);
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showRaatikCredentialDialog(
            context: context,
            password: password,
            error: 'failed for $_secret because $_longError',
            onSubmit: () => calls.add('accept'),
            onCancel: () => calls.add('cancel'),
          ),
          child: const Text('open-credential'),
        ),
      ),
    );
    await tester.tap(find.text('open-credential'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, isEmpty);

    final error = tester.widget<SelectableText>(
      find.byKey(const Key('raatik-wrapping-error')),
    );
    expect(error.data, isNot(contains(_secret)));
    expect(error.maxLines, isNull);
    expect(
      tester.getSize(find.byKey(const Key('raatik-wrapping-error'))).height,
      greaterThan(60),
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is EditableText && widget.obscureText) return false;
        if (widget is Text) return (widget.data ?? '').contains(_secret);
        if (widget is SelectableText) {
          return (widget.data ?? '').contains(_secret);
        }
        return false;
      }),
      findsNothing,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(calls, ['cancel']);
    expect(find.byKey(const Key('raatik-wrapping-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter submits only the focused chat action', (tester) async {
    final sent = <String>[];
    var otherCalls = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final sendFocus = FocusNode();
    final otherFocus = FocusNode();
    addTearDown(sendFocus.dispose);
    addTearDown(otherFocus.dispose);

    await _pump(
      tester,
      RaatikChatComposer(
        controller: controller,
        messages: const ['first line', 'second line'],
        unread: 3,
        sendFocus: sendFocus,
        otherFocus: otherFocus,
        onSend: sent.add,
        onOther: () => otherCalls++,
      ),
    );
    expect(find.text('3'), findsOneWidget);
    final first = tester.getTopLeft(find.text('first line'));
    final second = tester.getTopLeft(find.text('second line'));
    expect(first.dy, lessThan(second.dy));

    await tester.enterText(find.byKey(const Key('chat-composer')), 'سلام');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['سلام']);

    await tester.enterText(find.byKey(const Key('chat-composer')), 'line');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.text, contains('\n'));
    expect(sent, ['سلام']);

    controller.value = const TextEditingValue(
      text: 'composing',
      composing: TextRange(start: 0, end: 9),
    );
    await tester.pump();
    await tester.showKeyboard(find.byKey(const Key('chat-composer')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['سلام']);

    controller.value = const TextEditingValue(text: 'ready');
    await tester.pump();
    otherFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(otherCalls, 1);
    expect(sent, ['سلام']);

    sendFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['سلام', 'ready']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact file names and ids stay in LTR isolates and wide shows both panels',
      (tester) async {
    await _pump(
      tester,
      const RaatikFileTransferSurface(
        width: 900,
        localLabel: 'This computer',
        remoteLabel: 'Remote computer',
        overflowLabel: 'More',
        transferPermitted: true,
        localFiles: [
          RaatikFileEntry(name: 'quarterly-plan.txt', id: '123456789'),
        ],
        remoteFiles: [
          RaatikFileEntry(name: 'remote-note.txt', id: '987654321'),
        ],
      ),
      size: const Size(900, 680),
      locale: const Locale('en'),
      scale: 1,
    );
    expect(find.byKey(const Key('file-panel-local')), findsOneWidget);
    expect(find.byKey(const Key('file-panel-remote')), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Text &&
          (widget.data ?? '').startsWith('\u2066') &&
          (widget.data ?? '').contains('quarterly-plan.txt')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Text &&
          (widget.data ?? '').startsWith('\u2066') &&
          (widget.data ?? '').contains('123') &&
          widget.style?.fontFamily == kRaatikIdentifierFontFamily),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling a transfer does not start one', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      RaatikFileTransferSurface(
        width: _compact.width,
        localLabel: 'این رایانه',
        remoteLabel: 'رایانهٔ مقابل',
        overflowLabel: 'More',
        transferPermitted: true,
        onTransfer: () => calls.add('transfer'),
        onCancel: () => calls.add('cancel'),
        progress: 0.4,
        localFiles: const [
          RaatikFileEntry(name: 'quarterly-plan.txt', id: '123456789'),
        ],
        remoteFiles: const [
          RaatikFileEntry(name: 'remote-note.txt', id: '987654321'),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('file-side-remote')));
    await tester.pump();
    expect(find.byKey(const Key('file-panel-remote')), findsOneWidget);
    expect(find.textContaining('remote-note.txt'), findsOneWidget);
    await tester.tap(find.byKey(const Key('file-cancel')));
    await tester.pump();
    expect(calls, ['cancel']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium toolbar keeps control in the bar and hides a blocked tool',
      (tester) async {
    var transferCalls = 0;
    await _pump(
      tester,
      RaatikSessionToolbar(
        windowWidth: 900,
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
        tools: [
          RaatikToolbarTool(
            id: RaatikSessionTool.display,
            label: 'Display',
            child: const Text('Display', key: Key('tool-display')),
          ),
          RaatikToolbarTool(
            id: RaatikSessionTool.image,
            label: 'Image',
            child: const Text('Image', key: Key('tool-image')),
          ),
          RaatikToolbarTool(
            id: RaatikSessionTool.control,
            label: 'Control',
            child: const Text('Control', key: Key('tool-control')),
          ),
          RaatikToolbarTool(
            id: RaatikSessionTool.keyboard,
            label: 'Keyboard',
            child: const Text('Keyboard', key: Key('tool-keyboard')),
          ),
          RaatikToolbarTool(
            id: RaatikSessionTool.chat,
            label: 'Chat',
            child: const Text('Chat', key: Key('tool-chat')),
          ),
          RaatikToolbarTool(
            id: RaatikSessionTool.record,
            label: 'Record',
            hidden: true,
            child: const Text('Record', key: Key('tool-record')),
          ),
          RaatikToolbarTool(
            id: RaatikSessionTool.fileTransfer,
            label: 'Transfer',
            enabled: false,
            disabledReason: 'File transfer is denied',
            child: TextButton(
              key: const Key('tool-transfer'),
              onPressed: () => transferCalls++,
              child: const Text('Transfer'),
            ),
          ),
        ],
      ),
      size: const Size(900, 680),
      locale: const Locale('en'),
      scale: 1,
    );
    expect(find.byKey(const Key('tool-control')), findsOneWidget);
    expect(find.byKey(const Key('tool-record')), findsNothing);
    expect(find.text('RaatikDesk'), findsOneWidget);
    await tester.tap(find.byKey(RaatikLabelledOverflow.buttonKey));
    await tester.pumpAndSettle();
    expect(find.text('File transfer is denied'), findsOneWidget);
    expect(find.byKey(const Key('tool-record')), findsNothing);
    await tester.tap(
      find.byKey(const Key('tool-transfer')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(transferCalls, 0);
    final disconnect =
        tester.widget<ColoredBox>(find.byKey(const Key('session-disconnect')));
    expect(disconnect.color, RaatikTokens.danger);
    expect(tester.takeException(), isNull);
  });
}
