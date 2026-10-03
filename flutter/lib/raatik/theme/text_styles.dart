import 'package:flutter/material.dart';

/// Latin-digit faces. An explicit [TextStyle.fontFamily] overrides the
/// theme's IRANSansXFaNum, whose ASCII digits render as Persian numerals.
const String kRaatikIdentifierFontFamily = 'Segoe UI';
const List<String> kRaatikIdentifierFontFallback = [
  'Roboto',
  'Helvetica Neue',
  'Arial',
];
const String kRaatikMonoFontFamily = 'Consolas';
const List<String> kRaatikMonoFontFallback = ['Menlo', 'monospace'];

/// Text styles from DESIGN-SYSTEM.md section 1.6. Prose styles inherit the
/// theme font; identifier and mono force a Latin-digit face.
class RaatikTextStyles {
  RaatikTextStyles._();

  static TextStyle _base(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

  static Color? _strong(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.color;

  /// IDs, passwords, versions, IPs, durations, shortcuts, monitor numbers.
  static TextStyle identifier(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      _base(context).copyWith(
        fontFamily: kRaatikIdentifierFontFamily,
        fontFamilyFallback: kRaatikIdentifierFontFallback,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        height: 1.4,
        color: color ?? _strong(context),
      );

  /// The remote-ID field value and the user's own ID in the hero.
  static TextStyle displayId(BuildContext context) =>
      identifier(context, fontSize: 26, fontWeight: FontWeight.w500)
          .copyWith(height: 1.2, letterSpacing: 1.5);

  /// IPs, ports, keys, logs.
  static TextStyle mono(BuildContext context) => _base(context).copyWith(
        fontFamily: kRaatikMonoFontFamily,
        fontFamilyFallback: kRaatikMonoFontFallback,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: _strong(context),
      );

  static TextStyle titleLg(BuildContext context) => _base(context).copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: _strong(context));

  static TextStyle titleMd(BuildContext context) => _base(context).copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: _strong(context));

  static TextStyle body(BuildContext context) => _base(context)
      .copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);

  static TextStyle label(BuildContext context) => _base(context)
      .copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);

  static TextStyle caption(BuildContext context) => _base(context).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: Theme.of(context).textTheme.bodySmall?.color);
}
