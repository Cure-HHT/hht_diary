// Implements: DIARY-PRD-action-inventory/A
// Implements: DIARY-DEV-shared-events-catalog/D
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class ReactivateUserAccountInput {
  ReactivateUserAccountInput({
    required this.userId,
    required this.reason,
    required this.activationExpiresAt,
  });
  final String userId;
  final String reason;
  final String activationExpiresAt;
}

class ReactivateUserAccountResult {
  const ReactivateUserAccountResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-004: reactivate a deactivated staff user account. Emits
/// user_reactivated + user_activation_code_issued (same flowToken). The
/// flowToken correlates with the Phase-2 email/notification subscriber.
class ReactivateUserAccountAction
    extends Action<ReactivateUserAccountInput, ReactivateUserAccountResult> {
  ReactivateUserAccountAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-USR-004';

  @override
  String get description =>
      'Reactivate a deactivated staff user account. Emits user_reactivated + '
      'user_activation_code_issued; the activation email is driven by a '
      'Phase-2 notification subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-004']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ReactivateUserAccountInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final reason = raw['reason'];
    final activationExpiresAt = raw['activationExpiresAt'];
    if (userId is! String ||
        reason is! String ||
        activationExpiresAt is! String) {
      throw const FormatException(
        'ReactivateUserAccountAction expects '
        '{userId, reason, activationExpiresAt}: String',
      );
    }
    return ReactivateUserAccountInput(
      userId: userId.trim(),
      reason: reason.trim(),
      activationExpiresAt: activationExpiresAt.trim(),
    );
  }

  @override
  void validate(ReactivateUserAccountInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.reason.trim().isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
    if (input.activationExpiresAt.trim().isEmpty) {
      throw ArgumentError.value(
        input.activationExpiresAt,
        'activationExpiresAt',
        'must be non-empty',
      );
    }
  }

  @override
  Future<ExecutionResult<ReactivateUserAccountResult>> execute(
    ReactivateUserAccountInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'USR');
    return ExecutionResult<ReactivateUserAccountResult>(
      result: ReactivateUserAccountResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_reactivated',
          eventType: 'user_reactivated',
          flowToken: flowToken,
          data: <String, Object?>{
            'reason': input.reason,
            'by': ctx.principal.id,
          },
        ),
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_activation_code_issued',
          eventType: 'user_activation_code_issued',
          flowToken: flowToken,
          data: <String, Object?>{
            'expires_at': input.activationExpiresAt,
            'issued_by': ctx.principal.id,
            'reissue': false,
          },
        ),
      ],
    );
  }
}
