// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-006 Reactivate Participant; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class ReactivateParticipantInput {
  const ReactivateParticipantInput({
    required this.siteId,
    required this.participantId,
    required this.reason,
    required this.linkingCode,
    required this.expiresAt,
  });
  final String siteId;
  final String participantId;
  final String reason;
  final String linkingCode;
  final String expiresAt;
}

class ReactivateParticipantResult {
  const ReactivateParticipantResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-006: reactivate a not-participating participant and issue a new
/// linking code. Emits `participant_reactivated` then
/// `participant_linking_code_issued`, both sharing a single flowToken. Mints a
/// flowToken correlating this fact with the Phase-2 participant-notification
/// subscriber that emits notification_sent.
class ReactivateParticipantAction
    extends Action<ReactivateParticipantInput, ReactivateParticipantResult> {
  ReactivateParticipantAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-PAT-006';

  @override
  String get description =>
      'Reactivate a not-participating participant and issue a new linking code. '
      'Emits participant_reactivated + participant_linking_code_issued.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-006']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ReactivateParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    final reason = raw['reason'];
    final linkingCode = raw['linkingCode'];
    final expiresAt = raw['expiresAt'];
    if (siteId is! String ||
        participantId is! String ||
        reason is! String ||
        linkingCode is! String ||
        expiresAt is! String) {
      throw const FormatException(
        'ReactivateParticipantAction expects {siteId, participantId, reason, linkingCode, expiresAt}: String',
      );
    }
    return ReactivateParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
      reason: reason.trim(),
      linkingCode: linkingCode.trim(),
      expiresAt: expiresAt.trim(),
    );
  }

  @override
  void validate(ReactivateParticipantInput input) {
    if (input.siteId.isEmpty) {
      throw ArgumentError.value(input.siteId, 'siteId', 'must be non-empty');
    }
    if (input.participantId.isEmpty) {
      throw ArgumentError.value(
        input.participantId,
        'participantId',
        'must be non-empty',
      );
    }
    if (input.reason.isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
    if (input.linkingCode.isEmpty) {
      throw ArgumentError.value(
        input.linkingCode,
        'linkingCode',
        'must be non-empty',
      );
    }
    if (input.expiresAt.isEmpty) {
      throw ArgumentError.value(
        input.expiresAt,
        'expiresAt',
        'must be non-empty',
      );
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, ReactivateParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<ReactivateParticipantResult>> execute(
    ReactivateParticipantInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next();
    return ExecutionResult<ReactivateParticipantResult>(
      result: ReactivateParticipantResult(participantId: input.participantId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_reactivated',
          eventType: 'participant_reactivated',
          flowToken: flowToken,
          data: <String, Object?>{
            'reason': input.reason,
            'by': ctx.principal.id,
          },
        ),
        // purpose 'reconnect' (the code's function is device reconnection); the
        // reactivation context is carried by the co-emitted participant_reactivated
        // event sharing this flowToken — distinct from ACT-PAT-004's participant_reconnected.
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_linking_code_issued',
          eventType: 'participant_linking_code_issued',
          flowToken: flowToken,
          data: <String, Object?>{
            'linking_code': input.linkingCode,
            'generated_by': ctx.principal.id,
            'expires_at': input.expiresAt,
            'purpose': 'reconnect',
          },
        ),
      ],
    );
  }
}
