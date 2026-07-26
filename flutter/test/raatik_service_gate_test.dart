import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/models/svc_status.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

const _faCopy = RaatikServiceGateCopy(
  stoppedTitle: 'سرویس اجرا نشده',
  startLabel: 'اجرای سرویس',
  startingLabel: '...در حال برقراری ارتباط با سرور',
  readyLabel: 'آماده به کار',
  stoppedBody: 'ارتباط برقرار نشد. لطفا شبکه خود را بررسی کنید',
  failedTitle: 'ناموفق',
  retryBody: 'تلاش مجدد',
);

Widget _wrap(Widget child) => MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('deriveRaatikServicePhase', () {
    test('stopped wins over stale SvcStatus.ready', () {
      expect(
        deriveRaatikServicePhase(
          stopped: true,
          status: SvcStatus.ready,
          startPending: false,
          error: null,
        ),
        RaatikServicePhase.stopped,
      );
    });

    test('failed when error is set and service is not stopped', () {
      expect(
        deriveRaatikServicePhase(
          stopped: false,
          status: SvcStatus.notReady,
          startPending: false,
          error: 'timeout',
        ),
        RaatikServicePhase.failed,
      );
    });

    test('starting while start is pending', () {
      expect(
        deriveRaatikServicePhase(
          stopped: false,
          status: SvcStatus.notReady,
          startPending: true,
          error: null,
        ),
        RaatikServicePhase.starting,
      );
    });

    test('connecting when pending and status is connecting', () {
      expect(
        deriveRaatikServicePhase(
          stopped: false,
          status: SvcStatus.connecting,
          startPending: true,
          error: null,
        ),
        RaatikServicePhase.connecting,
      );
    });

    test('ready only when status is ready and service is not stopped', () {
      expect(
        deriveRaatikServicePhase(
          stopped: false,
          status: SvcStatus.ready,
          startPending: false,
          error: null,
        ),
        RaatikServicePhase.ready,
      );
    });
  });

  group('RaatikServiceGate', () {
    testWidgets('stopped shows Persian title and start label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          RaatikServiceGate(
            phase: RaatikServicePhase.stopped,
            copy: _faCopy,
            onStart: () {},
          ),
        ),
      );

      expect(find.text('سرویس اجرا نشده'), findsOneWidget);
      expect(find.text('اجرای سرویس'), findsOneWidget);
      expect(find.text('ارتباط برقرار نشد. لطفا شبکه خود را بررسی کنید'),
          findsOneWidget);
    });

    testWidgets('starting disables button and shows progress',
        (WidgetTester tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          RaatikServiceGate(
            phase: RaatikServicePhase.starting,
            copy: _faCopy,
            onStart: () => tapped++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('...در حال برقراری ارتباط با سرور'), findsNWidgets(2));

      expect(find.text('سرویس اجرا نشده'), findsNothing);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(tapped, 0);
    });

    testWidgets('connecting shows starting label as title, not stopped title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          RaatikServiceGate(
            phase: RaatikServicePhase.connecting,
            copy: _faCopy,
            onStart: () {},
          ),
        ),
      );

      expect(find.text('...در حال برقراری ارتباط با سرور'), findsNWidgets(2));
      expect(find.text('سرویس اجرا نشده'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ready shows compact success row', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          RaatikServiceGate(
            phase: RaatikServicePhase.ready,
            copy: _faCopy,
            onStart: () {},
          ),
        ),
      );

      expect(find.text('آماده به کار'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('failed shows retry action', (WidgetTester tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          RaatikServiceGate(
            phase: RaatikServicePhase.failed,
            copy: _faCopy,
            onStart: () => retried = true,
          ),
        ),
      );

      expect(find.text('ناموفق'), findsOneWidget);
      expect(find.text('تلاش مجدد'), findsOneWidget);

      await tester.tap(find.text('تلاش مجدد'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('uses live-region semantics container',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          RaatikServiceGate(
            phase: RaatikServicePhase.stopped,
            copy: _faCopy,
            onStart: () {},
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    });
  });
}
