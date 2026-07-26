import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/layout/breakpoints.dart';

void main() {
  test('classifies window widths into compact, medium, and wide', () {
    expect(raatikWindowClassFor(800), RaatikWindowClass.compact);
    expect(raatikWindowClassFor(899.9), RaatikWindowClass.compact);
    expect(raatikWindowClassFor(900), RaatikWindowClass.medium);
    expect(raatikWindowClassFor(1199.9), RaatikWindowClass.medium);
    expect(raatikWindowClassFor(1200), RaatikWindowClass.wide);
  });
}
