// Implements: DIARY-PRD-user-account-edit/E — assigning a role-scope appends a
//   role_assigned event the user_role_scopes projection folds, so the change is
//   enforced on the next dispatch (single (user, role, scope) tuple).
// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class AssignRoleInput {
  AssignRoleInput({
    required this.userId,
    required this.role,
    required this.scope,
  });
  final String userId;
  final String role;
  final ScopeValue scope;
}

class AssignRoleResult {
  const AssignRoleResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-007: assign one role-scope to a staff user account. Emits a single
/// role_assigned event for the (userId, role, scope) tuple.
class AssignRoleAction extends Action<AssignRoleInput, AssignRoleResult> {
  AssignRoleAction();

  @override
  String get name => 'ACT-USR-007';

  @override
  String get description =>
      'Assign one role-scope to a staff user. Emits a single role_assigned '
      'event for the (user, role, scope) tuple.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-007']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  AssignRoleInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final role = raw['role'];
    final scopeJson = raw['scope'];
    if (userId is! String || role is! String) {
      throw const FormatException(
        'AssignRoleAction expects {userId, role}: String',
      );
    }
    if (scopeJson is! Map) {
      throw const FormatException('AssignRoleAction expects {scope}: object');
    }
    return AssignRoleInput(
      userId: userId.trim(),
      role: role.trim(),
      scope: ScopeValue.fromJson(scopeJson.cast<String, Object?>()),
    );
  }

  @override
  void validate(AssignRoleInput input) {
    if (input.userId.isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.role.isEmpty) {
      throw ArgumentError.value(input.role, 'role', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<AssignRoleResult>> execute(
    AssignRoleInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<AssignRoleResult>(
      result: AssignRoleResult(userId: input.userId),
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
