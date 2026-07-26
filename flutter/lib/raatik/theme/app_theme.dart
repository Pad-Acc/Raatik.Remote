import 'package:flutter/material.dart';

import 'tokens.dart';

const _radiusSm = BorderRadius.all(Radius.circular(RaatikTokens.radiusSm));
const _radiusLg = BorderRadius.all(Radius.circular(RaatikTokens.radiusLg));

ButtonStyle _raatikButtonStyle({
  required Color background,
  required Color foreground,
}) {
  return ButtonStyle(
    minimumSize: const MaterialStatePropertyAll(
      Size(0, RaatikTokens.minTarget),
    ),
    padding: const MaterialStatePropertyAll(
      EdgeInsets.symmetric(horizontal: RaatikTokens.spaceLg),
    ),
    backgroundColor: MaterialStatePropertyAll(background),
    foregroundColor: MaterialStatePropertyAll(foreground),
    shape: const MaterialStatePropertyAll(
      RoundedRectangleBorder(borderRadius: _radiusLg),
    ),
    elevation: const MaterialStatePropertyAll(0),
  );
}

InputDecorationTheme _raatikInputDecorationTheme({
  required Color fill,
  required Color border,
  required Color focus,
}) {
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    isDense: false,
    contentPadding: RaatikTokens.inputContentPadding,
    border: OutlineInputBorder(borderRadius: _radiusSm),
    enabledBorder: OutlineInputBorder(
      borderRadius: _radiusSm,
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: _radiusSm,
      borderSide: BorderSide(color: focus, width: 2),
    ),
  );
}

ThemeData buildRaatikLightTheme() {
  return ThemeData(
    useMaterial3: false,
    fontFamily: 'IRANSansXFaNum',
    brightness: Brightness.light,
    scaffoldBackgroundColor: RaatikTokens.lightCanvas,
    dialogBackgroundColor: Colors.white,
    cardColor: Colors.white,
    hoverColor: const Color(0xFFE2E8F0),
    focusColor: RaatikTokens.primary.withOpacity(0.12),
    colorScheme: const ColorScheme.light(
      primary: RaatikTokens.primary,
      secondary: RaatikTokens.accent,
      error: RaatikTokens.danger,
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
    ),
    appBarTheme: const AppBarTheme(
      shadowColor: Colors.transparent,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
    ),
    dialogTheme: const DialogTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: _radiusLg,
        side: BorderSide(color: Color(0xFFCBD5E1)),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 19, color: Color(0xFF0F172A)),
      titleSmall: TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      bodySmall:
          TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.25),
      bodyMedium:
          TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.25),
      labelLarge: TextStyle(fontSize: 16, color: RaatikTokens.accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _raatikButtonStyle(
        background: RaatikTokens.primary,
        foreground: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, RaatikTokens.minTarget),
        foregroundColor: RaatikTokens.primary,
        side: const BorderSide(color: RaatikTokens.primary),
        shape: const RoundedRectangleBorder(borderRadius: _radiusLg),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, RaatikTokens.minTarget),
        foregroundColor: RaatikTokens.primary,
        shape: const RoundedRectangleBorder(borderRadius: _radiusSm),
      ),
    ),
    inputDecorationTheme: _raatikInputDecorationTheme(
      fill: Colors.white,
      border: Color(0xFFCBD5E1),
      focus: RaatikTokens.primary,
    ),
    checkboxTheme: const CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: _radiusSm),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: _radiusSm),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: _radiusSm,
        side: BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Color(0xFF0F172A),
      unselectedLabelColor: Color(0xFF64748B),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

ThemeData buildRaatikDarkTheme() {
  const surface = Color(0xFF1F2937);
  const border = Color(0xFF374151);

  return ThemeData(
    useMaterial3: false,
    fontFamily: 'IRANSansXFaNum',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RaatikTokens.darkCanvas,
    dialogBackgroundColor: surface,
    cardColor: surface,
    hoverColor: const Color(0xFF374151),
    focusColor: RaatikTokens.accent.withOpacity(0.24),
    colorScheme: const ColorScheme.dark(
      primary: RaatikTokens.primary,
      secondary: RaatikTokens.accent,
      error: RaatikTokens.danger,
      surface: surface,
      onSurface: Color(0xFFE2E8F0),
    ),
    appBarTheme: const AppBarTheme(
      shadowColor: Colors.transparent,
      backgroundColor: RaatikTokens.darkCanvas,
      foregroundColor: Color(0xFFE2E8F0),
      elevation: 0,
    ),
    dialogTheme: const DialogTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: _radiusLg,
        side: BorderSide(color: border),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 19, color: Color(0xFFE2E8F0)),
      titleSmall: TextStyle(fontSize: 14, color: Color(0xFFE2E8F0)),
      bodySmall:
          TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.25),
      bodyMedium:
          TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.25),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: RaatikTokens.accent,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _raatikButtonStyle(
        background: RaatikTokens.accent,
        foreground: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, RaatikTokens.minTarget),
        foregroundColor: Color(0xFFE2E8F0),
        backgroundColor: surface,
        side: const BorderSide(color: border),
        shape: const RoundedRectangleBorder(borderRadius: _radiusLg),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, RaatikTokens.minTarget),
        foregroundColor: Color(0xFFE2E8F0),
        shape: const RoundedRectangleBorder(borderRadius: _radiusSm),
      ),
    ),
    inputDecorationTheme: _raatikInputDecorationTheme(
      fill: surface,
      border: border,
      focus: RaatikTokens.accent,
    ),
    checkboxTheme: const CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: _radiusSm),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: _radiusSm),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: _radiusSm,
        side: BorderSide(color: border),
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Color(0xFFE2E8F0),
      unselectedLabelColor: Color(0xFF94A3B8),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
