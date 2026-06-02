import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// Theme extension carrying semantic colors that Material's ColorScheme does
/// not model directly — status badges, severity banners, and other non-Material
/// semantic surfaces. Accessed via `Theme.of(context).extension<AppSemanticColors>()`.
///
/// These are NOT sponsor-overridable. "Active green" and "at-risk red" stay
/// constant across the platform for clinical clarity.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  // Status (patient/cycle state)
  final Color statusActive;
  final Color statusAttention;
  final Color statusAtRisk;
  final Color statusNoData;

  // Severity (banners, alerts, callouts)
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  const AppSemanticColors({
    required this.statusActive,
    required this.statusAttention,
    required this.statusAtRisk,
    required this.statusNoData,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
  });

  /// Default light-mode semantic colors, sourced directly from tokens.
  ///
  /// API-level severity names (success/warning/info) map to Figma tokens
  /// (approved/pending/—). "Error" is sourced from `colorScheme.error`, not
  /// from this extension.
  static const AppSemanticColors light = AppSemanticColors(
    statusActive: ColorTokens.statusActive,
    statusAttention: ColorTokens.statusAttention,
    statusAtRisk: ColorTokens.statusAtRisk,
    statusNoData: ColorTokens.statusNoData,
    success: ColorTokens.approved,
    successContainer: ColorTokens.approvedBg,
    warning: ColorTokens.pending,
    warningContainer: ColorTokens.pendingBg,
    info: ColorTokens.info500,
    infoContainer: ColorTokens.info100,
  );

  /// Minimal dark-mode placeholder until a proper dark palette is designed.
  /// Uses the "Dark" Figma variants as approximate container backgrounds.
  static const AppSemanticColors dark = AppSemanticColors(
    statusActive: ColorTokens.approved,
    statusAttention: ColorTokens.pending,
    statusAtRisk: ColorTokens.critical,
    statusNoData: ColorTokens.grey,
    success: ColorTokens.approved,
    successContainer: ColorTokens.approvedDark,
    warning: ColorTokens.pending,
    warningContainer: ColorTokens.pendingDark,
    info: ColorTokens.info500,
    infoContainer: ColorTokens.info100,
  );

  @override
  AppSemanticColors copyWith({
    Color? statusActive,
    Color? statusAttention,
    Color? statusAtRisk,
    Color? statusNoData,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      statusActive: statusActive ?? this.statusActive,
      statusAttention: statusAttention ?? this.statusAttention,
      statusAtRisk: statusAtRisk ?? this.statusAtRisk,
      statusNoData: statusNoData ?? this.statusNoData,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      statusActive: Color.lerp(statusActive, other.statusActive, t)!,
      statusAttention: Color.lerp(statusAttention, other.statusAttention, t)!,
      statusAtRisk: Color.lerp(statusAtRisk, other.statusAtRisk, t)!,
      statusNoData: Color.lerp(statusNoData, other.statusNoData, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

/// Per-state colors for a filled button (primary, destructive).
///
/// Background varies per state, foreground is typically constant (e.g., white
/// on primary). Used by [AppButtonColors.primary] and downstream filled
/// variants. Material 3's automatic state-layer overlay does not reproduce the
/// design system's hand-tuned hover / pressed / disabled tones; this type lets
/// the AppButton resolver source each state's hex from Figma directly.
@immutable
class FilledButtonColors {
  final Color background;
  final Color backgroundHover;
  final Color backgroundPressed;
  final Color backgroundDisabled;
  final Color foreground;

  const FilledButtonColors({
    required this.background,
    required this.backgroundHover,
    required this.backgroundPressed,
    required this.backgroundDisabled,
    required this.foreground,
  });

  FilledButtonColors lerp(FilledButtonColors? other, double t) {
    if (other == null) return this;
    return FilledButtonColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundHover: Color.lerp(backgroundHover, other.backgroundHover, t)!,
      backgroundPressed: Color.lerp(
        backgroundPressed,
        other.backgroundPressed,
        t,
      )!,
      backgroundDisabled: Color.lerp(
        backgroundDisabled,
        other.backgroundDisabled,
        t,
      )!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
    );
  }
}

/// Per-state colors for an outlined button (secondary).
///
/// Background is transparent across all states; border and foreground vary.
/// Used by [AppButtonColors.secondary].
@immutable
class OutlinedButtonColors {
  final Color foreground;
  final Color foregroundHover;
  final Color foregroundPressed;
  final Color foregroundDisabled;
  final Color border;
  final Color borderHover;
  final Color borderPressed;
  final Color borderDisabled;

  const OutlinedButtonColors({
    required this.foreground,
    required this.foregroundHover,
    required this.foregroundPressed,
    required this.foregroundDisabled,
    required this.border,
    required this.borderHover,
    required this.borderPressed,
    required this.borderDisabled,
  });

  OutlinedButtonColors lerp(OutlinedButtonColors? other, double t) {
    if (other == null) return this;
    return OutlinedButtonColors(
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundHover: Color.lerp(foregroundHover, other.foregroundHover, t)!,
      foregroundPressed: Color.lerp(
        foregroundPressed,
        other.foregroundPressed,
        t,
      )!,
      foregroundDisabled: Color.lerp(
        foregroundDisabled,
        other.foregroundDisabled,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      borderPressed: Color.lerp(borderPressed, other.borderPressed, t)!,
      borderDisabled: Color.lerp(borderDisabled, other.borderDisabled, t)!,
    );
  }
}

/// Theme extension carrying per-variant per-state button colors.
///
/// `AppButton` resolves background, foreground, and border from this extension
/// via `WidgetStateProperty.resolveWith` so Figma's explicit per-state hexes
/// are rendered exactly, not approximated by Material's auto state-layer
/// overlay.
///
/// Phase 3 iteration: [primary] and [secondary] wired here. Tertiary uses
/// theme primary directly; destructive uses `colorScheme.error` with Material
/// state layers until per-state destructive hexes are defined in Figma.
@immutable
class AppButtonColors extends ThemeExtension<AppButtonColors> {
  final FilledButtonColors primary;
  final OutlinedButtonColors secondary;

  const AppButtonColors({required this.primary, required this.secondary});

  /// Default light-mode button colors, sourced from tokens.
  static const AppButtonColors light = AppButtonColors(
    primary: FilledButtonColors(
      background: ColorTokens.primary,
      backgroundHover: ColorTokens.primaryHover,
      backgroundPressed: ColorTokens.primaryPressed,
      backgroundDisabled: ColorTokens.primaryDisabled,
      foreground: ColorTokens.white,
    ),
    secondary: OutlinedButtonColors(
      foreground: ColorTokens.darkGrey,
      foregroundHover: ColorTokens.darkGrey,
      foregroundPressed: ColorTokens.primaryPressed,
      foregroundDisabled: ColorTokens.lightGray,
      border: ColorTokens.lightGray,
      borderHover: ColorTokens.darkGrey,
      borderPressed: ColorTokens.darkGrey,
      borderDisabled: ColorTokens.grey,
    ),
  );

  /// Minimal dark-mode placeholder — mirrors light until a dark palette lands.
  static const AppButtonColors dark = light;

  @override
  AppButtonColors copyWith({
    FilledButtonColors? primary,
    OutlinedButtonColors? secondary,
  }) {
    return AppButtonColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
    );
  }

  @override
  AppButtonColors lerp(ThemeExtension<AppButtonColors>? other, double t) {
    if (other is! AppButtonColors) return this;
    return AppButtonColors(
      primary: primary.lerp(other.primary, t),
      secondary: secondary.lerp(other.secondary, t),
    );
  }
}
