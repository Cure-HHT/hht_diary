// Implements: DIARY-PRD-user-account-site-assignment/D — assign one Site to a
//   user as a BoundScope('site', X) under a role; emits a single role_assigned.
// Implements: DIARY-PRD-user-account-edit/E — the Site change is enforced on the
//   next dispatch (role_assigned folds into user_role_scopes).
// Implements: DIARY-PRD-action-inventory/A — declares the portal.user.assign_site
//   permission the dispatcher enforces RBAC against.
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class AssignSiteInput {
  AssignSiteInput({
    required this.userId,
    required this.role,
    required this.site,
  });
  final String userId;
  final String role;
  final String site;

  ScopeValue get scope => BoundScope(class_: 'site', value: site);
}

class AssignSiteResult {
  const AssignSiteResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-008: assign one Site to a staff user under a role. Emits a single
/// role_assigned event whose scope is BoundScope('site', site).
class AssignSiteAction extends Action<AssignSiteInput, AssignSiteResult> {
  AssignSiteAction();

  @override
  String get name => 'ACT-USR-008';

  @override
  String get description =>
      'Assign one Site to a staff user under a role. Emits a single '
      'role_assigned with scope BoundScope(site, X).';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-008']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  AssignSiteInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final role = raw['role'];
    final site = raw['site'];
    if (userId is! String || role is! String || site is! String) {
      throw const FormatException(
        'AssignSiteAction expects {userId, role, site}: String',
      );
    }
    return AssignSiteInput(
      userId: userId.trim(),
      role: role.trim(),
      site: site.trim(),
    );
  }

  @override
  void validate(AssignSiteInput input) {
    if (input.userId.isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.role.isEmpty) {
      throw ArgumentError.value(input.role, 'role', 'must be non-empty');
    }
    if (input.site.isEmpty) {
      throw ArgumentError.value(input.site, 'site', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<AssignSiteResult>> execute(
    AssignSiteInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<AssignSiteResult>(
      result: AssignSiteResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'user_role_scope',
          aggregateId: computeRoleAssignmentAggregateId(
            userId: input.userId,
            role: input.role,
            scope: input.scope,
          ),
          entryType: 'user_role_scope',
          eventType: 'role_assigned',
          data: RoleAssignedPayload(
            userId: input.userId,
            role: input.role,
            scope: input.scope,
          ).toJson(),
        ),
      ],
    );
  }
}
