import 'package:flutter/material.dart';

import '../tokens/typography_tokens.dart';

/// Supported font families.
///
/// - [inter]: default. Variable font bundled with diary_design_system.
/// - [atkinsonHyperlegible] and [openDyslexic]: accessibility options exposed
///   through the mobile font picker (CUR-528). Their assets currently live in
///   clinical_diary's pubspec; they will be relocated into diary_design_system
///   in Phase 1b. Until then, these enum values resolve only when used from
///   clinical_diary (which still declares the assets in its own pubspec).
enum AppFontFamily {
  inter('Inter'),
  atkinsonHyperlegible('AtkinsonHyperlegible'),
  openDyslexic('OpenDyslexic');

  final String familyName;
  const AppFontFamily(this.familyName);
}

/// Build a Material TextTheme using the chosen font family.
///
/// The explicit ['Inter'] fallback chain matters: Flutter silently substitutes
/// the platform default font (.SF on iOS, Roboto on Android) when an asset
/// fails to load. In a clinical app where text-rendering bugs can mask data,
/// an explicit fallback to Inter keeps the failure mode predictable.
TextTheme buildAppTextTheme(AppFontFamily family) {
  return _baseTextTheme.apply(
    fontFamily: family.familyName,
    fontFamilyFallback: const ['Inter'],
    package: 'diary_design_system',
  );
}

const TextTheme _baseTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontSize: TypographyTokens.displayLarge,
    fontWeight: TypographyTokens.regular,
    height: TypographyTokens.lineHeightTight,
  ),
  displayMedium: TextStyle(
    fontSize: TypographyTokens.displayMedium,
    fontWeight: TypographyTokens.regular,
    height: TypographyTokens.lineHeightTight,
  ),
  displaySmall: TextStyle(
    fontSize: TypographyTokens.displaySmall,
    fontWeight: TypographyTokens.regular,
    height: TypographyTokens.lineHeightTight,
  ),
  headlineLarge: TextStyle(
    fontSize: TypographyTokens.headlineLarge,
    fontWeight: TypographyTokens.semiBold,
    height: TypographyTokens.lineHeightTight,
  ),
  headlineMedium: TextStyle(
    fontSize: TypographyTokens.headlineMedium,
    fontWeight: TypographyTokens.semiBold,
    height: TypographyTokens.lineHeightTight,
  ),
  headlineSmall: TextStyle(
    fontSize: TypographyTokens.headlineSmall,
    fontWeight: TypographyTokens.semiBold,
    height: TypographyTokens.lineHeightTight,
  ),
  titleLarge: TextStyle(
    fontSize: TypographyTokens.titleLarge,
    fontWeight: TypographyTokens.semiBold,
    height: TypographyTokens.lineHeightNormal,
  ),
  titleMedium: TextStyle(
    fontSize: TypographyTokens.titleMedium,
    fontWeight: TypographyTokens.semiBold,
    height: TypographyTokens.lineHeightNormal,
  ),
  titleSmall: TextStyle(
    fontSize: TypographyTokens.titleSmall,
    fontWeight: TypographyTokens.medium,
    height: TypographyTokens.lineHeightNormal,
  ),
  bodyLarge: TextStyle(
    fontSize: TypographyTokens.bodyLarge,
    fontWeight: TypographyTokens.regular,
    height: TypographyTokens.lineHeightNormal,
  ),
  bodyMedium: TextStyle(
    fontSize: TypographyTokens.bodyMedium,
    fontWeight: TypographyTokens.regular,
    height: TypographyTokens.lineHeightNormal,
  ),
  bodySmall: TextStyle(
    fontSize: TypographyTokens.bodySmall,
    fontWeight: TypographyTokens.regular,
    height: TypographyTokens.lineHeightNormal,
  ),
  labelLarge: TextStyle(
    fontSize: TypographyTokens.labelLarge,
    fontWeight: TypographyTokens.medium,
    height: TypographyTokens.lineHeightNormal,
  ),
  labelMedium: TextStyle(
    fontSize: TypographyTokens.labelMedium,
    fontWeight: TypographyTokens.medium,
    height: TypographyTokens.lineHeightNormal,
  ),
  labelSmall: TextStyle(
    fontSize: TypographyTokens.labelSmall,
    fontWeight: TypographyTokens.medium,
    height: TypographyTokens.lineHeightNormal,
  ),
);
