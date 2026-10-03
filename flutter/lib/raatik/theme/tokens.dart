import 'package:flutter/material.dart';

/// RaatikDesk design tokens. See raatik/design/DESIGN-SYSTEM.md sections 1 and 4.
class RaatikTokens {
  RaatikTokens._();

  // Colour: RaatikDesk palette (deliberately not taken from any reference app).
  static const primary = Color(0xFF0284C7);
  static const accent = Color(0xFF0891B2);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const lightCanvas = Color(0xFFF4F7FB);
  static const darkCanvas = Color(0xFF111827);

  // Spacing: 4-based scale.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;
  // Legacy aliases kept for existing call sites.
  static const spaceXs = space1;
  static const spaceSm = space2;
  static const spaceMd = space3;
  static const spaceLg = space4;
  static const spaceXl = space5;
  static const iconLabelGap = space3;

  // Radius: nested containers step 20 -> 16 -> 12 -> 8.
  static const radiusXs = 8.0;
  static const radiusSm = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radiusPill = 999.0;

  // Sizes.
  static const minTarget = 44.0;
  static const heroInput = 52.0;
  static const toolbarBtn = 36.0;
  static const toolbarBar = 48.0;
  static const rail = 64.0;
  static const sidebar = 232.0;
  static const heroMax = 640.0;
  static const dialogMax = 560.0;
  static const confirmDialogMax = 360.0;
  static const tileMaxExtent = 220.0;
  static const tileHeader = 96.0;
  static const tileFooter = 40.0;
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const glyph = 48.0;
  static const dot = 8.0;
  static const contentMaxWidth = 1440.0;
  /// Widths for short numeric fields (ports, resolutions, codes).
  static const numericField4 = 64.0;
  static const numericField5 = 80.0;

  // Breakpoints (window width). compact < compactMax <= medium < mediumMax <= wide.
  static const compactMax = 640.0;
  static const mediumMax = 1200.0;

  // Motion.
  static const motion = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;

  static const inputContentPadding =
      EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12);
}
