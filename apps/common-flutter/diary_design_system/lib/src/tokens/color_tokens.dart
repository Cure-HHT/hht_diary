import 'package:flutter/material.dart';

/// Raw color tokens — the lowest layer of the design system.
///
/// **Two categories:**
/// - **Brand** tokens (primary, secondary, neutral) — overridable per sponsor
///   via BrandPalette at theme-build time.
/// - **Semantic** tokens (danger, success, warning, info) — NOT overridable.
///   "Red means error" is universal and FDA-auditable.
///
/// Components consume the resolved theme (Theme.of(context)), not these
/// constants directly. Importing this file outside src/theme/ is forbidden.
///
/// TODO(CUR-1426): Reconcile each value against the Figma UI Kit color palette
/// (file qWMfvnr455NSByXqsDcok7, node 54:9692). Some shades below are placeholders
/// based on the existing portal teal/Carina blue; the explicit Figma palette has
/// not yet been audited frame-by-frame.
class ColorTokens {
  ColorTokens._();

  // ---------------------------------------------------------------------------
  // Brand — Carina blue (default; sponsor overrides via BrandPalette)
  // ---------------------------------------------------------------------------
  static const Color primary50 = Color(0xFFE6F3FB);
  static const Color primary100 = Color(0xFFC0E0F4);
  static const Color primary200 = Color(0xFF96CCEC);
  static const Color primary300 = Color(0xFF6BB8E3);
  static const Color primary400 = Color(0xFF4AA9DC);
  static const Color primary500 = Color(0xFF0175C2); // Carina blue
  static const Color primary600 = Color(0xFF016BB5);
  static const Color primary700 = Color(0xFF015FA4);
  static const Color primary800 = Color(0xFF015393);
  static const Color primary900 = Color(0xFF013D74);

  // ---------------------------------------------------------------------------
  // Neutral — grayscale (overridable as part of BrandPalette, but rarely changed)
  // ---------------------------------------------------------------------------
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral900 = Color(0xFF171717);
  static const Color neutral1000 = Color(0xFF000000);

  // ---------------------------------------------------------------------------
  // Semantic — universal across sponsors. NOT overridable.
  // ---------------------------------------------------------------------------
  static const Color danger50 = Color(0xFFFEF2F2);
  static const Color danger100 = Color(0xFFFEE2E2);
  static const Color danger500 = Color(0xFFDC2626);
  static const Color danger600 = Color(0xFFB91C1C);
  static const Color danger700 = Color(0xFF991B1B);

  static const Color success50 = Color(0xFFF0FDF4);
  static const Color success100 = Color(0xFFDCFCE7);
  static const Color success500 = Color(0xFF16A34A);
  static const Color success600 = Color(0xFF15803D);
  static const Color success700 = Color(0xFF166534);

  static const Color warning50 = Color(0xFFFFFBEB);
  static const Color warning100 = Color(0xFFFEF3C7);
  static const Color warning500 = Color(0xFFD97706);
  static const Color warning600 = Color(0xFFB45309);
  static const Color warning700 = Color(0xFF92400E);

  static const Color info50 = Color(0xFFEFF6FF);
  static const Color info100 = Color(0xFFDBEAFE);
  static const Color info500 = Color(0xFF2563EB);
  static const Color info600 = Color(0xFF1D4ED8);
  static const Color info700 = Color(0xFF1E40AF);

  // ---------------------------------------------------------------------------
  // Status — for patient/cycle state badges. NOT overridable.
  // ---------------------------------------------------------------------------
  static const Color statusActive = success500;
  static const Color statusAttention = warning500;
  static const Color statusAtRisk = danger500;
  static const Color statusNoData = neutral400;
}
