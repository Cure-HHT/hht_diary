import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

const String _assignSiteAction = 'ACT-USR-008'; // rawInput {userId, role, site}
const String _revokeSiteAction = 'ACT-USR-011';
const List<String> _roles = <String>['StudyCoordinator', 'CRA'];
const List<String> _sites = <String>['site-1', 'site-2', 'site-3'];

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

  String? get siteValue =>
      scope is BoundScope ? (scope as BoundScope).value : null;

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
  final TextEditingController _targetUser =
      TextEditingController(text: 'target-1');
  String _role = _roles.first;
  String _site = _sites.first;

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
          // Assign-site form.
          Wrap(
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
                  actionName: _assignSiteAction,
                  rawInput: <String, Object?>{
                    'userId': target,
                    'role': _role,
                    'site': _site,
                  },
                ),
                builder: (context, state, submit) => FilledButton(
                  onPressed: state is Submitting ? null : submit,
                  child: Text(switch (state) {
                    Submitting() => '...',
                    Denied() => 'Denied',
                    Failed() => 'Failed',
                    _ => 'Assign Site',
                  }),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Live list of all assignments (user filters client-side).
          Expanded(
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
                  return Center(child: Text('(no assignments for "$target")'));
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
    final site = assignment.siteValue;
    if (site == null) {
      // Non-site (wildcard) scopes aren't revocable via the site-only slice.
      return const SizedBox.shrink();
    }
    return ActionBuilder(
      submissionFactory: () => ActionSubmission(
        actionName: _revokeSiteAction,
        rawInput: <String, Object?>{
          'userId': assignment.userId,
          'role': assignment.role,
          'site': site,
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
    );
  }
}
