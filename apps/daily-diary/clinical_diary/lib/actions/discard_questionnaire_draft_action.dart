// Per-app diary Action: discards a diary-LOCAL questionnaire `checkpoint`
// draft whose Session reached Session Expiry (CUR-1543). Emits ONE
// `draft_discarded` event on the SAME `<id>_survey` aggregate the checkpoint
// lives on; `diaryIncompleteProjection` treats `draft_discarded` as a
// tombstone-type event, so the draft row is removed and the flow can no longer
// resume from it.
//
// Deliberately NOT the cross-wire `tombstone` eventType: DiaryServerDestination
// ships `finalized` + `tombstone` DiaryEntry events, and a draft the portal has
// never seen (checkpoints never sync) must not ship a tombstone for an
// aggregate unknown to the portal. `draft_discarded` stays diary-local by
// construction, exactly like the `checkpoint` it deletes. For the same reason
// `reason` is a local free field (default `session-expired`) rather than a
// member of the frozen cross-wire `changeReason` vocabulary.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Parsed input for a draft discard: which instance + questionnaire, and why.
class DiscardQuestionnaireDraftInput {
  const DiscardQuestionnaireDraftInput({
    required this.instanceId,
    required this.questionnaireType,
    required this.reason,
  });

  final String instanceId;
  final String questionnaireType;
  final String reason;
}

/// Discards an in-progress questionnaire draft by emitting a diary-local
/// `draft_discarded` event on the `<id>_survey` aggregate. Returns the
/// survey-instance aggregate id.
// Implements: DIARY-PRD-questionnaire-session-timeout/C — on Session Expiry
//   the answers selected so far (the local checkpoint draft) are discarded.
// Implements: DIARY-GUI-questionnaire-session-expiry/B — host-side discard of
//   the expired draft before the Session Expiry Dialog is presented.
// Implements: DIARY-DEV-action-write-path/A
class DiscardQuestionnaireDraftAction
    extends Action<DiscardQuestionnaireDraftInput, String> {
  const DiscardQuestionnaireDraftAction();

  @override
  String get name => 'discard_questionnaire_draft';

  @override
  String get description =>
      'Discard an expired in-progress questionnaire draft (diary-local '
      'draft_discarded on the <id>_survey aggregate; never synced).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.submit_questionnaire'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  DiscardQuestionnaireDraftInput parseInput(Map<String, Object?> raw) {
    final instanceId = raw['instance_id'];
    final questionnaireType = raw['questionnaire_type'];
    final reason = raw['reason'] ?? 'session-expired';
    if (instanceId is! String || instanceId.isEmpty) {
      throw const FormatException('instance_id is required');
    }
    if (questionnaireType is! String || questionnaireType.isEmpty) {
      throw const FormatException('questionnaire_type is required');
    }
    if (reason is! String || reason.isEmpty) {
      throw const FormatException('reason must be a non-empty string');
    }
    return DiscardQuestionnaireDraftInput(
      instanceId: instanceId,
      questionnaireType: questionnaireType,
      reason: reason,
    );
  }

  @override
  void validate(DiscardQuestionnaireDraftInput input) {
    // Structural validation happens in parseInput; nothing clinical to gate
    // here — discarding a draft is always legal (drafts are diary-local).
  }

  @override
  Future<ExecutionResult<String>> execute(
    DiscardQuestionnaireDraftInput input,
    ActionContext ctx,
  ) async {
    if (ctx.principal is! UserPrincipal) {
      throw StateError(
        'discarding a questionnaire draft requires an identified participant',
      );
    }
    return ExecutionResult<String>(
      result: input.instanceId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: input.instanceId,
          entryType: '${input.questionnaireType}_survey',
          eventType: 'draft_discarded',
          data: <String, Object?>{
            'instance_id': input.instanceId,
            'reason': input.reason,
          },
        ),
      ],
    );
  }
}
