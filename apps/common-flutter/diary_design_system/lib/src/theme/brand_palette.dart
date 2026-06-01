import 'package:flutter/material.dart';

/// Sponsor-specific brand color overrides.
///
/// Passed to buildAppTheme(brandOverride:) to replace the default Carina-blue
/// brand tokens in the resulting ColorScheme. Semantic colors (danger, success,
/// warning, info, status badges) are NOT overridable and stay constant across
/// sponsors — "red means error" is universal.
///
/// Sourced at runtime from the backend's sponsor branding endpoint (see
/// SponsorBrandingConfig in sponsor_branding_service.dart). The endpoint
/// extension to carry palette is tracked separately from this design system
/// work; until it lands, all sponsors render with the default Carina palette.
@immutable
class BrandPalette {
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  const BrandPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
  });
}
