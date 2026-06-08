import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'create_user_dialog.dart';
import 'user_account_logic.dart';

/// Thin reactive wrapper that feeds [UsersScreen] a snapshot of users
/// joined with their `(role, scope)` assignments.
///
/// Sits between `portal_ui_evs`'s `ViewBuilder` plumbing and the pure
/// presentation layer in `portal_screens`: subscribes to the two
/// projections, maps the raw rows into the snapshot value types that
/// `UsersScreen` consumes, and emits the action callbacks back out
/// (no-ops for now — Phase 7 wires the kebab actions, Phase 7.5 wires
/// the Create User dialog).
///
/// Self-gates on `portal.user.view_accounts` (ACT-SEE-003) so a role that
/// can't read the directory never opens a subscription. The inner
/// `ViewBuilder` for `user_role_scopes` is gated on the same Action (one
/// Action governs both the `users_index` and `user_role_scopes`
/// projections under CUR-1474), so in practice it opens whenever the outer
/// gate does; the empty-assignments fallback remains as a defensive default.
class UsersScreenBinding extends StatelessWidget {
  const UsersScreenBinding({super.key});

  /// Permission a role must hold to see the users tab + table at all.
  static const String viewUsersPermission = 'portal.user.view_accounts';

  /// Permission for the assignment join. Modeled as the SAME Action as the
  /// directory read (`portal.user.view_accounts`, ACT-SEE-003): one Action
  /// gates both the `users_index` and `user_role_scopes` projections. The
  /// inner gate is kept separate so the structure survives a future split.
  static const String viewAssignmentsPermission = 'portal.user.view_accounts';

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: viewUsersPermission,
    fallback: const Center(
      child: Text("You don't have permission to view users."),
    ),
    child: ViewBuilder<_UserRow>(
      viewName: 'users_index',
      mapper: _UserRow.fromRow,
      aggregateIdOf: (u) => u.email,
      builder: (context, userState) {
        final users = switch (userState) {
          Loading<_UserRow>() => const <_UserRow>[],
          Ready<_UserRow>(:final rows) => rows,
          Stale<_UserRow>(:final lastRows) => lastRows,
        };
        final isLoadingUsers = userState is Loading<_UserRow>;

        // Inner subscription for the assignment join. Gated separately
        // so a role with view:users_index but without view:user_role_scopes
        // still gets a usable table — empty assignments, but rows visible.
        return PermissionGate(
          permission: viewAssignmentsPermission,
          fallback: _renderUsersScreen(
            users: users,
            assignmentsByUser: const <String, List<_Assignment>>{},
            isLoading: isLoadingUsers,
          ),
          child: ViewBuilder<_Assignment>(
            viewName: 'user_role_scopes',
            mapper: _Assignment.fromRow,
            aggregateIdOf: (a) => a.aggregateId,
            builder: (context, assignmentState) {
              final assignments = switch (assignmentState) {
                Loading<_Assignment>() => const <_Assignment>[],
                Ready<_Assignment>(:final rows) => rows,
                Stale<_Assignment>(:final lastRows) => lastRows,
              };
              final assignmentsByUser = _groupByUser(assignments);
              final isLoadingAssignments =
                  assignmentState is Loading<_Assignment>;
              return _renderUsersScreen(
                users: users,
                assignmentsByUser: assignmentsByUser,
                isLoading: isLoadingUsers || isLoadingAssignments,
              );
            },
          ),
        );
      },
    ),
  );

  /// Permission a role must hold to see the "Create User" CTA on the
  /// directory header. The button stays hidden when the active role is
  /// missing this permission — gated reactively by [_CreateCtaGate] so
  /// it re-evaluates on a role switch without rebuilding the table.
  static const String createUserPermission = 'portal.user.create';

  Widget _renderUsersScreen({
    required List<_UserRow> users,
    required Map<String, List<_Assignment>> assignmentsByUser,
    required bool isLoading,
  }) {
    final views = <PortalUserView>[
      for (final u in users)
        PortalUserView(
          email: u.email,
          name: u.name,
          status: _toStatusView(u.status),
          assignments: _toAssignmentViews(
            assignmentsByUser[u.email] ?? const [],
          ),
        ),
    ];
    return _CreateCtaGate(
      builder: (context, canCreate) => UsersScreen(
        users: views,
        isLoading: isLoading,
        canCreate: canCreate,
        onCreate: canCreate ? () => _openCreateUserDialog(context) : () {},
      ),
    );
  }

  void _openCreateUserDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const CreateUserDialog(),
    );
  }
}

/// Subscribes to the active permission snapshot and rebuilds when the
/// active role holds [UsersScreenBinding.createUserPermission] flips.
/// Mirrors [PermissionGate]'s subscription but exposes the held-status
/// as a bool to a [builder] so the parent renders a single [UsersScreen]
/// with the right `canCreate` prop instead of two divergent branches.
class _CreateCtaGate extends StatefulWidget {
  const _CreateCtaGate({required this.builder});

  final Widget Function(BuildContext context, bool canCreate) builder;

  @override
  State<_CreateCtaGate> createState() => _CreateCtaGateState();
}

class _CreateCtaGateState extends State<_CreateCtaGate> {
  StreamSubscription<EffectiveAuthorization?>? _sub;
  EffectiveAuthorization? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final scope = ReActionScope.of(context);
    _auth = scope.permissionSource.current;
    _sub = scope.permissionSource.stream.listen((auth) {
      if (!mounted) return;
      setState(() => _auth = auth);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  bool get _canCreate {
    final auth = _auth;
    if (auth == null) return false;
    for (final p in auth.rolePermissions) {
      if (p.name == UsersScreenBinding.createUserPermission) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _canCreate);
}

// -----------------------------------------------------------------------------
// Row types — file-private projections of the raw `users_index` /
// `user_role_scopes` rows.
// -----------------------------------------------------------------------------

class _UserRow {
  const _UserRow({
    required this.email,
    required this.name,
    required this.status,
  });
  final String email;
  final String name;
  final UserStatus status;

  static _UserRow fromRow(Map<String, Object?> row) => _UserRow(
    email: (row['aggregateId'] as String?) ?? (row['email'] as String?) ?? '?',
    name: (row['name'] as String?) ?? (row['after'] as String?) ?? '—',
    status: statusFromRow(row),
  );
}

class _Assignment {
  const _Assignment({
    required this.aggregateId,
    required this.userId,
    required this.role,
    required this.scope,
  });
  final String aggregateId;
  final String userId;
  final String role;
  final ScopeValue scope;

  /// The site id this assignment binds (when scope is a `BoundScope`),
  /// or null for the wildcard scopes carried by Administrator / System
  /// Operator. Mirrors the legacy `_Assignment.boundSite` accessor.
  String? get boundSite => switch (scope) {
    BoundScope(:final value) => value,
    _ => null,
  };

  bool get isWildcard => switch (scope) {
    ValueWildcardScope() || TotalWildcardScope() => true,
    BoundScope() => false,
  };

  static _Assignment fromRow(Map<String, Object?> row) {
    final scopeJson = row['scope'];
    return _Assignment(
      aggregateId: row['aggregateId']! as String,
      userId: (row['user_id'] as String?) ?? '?',
      role: (row['role'] as String?) ?? '?',
      scope: scopeJson is Map
          ? ScopeValue.fromJson(scopeJson.cast<String, Object?>())
          : const TotalWildcardScope(),
    );
  }
}

Map<String, List<_Assignment>> _groupByUser(List<_Assignment> rows) {
  final out = <String, List<_Assignment>>{};
  for (final a in rows) {
    (out[a.userId] ??= <_Assignment>[]).add(a);
  }
  return out;
}

/// Collapses every assignment for a single user into the snapshot shape
/// `RoleAssignmentView` expects. A role with multiple bound sites
/// becomes one view with all sites collected; a wildcard assignment
/// becomes its own view with `isWildcard: true` and an empty
/// `boundSites` list.
List<RoleAssignmentView> _toAssignmentViews(List<_Assignment> assignments) {
  // Two buckets so wildcards stay distinct from site-bound assignments
  // even when they share a role name (an Administrator with a
  // `site=*` wildcard scope shouldn't merge with their staff-`tier`
  // bound scope into "Administrator [tier]").
  final wildcardRoles = <String>{};
  final boundSitesByRole = <String, List<String>>{};
  for (final a in assignments) {
    if (a.isWildcard) {
      wildcardRoles.add(a.role);
    } else {
      final site = a.boundSite;
      if (site == null) continue;
      (boundSitesByRole[a.role] ??= <String>[]).add(site);
    }
  }
  return <RoleAssignmentView>[
    for (final role in wildcardRoles)
      RoleAssignmentView(
        role: role,
        boundSites: const <String>[],
        isWildcard: true,
      ),
    for (final entry in boundSitesByRole.entries)
      RoleAssignmentView(
        role: entry.key,
        boundSites: entry.value,
        isWildcard: false,
      ),
  ];
}

UserStatusView _toStatusView(UserStatus s) => switch (s) {
  UserStatus.pending => UserStatusView.pending,
  UserStatus.active => UserStatusView.active,
  UserStatus.revoked => UserStatusView.revoked,
  UserStatus.locked => UserStatusView.locked,
  UserStatus.unknown => UserStatusView.unknown,
};
