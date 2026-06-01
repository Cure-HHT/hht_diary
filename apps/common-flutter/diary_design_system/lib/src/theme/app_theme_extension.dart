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
  static const AppSemanticColors light = AppSemanticColors(
    statusActive: ColorTokens.statusActive,
    statusAttention: ColorTokens.statusAttention,
    statusAtRisk: ColorTokens.statusAtRisk,
    statusNoData: ColorTokens.statusNoData,
    success: ColorTokens.success500,
    successContainer: ColorTokens.success100,
    warning: ColorTokens.warning500,
    warningContainer: ColorTokens.warning100,
    info: ColorTokens.info500,
    infoContainer: ColorTokens.info100,
  );

  /// Minimal dark-mode placeholder until a proper dark palette is designed.
  static const AppSemanticColors dark = AppSemanticColors(
    statusActive: ColorTokens.success500,
    statusAttention: ColorTokens.warning500,
    statusAtRisk: ColorTokens.danger500,
    statusNoData: ColorTokens.neutral500,
    success: ColorTokens.success500,
    successContainer: ColorTokens.success700,
    warning: ColorTokens.warning500,
    warningContainer: ColorTokens.warning700,
    info: ColorTokens.info500,
    infoContainer: ColorTokens.info700,
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
