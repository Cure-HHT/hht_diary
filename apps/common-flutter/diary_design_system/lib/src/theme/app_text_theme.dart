import 'package:flutter/material.dart';

import '../tokens/typography_tokens.dart';

/// Supported font families.
///
/// - [inter]: default. Variable font bundled with `diary_design_system`.
/// - [atkinsonHyperlegible] and [openDyslexic]: mobile-only accessibility options
///   exposed through the font picker (CUR-528). Their assets live in
///   `clinical_diary`'s own pubspec — the portal does not bundle them (saves
///   5–15 MB of font assets the portal never renders). These families resolve
///   in any binary that declares the assets; selecting them from the portal
///   would silently fall back to Inter.
///
/// The per-family [package] field is what makes this work: it's the package
/// argument Flutter uses to resolve `fontFamily` lookups. `'diary_design_system'`
/// scopes the lookup to fonts declared in this package's pubspec; `null` falls
/// through to the binary's global font registry (where `clinical_diary`'s own
/// declarations live).
enum AppFontFamily {
  inter('Inter', 'diary_design_system'),
  atkinsonHyperlegible('AtkinsonHyperlegible', null),
  openDyslexic('OpenDyslexic', null);

  final String familyName;
  final String? package;
  const AppFontFamily(this.familyName, this.package);
}

/// Build a Material TextTheme using the chosen font family.
///
/// The explicit `['Inter']` fallback chain matters: Flutter silently substitutes
/// the platform default font (.SF on iOS, Roboto on Android) when an asset
/// fails to load. In a clinical app where text-rendering bugs can mask data,
/// an explicit fallback to Inter keeps the failure mode predictable.
TextTheme buildAppTextTheme(AppFontFamily family) {
  return _baseTextTheme.apply(
    fontFamily: family.familyName,
    fontFamilyFallback: const ['Inter'],
    package: family.package,
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
