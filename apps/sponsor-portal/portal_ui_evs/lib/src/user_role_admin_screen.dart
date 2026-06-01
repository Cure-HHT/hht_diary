import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

// Permission-driven visibility: every action/view-exposing widget is wrapped in
// a PermissionGate keyed on the permission it needs, so a user only sees the
// widgets their active role holds. PermissionGate is reactive — it re-gates live
// on role switch or revocation. This is the template every future screen follows.
//
// Assign/Revoke Role (ACT-USR-007/010) take a full ScopeValue, so they generalize
// the site-only ACT-USR-008/011: the scope picker constructs BoundScope (one
// site), ValueWildcardScope (all sites — Administrator), or TotalWildcardScope
// (everything — System Operator). The user never types raw scope JSON.
const String _assignRoleAction =
    'ACT-USR-007'; // rawInput {userId, role, scope}
const String _revokeRoleAction =
    'ACT-USR-010'; // rawInput {userId, role, scope}
const String _assignRolePerm = 'portal.user.assign_role';
const String _revokeRolePerm = 'portal.user.revoke_role';
const String _viewAssignmentsPerm = 'view:user_role_scopes';
const List<String> _roles = <String>[
  'StudyCoordinator',
  'CRA',
  'Administrator',
  'SystemOperator',
];
const List<String> _sites = <String>['site-1', 'site-2', 'site-3'];

/// Scope-picker choices; the screen builds a ScopeValue from the choice (+ the
/// selected site for [thisSite]).
enum _ScopeKind { thisSite, allSites, everything }

String _scopeKindLabel(_ScopeKind k) => switch (k) {
      _ScopeKind.thisSite => 'this site',
      _ScopeKind.allSites => 'all sites',
      _ScopeKind.everything => 'everything',
    };

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

class UserRoleAdminScreen extends StatefulWidget {
  const UserRoleAdminScreen({super.key});
  @override
  State<UserRoleAdminScreen> createState() => _UserRoleAdminScreenState();
}

class _UserRoleAdminScreenState extends State<UserRoleAdminScreen> {
  final TextEditingController _targetUser = TextEditingController(
    text: 'target-1',
  );
  String _role = _roles.first;
  _ScopeKind _scopeKind = _ScopeKind.thisSite;
  String _site = _sites.first;

  ScopeValue _selectedScope() => switch (_scopeKind) {
        _ScopeKind.thisSite => BoundScope(class_: 'site', value: _site),
        _ScopeKind.allSites => const ValueWildcardScope(class_: 'site'),
        _ScopeKind.everything => const TotalWildcardScope(),
      };

  @override
  void dispose() {
    _targetUser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetUser.text.trim();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _targetUser,
            decoration: const InputDecoration(
              labelText: 'Target userId',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Assign-role form — only visible to roles that hold assign_role.
          PermissionGate(
            permission: _assignRolePerm,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text('Assign'),
                DropdownButton<String>(
                  value: _role,
                  items: <DropdownMenuItem<String>>[
                    for (final r in _roles)
                      DropdownMenuItem<String>(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const Text('@'),
                DropdownButton<_ScopeKind>(
                  value: _scopeKind,
                  items: <DropdownMenuItem<_ScopeKind>>[
                    for (final k in _ScopeKind.values)
                      DropdownMenuItem<_ScopeKind>(
                        value: k,
                        child: Text(_scopeKindLabel(k)),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _scopeKind = v ?? _scopeKind),
                ),
                if (_scopeKind == _ScopeKind.thisSite)
                  DropdownButton<String>(
                    value: _site,
                    items: <DropdownMenuItem<String>>[
                      for (final s in _sites)
                        DropdownMenuItem<String>(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => _site = v ?? _site),
                  ),
                ActionBuilder(
                  submissionFactory: () => ActionSubmission(
                    actionName: _assignRoleAction,
                    rawInput: <String, Object?>{
                      'userId': target,
                      'role': _role,
                      'scope': _selectedScope().toJson(),
                    },
                  ),
                  builder: (context, state, submit) => FilledButton(
                    onPressed: state is Submitting ? null : submit,
                    child: Text(switch (state) {
                      Submitting() => '...',
                      Denied() => 'Denied',
                      Failed() => 'Failed',
                      _ => 'Assign Role',
                    }),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          // Live list — gated on the view permission, so roles without it see a
          // clear "no access" message instead of a perpetual spinner (the server
          // denies their subscription).
          Expanded(
            child: PermissionGate(
              permission: _viewAssignmentsPerm,
              fallback: const Center(
                child: Text("You don't have permission to view assignments."),
              ),
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
                  if (state is Loading<_Assignment>) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final mine = rows.where((a) => a.userId == target).toList();
                  if (mine.isEmpty) {
                    return Center(
                      child: Text('(no assignments for "$target")'),
                    );
                  }
                  return ListView(
                    children: <Widget>[
                      for (final a in mine)
                        ListTile(
                          title: Text('${a.role}  ·  ${a.scopeLabel}'),
                          trailing: _RevokeButton(assignment: a),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevokeButton extends StatelessWidget {
  const _RevokeButton({required this.assignment});
  final _Assignment assignment;

  @override
  Widget build(BuildContext context) {
    // ACT-USR-010 takes the full ScopeValue, so it revokes any assignment —
    // BoundScope, value-wildcard, or total-wildcard alike.
    return PermissionGate(
      permission: _revokeRolePerm,
      child: ActionBuilder(
        submissionFactory: () => ActionSubmission(
          actionName: _revokeRoleAction,
          rawInput: <String, Object?>{
            'userId': assignment.userId,
            'role': assignment.role,
            'scope': assignment.scope.toJson(),
          },
        ),
        builder: (context, state, submit) => IconButton(
          tooltip: switch (state) {
            Denied() => 'Denied: ${state.reason}',
            Failed() => 'Failed',
            _ => 'Revoke',
          },
          onPressed: state is Submitting ? null : submit,
          icon: Icon(
            state is Submitting ? Icons.hourglass_empty : Icons.delete_outline,
          ),
        ),
      ),
    );
  }
}
