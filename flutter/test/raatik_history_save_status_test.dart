import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/session/history_save_status.dart';

import 'raatik_test_app.dart';

const _text = 'ثبت تاریخچه روی این رایانه انجام نشد؛ اتصال برقرار است.';
const _action = 'تلاش دوباره';

void main() {
  testWidgets('retry stays on this session and does not reconnect',
      (tester) async {
    var retried = 0;
    var reconnected = 0;
    await tester.pumpWidget(testApp(
      Column(
        children: [
          HistorySaveStatus(
            text: _text,
            actionLabel: _action,
            onRetry: () => retried++,
          ),
          TextButton(
            onPressed: () => reconnected++,
            child: const Text('reconnect-spy'),
          ),
        ],
      ),
    ));

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(_text), findsOneWidget);
    expect(find.text(_action), findsOneWidget);
    final button = find.byKey(HistorySaveStatus.actionKey);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    await tester.pump();
    expect(retried, 1);
    expect(reconnected, 0);
  });

  testWidgets('one session retry leaves the other warning up', (tester) async {
    var first = 0;
    var second = 0;
    await tester.pumpWidget(testApp(
      Column(
        children: [
          HistorySaveStatus(
            text: _text,
            actionLabel: _action,
            onRetry: () => first++,
            actionKey: const Key('history-retry-a'),
          ),
          HistorySaveStatus(
            text: _text,
            actionLabel: _action,
            onRetry: () => second++,
            actionKey: const Key('history-retry-b'),
          ),
        ],
      ),
      locale: const Locale('en'),
      themeMode: ThemeMode.dark,
    ));

    await tester.tap(find.byKey(const Key('history-retry-a')));
    await tester.pump();
    expect(first, 1);
    expect(second, 0);
    expect(find.text(_text), findsNWidgets(2));
    expect(find.byType(Dialog), findsNothing);
  });
}
