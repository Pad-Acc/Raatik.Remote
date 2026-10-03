import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/layout/breakpoints.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

void main() {
  test('classifies window widths into compact, medium, and wide', () {
    expect(raatikWindowClassFor(480), RaatikWindowClass.compact);
    expect(raatikWindowClassFor(639.9), RaatikWindowClass.compact);
    expect(raatikWindowClassFor(640), RaatikWindowClass.medium);
    expect(raatikWindowClassFor(1199.9), RaatikWindowClass.medium);
    expect(raatikWindowClassFor(1200), RaatikWindowClass.wide);
  });

  test('breakpoints come from tokens', () {
    expect(RaatikTokens.compactMax, 640);
    expect(RaatikTokens.mediumMax, 1200);
  });
}
