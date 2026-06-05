import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/portal_role.dart';

/// A role-coloured chip used across the portal — the AppBar role switcher
/// and the Users table's "Roles" column both render through this.
///
/// Thin wrapper around [AppBadge] that owns the portal-specific
/// resolution: takes a backend-canonical [systemRole] string, looks up
/// the right tone via [PortalRole.fromSystemName], and either uses the
/// caller-supplied [displayName] (sponsor-mapped label) or falls back to
/// the enum's canonical label.
///
/// Fallback policy:
///
/// | `systemRole` in catalog? | `displayName` set?  | Renders                              |
/// | ------------------------ | ------------------- | ------------------------------------ |
/// | yes                      | yes                 | sponsor label, role tone             |
/// | yes                      | no                  | canonical label, role tone           |
/// | no                       | yes                 | sponsor label, neutral tone          |
/// | no                       | no                  | raw [systemRole], neutral tone       |
///
/// An unknown role never blanks — the worst case still shows the raw
/// backend string, so a projection drift between server and client is
/// visible rather than silently hidden.
class RolePill extends StatelessWidget {
  const RolePill({
    super.key,
    required this.systemRole,
    this.displayName,
    this.variant = AppBadgeVariant.tinted,
    this.trailing,
    this.onTap,
  });

  /// Backend-canonical role identifier (e.g. `Administrator`,
  /// `StudyCoordinator`, `CRA`). Required because it's the contract
  /// with the data layer — display labels are negotiated separately.
  final String systemRole;

  /// Sponsor-mapped human label, when the wiring layer has a mapping
  /// available (see `portal-ui`'s `AuthService.sponsorRoleName`). When
  /// null, falls back to [PortalRole.canonicalDisplayName] or the raw
  /// [systemRole] string.
  final String? displayName;

  /// Forwarded to [AppBadge.variant]. Defaults to [AppBadgeVariant.tinted]
  /// — the soft-fill shape the AppBar's role switcher uses (light pink
  /// "Admin" chip with dark-red border + label, etc.). Pass
  /// [AppBadgeVariant.outlined] for the Users-table rows where the chip
  /// sits over a white card and the heavier outlined treatment reads
  /// better.
  final AppBadgeVariant variant;

  /// Forwarded to [AppBadge.trailing]. Used by the AppBar's multi-role
  /// switcher to drop a dropdown caret inside the pill.
  final Widget? trailing;

  /// Forwarded to [AppBadge.onTap]. Null → passive label (table cells,
  /// single-role variants). Non-null → tappable pill.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final role = PortalRole.fromSystemName(systemRole);
    final label = displayName ?? role?.canonicalDisplayName ?? systemRole;
    final tone = role?.tone ?? AppBadgeTone.neutral;
    return AppBadge(
      label: label,
      variant: variant,
      tone: tone,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
