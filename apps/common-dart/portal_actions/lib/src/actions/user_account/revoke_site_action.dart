// Implements: DIARY-PRD-user-account-edit/E — revoking one Site appends a
//   role_unassigned of BoundScope('site', X) under a role, enforced on the next
//   dispatch (the row is removed from user_role_scopes).
// Implements: DIARY-PRD-action-inventory/A — declares the portal.user.revoke_site
//   permission the dispatcher enforces RBAC against.
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class RevokeSiteInput {
  RevokeSiteInput({
    required this.userId,
    required this.role,
    required this.site,
  });
  final String userId;
  final String role;
  final String site;

  ScopeValue get scope => BoundScope(class_: 'site', value: site);
}

class RevokeSiteResult {
  const RevokeSiteResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-011: revoke one Site from a staff user under a role. Emits a single
/// role_unassigned whose scope is BoundScope('site', site).
class RevokeSiteAction extends Action<RevokeSiteInput, RevokeSiteResult> {
  RevokeSiteAction();

  @override
  String get name => 'ACT-USR-011';

  @override
  String get description =>
      'Revoke one Site from a staff user under a role. Emits a single '
      'role_unassigned with scope BoundScope(site, X).';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-011']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  RevokeSiteInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final role = raw['role'];
    final site = raw['site'];
    if (userId is! String || role is! String || site is! String) {
      throw const FormatException(
        'RevokeSiteAction expects {userId, role, site}: String',
      );
    }
    return RevokeSiteInput(
      userId: userId.trim(),
      role: role.trim(),
      site: site.trim(),
    );
  }

  @override
  void validate(RevokeSiteInput input) {
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
  Future<ExecutionResult<RevokeSiteResult>> execute(
    RevokeSiteInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<RevokeSiteResult>(
      result: RevokeSiteResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'user_role_scope',
          aggregateId: computeRoleAssignmentAggregateId(
            userId: input.userId,
            role: input.role,
            scope: input.scope,
          ),
          entryType: 'user_role_scope',
          eventType: 'role_unassigned',
          data: RoleUnassignedPayload(
            userId: input.userId,
            role: input.role,
            scope: input.scope,
          ).toJson(),
        ),
      ],
    );
  }
}
