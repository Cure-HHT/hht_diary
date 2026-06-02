import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'app_color_scheme.dart';
import 'app_text_theme.dart';
import 'app_theme_extension.dart';
import 'brand_palette.dart';

/// Build the application theme.
///
/// Parameters:
/// - [font]: which font family to render — default Inter. Accessibility variants
///   (Atkinson Hyperlegible, OpenDyslexic) are exposed through the mobile font
///   picker (CUR-528).
/// - [brightness]: light only for now. Passing Brightness.dark returns a minimal
///   dark scheme that mirrors light with brightness flipped, kept alive so the
///   existing mobile dark-mode call sites keep working. A properly-designed dark
///   palette will replace it when designed in Figma.
/// - [brandOverride]: optional sponsor brand palette. When null, Carina-blue
///   defaults are used. Semantic colors (danger/success/warning/info) are NOT
///   overridable — see brand_palette.dart.
ThemeData buildAppTheme({
  AppFontFamily font = AppFontFamily.inter,
  Brightness brightness = Brightness.light,
  BrandPalette? brandOverride,
}) {
  final colorScheme = brightness == Brightness.light
      ? buildAppLightColorScheme(brandOverride: brandOverride)
      : buildAppDarkColorScheme(brandOverride: brandOverride);

  final semanticColors = brightness == Brightness.light
      ? AppSemanticColors.light
      : AppSemanticColors.dark;

  final buttonColors = brightness == Brightness.light
      ? AppButtonColors.light
      : AppButtonColors.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    textTheme: buildAppTextTheme(font),
    extensions: <ThemeExtension<dynamic>>[semanticColors, buttonColors],
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
  );
}
