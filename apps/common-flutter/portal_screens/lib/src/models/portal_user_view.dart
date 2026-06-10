import 'package:flutter/foundation.dart';

import 'portal_role.dart';
import 'role_assignment_view.dart';
import 'user_status_view.dart';

/// The Users-table row-visibility rule for operator-tier accounts:
/// an account whose KNOWN roles are exactly {SystemOperator} is visible
/// only when the viewer's active role is SystemOperator. A SysOp who
/// also holds a regular role stays visible to everyone — rendered
/// normally, SysOp badge included.
///
/// Accounts with NO known roles are never hidden: role data flows from a
/// separately-gated `user_role_scopes` subscription, so an empty role set
/// usually means "assignments not visible to this viewer", and hiding the
/// whole directory on missing data would be wrong. This is a PRESENTATION
/// rule layered over the server's action-level operator-tier enforcement
/// (DIARY-DEV-operator-tier-authz) — the rows still reach any client
/// holding the users-view permission.
///
/// SPEC GAP: DIARY-DEV-operator-tier-authz's assertions cover only the
/// tier projection and Action authorization, not row VISIBILITY; this
/// rule needs a GUI/DEV assertion of its own (flagged per convention
/// rather than minted ad hoc — CUR-1483).
List<PortalUserView> visibleUserRows({
  required List<PortalUserView> users,
  required bool viewerIsOperator,
}) {
  if (viewerIsOperator) return users;
  return users
      .where((u) {
        final roles = u.distinctRoles;
        final sysOpOnly =
            roles.isNotEmpty &&
            roles.every((r) => r == PortalRole.systemOperator.systemName);
        return !sysOpOnly;
      })
      .toList(growable: false);
}

/// One row in the User Management table.
///
/// Snapshot value type — built fresh by the wiring layer on each
/// `users_index` projection emission and handed to `UsersScreen`. Owns its
/// own data; no dependency on event_sourcing or reaction_widgets types.
@immutable
class PortalUserView {
  /// The user's email. Also acts as the aggregate id in `users_index`
  /// (matches how the legacy `_UserRow.fromRow` reads it).
  final String email;

  /// Display name. Falls back to '—' in fixtures for users without one.
  final String name;

  /// Current account lifecycle state.
  final UserStatusView status;

  /// All `(role, scope)` assignments currently bound to the user. Empty
  /// when the user has no role yet (e.g. a freshly-invited pending user).
  final List<RoleAssignmentView> assignments;

  const PortalUserView({
    required this.email,
    required this.name,
    required this.status,
    required this.assignments,
  });

  /// Deduplicated role names for the table's "Roles" badges. Two
  /// assignments to the same role with different scopes collapse to one
  /// badge (Q4a in the plan). Insertion-ordered.
  List<String> get distinctRoles {
    final seen = <String>{};
    final out = <String>[];
    for (final a in assignments) {
      if (seen.add(a.role)) out.add(a.role);
    }
    return out;
  }

  /// Concrete site IDs across all assignments. Wildcard assignments
  /// contribute zero — the row label is "All sites" in that case, surfaced
  /// via [hasWildcardScope]. Order is whatever the assignments produced.
  List<String> get boundSites =>
      assignments.expand((a) => a.boundSites).toList(growable: false);

  /// True when any assignment has a wildcard scope (all-sites or
  /// everything). UI should render "All sites" rather than the
  /// [boundSites] count when this is set.
  bool get hasWildcardScope => assignments.any((a) => a.isWildcard);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortalUserView &&
          email == other.email &&
          name == other.name &&
          status == other.status &&
          listEquals(assignments, other.assignments);

  @override
  int get hashCode =>
      Object.hash(email, name, status, Object.hashAll(assignments));

  @override
  String toString() =>
      'PortalUserView(email: $email, name: $name, '
      'status: $status, assignments: $assignments)';
}
