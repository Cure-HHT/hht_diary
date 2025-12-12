// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';

/// App theme configuration
class AppTheme {
  // Brand colors - calming teal for health/medical app
  static const Color primaryTeal = Color(0xFF0D9488); // teal-600
  static const Color primaryTealDark = Color(0xFF0F766E); // teal-700
  static const Color primaryTealLight = Color(0xFF14B8A6); // teal-500

  // Intensity indicator colors (neutral scale, not alarming)
  static const Color intensityLow = Color(0xFFE0F2FE); // sky-100
  static const Color intensityMedium = Color(0xFFFEF3C7); // amber-100
  static const Color intensityHigh = Color(0xFFFFE4E6); // rose-100

  // Warning/Alert colors
  static const Color warningYellow = Color(0xFFFEF9C3); // yellow-50
  static const Color warningOrange = Color(0xFFFFEDD5); // orange-100
  static const Color infoBlue = Color(0xFFDBEAFE); // blue-100

  /// OpenDyslexic font family name for dyslexia-friendly text
  static const String openDyslexicFontFamily = 'OpenDyslexic';

  /// Get light theme with optional dyslexia-friendly font
  static ThemeData getLightTheme({bool useDyslexicFont = false}) {
    final fontFamily = useDyslexicFont ? openDyslexicFontFamily : null;
    return _buildLightTheme(fontFamily: fontFamily);
  }

  /// Get dark theme with optional dyslexia-friendly font
  static ThemeData getDarkTheme({bool useDyslexicFont = false}) {
    final fontFamily = useDyslexicFont ? openDyslexicFontFamily : null;
    return _buildDarkTheme(fontFamily: fontFamily);
  }

  /// Legacy getter for light theme (without dyslexic font)
  static ThemeData get lightTheme => getLightTheme();

  /// Legacy getter for dark theme (without dyslexic font)
  static ThemeData get darkTheme => getDarkTheme();

  static ThemeData _buildLightTheme({String? fontFamily}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        primary: primaryTeal,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme({String? fontFamily}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.dark,
        primary: primaryTeal,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
