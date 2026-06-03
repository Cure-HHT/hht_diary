// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-003 Disconnect Participant; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class DisconnectParticipantInput {
  const DisconnectParticipantInput({
    required this.siteId,
    required this.participantId,
    required this.reason,
  });
  final String siteId;
  final String participantId;
  final String reason;
}

class DisconnectParticipantResult {
  const DisconnectParticipantResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-003: disconnect a participant from their device/site association.
/// Emits `participant_disconnected`. Mints a flowToken correlating this fact
/// with the Phase-2 participant-notification subscriber that emits notification_sent.
class DisconnectParticipantAction
    extends Action<DisconnectParticipantInput, DisconnectParticipantResult> {
  DisconnectParticipantAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-PAT-003';

  @override
  String get description =>
      'Disconnect a participant from their device/site association. '
      'Emits participant_disconnected.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-003']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  DisconnectParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    final reason = raw['reason'];
    if (siteId is! String || participantId is! String || reason is! String) {
      throw const FormatException(
        'DisconnectParticipantAction expects {siteId, participantId, reason}: String',
      );
    }
    return DisconnectParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
      reason: reason.trim(),
    );
  }

  @override
  void validate(DisconnectParticipantInput input) {
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
  }

  @override
  ScopeValue? scopeFor(Permission perm, DisconnectParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<DisconnectParticipantResult>> execute(
    DisconnectParticipantInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'PAT');
    return ExecutionResult<DisconnectParticipantResult>(
      result: DisconnectParticipantResult(participantId: input.participantId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_disconnected',
          eventType: 'participant_disconnected',
          flowToken: flowToken,
          data: <String, Object?>{
            'reason': input.reason,
            'by': ctx.principal.id,
          },
        ),
      ],
    );
  }
}
