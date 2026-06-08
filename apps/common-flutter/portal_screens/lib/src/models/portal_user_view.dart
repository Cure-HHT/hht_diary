import 'package:flutter/foundation.dart';

import 'role_assignment_view.dart';
import 'user_status_view.dart';

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
