// Implements: DIARY-PRD-action-inventory/A
// Implements: DIARY-DEV-shared-events-catalog/D
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class ResendActivationEmailInput {
  ResendActivationEmailInput({
    required this.userId,
    required this.activationExpiresAt,
  });
  final String userId;
  final String activationExpiresAt;
}

class ResendActivationEmailResult {
  const ResendActivationEmailResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-006: resend an activation email to a pending staff user. Emits
/// user_activation_code_issued (reissue: true); the flowToken correlates
/// with the Phase-2 email/notification subscriber.
class ResendActivationEmailAction
    extends Action<ResendActivationEmailInput, ResendActivationEmailResult> {
  ResendActivationEmailAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-USR-006';

  @override
  String get description =>
      'Resend activation email to a pending staff user. Emits '
      'user_activation_code_issued (reissue: true); the activation email is '
      'driven by a Phase-2 notification subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-006']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ResendActivationEmailInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final activationExpiresAt = raw['activationExpiresAt'];
    if (userId is! String || activationExpiresAt is! String) {
      throw const FormatException(
        'ResendActivationEmailAction expects '
        '{userId, activationExpiresAt}: String',
      );
    }
    return ResendActivationEmailInput(
      userId: userId.trim(),
      activationExpiresAt: activationExpiresAt.trim(),
    );
  }

  @override
  void validate(ResendActivationEmailInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.activationExpiresAt.trim().isEmpty) {
      throw ArgumentError.value(
        input.activationExpiresAt,
        'activationExpiresAt',
        'must be non-empty',
      );
    }
  }

  // Implements: DIARY-DEV-operator-tier-authz/C
  @override
  ScopeValue? scopeFor(Permission perm, ResendActivationEmailInput input) =>
      perm.scopeClass == 'user'
      ? BoundScope(class_: 'user', value: input.userId)
      : null;

  @override
  Future<ExecutionResult<ResendActivationEmailResult>> execute(
    ResendActivationEmailInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'USR');
    return ExecutionResult<ResendActivationEmailResult>(
      result: ResendActivationEmailResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_activation_code_issued',
          eventType: 'user_activation_code_issued',
          flowToken: flowToken,
          data: <String, Object?>{
            'expires_at': input.activationExpiresAt,
            'issued_by': ctx.principal.id,
            'reissue': true,
          },
        ),
      ],
    );
  }
}
