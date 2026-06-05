import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'user_account_logic.dart';

// User Accounts screen — the reactive operator console for portal users.
//
// Lists portal users from users_index, creates users, drives their lifecycle
// (deactivate/reactivate/unlock/resend/delete-pending), and edits each user's
// role-set x site-set via the pure planAssignmentChanges diff in
// user_account_logic.dart. Every action/view widget is wrapped in a
// PermissionGate keyed on the permission it needs, so a user only ever sees the
// controls their active role holds (re-gated live on role switch/revocation).
//
// Multi-step flows (create-then-assign; apply-a-whole-assignment-plan) dispatch
// through an ActionClient (ReActionScope.of(context).actionSubmitter) in
// sequence, awaiting each DispatchResult. ActionClient mints the idempotency key
// these actions require (Idempotency.required) and each result is checked so a
// denied submission surfaces a real failure rather than a false 'Applied.'.
// Single-shot lifecycle buttons stay on ActionBuilder for its idempotency-key
// lifecycle + per-button state rendering.
//
// Implements: DIARY-DEV-user-account-projection/A+C

const String _viewUsersPerm = 'view:users_index';
const String _viewAssignmentsPerm = 'view:user_role_scopes';

const String _createAction = 'ACT-USR-001';
const String _editAction = 'ACT-USR-002';
const String _deactivateAction = 'ACT-USR-003';
const String _reactivateAction = 'ACT-USR-004';
const String _unlockAction = 'ACT-USR-005';
const String _resendAction = 'ACT-USR-006';
const String _deletePendingAction = 'ACT-USR-009';
// The assign/revoke action names (ACT-USR-007/008/010/011) live in
// user_account_logic.dart, where the pure assignmentSubmissions builder uses
// them; the screen dispatches that builder's submissions via ActionClient.

const String _createPerm = 'portal.user.create';
const String _editPerm = 'portal.user.edit';
const String _deactivatePerm = 'portal.user.deactivate';
const String _reactivatePerm = 'portal.user.reactivate';
const String _unlockPerm = 'portal.user.unlock';
const String _resendPerm = 'portal.user.resend_activation';
const String _assignRolePerm = 'portal.user.assign_role';
const String _deletePendingPerm = 'portal.user.delete_pending';

const List<String> _roles = <String>[
  'StudyCoordinator',
  'CRA',
  'Administrator',
  'SystemOperator',
];

/// Operator-tier roles can only be granted by an operator-tier active role
/// (the server gates this on `portal.user.grant_role` scoped to the operator
/// tier). The client mirrors that so a non-operator (e.g. Administrator) is not
/// shown a role chip whose grant would be denied.
const Set<String> _operatorTierRoles = <String>{'SystemOperator'};

/// The roles the ACTIVE role may grant: all staff-tier roles, plus operator-tier
/// roles only when the active role is itself operator-tier. Keyed on the
/// effective authorization's `activeRole` (the same surface the server evaluates).
///
/// Implements: DIARY-GUI-role-switching/E+F
List<String> _grantableRoles(EffectiveAuthorization? auth) {
  final isOperator = _operatorTierRoles.contains(auth?.activeRole ?? '');
  return <String>[
    for (final r in _roles)
      if (isOperator || !_operatorTierRoles.contains(r)) r,
  ];
}

/// Test-only accessor for [_grantableRoles].
@visibleForTesting
List<String> grantableRolesForTest(EffectiveAuthorization? auth) =>
    _grantableRoles(auth);

/// One option in the site picker, sourced from the RAVE-synced sites_index
/// view (same source as SitesScreen) — NOT a hardcoded list. [id] is the
/// site_id used as the assignment scope value; [label] is the human display.
class _SiteOption {
  const _SiteOption({
    required this.id,
    required this.label,
    required this.number,
  });
  final String id;
  final String label;
  final String number;

  static _SiteOption fromRow(Map<String, Object?> r) {
    final id = (r['site_id'] as String?) ?? '?';
    final name = (r['site_name'] as String?) ?? '';
    final number = (r['site_number'] as String?) ?? '';
    final label = name.isNotEmpty ? '$number · $name' : id;
    return _SiteOption(id: id, label: label, number: number);
  }
}

/// Reactive site picker backed by sites_index (gated upstream on
/// view:sites_index), sorted by site number. Hands the current site options to
/// [builder] so each call site can render them in its own style (checkboxes /
/// chips). Replaces the former hardcoded ['site-1','site-2','site-3'].
class _SitesView extends StatelessWidget {
  const _SitesView({required this.builder});
  final Widget Function(BuildContext context, List<_SiteOption> sites) builder;

  @override
  Widget build(BuildContext context) => ViewBuilder<_SiteOption>(
    viewName: 'sites_index',
    mapper: _SiteOption.fromRow,
    aggregateIdOf: (s) => s.id,
    builder: (context, state) {
      final rows = switch (state) {
        Loading<_SiteOption>() => const <_SiteOption>[],
        Ready<_SiteOption>(:final rows) => rows,
        Stale<_SiteOption>(:final lastRows) => lastRows,
      };
      if (state is Loading<_SiteOption>) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Loading sites…',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        );
      }
      if (rows.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '(no sites available)',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        );
      }
      final sorted = <_SiteOption>[...rows]
        ..sort((a, b) => a.number.compareTo(b.number));
      return builder(context, sorted);
    },
  );
}

String _activationExpiresAt() =>
    DateTime.now().toUtc().add(const Duration(days: 14)).toIso8601String();

/// The role-level scopes a non-site role's assignment carries. Returns a LIST
/// because a role can need coverage in more than one scope class:
///   - Administrator (all-sites): an all-sites scope (for its site-scoped
///     permissions) AND a staff-`tier` scope so it can run user-management
///     actions against staff-tier accounts (DIARY-DEV-operator-tier-authz/E).
///     Without the tier scope a freshly-provisioned Administrator is denied
///     assign_site / edit / etc. — it must mirror the bootstrap seed, which
///     grants admins exactly these two scopes.
///   - System Operator (everything): a single total-wildcard scope, which
///     already spans every class (including `tier`).
/// Each scope becomes its own assign_role/revoke_role in [assignmentSubmissions].
List<Object> _roleScopesJsonFor(String role) => switch (roleScopeKind(role)) {
  RoleScopeKind.allSites => <Object>[
    const ValueWildcardScope(class_: 'site').toJson(),
    const BoundScope(class_: 'tier', value: 'staff').toJson(),
  ],
  RoleScopeKind.everything => <Object>[const TotalWildcardScope().toJson()],
  // site-scoped roles never carry a role-level wildcard scope: assignRoles /
  // revokeRoles only ever contain wildcard roles (planAssignmentChanges
  // routes site-scoped roles to assignSites/revokeSites). Reaching here is a
  // bug, not a runtime input condition.
  RoleScopeKind.site => throw StateError(
    '_roleScopesJsonFor called for site-scoped role $role',
  ),
};

/// One users_index row.
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

/// One user_role_scopes row (library shape: user_id/role/scope JSON).
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

  String get scopeLabel => switch (scope) {
    BoundScope(:final class_, :final value) => '$class_=$value',
    ValueWildcardScope(:final class_) => '$class_=*',
    TotalWildcardScope() => '(all)',
  };

  /// The site id this assignment binds (BoundScope value), or null for the
  /// wildcard scopes carried by Administrator/SystemOperator roles.
  String? get boundSite => switch (scope) {
    BoundScope(:final value) => value,
    _ => null,
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

class UserAccountsScreen extends StatelessWidget {
  const UserAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: _viewUsersPerm,
    fallback: const Center(
      child: Text("You don't have permission to view users."),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PermissionGate(
            permission: _createPerm,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Create User'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ReActionScope(
                    scope: ReActionScope.of(context),
                    child: const _CreateUserDialog(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ViewBuilder<_UserRow>(
              viewName: 'users_index',
              mapper: _UserRow.fromRow,
              aggregateIdOf: (u) => u.email,
              builder: (context, state) {
                final rows = switch (state) {
                  Loading<_UserRow>() => const <_UserRow>[],
                  Ready<_UserRow>(:final rows) => rows,
                  Stale<_UserRow>(:final lastRows) => lastRows,
                };
                if (state is Loading<_UserRow>) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('(no users yet)'));
                }
                final sorted = <_UserRow>[...rows]
                  ..sort((a, b) => a.email.compareTo(b.email));
                return ListView(
                  children: <Widget>[
                    for (final u in sorted)
                      ExpansionTile(
                        title: Text(u.email),
                        subtitle: Text('${u.name} · ${u.status.label}'),
                        children: <Widget>[
                          _UserDetail(email: u.email, status: u.status),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Create dialog: email + name, a role multi-select, and (when any selected
/// role is site-scoped) a site multi-select. On Create it dispatches ACT-USR-001
/// then realizes the role/site assignment plan sequentially through the action
/// submitter.
class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();
  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final Set<String> _selectedRoles = <String>{};
  final Set<String> _selectedSites = <String>{};
  bool _submitting = false;
  String? _error;

  bool get _anySiteScopedRole =>
      _selectedRoles.any((r) => roleScopeKind(r) == RoleScopeKind.site);

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final email = _email.text.trim();
    final name = _name.text.trim();
    if (email.isEmpty || name.isEmpty) {
      setState(() => _error = 'Email and name are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    // ActionClient mints the per-submission idempotency key the actions require
    // (Idempotency.required) — raw actionSubmitter.submit(...) would be
    // parse-denied for these programmatic submissions.
    final client = ActionClient(ReActionScope.of(context).actionSubmitter);
    final sites = _selectedSites.toList();
    try {
      // 1. Create the account (Pending). userId == email.
      final created = await client.submit(
        ActionSubmission(
          actionName: _createAction,
          rawInput: <String, Object?>{
            'email': email,
            'name': name,
            'activationExpiresAt': _activationExpiresAt(),
            'roles': _selectedRoles.toList(),
            'sites': sites,
          },
        ),
      );
      if (created is! DispatchSuccess && created is! DispatchIdempotencyHit) {
        setState(() {
          _submitting = false;
          _error = 'Create denied: ${_denialLabel(created)}';
        });
        return;
      }

      // 2. Realize the assignment plan from the empty current state.
      final plan = planAssignmentChanges(
        desired: <DesiredAssignment>[
          for (final r in _selectedRoles)
            DesiredAssignment(
              role: r,
              sites: roleScopeKind(r) == RoleScopeKind.site ? sites : const [],
            ),
        ],
        current: const <CurrentTuple>[],
      );
      await _applyPlan(client, email, plan);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create User'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Roles'),
              ),
              // Only show roles the active role may grant (server enforces too).
              for (final r in _grantableRoles(
                ReActionScope.of(context).permissionSource.current,
              ))
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r),
                  value: _selectedRoles.contains(r),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _selectedRoles.add(r);
                    } else {
                      _selectedRoles.remove(r);
                    }
                  }),
                ),
              if (_anySiteScopedRole) ...<Widget>[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sites (for site-scoped roles)'),
                ),
                _SitesView(
                  builder: (context, sites) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final s in sites)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.label),
                          value: _selectedSites.contains(s.id),
                          onChanged: (v) => setState(() {
                            if (v ?? false) {
                              _selectedSites.add(s.id);
                            } else {
                              _selectedSites.remove(s.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Activation email is sent by the auth subsystem (not yet '
                'wired) — the user starts Pending.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _create,
          child: Text(_submitting ? '...' : 'Create'),
        ),
      ],
    );
  }
}

/// Per-user detail panel: current assignments, the role/site editor, and the
/// status-gated lifecycle buttons.
class _UserDetail extends StatelessWidget {
  const _UserDetail({required this.email, required this.status});
  final String email;
  final UserStatus status;

  @override
  Widget build(BuildContext context) {
    final enabled = enabledUserActions(status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Current roles/sites + the editor (manageRolesSites). Shown for the
          // statuses that permit it (pending/active).
          if (enabled.contains(UserAction.manageRolesSites))
            PermissionGate(
              permission: _viewAssignmentsPerm,
              fallback: const SizedBox.shrink(),
              child: ViewBuilder<_Assignment>(
                viewName: 'user_role_scopes',
                mapper: _Assignment.fromRow,
                aggregateIdOf: (a) => a.aggregateId,
                builder: (context, state) {
                  final rows = switch (state) {
                    Loading<_Assignment>() => const <_Assignment>[],
                    Ready<_Assignment>(:final rows) => rows,
                    Stale<_Assignment>(:final lastRows) => lastRows,
                  };
                  final mine = rows.where((a) => a.userId == email).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Roles & sites',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (mine.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('(no assignments)'),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final a in mine)
                              Chip(label: Text('${a.role} · ${a.scopeLabel}')),
                          ],
                        ),
                      const SizedBox(height: 8),
                      _RoleSiteEditor(email: email, current: mine),
                      const Divider(height: 24),
                    ],
                  );
                },
              ),
            ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Lifecycle',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final action in UserAction.values)
                if (action != UserAction.manageRolesSites &&
                    enabled.contains(action))
                  _LifecycleButton(email: email, action: action),
            ],
          ),
        ],
      ),
    );
  }
}

/// The role/site editor: a multi-select pre-filled from the user's current
/// assignments. On Apply it computes planAssignmentChanges(desired, current)
/// and dispatches the resulting assign/revoke actions in sequence.
class _RoleSiteEditor extends StatefulWidget {
  const _RoleSiteEditor({required this.email, required this.current});
  final String email;
  final List<_Assignment> current;
  @override
  State<_RoleSiteEditor> createState() => _RoleSiteEditorState();
}

class _RoleSiteEditorState extends State<_RoleSiteEditor> {
  late Set<String> _selRoles;
  late Set<String> _selSites;
  bool _submitting = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _seedFromCurrent();
  }

  @override
  void didUpdateWidget(covariant _RoleSiteEditor old) {
    super.didUpdateWidget(old);
    // Re-seed only when the live assignments actually changed underneath us and
    // we're not mid-edit. An unrelated user_role_scopes update rebuilds this
    // widget with the same current set; reseeding then would discard the admin's
    // in-progress (role, site) edits.
    if (!_submitting && _tupleSet(widget.current) != _tupleSet(old.current)) {
      _seedFromCurrent();
    }
  }

  /// The (role, boundSite) tuples of [assignments] as a set, so widget updates
  /// that don't change the assignment set don't trigger a reseed. Wildcard roles
  /// (no bound site) use '*' as their site marker.
  Set<(String, String)> _tupleSet(List<_Assignment> assignments) =>
      <(String, String)>{
        for (final a in assignments) (a.role, a.boundSite ?? '*'),
      };

  void _seedFromCurrent() {
    _selRoles = <String>{for (final a in widget.current) a.role};
    _selSites = <String>{
      for (final a in widget.current)
        if (a.boundSite != null) a.boundSite!,
    };
  }

  bool get _anySiteScopedRole =>
      _selRoles.any((r) => roleScopeKind(r) == RoleScopeKind.site);

  /// Builds the CurrentTuple list from the live user_role_scopes rows:
  /// site-scoped roles -> (role, boundSite); wildcard roles -> (role, '*').
  List<CurrentTuple> _currentTuples() => <CurrentTuple>[
    for (final a in widget.current)
      CurrentTuple(role: a.role, site: a.boundSite ?? '*'),
  ];

  Future<void> _apply() async {
    setState(() {
      _submitting = true;
      _msg = null;
    });
    // ActionClient mints the per-submission idempotency key the assign/revoke
    // actions require; _applyPlan throws on any non-success result so a denied
    // tuple surfaces a real failure instead of a false 'Applied.'.
    final client = ActionClient(ReActionScope.of(context).actionSubmitter);
    final sites = _selSites.toList();
    final plan = planAssignmentChanges(
      desired: <DesiredAssignment>[
        for (final r in _selRoles)
          DesiredAssignment(
            role: r,
            sites: roleScopeKind(r) == RoleScopeKind.site ? sites : const [],
          ),
      ],
      current: _currentTuples(),
    );
    try {
      await _applyPlan(client, widget.email, plan);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _msg = 'Applied.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _msg = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The editor controls are only meaningful to roles that can mutate
    // assignments; gate the whole editor on assign_role. The individual
    // assign_site/revoke_role/revoke_site permissions the Apply plan exercises
    // are enforced server-side at dispatch — a denied tuple surfaces as a
    // Failed message rather than silently succeeding.
    return PermissionGate(
      permission: _assignRolePerm,
      fallback: const SizedBox.shrink(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Edit roles'),
          ),
          Wrap(
            spacing: 6,
            children: <Widget>[
              // Only roles the active role may grant (server enforces too).
              for (final r in _grantableRoles(
                ReActionScope.of(context).permissionSource.current,
              ))
                FilterChip(
                  label: Text(r),
                  selected: _selRoles.contains(r),
                  onSelected: _submitting
                      ? null
                      : (sel) => setState(() {
                          if (sel) {
                            _selRoles.add(r);
                          } else {
                            _selRoles.remove(r);
                          }
                        }),
                ),
            ],
          ),
          if (_anySiteScopedRole) ...<Widget>[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sites (for site-scoped roles)'),
            ),
            _SitesView(
              builder: (context, sites) => Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final s in sites)
                    FilterChip(
                      label: Text(s.label),
                      selected: _selSites.contains(s.id),
                      onSelected: _submitting
                          ? null
                          : (sel) => setState(() {
                              if (sel) {
                                _selSites.add(s.id);
                              } else {
                                _selSites.remove(s.id);
                              }
                            }),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _submitting ? null : _apply,
              child: Text(_submitting ? '...' : 'Apply'),
            ),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_msg!, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// One status-gated lifecycle button. Wrapped in the action's PermissionGate
/// and dispatched via ActionBuilder. edit/deactivate/reactivate/unlock collect
/// name/email/reason via a small dialog before submitting; resend/deletePending
/// are direct.
class _LifecycleButton extends StatelessWidget {
  const _LifecycleButton({required this.email, required this.action});
  final String email;
  final UserAction action;

  String get _permission => switch (action) {
    UserAction.edit => _editPerm,
    UserAction.resendActivation => _resendPerm,
    UserAction.deletePending => _deletePendingPerm,
    UserAction.deactivate => _deactivatePerm,
    UserAction.reactivate => _reactivatePerm,
    UserAction.unlock => _unlockPerm,
    UserAction.manageRolesSites => _assignRolePerm,
  };

  String get _label => switch (action) {
    UserAction.edit => 'Edit',
    UserAction.resendActivation => 'Resend activation (email not yet wired)',
    UserAction.deletePending => 'Delete pending',
    UserAction.deactivate => 'Deactivate',
    UserAction.reactivate => 'Reactivate',
    UserAction.unlock => 'Unlock',
    UserAction.manageRolesSites => 'Manage roles/sites',
  };

  /// Direct submissions (no dialog) — resend + deletePending.
  ActionSubmission? _directSubmission() => switch (action) {
    UserAction.resendActivation => ActionSubmission(
      actionName: _resendAction,
      rawInput: <String, Object?>{
        'userId': email,
        'activationExpiresAt': _activationExpiresAt(),
      },
    ),
    UserAction.deletePending => ActionSubmission(
      actionName: _deletePendingAction,
      rawInput: <String, Object?>{'userId': email},
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final direct = _directSubmission();
    return PermissionGate(
      permission: _permission,
      child: direct != null
          ? ActionBuilder(
              submissionFactory: () => direct,
              builder: (context, state, submit) => FilledButton.tonal(
                onPressed: state is Submitting ? null : submit,
                child: Text(switch (state) {
                  Submitting() => '...',
                  Denied() => 'Denied',
                  Failed() => 'Failed',
                  _ => _label,
                }),
              ),
            )
          : FilledButton.tonal(
              onPressed: () => _openDialog(context),
              child: Text(_label),
            ),
    );
  }

  void _openDialog(BuildContext context) {
    final scope = ReActionScope.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => ReActionScope(
        scope: scope,
        child: _LifecycleDialog(email: email, action: action),
      ),
    );
  }
}

/// Collects the free-text fields a lifecycle action needs (name/email for edit;
/// reason for deactivate/unlock; reason + activation expiry for reactivate),
/// then dispatches via ActionBuilder inside the dialog.
class _LifecycleDialog extends StatefulWidget {
  const _LifecycleDialog({required this.email, required this.action});
  final String email;
  final UserAction action;
  @override
  State<_LifecycleDialog> createState() => _LifecycleDialogState();
}

class _LifecycleDialogState extends State<_LifecycleDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _newEmail = TextEditingController();
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _newEmail.dispose();
    _reason.dispose();
    super.dispose();
  }

  String get _title => switch (widget.action) {
    UserAction.edit => 'Edit user',
    UserAction.deactivate => 'Deactivate user',
    UserAction.reactivate => 'Reactivate user',
    UserAction.unlock => 'Unlock user',
    _ => 'Action',
  };

  ActionSubmission _submission() {
    switch (widget.action) {
      case UserAction.edit:
        final name = _name.text.trim();
        final newEmail = _newEmail.text.trim();
        return ActionSubmission(
          actionName: _editAction,
          rawInput: <String, Object?>{
            'userId': widget.email,
            if (name.isNotEmpty) 'name': name,
            if (newEmail.isNotEmpty) 'newEmail': newEmail,
          },
        );
      case UserAction.deactivate:
        return ActionSubmission(
          actionName: _deactivateAction,
          rawInput: <String, Object?>{
            'userId': widget.email,
            'reason': _reason.text.trim(),
          },
        );
      case UserAction.reactivate:
        return ActionSubmission(
          actionName: _reactivateAction,
          rawInput: <String, Object?>{
            'userId': widget.email,
            'reason': _reason.text.trim(),
            'activationExpiresAt': _activationExpiresAt(),
          },
        );
      case UserAction.unlock:
        return ActionSubmission(
          actionName: _unlockAction,
          rawInput: <String, Object?>{
            'userId': widget.email,
            'reason': _reason.text.trim(),
          },
        );
      default:
        return ActionSubmission(
          actionName: _editAction,
          rawInput: <String, Object?>{'userId': widget.email},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.action == UserAction.edit;
    final needsReason =
        widget.action == UserAction.deactivate ||
        widget.action == UserAction.reactivate ||
        widget.action == UserAction.unlock;
    // ActionBuilder wraps the whole dialog so the submission state is available
    // to both the in-content error line (M1) and the submit button.
    return ActionBuilder(
      submissionFactory: _submission,
      builder: (context, state, submit) {
        // Close the dialog once the submission lands successfully; the reactive
        // views (users_index / user_role_scopes) reflect the change on their own.
        if (state is Success) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
        final detail = switch (state) {
          Denied(:final reason) => reason,
          Failed(:final error) => '$error',
          _ => null,
        };
        return AlertDialog(
          title: Text(_title),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (isEdit) ...<Widget>[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'New name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newEmail,
                    decoration: const InputDecoration(
                      labelText: 'New email (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (needsReason)
                  TextField(
                    controller: _reason,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(detail, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: state is Submitting ? null : submit,
              child: Text(switch (state) {
                Submitting() => '...',
                Denied() => 'Denied',
                Failed() => 'Failed',
                Success() => 'Done',
                _ => 'Submit',
              }),
            ),
          ],
        );
      },
    );
  }
}

/// Dispatches an [AssignmentPlan] for [userId] in sequence through [client]:
/// revoke sites/roles first, then assign sites/roles. Site-scoped pairs use
/// ACT-USR-008/011 (role + site); wildcard roles use ACT-USR-007/010 (role +
/// the role's wildcard ScopeValue). The [ActionClient] mints each submission's
/// idempotency key. Awaits each result so the materialized user_role_scopes view
/// converges deterministically.
///
/// Throws [_DispatchDeniedException] on the first non-success result so the
/// caller (create / role-site editor) surfaces a real failure rather than a
/// false 'Applied.'. The submissions themselves come from the pure
/// [assignmentSubmissions] builder.
Future<void> _applyPlan(
  ActionClient client,
  String userId,
  AssignmentPlan plan,
) async {
  for (final s in assignmentSubmissions(plan, userId, _roleScopesJsonFor)) {
    final r = await client.submit(s);
    if (r is! DispatchSuccess && r is! DispatchIdempotencyHit) {
      throw _DispatchDeniedException('${s.actionName}: ${_denialLabel(r)}');
    }
  }
}

/// Raised by [_applyPlan] when a submission returns a non-success
/// [DispatchResult]; its message carries the action + denial reason for display.
class _DispatchDeniedException implements Exception {
  const _DispatchDeniedException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _denialLabel(DispatchResult<Object?> r) => switch (r) {
  DispatchAuthorizationDenied(:final permission) => 'denied ($permission)',
  DispatchValidationDenied(:final error) => 'invalid ($error)',
  DispatchParseDenied(:final error) => 'parse ($error)',
  DispatchUnknownAction(:final requestedName) => 'unknown ($requestedName)',
  DispatchExecutionFailed(:final error) => 'failed ($error)',
  _ => 'denied',
};
