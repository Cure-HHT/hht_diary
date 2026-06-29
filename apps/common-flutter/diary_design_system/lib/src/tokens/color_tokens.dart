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
/// TODO(CUR-1426): Reconcile remaining values against the Figma UI Kit color
/// palette (file qWMfvnr455NSByXqsDcok7, node 54:9692). Primary state tokens
/// below were confirmed against Figma in Phase 3 iteration; secondary state
/// tokens and the full neutral/semantic palettes still pending audit.
class ColorTokens {
  ColorTokens._();

  // ---------------------------------------------------------------------------
  // Brand — primary (default; sponsor overrides via BrandPalette)
  //
  // Named state tokens are confirmed against Figma. The chromatic ladder
  // (primary50–900) is kept for surface tints / containers but the live button
  // states use the four named tokens below, not the ladder.
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF165C7D);
  static const Color primaryHover = Color(0xFF4094BC);
  static const Color primaryPressed = Color(0xFF0F425A);
  static const Color primaryDisabled = Color(0xFFE8F3F7);

  // Chromatic ladder — used for surface tints / Material container slots.
  // Realigned around the confirmed primary; intermediate shades remain
  // estimated and will be tightened when the full Figma palette is audited.
  static const Color primary50 = primaryDisabled;
  static const Color primary100 = Color(0xFFCFE3EC);
  static const Color primary200 = Color(0xFFA8CBDC);
  static const Color primary300 = Color(0xFF7AB1C9);
  static const Color primary400 = primaryHover;
  static const Color primary500 = primary;
  static const Color primary600 = Color(0xFF124F6C);
  static const Color primary700 = primaryPressed;
  static const Color primary800 = Color(0xFF093047);
  static const Color primary900 = Color(0xFF051F2F);

  // ---------------------------------------------------------------------------
  // Page background — light wash used for app shells.
  // ---------------------------------------------------------------------------
  static const Color primaryBg = Color(0xFFF7FAFB); // Figma: Primary Bg

  // ---------------------------------------------------------------------------
  // Neutrals — confirmed against Figma.
  // ---------------------------------------------------------------------------
  static const Color black = Color(0xFF04161E); // Figma: Black
  static const Color darkGrey = Color(0xFF54636A); // Figma: Dark Grey
  static const Color grey = Color(0xFFA4B9C2); // Figma: Grey
  static const Color lightGray = Color(0xFFECEEF0); // Figma: Light Gray
  static const Color white = Color(0xFFFFFFFF); // Figma: White

  // Legacy chromatic ladder — preserved for Material slots that still want
  // intermediate steps. Endpoints anchor on Figma named neutrals; intermediate
  // shades stay as estimates until / unless Figma defines them.
  static const Color neutral0 = white;
  static const Color neutral50 = primaryBg;
  static const Color neutral100 = lightGray;
  static const Color neutral200 = Color(0xFFDDE2E5);
  static const Color neutral300 = grey;
  static const Color neutral400 = Color(0xFF8597A0);
  static const Color neutral500 = Color(0xFF67767E);
  static const Color neutral600 = darkGrey;
  static const Color neutral700 = Color(0xFF38474E);
  static const Color neutral800 = Color(0xFF1E2C32);
  static const Color neutral900 = black;
  static const Color neutral1000 = Color(0xFF000000);

  // ---------------------------------------------------------------------------
  // Semantic — universal across sponsors. NOT overridable.
  //
  // Token names use technical severity (critical/pending/approved/info); these
  // map to Figma names in comments. Consumers reach them through
  // AppSemanticColors with API-level severity names (success/warning/error/info).
  // ---------------------------------------------------------------------------
  static const Color critical = Color(0xFFCB333B); // Figma: Critical (error)
  static const Color criticalDark = Color(0xFFB42B33); // Figma: Critical Dark
  static const Color criticalBg = Color(0xFFFDEBEC); // Figma: Critical Bg

  static const Color pending = Color(0xFF8A5A00); // Figma: Pending (warning)
  static const Color pendingDark = Color(0xFF6F4600); // Figma: Pending Dark
  static const Color pendingBg = Color(0xFFFFF5DE); // Figma: Pending Bg

  static const Color approved = Color(0xFF1E7A51); // Figma: Approved (success)
  static const Color approvedDark = Color(0xFF16613F); // Figma: Approved Dark
  static const Color approvedBg = Color(0xFFEAF7F1); // Figma: Approved Bg

  // Info — Figma did NOT define info colors. Placeholders retained until/unless
  // a Figma decision lands. Banners with severity: info render with these.
  // TODO(CUR-1426): confirm or remove the info severity once Figma decides.
  static const Color info500 = Color(0xFF2563EB);
  static const Color info100 = Color(0xFFDBEAFE);

  // ---------------------------------------------------------------------------
  // Status — for patient/cycle state badges. NOT overridable.
  // Each maps to the Figma severity color of the same semantic.
  // ---------------------------------------------------------------------------
  static const Color statusActive = Color(
    0xFF16613F,
  ); // Figma: Approved Dark (status text + dot)
  static const Color statusAttention = Color(0xFFB9790A); // Figma: Pending Dark
  static const Color statusAtRisk = Color(0xFFA52A31); // Figma: Critical Dark
  static const Color statusNoData = grey;
}
