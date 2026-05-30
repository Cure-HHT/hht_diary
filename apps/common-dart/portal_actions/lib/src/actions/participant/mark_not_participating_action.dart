// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-005 Mark Not Participating; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class MarkNotParticipatingInput {
  const MarkNotParticipatingInput({
    required this.siteId,
    required this.participantId,
    required this.reason,
  });
  final String siteId;
  final String participantId;
  final String reason;
}

class MarkNotParticipatingResult {
  const MarkNotParticipatingResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-005: mark a participant as not participating.
/// Emits `participant_marked_not_participating`. Mints a flowToken correlating
/// this fact with the Phase-2 participant-notification subscriber that emits
/// notification_sent.
class MarkNotParticipatingAction
    extends Action<MarkNotParticipatingInput, MarkNotParticipatingResult> {
  MarkNotParticipatingAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-PAT-005';

  @override
  String get description =>
      'Mark a participant as not participating. '
      'Emits participant_marked_not_participating.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-005']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  MarkNotParticipatingInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    final reason = raw['reason'];
    if (siteId is! String || participantId is! String || reason is! String) {
      throw const FormatException(
        'MarkNotParticipatingAction expects {siteId, participantId, reason}: String',
      );
    }
    return MarkNotParticipatingInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
      reason: reason.trim(),
    );
  }

  @override
  void validate(MarkNotParticipatingInput input) {
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
  ScopeValue? scopeFor(Permission perm, MarkNotParticipatingInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<MarkNotParticipatingResult>> execute(
    MarkNotParticipatingInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next();
    return ExecutionResult<MarkNotParticipatingResult>(
      result: MarkNotParticipatingResult(participantId: input.participantId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_marked_not_participating',
          eventType: 'participant_marked_not_participating',
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
