// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class DeletePendingUserInput {
  const DeletePendingUserInput({required this.userId});
  final String userId;
}

class DeletePendingUserResult {
  const DeletePendingUserResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-009: delete a pending (not-yet-activated) staff user account.
/// Emits user_deleted.
class DeletePendingUserAction
    extends Action<DeletePendingUserInput, DeletePendingUserResult> {
  DeletePendingUserAction();

  @override
  String get name => 'ACT-USR-009';

  @override
  String get description =>
      'Delete a pending (not-yet-activated) staff user account. '
      'Emits user_deleted.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-009']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  DeletePendingUserInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    if (userId is! String) {
      throw const FormatException(
        'DeletePendingUserAction expects {userId}: String',
      );
    }
    return DeletePendingUserInput(userId: userId.trim());
  }

  @override
  void validate(DeletePendingUserInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<DeletePendingUserResult>> execute(
    DeletePendingUserInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<DeletePendingUserResult>(
      result: DeletePendingUserResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_deleted',
          eventType: 'user_deleted',
          data: <String, Object?>{'deleted_by': ctx.principal.id},
        ),
      ],
    );
  }
}
