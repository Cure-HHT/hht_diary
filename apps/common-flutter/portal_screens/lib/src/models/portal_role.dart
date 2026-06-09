import 'package:diary_design_system/diary_design_system.dart';

/// Catalog of portal roles, with their canonical display label and badge
/// tone.
///
/// Two-layer naming, mirrors how `portal-ui` separates concerns:
///
/// - [systemName] is the canonical, sponsor-independent identifier stored
///   by the backend on `user_role_scopes.role` and surfaced on
///   `users_index` rows. Never changes per tenant.
/// - [canonicalDisplayName] is the **fallback** human label, used when
///   the wiring layer doesn't have a sponsor mapping to apply. Sponsors
///   can override it: `portal-ui`'s `AuthService.sponsorRoleName(...)`
///   reads from `sponsor_role_mapping`, and consumers pass the mapped
///   string to [RolePill.displayName]. We don't bake those overrides
///   here because they're per-tenant configuration, not a design system
///   decision.
/// - [tone] IS a design system decision (red = privileged, blue = clinical
///   workflow, gray = read-mostly, amber = above-admin) and stays on the
///   enum. Sponsors can rename a role; they don't get to recolor it.
///
/// To add a new role: add a value here, no other code change needed —
/// [RolePill] resolves automatically.
enum PortalRole {
  /// Full administrative access. Wildcard scope.
  administrator(
    systemName: 'Administrator',
    canonicalDisplayName: 'Admin',
    tone: AppBadgeTone.danger,
  ),

  /// Per-site clinical workflow operator. Sponsors may still override
  /// the label per-tenant (e.g. "Investigator").
  studyCoordinator(
    systemName: 'StudyCoordinator',
    canonicalDisplayName: 'Study Coordinator',
    tone: AppBadgeTone.primary,
  ),

  /// Clinical Research Associate — read-mostly review role.
  cra(
    systemName: 'CRA',
    canonicalDisplayName: 'CRA',
    tone: AppBadgeTone.neutral,
  ),

  /// Operator role above Admin — system-level lifecycle. Tentative
  /// warning tone pending a Figma showing the pill explicitly (tracked
  /// in the redesign plan §6 risks).
  systemOperator(
    systemName: 'SystemOperator',
    canonicalDisplayName: 'System Operator',
    tone: AppBadgeTone.warning,
  );

  const PortalRole({
    required this.systemName,
    required this.canonicalDisplayName,
    required this.tone,
  });

  /// Value the backend stores. Used for equality round-trips with the
  /// projection row and for [fromSystemName] lookup.
  final String systemName;

  /// Display label used when no sponsor mapping is available. Sponsors
  /// can override by passing a different string to [RolePill.displayName].
  final String canonicalDisplayName;

  /// Badge tone for [RolePill] and any other chip rendering of this role.
  /// Not sponsor-overridable.
  final AppBadgeTone tone;

  /// Resolve a raw system-name string to its [PortalRole], or null when
  /// the string is unknown to the catalog. Unknown roles render via
  /// [RolePill] as a neutral pill with the raw string preserved as the
  /// label — so an out-of-date catalog never blanks the UI.
  static PortalRole? fromSystemName(String name) {
    for (final r in values) {
      if (r.systemName == name) return r;
    }
    return null;
  }
}
