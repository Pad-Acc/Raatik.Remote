import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/chrome/window_chrome.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

void main() {
  testWidgets('RaatikWindowBrand shows logo, title, and semantic label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRaatikLightTheme(),
        home: const Scaffold(
          body: RaatikWindowBrand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RaatikDesk'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'RaatikDesk',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.header == true,
      ),
      findsWidgets,
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, const AssetImage('assets/logo.png'));
    expect(image.width, 22);
    expect(image.height, 22);
  });

  testWidgets('RaatikWindowBrand with showTitle false shows logo only',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRaatikLightTheme(),
        home: const Scaffold(
          body: RaatikWindowBrand(showTitle: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RaatikDesk'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'RaatikDesk',
      ),
      findsOneWidget,
    );
  });
}
