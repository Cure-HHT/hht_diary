import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'user_account_logic.dart';

// Implements: DIARY-DEV-user-account-projection/A+C

const String _createAction = 'ACT-USR-001';

const List<String> _roles = <String>[
  'StudyCoordinator',
  'CRA',
  'Administrator',
  'SystemOperator',
];

/// Create-user dialog. Lifted from the legacy `user_accounts_screen.dart`
/// so the redesigned `UsersScreen` binding can open it from its
/// `onCreate` callback without depending on the legacy screen.
///
/// Email + name, a role multi-select, and (when any selected role is
/// site-scoped) a site multi-select. On Create it dispatches
/// `ACT-USR-001` then realizes the role/site assignment plan
/// sequentially through the action submitter.
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
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
    final client = ActionClient(ReActionScope.of(context).actionSubmitter);
    final sites = _selectedSites.toList();
    try {
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
              for (final r in _roles)
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

/// Role-level scopes a non-site role's assignment carries. See the legacy
/// `user_accounts_screen.dart` for the rationale (Administrator needs
/// site-wildcard + staff-tier; SystemOperator a single total-wildcard).
List<Object> _roleScopesJsonFor(String role) => switch (roleScopeKind(role)) {
  RoleScopeKind.allSites => <Object>[
    const ValueWildcardScope(class_: 'site').toJson(),
    const BoundScope(class_: 'tier', value: 'staff').toJson(),
  ],
  RoleScopeKind.everything => <Object>[const TotalWildcardScope().toJson()],
  RoleScopeKind.site => throw StateError(
    '_roleScopesJsonFor called for site-scoped role $role',
  ),
};

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
