// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class UnlockUserAccountInput {
  const UnlockUserAccountInput({required this.userId, required this.reason});
  final String userId;
  final String reason;
}

class UnlockUserAccountResult {
  const UnlockUserAccountResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-005: unlock a locked staff user account. Emits user_account_unlocked.
class UnlockUserAccountAction
    extends Action<UnlockUserAccountInput, UnlockUserAccountResult> {
  UnlockUserAccountAction();

  @override
  String get name => 'ACT-USR-005';

  @override
  String get description =>
      'Unlock a locked staff user account (reason required). '
      'Emits user_account_unlocked.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-005']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  UnlockUserAccountInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final reason = raw['reason'];
    if (userId is! String || reason is! String) {
      throw const FormatException(
        'UnlockUserAccountAction expects {userId, reason}: String',
      );
    }
    return UnlockUserAccountInput(userId: userId.trim(), reason: reason.trim());
  }

  @override
  void validate(UnlockUserAccountInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.reason.trim().isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
  }

  // Implements: DIARY-DEV-operator-tier-authz/C
  @override
  ScopeValue? scopeFor(Permission perm, UnlockUserAccountInput input) =>
      perm.scopeClass == 'user'
      ? BoundScope(class_: 'user', value: input.userId)
      : null;

  @override
  Future<ExecutionResult<UnlockUserAccountResult>> execute(
    UnlockUserAccountInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<UnlockUserAccountResult>(
      result: UnlockUserAccountResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_account_unlocked',
          eventType: 'user_account_unlocked',
          data: <String, Object?>{
            'by': ctx.principal.id,
            'reason': input.reason,
          },
        ),
      ],
    );
  }
}
