import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'create_user_dialog.dart';
import 'user_account_flows.dart';
import 'user_account_logic.dart';

/// Thin reactive wrapper that feeds [UsersScreen] a snapshot of users
/// joined with their `(role, scope)` assignments.
///
/// Sits between `portal_ui_evs`'s `ViewBuilder` plumbing and the pure
/// presentation layer in `portal_screens`: subscribes to the two
/// projections, maps the raw rows into the snapshot value types that
/// `UsersScreen` consumes, and routes the Create-User CTA + row kebab
/// actions to their dialog flows (`user_account_flows.dart`).
///
/// Self-gates on `portal.user.view_accounts` (ACT-SEE-003) so a role that
/// can't read the directory never opens a subscription. The inner
/// `ViewBuilder` for `user_role_scopes` is gated on the same Action (one
/// Action governs both the `users_index` and `user_role_scopes`
/// projections under CUR-1474), so in practice it opens whenever the outer
/// gate does; the empty-assignments fallback remains as a defensive default.
class UsersScreenBinding extends StatefulWidget {
  const UsersScreenBinding({super.key, this.currentUserId, this.activeRole});

  /// The authenticated principal's userId (the account email). Forwarded
  /// to the row-actions config so Edit / Deactivate are suppressed on
  /// the admin's own row (DIARY-GUI-user-information-modal/K).
  final String? currentUserId;

  /// The principal's active role. Operator-tier targets (rows holding
  /// SystemOperator) only offer management actions when this is
  /// SystemOperator — mirrors the server's user-contained-in-tier gate,
  /// which the active role's tier coverage derives from. Permission
  /// NAMES can't drive this: Administrator also holds e.g.
  /// portal.user.grant_role, just with staff-tier-only coverage.
  final String? activeRole;

  /// Permission a role must hold to see the users tab + table at all.
  static const String viewUsersPermission = 'portal.user.view_accounts';

  /// Permission for the assignment join. Modeled as the SAME Action as the
  /// directory read (`portal.user.view_accounts`, ACT-SEE-003): one Action
  /// gates both the `users_index` and `user_role_scopes` projections. The
  /// inner gate is kept separate so the structure survives a future split.
  static const String viewAssignmentsPermission = 'portal.user.view_accounts';

  /// Permission a role must hold to see the "Create User" CTA on the
  /// directory header.
  static const String createUserPermission = 'portal.user.create';

  @override
  State<UsersScreenBinding> createState() => _UsersScreenBindingState();
}

class _UsersScreenBindingState extends State<UsersScreenBinding> {
  /// Emails whose activation invite was re-sent in this session. UI-only
  /// acknowledgment (Figma "Invite Sent"); the projection has no
  /// resend-recency column, and the badge resets on reload by design.
  final Set<String> _inviteSent = <String>{};

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: UsersScreenBinding.viewUsersPermission,
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
          permission: UsersScreenBinding.viewAssignmentsPermission,
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

  Widget _renderUsersScreen({
    required List<_UserRow> users,
    required Map<String, List<_Assignment>> assignmentsByUser,
    required bool isLoading,
  }) {
    final allViews = <PortalUserView>[
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
    // Only an active SystemOperator role can touch operator-tier targets
    // or grant the SystemOperator role. Permission names can't decide
    // this (Administrator holds the same names with staff-tier-only
    // coverage), so it keys off the active role like the server's tier
    // derivation does.
    final isOperator =
        widget.activeRole == PortalRole.systemOperator.systemName;
    // SysOp-ONLY accounts are an operator concern — hidden from staff
    // viewers entirely. A SysOp who also holds a regular role renders
    // normally (badge included). See visibleUserRows for the
    // missing-role-data and read-scope caveats.
    final views = visibleUserRows(
      users: allViews,
      viewerIsOperator: isOperator,
    );
    return _PermissionsGate(
      builder: (context, permissions) {
        final canCreate = permissions.contains(
          UsersScreenBinding.createUserPermission,
        );
        late final UserRowActionsConfig config;
        config = UserRowActionsConfig(
          canEdit: permissions.contains('portal.user.edit'),
          canDeactivate: permissions.contains('portal.user.deactivate'),
          canReactivate: permissions.contains('portal.user.reactivate'),
          canResendInvite: permissions.contains(
            'portal.user.resend_activation',
          ),
          canUnlock: permissions.contains('portal.user.unlock'),
          canManageOperatorTier: isOperator,
          currentUserEmail: widget.currentUserId,
          inviteSentEmails: _inviteSent,
          onAction: (user, action) {
            unawaited(
              _handleRowAction(
                context,
                user: user,
                action: action,
                config: config,
                canGrantOperator: isOperator,
              ),
            );
          },
        );
        return UsersScreen(
          users: views,
          isLoading: isLoading,
          canCreate: canCreate,
          onCreate: canCreate
              ? () => _openCreateUserDialog(
                  context,
                  offerSystemOperator: isOperator,
                )
              : () {},
          rowActions: config,
        );
      },
    );
  }

  Future<void> _handleRowAction(
    BuildContext context, {
    required PortalUserView user,
    required UserRowAction action,
    required UserRowActionsConfig config,
    required bool canGrantOperator,
    bool fromDetails = false,
  }) async {
    // Flow dialogs launched FROM the details modal carry a "\u2190 User
    // Details" back-link that reopens it (Figma); kebab-launched flows
    // don't.
    final VoidCallback? backToDetails = fromDetails && context.mounted
        ? () => unawaited(
            _handleRowAction(
              context,
              user: user,
              action: UserRowAction.viewDetails,
              config: config,
              canGrantOperator: canGrantOperator,
            ),
          )
        : null;
    switch (action) {
      case UserRowAction.viewDetails:
        final next = await showUserDetailsFlow(
          context,
          user: user,
          config: config,
        );
        if (next != null && context.mounted) {
          await _handleRowAction(
            context,
            user: user,
            action: next,
            config: config,
            canGrantOperator: canGrantOperator,
            fromDetails: true,
          );
        }
      case UserRowAction.edit:
        await showEditUserFlow(
          context,
          user: user,
          offerSystemOperator: canGrantOperator,
          onBack: backToDetails,
        );
      case UserRowAction.resendInvite:
        final sent = await resendInviteFlow(context, user: user);
        if (sent && mounted) {
          setState(() => _inviteSent.add(user.email));
        }
      case UserRowAction.deactivate:
        await showDeactivateUserFlow(
          context,
          user: user,
          onBack: backToDetails,
        );
      case UserRowAction.reactivate:
        await showReactivateUserFlow(
          context,
          user: user,
          onBack: backToDetails,
        );
      case UserRowAction.unlock:
        await showUnlockUserFlow(context, user: user);
    }
  }

  void _openCreateUserDialog(
    BuildContext context, {
    required bool offerSystemOperator,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          CreateUserDialog(offerSystemOperator: offerSystemOperator),
    );
  }
}

/// Subscribes to the active permission snapshot and rebuilds when it
/// changes (e.g. on a role switch). Mirrors [PermissionGate]'s
/// subscription but exposes the full set of held permission names so
/// the parent can derive every capability flag from one subscription
/// instead of stacking six gates.
class _PermissionsGate extends StatefulWidget {
  const _PermissionsGate({required this.builder});

  final Widget Function(BuildContext context, Set<String> permissions) builder;

  @override
  State<_PermissionsGate> createState() => _PermissionsGateState();
}

class _PermissionsGateState extends State<_PermissionsGate> {
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

  Set<String> get _permissions {
    final auth = _auth;
    if (auth == null) return const <String>{};
    return {for (final p in auth.rolePermissions) p.name};
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _permissions);
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
    name: (row['name'] as String?) ?? '—',
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

  /// The site id this assignment binds — ONLY for a `site`-class [BoundScope].
  /// Null for wildcard scopes (Administrator / System Operator) AND for
  /// non-site bound scopes such as the Administrator's staff-`tier` scope:
  /// `('tier', 'staff')` is not a Site and must never leak into the Assigned
  /// Sites list/count (it showed up as a bogus "staff" site and, because it
  /// kept boundSites non-empty, defeated the "site-scoped role needs a Site"
  /// edit guard).
  String? get boundSite => switch (scope) {
    BoundScope(class_: 'site', :final value) => value,
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
