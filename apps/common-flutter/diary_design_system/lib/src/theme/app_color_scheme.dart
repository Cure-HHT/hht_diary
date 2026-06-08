import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import 'brand_palette.dart';

/// Build a Material ColorScheme from the design system tokens.
///
/// Brand-scoped colors (primary, secondary, surface tones) come from the optional
/// [brandOverride]; when null, Carina-blue defaults from ColorTokens are used.
/// Semantic colors (error, success/warning/info via ThemeExtension) are sourced
/// directly from ColorTokens and cannot be overridden — see brand_palette.dart.
ColorScheme buildAppLightColorScheme({BrandPalette? brandOverride}) {
  return ColorScheme(
    brightness: Brightness.light,

    // Brand-scoped (overridable)
    primary: brandOverride?.primary ?? ColorTokens.primary500,
    onPrimary: brandOverride?.onPrimary ?? ColorTokens.neutral0,
    primaryContainer: brandOverride?.primaryContainer ?? ColorTokens.primary100,
    onPrimaryContainer:
        brandOverride?.onPrimaryContainer ?? ColorTokens.primary900,

    secondary: brandOverride?.secondary ?? ColorTokens.primary600,
    onSecondary: brandOverride?.onSecondary ?? ColorTokens.neutral0,
    secondaryContainer:
        brandOverride?.secondaryContainer ?? ColorTokens.primary50,
    onSecondaryContainer:
        brandOverride?.onSecondaryContainer ?? ColorTokens.primary800,

    // Semantic (NOT overridable)
    error: ColorTokens.critical,
    onError: ColorTokens.white,
    errorContainer: ColorTokens.criticalBg,
    onErrorContainer: ColorTokens.criticalDark,

    // Surface scale (neutral; constant)
    surface: ColorTokens.neutral0,
    onSurface: ColorTokens.neutral900,
    surfaceContainerLowest: ColorTokens.neutral0,
    surfaceContainerLow: ColorTokens.neutral50,
    surfaceContainer: ColorTokens.neutral100,
    surfaceContainerHigh: ColorTokens.neutral200,
    surfaceContainerHighest: ColorTokens.neutral300,

    outline: ColorTokens.neutral300,
    outlineVariant: ColorTokens.neutral200,
    // Dark Grey (#54636A) for secondary text — column labels, helper text,
    // disabled labels, etc.
    onSurfaceVariant: ColorTokens.darkGrey,

    shadow: ColorTokens.neutral1000,
    scrim: ColorTokens.neutral1000,

    inverseSurface: ColorTokens.neutral900,
    onInverseSurface: ColorTokens.neutral50,
    inversePrimary: ColorTokens.primary300,
  );
}

/// Minimal dark scheme placeholder.
///
/// Built only so existing mobile dark-mode call sites in clinical_diary keep
/// working through the migration. The design system is light-only by decision
/// for now — this scheme mirrors light with brightness flipped; a proper dark
/// palette will be added when designed in Figma.
ColorScheme buildAppDarkColorScheme({BrandPalette? brandOverride}) {
  return ColorScheme(
    brightness: Brightness.dark,
    primary: brandOverride?.primary ?? ColorTokens.primary300,
    onPrimary: brandOverride?.onPrimary ?? ColorTokens.primary900,
    primaryContainer: brandOverride?.primaryContainer ?? ColorTokens.primary800,
    onPrimaryContainer:
        brandOverride?.onPrimaryContainer ?? ColorTokens.primary100,
    secondary: brandOverride?.secondary ?? ColorTokens.primary400,
    onSecondary: brandOverride?.onSecondary ?? ColorTokens.primary900,
    secondaryContainer:
        brandOverride?.secondaryContainer ?? ColorTokens.primary700,
    onSecondaryContainer:
        brandOverride?.onSecondaryContainer ?? ColorTokens.primary50,
    error: ColorTokens.critical,
    onError: ColorTokens.white,
    errorContainer: ColorTokens.criticalDark,
    onErrorContainer: ColorTokens.criticalBg,
    surface: ColorTokens.neutral900,
    onSurface: ColorTokens.neutral50,
    surfaceContainerLowest: ColorTokens.neutral1000,
    surfaceContainerLow: ColorTokens.neutral900,
    surfaceContainer: ColorTokens.neutral800,
    surfaceContainerHigh: ColorTokens.neutral700,
    surfaceContainerHighest: ColorTokens.neutral600,
    outline: ColorTokens.neutral600,
    outlineVariant: ColorTokens.neutral700,
    shadow: ColorTokens.neutral1000,
    scrim: ColorTokens.neutral1000,
    inverseSurface: ColorTokens.neutral50,
    onInverseSurface: ColorTokens.neutral900,
    inversePrimary: ColorTokens.primary600,
  );
}
