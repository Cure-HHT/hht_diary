import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// App theme configuration
// Implements: DIARY-PRD-mobile-offline-first/A+B+C
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
  @Deprecated('Use fontFamilyName instead')
  static const String openDyslexicFontFamily = 'OpenDyslexic';

  /// CUR-528: Atkinson Hyperlegible font family name
  static const String atkinsonHyperlegibleFontFamily = 'AtkinsonHyperlegible';

  /// Get light theme with optional dyslexia-friendly font
  @Deprecated('Use getLightThemeWithFont instead')
  static ThemeData getLightTheme({bool useDyslexicFont = false}) {
    // ignore: deprecated_member_use_from_same_package
    final fontFamily = useDyslexicFont ? openDyslexicFontFamily : null;
    return _buildLightTheme(fontFamily: fontFamily);
  }

  /// Get dark theme with optional dyslexia-friendly font
  @Deprecated('Use getDarkThemeWithFont instead')
  static ThemeData getDarkTheme({bool useDyslexicFont = false}) {
    // ignore: deprecated_member_use_from_same_package
    final fontFamily = useDyslexicFont ? openDyslexicFontFamily : null;
    return _buildDarkTheme(fontFamily: fontFamily);
  }

  /// CUR-528: Get light theme with selected font
  /// Pass 'Roboto' or null for default, 'OpenDyslexic', or 'AtkinsonHyperlegible'
  static ThemeData getLightThemeWithFont({String? fontFamily}) {
    // 'Roboto' uses system default (null), others use their font family name
    final effectiveFontFamily = (fontFamily == null || fontFamily == 'Roboto')
        ? null
        : fontFamily;
    return _buildLightTheme(fontFamily: effectiveFontFamily);
  }

  /// CUR-528: Get dark theme with selected font
  /// Pass 'Roboto' or null for default, 'OpenDyslexic', or 'AtkinsonHyperlegible'
  static ThemeData getDarkThemeWithFont({String? fontFamily}) {
    // 'Roboto' uses system default (null), others use their font family name
    final effectiveFontFamily = (fontFamily == null || fontFamily == 'Roboto')
        ? null
        : fontFamily;
    return _buildDarkTheme(fontFamily: effectiveFontFamily);
  }

  /// Page background — soft grey behind white cards, matching the Figma
  /// "Sponsor Portal UI Pack" home screen.
  static const Color pageBackgroundLight = Color(0xFFF4F6F8);

  /// Row surface for "No records" / neutral data rows — Figma "Primary Bg"
  /// (`#F7FAFB`). Drives `colorScheme.surfaceContainerLow`, which the DS
  /// [EventListItem] resolves for both empty-state and finalised rows so the
  /// two share one pale surface (only the left accent + glyph differ).
  static const Color rowSurfaceLight = Color(0xFFF7FAFB);

  static ThemeData _buildLightTheme({String? fontFamily}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      // Register the design-system theme extensions so DS widgets (AppBanner,
      // AppAlertRow, AppButton, AppExpansionTile, ...) can resolve their
      // semantic/button colors. Without this, `theme.extension<AppSemanticColors>()!`
      // inside those widgets blows up with a null-check error at first paint.
      extensions: const <ThemeExtension<dynamic>>[
        AppSemanticColors.light,
        AppButtonColors.light,
      ],
      // Grey page bg with white cards — Figma "Your Records" pattern. AppCard
      // and other DS surfaces read `colorScheme.surface`, so we force it to
      // pure white here rather than the seed-tinted off-white the M3 generator
      // returns; the page bg goes to `scaffoldBackgroundColor` below.
      scaffoldBackgroundColor: pageBackgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        primary: primaryTeal,
        surface: Colors.white,
        surfaceContainerLow: rowSurfaceLight,
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
      extensions: const <ThemeExtension<dynamic>>[
        AppSemanticColors.dark,
        AppButtonColors.dark,
      ],
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
