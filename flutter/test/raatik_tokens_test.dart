import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

void main() {
  test('spacing scale is 4-based and legacy names alias it', () {
    expect([
      RaatikTokens.space1,
      RaatikTokens.space2,
      RaatikTokens.space3,
      RaatikTokens.space4,
      RaatikTokens.space5,
      RaatikTokens.space6,
      RaatikTokens.space8,
    ], [4, 8, 12, 16, 20, 24, 32]);
    expect(RaatikTokens.spaceXs, RaatikTokens.space1);
    expect(RaatikTokens.spaceSm, RaatikTokens.space2);
    expect(RaatikTokens.spaceMd, RaatikTokens.space3);
    expect(RaatikTokens.spaceLg, RaatikTokens.space4);
    expect(RaatikTokens.spaceXl, RaatikTokens.space5);
  });

  test('radius scale steps 8 12 16 20 pill', () {
    expect([
      RaatikTokens.radiusXs,
      RaatikTokens.radiusSm,
      RaatikTokens.radiusLg,
      RaatikTokens.radiusXl,
    ], [8, 12, 16, 20]);
    expect(RaatikTokens.radiusPill, greaterThanOrEqualTo(999));
  });

  test('control sizes match the design system', () {
    expect(RaatikTokens.minTarget, 44);
    expect(RaatikTokens.heroInput, 52);
    expect(RaatikTokens.toolbarBtn, 36);
    expect(RaatikTokens.toolbarBar, 48);
    expect(RaatikTokens.rail, 64);
    expect(RaatikTokens.sidebar, 232);
    expect(RaatikTokens.heroMax, 640);
    expect(RaatikTokens.tileMaxExtent, 220);
    expect(RaatikTokens.tileHeader + RaatikTokens.tileFooter, 136);
    expect(RaatikTokens.numericField4, 64);
    expect(RaatikTokens.numericField5, 80);
    expect(RaatikTokens.motion, const Duration(milliseconds: 180));
    expect(RaatikTokens.curve, Curves.easeOutCubic);
  });
}
