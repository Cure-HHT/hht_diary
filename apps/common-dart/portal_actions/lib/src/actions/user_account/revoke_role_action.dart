// Implements: DIARY-PRD-user-account-edit/E — revoking a role-scope appends a
//   role_unassigned event removing the (user, role, scope) row from
//   user_role_scopes, enforced on the next dispatch.
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class RevokeRoleInput {
  RevokeRoleInput({
    required this.userId,
    required this.role,
    required this.scope,
  });
  final String userId;
  final String role;
  final ScopeValue scope;
}

class RevokeRoleResult {
  const RevokeRoleResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-010: revoke one role-scope from a staff user. Emits a single
/// role_unassigned for the (userId, role, scope) tuple.
class RevokeRoleAction extends Action<RevokeRoleInput, RevokeRoleResult> {
  RevokeRoleAction();

  @override
  String get name => 'ACT-USR-010';

  @override
  String get description =>
      'Revoke one role-scope from a staff user. Emits a single role_unassigned '
      'for the (user, role, scope) tuple.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-010']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  RevokeRoleInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final role = raw['role'];
    final scopeJson = raw['scope'];
    if (userId is! String || role is! String) {
      throw const FormatException(
        'RevokeRoleAction expects {userId, role}: String',
      );
    }
    if (scopeJson is! Map) {
      throw const FormatException('RevokeRoleAction expects {scope}: object');
    }
    return RevokeRoleInput(
      userId: userId.trim(),
      role: role.trim(),
      scope: ScopeValue.fromJson(scopeJson.cast<String, Object?>()),
    );
  }

  @override
  void validate(RevokeRoleInput input) {
    if (input.userId.isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.role.isEmpty) {
      throw ArgumentError.value(input.role, 'role', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<RevokeRoleResult>> execute(
    RevokeRoleInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<RevokeRoleResult>(
      result: RevokeRoleResult(userId: input.userId),
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
