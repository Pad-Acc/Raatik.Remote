import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop_tab_page Settings ActionIcon uses Icons.settings not IconFont.menu', () {
    final file = File('lib/desktop/pages/desktop_tab_page.dart');
    expect(file.existsSync(), isTrue, reason: 'run from flutter/ directory');
    final src = file.readAsStringSync();
    expect(src.contains('icon: Icons.settings'), isTrue);
    expect(src.contains('icon: IconFont.menu'), isFalse);
  });

  testWidgets('Icons.settings is distinct from IconFont.menu glyph', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Icon(Icons.settings)));
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(Icons.settings.codePoint != 0xe628, isTrue);
  });
}
