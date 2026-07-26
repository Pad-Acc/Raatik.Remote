import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/preview/fake_home.dart';
import 'package:flutter_hbb/preview_main.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

Widget _wrapHome(Widget child) {
  return MaterialApp(
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildRaatikLightTheme(),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: SizedBox.expand(child: child),
    ),
  );
}

void main() {
  testWidgets('tip title aligns to start under RTL', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapHome(
        FakeHomePage(
          phase: RaatikServicePhase.ready,
          copy: previewServiceGateCopy(const Locale('fa')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('آماده برای پشتیبانی اتوفای');
    expect(title, findsOneWidget);
    final textWidget = tester.widget<Text>(title);
    // Production tip must not use Alignment.centerLeft; assert geometry:
    // ignore: unused_local_variable
    final titleBox = tester.getTopLeft(title);
    // ignore: unused_local_variable
    final panelBox = tester.getTopLeft(find.byType(FakeHomePage));
    // In RTL, title's left edge should be farther right than panel mid if start-aligned;
    // simpler: ensure no Align with Alignment.centerLeft ancestor.
    expect(
      find.ancestor(
        of: title,
        matching: find.byWidgetPredicate(
          (w) => w is Align && w.alignment == Alignment.centerLeft,
        ),
      ),
      findsNothing,
    );
    expect(
        textWidget.textAlign == null ||
            textWidget.textAlign == TextAlign.start,
        isTrue);
  });

  testWidgets('Ready appears once on ready home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapHome(
        FakeHomePage(
          phase: RaatikServicePhase.ready,
          copy: previewServiceGateCopy(const Locale('fa')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('آماده به کار'), findsOneWidget);
  });
}
