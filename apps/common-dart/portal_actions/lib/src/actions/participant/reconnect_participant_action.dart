// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-004 Reconnect Participant; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class ReconnectParticipantInput {
  const ReconnectParticipantInput({
    required this.siteId,
    required this.participantId,
    required this.linkingCode,
    required this.expiresAt,
  });
  final String siteId;
  final String participantId;
  final String linkingCode;
  final String expiresAt;
}

class ReconnectParticipantResult {
  const ReconnectParticipantResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-004: reconnect a participant after a disconnect, issuing a new
/// linking code. Emits `participant_linking_code_issued` then
/// `participant_reconnected`, both sharing a single flowToken. Mints a flowToken
/// correlating this fact with the Phase-2 participant-notification subscriber
/// that emits notification_sent.
class ReconnectParticipantAction
    extends Action<ReconnectParticipantInput, ReconnectParticipantResult> {
  ReconnectParticipantAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-PAT-004';

  @override
  String get description =>
      'Reconnect a participant after a disconnect; issues a new linking code. '
      'Emits participant_linking_code_issued + participant_reconnected.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-004']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ReconnectParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    final linkingCode = raw['linkingCode'];
    final expiresAt = raw['expiresAt'];
    if (siteId is! String ||
        participantId is! String ||
        linkingCode is! String ||
        expiresAt is! String) {
      throw const FormatException(
        'ReconnectParticipantAction expects {siteId, participantId, linkingCode, expiresAt}: String',
      );
    }
    return ReconnectParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
      linkingCode: linkingCode.trim(),
      expiresAt: expiresAt.trim(),
    );
  }

  @override
  void validate(ReconnectParticipantInput input) {
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
  ScopeValue? scopeFor(Permission perm, ReconnectParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<ReconnectParticipantResult>> execute(
    ReconnectParticipantInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next();
    return ExecutionResult<ReconnectParticipantResult>(
      result: ReconnectParticipantResult(participantId: input.participantId),
      events: <EventDraft>[
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
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_reconnected',
          eventType: 'participant_reconnected',
          flowToken: flowToken,
          data: <String, Object?>{'by': ctx.principal.id},
        ),
      ],
    );
  }
}
