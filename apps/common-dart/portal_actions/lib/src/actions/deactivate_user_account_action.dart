// Implements: DIARY-PRD-action-inventory/A+B
// Implements: DIARY-DEV-shared-events-catalog/A
// Implements: DIARY-DEV-user-account-projection/B
import 'package:event_sourcing/event_sourcing.dart';

import '../portal_permissions.dart';

class DeactivateUserAccountInput {
  const DeactivateUserAccountInput({
    required this.userId,
    required this.reason,
  });
  final String userId;
  final String reason;
}

class DeactivateUserAccountResult {
  const DeactivateUserAccountResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-003: deactivate a staff account. Emits user_deactivated +
/// user_sessions_revoked; the actual session kill is driven by a subscriber
/// on user_sessions_revoked (outbox pattern), not here.
class DeactivateUserAccountAction
    extends Action<DeactivateUserAccountInput, DeactivateUserAccountResult> {
  DeactivateUserAccountAction();

  @override
  String get name => 'ACT-USR-003';

  @override
  String get description =>
      'Deactivate a staff user account (reason required); revokes active '
      'sessions. Emits user_deactivated + user_sessions_revoked.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-003']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  DeactivateUserAccountInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final reason = raw['reason'];
    if (userId is! String || reason is! String) {
      throw const FormatException(
        'DeactivateUserAccountAction expects {userId, reason}: String',
      );
    }
    // Normalize at the parse boundary so emitted events carry a canonical
    // aggregateId (audit-safety: no whitespace-variant duplicate aggregates).
    return DeactivateUserAccountInput(
      userId: userId.trim(),
      reason: reason.trim(),
    );
  }

  @override
  void validate(DeactivateUserAccountInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.reason.trim().isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<DeactivateUserAccountResult>> execute(
    DeactivateUserAccountInput input,
    ActionContext ctx,
  ) async {
    final events = <EventDraft>[
      EventDraft(
        aggregateType: 'portal_user',
        aggregateId: input.userId,
        entryType: 'user_deactivated',
        eventType: 'user_deactivated',
        data: <String, Object?>{
          'reason': input.reason,
          'deactivated_by': ctx.principal.id,
          'status': 'revoked',
        },
      ),
      EventDraft(
        aggregateType: 'portal_user',
        aggregateId: input.userId,
        entryType: 'user_sessions_revoked',
        eventType: 'user_sessions_revoked',
        data: <String, Object?>{
          'reason_kind': 'deactivated',
          'by': ctx.principal.id,
        },
      ),
    ];
    return ExecutionResult<DeactivateUserAccountResult>(
      result: DeactivateUserAccountResult(userId: input.userId),
      events: events,
    );
  }
}
