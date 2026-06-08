// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-002 Start Trial; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class StartTrialInput {
  const StartTrialInput({required this.siteId, required this.participantId});
  final String siteId;
  final String participantId;
}

class StartTrialResult {
  const StartTrialResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-002: start a participant's trial. Emits `participant_trial_started`;
/// the participant notification is a Phase-2 subscriber on that fact.
class StartTrialAction extends Action<StartTrialInput, StartTrialResult> {
  StartTrialAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-PAT-002';

  @override
  String get description =>
      'Start a participant trial. Emits participant_trial_started; the '
      'notification is driven by a Phase-2 subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-002']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  StartTrialInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    if (siteId is! String || participantId is! String) {
      throw const FormatException(
        'StartTrialAction expects {siteId, participantId}: String',
      );
    }
    return StartTrialInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
    );
  }

  @override
  void validate(StartTrialInput input) {
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
  }

  @override
  ScopeValue? scopeFor(Permission perm, StartTrialInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<StartTrialResult>> execute(
    StartTrialInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'PAT');
    return ExecutionResult<StartTrialResult>(
      result: StartTrialResult(participantId: input.participantId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_trial_started',
          eventType: 'participant_trial_started',
          flowToken: flowToken,
          data: <String, Object?>{
            // NOTE: started_at is folded into participant_record by a key-wise
            // merge (latest-wins), so re-running Start Trial OVERWRITES the
            // original trial-start date — moving the diary's sync watermark
            // forward and dropping pre-reactivation entries. This action is
            // read-free (ActionContext has no state access) so it cannot itself
            // be first-write-wins; re-issue after a reactivate+re-link is
            // prevented at the portal UI, which reports an already-started,
            // re-linked participant as Trial Active (effectiveParticipantStatus)
            // and does not offer Start Trial.
            // Canonical UTC with a 'Z' designator (matches every other portal
            // timestamp, e.g. used_at/activated_at). Without toUtc() a non-UTC
            // requestStartedAt serializes WITHOUT 'Z', so the diary parses it as
            // LOCAL time and the trial-start sync watermark lands hours off,
            // silently gating outbound sync in any non-UTC client timezone.
            'started_at': ctx.requestStartedAt.toUtc().toIso8601String(),
            'by': ctx.principal.id,
          },
        ),
      ],
    );
  }
}
