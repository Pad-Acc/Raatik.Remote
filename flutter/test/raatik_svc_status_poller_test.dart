import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for Critical fix: removing OnlineStatusWidget Ready chrome
/// must not remove continuous svcStatus polling.
void main() {
  test('DesktopHomePage timer still polls connect status', () {
    final home = File('lib/desktop/pages/desktop_home_page.dart');
    expect(home.existsSync(), isTrue, reason: 'run from flutter/ directory');
    final src = home.readAsStringSync();

    expect(src.contains('await _pollConnectStatus();'), isTrue);
    expect(src.contains('videoConnCount'), isTrue);
    // Continuous poll must live inside the 1s home timer, not only start-wait loop.
    expect(
      src.contains('Continuous svcStatus / videoConnCount updates'),
      isTrue,
    );
  });

  test('OnlineStatusWidget is not mounted on home/connection pages', () {
    final connection = File('lib/desktop/pages/connection_page.dart');
    final home = File('lib/desktop/pages/desktop_home_page.dart');
    expect(connection.existsSync(), isTrue);
    expect(home.existsSync(), isTrue);

    final connectionSrc = connection.readAsStringSync();
    final homeSrc = home.readAsStringSync();

    // Home must not construct/mount the widget.
    expect(RegExp(r'OnlineStatusWidget\s*\(').hasMatch(homeSrc), isFalse);
    // Connection keeps the class + constructor; forbid bare mounts.
    expect(connectionSrc.contains('OnlineStatusWidget(),'), isFalse);
    expect(connectionSrc.contains('child: OnlineStatusWidget'), isFalse);
    expect(connectionSrc.contains('OnlineStatusWidget(onSvc'), isFalse);
  });
}
