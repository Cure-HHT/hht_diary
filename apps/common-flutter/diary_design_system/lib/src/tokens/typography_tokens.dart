import 'package:flutter/material.dart';

/// Typography scale tokens — weights and sizes.
///
/// The font *family* is not a token; it's selected per-theme via AppFontFamily
/// (see app_text_theme.dart). These tokens define what the type scale looks like
/// regardless of which family is bound at build time.
///
/// TODO(CUR-1426): Reconcile against Figma UI Kit type styles.
class TypographyTokens {
  TypographyTokens._();

  // Weights
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Sizes (logical pixels)
  static const double displayLarge = 57;
  static const double displayMedium = 45;
  static const double displaySmall = 36;

  static const double headlineLarge = 32;
  static const double headlineMedium = 28;
  static const double headlineSmall = 24;

  static const double titleLarge = 22;
  static const double titleMedium = 16;
  static const double titleSmall = 14;

  static const double bodyLarge = 16;
  static const double bodyMedium = 14;
  static const double bodySmall = 12;

  static const double labelLarge = 14;
  static const double labelMedium = 12;
  static const double labelSmall = 11;

  // Line heights (multipliers)
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightLoose = 1.6;
}
