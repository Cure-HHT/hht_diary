// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class AssignRoleInput {
  AssignRoleInput({
    required this.userId,
    required this.roles,
    // Phase 2: previousRoles is caller-supplied; Phase 2 reads from a projection.
    required this.previousRoles,
  });
  final String userId;
  final List<String> roles;
  final List<String> previousRoles;
}

class AssignRoleResult {
  const AssignRoleResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-007: assign roles to a staff user account. Emits user_roles_changed;
/// if the change narrows authz (a role is removed), also emits
/// user_sessions_revoked to invalidate existing sessions.
class AssignRoleAction extends Action<AssignRoleInput, AssignRoleResult> {
  AssignRoleAction();

  @override
  String get name => 'ACT-USR-007';

  @override
  String get description =>
      'Assign roles to a staff user. Emits user_roles_changed; also emits '
      'user_sessions_revoked when authz is narrowed (a role is removed).';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-007']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  AssignRoleInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    if (userId is! String) {
      throw const FormatException('AssignRoleAction expects {userId}: String');
    }
    final rawRoles = raw['roles'];
    if (rawRoles is! List || !rawRoles.every((dynamic e) => e is String)) {
      throw const FormatException(
        'AssignRoleAction: roles must be a List<String>',
      );
    }
    final rawPreviousRoles = raw['previousRoles'];
    if (rawPreviousRoles is! List ||
        !rawPreviousRoles.every((dynamic e) => e is String)) {
      throw const FormatException(
        'AssignRoleAction: previousRoles must be a List<String>',
      );
    }
    return AssignRoleInput(
      userId: userId.trim(),
      roles: List<String>.from(rawRoles),
      previousRoles: List<String>.from(rawPreviousRoles),
    );
  }

  @override
  void validate(AssignRoleInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<AssignRoleResult>> execute(
    AssignRoleInput input,
    ActionContext ctx,
  ) async {
    final events = <EventDraft>[
      EventDraft(
        aggregateType: 'portal_user',
        aggregateId: input.userId,
        entryType: 'user_roles_changed',
        eventType: 'user_roles_changed',
        data: <String, Object?>{
          'before': input.previousRoles,
          'after': input.roles,
          'changed_by': ctx.principal.id,
        },
      ),
    ];
    // Narrowing: a role was removed → authz narrows → revoke sessions.
    final narrowed = input.previousRoles
        .toSet()
        .difference(input.roles.toSet())
        .isNotEmpty;
    if (narrowed) {
      events.add(
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_sessions_revoked',
          eventType: 'user_sessions_revoked',
          data: <String, Object?>{
            'reason_kind': 'authz_narrowed',
            'by': ctx.principal.id,
          },
        ),
      );
    }
    return ExecutionResult<AssignRoleResult>(
      result: AssignRoleResult(userId: input.userId),
      events: events,
    );
  }
}
