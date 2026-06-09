// Implements: DIARY-GUI-role-switching/E+F — the home shell shows only the nav
//   sections the ACTIVE role may use. This module holds the widget-free gating
//   decision (which sections are visible, which is selected) so it is unit-
//   testable without a reaction scope; the widget layer (app.dart) supplies the
//   per-section icon + builder.

/// One nav section's gating spec: its display [label] and the permission its
/// screen self-gates on (the SAME name passed to that screen's `PermissionGate`,
/// so nav visibility and per-screen access never disagree).
class NavSectionSpec {
  const NavSectionSpec({required this.label, required this.permission});
  final String label;
  final String permission;
}

/// The portal's nav sections in display order. The permission of each MUST match
/// the constant its screen passes to `PermissionGate`. Reads are modeled as
/// Actions (CUR-1474): each section/screen gates on the Action permission that
/// governs its data, not a `view:<projection>` name.
///   User Accounts -> users_screen_binding.dart `portal.user.view_accounts`
///   Sites         -> sites_screen.dart         `portal.site.view`
///   Participants  -> participants_screen.dart  `portal.participant.view`
///   RAVE Sync     -> rave_sync_screen.dart     `portal.rave.view_sync`
///   Audit Log     -> audit_log_screen.dart     `portal.audit.view`
const List<NavSectionSpec> kNavSections = <NavSectionSpec>[
  NavSectionSpec(
    label: 'User Accounts',
    permission: 'portal.user.view_accounts',
  ),
  NavSectionSpec(label: 'Audit Log', permission: 'portal.audit.view'),
];

/// The sections (in order) a role holding [held] permission names may use. A
/// hidden section's screen is never built, so it never opens a denied
/// subscription.
List<NavSectionSpec> visibleSections(Set<String> held) => <NavSectionSpec>[
  for (final s in kNavSections)
    if (held.contains(s.permission)) s,
];

/// Resolves the selected index within [visible]: the index of [selectedLabel] if
/// still visible, else 0 (so a role switch that hides the current section falls
/// back to the first visible one). Returns -1 when nothing is visible.
int resolveSelectedIndex(List<NavSectionSpec> visible, String? selectedLabel) {
  if (visible.isEmpty) return -1;
  final i = visible.indexWhere((s) => s.label == selectedLabel);
  return i >= 0 ? i : 0;
}
