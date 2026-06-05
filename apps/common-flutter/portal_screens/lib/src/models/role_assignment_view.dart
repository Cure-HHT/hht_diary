import 'package:flutter/foundation.dart';

/// One `(role, scope)` assignment a portal user carries.
///
/// The backend models scope as a sealed type
/// (`BoundScope` / `ValueWildcardScope` / `TotalWildcardScope`), but the UI
/// only needs two things:
///
/// - the **bound site IDs** for the "N sites assigned" count column, and
/// - a flag telling us this is a **wildcard** ("all sites" / "everything")
///   so we can render it as "All sites" or similar rather than as zero.
///
/// The wiring layer collapses the sealed scope into one of these two shapes
/// when mapping a `user_role_scopes` row.
@immutable
class RoleAssignmentView {
  /// System role name (e.g. `Administrator`, `StudyCoordinator`, `CRA`).
  /// Carries the value the backend stores; display-side prettification
  /// happens at render time.
  final String role;

  /// Specific site IDs this assignment binds. Empty for wildcard scopes.
  /// Order is whatever the row stream produced — not guaranteed stable.
  final List<String> boundSites;

  /// True when the assignment is wildcard-scoped (`all sites` or
  /// `everything`). When true, [boundSites] is empty by construction; UI
  /// should render "All sites" rather than "0 sites assigned".
  final bool isWildcard;

  const RoleAssignmentView({
    required this.role,
    required this.boundSites,
    required this.isWildcard,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleAssignmentView &&
          role == other.role &&
          isWildcard == other.isWildcard &&
          listEquals(boundSites, other.boundSites);

  @override
  int get hashCode => Object.hash(role, isWildcard, Object.hashAll(boundSites));

  @override
  String toString() =>
      'RoleAssignmentView(role: $role, '
      'boundSites: $boundSites, isWildcard: $isWildcard)';
}
