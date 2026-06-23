// Implements: DIARY-PRD-questionnaire-portal-sent-rules/H — preserves the
//   participant's in-progress answers LOCALLY (a `checkpoint` on the
//   `<id>_survey` aggregate) without committing them as a Submission. A later
//   `finalized` (the actual Submission) on the SAME aggregate promotes it and
//   self-removes the draft (diaryIncompleteProjection tombstones on
//   `finalized`); checkpoints are never shipped by DiaryServerDestination (which
//   syncs `finalized`/`tombstone` only), so a draft never reaches the portal.
// Implements: DIARY-DEV-action-write-path/A
//
// Per-app diary Action: the questionnaire counterpart of
// CheckpointEpistaxisEventAction. Emits one `checkpoint` `<id>_survey` event
// carrying the partial responses — same cross-wire payload shape as a submission
// (QuestionnaireSubmissionPayload), just incomplete — on the SAME instance
// aggregate the eventual `submit_questionnaire` finalizes, so reopening the
// instance resumes from the draft. Same layering as SubmitQuestionnaireAction
// (pure structural validate), but a draft may legitimately omit answers, so
// validate does NOT require a fully-answered responses map.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Checkpoints an in-progress questionnaire as a `<id>_survey` / `checkpoint`
/// event. Returns the survey-instance aggregate id.
class CheckpointQuestionnaireAction
    extends Action<QuestionnaireSubmissionPayload, String> {
  const CheckpointQuestionnaireAction();

  @override
  String get name => 'checkpoint_questionnaire';

  @override
  String get description =>
      'Participant auto-saves an in-progress questionnaire as a resumable '
      'diary-local draft (checkpoint <id>_survey).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.submit_questionnaire'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  QuestionnaireSubmissionPayload parseInput(Map<String, Object?> raw) {
    try {
      return QuestionnaireSubmissionPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      // A missing required field surfaces as a TypeError from the `!` casts;
      // normalize to a FormatException so the dispatcher records parse_denied.
      throw FormatException('invalid questionnaire checkpoint payload: $e');
    }
  }

  @override
  void validate(QuestionnaireSubmissionPayload input) {
    if (input.instanceId.isEmpty) {
      throw ArgumentError.value(input.instanceId, 'instanceId', 'must be set');
    }
    if (input.questionnaireType.isEmpty) {
      throw ArgumentError.value(
        input.questionnaireType,
        'questionnaireType',
        'must be set',
      );
    }
    if (DateTime.tryParse(input.completedAt) == null) {
      throw ArgumentError.value(
        input.completedAt,
        'completedAt',
        'must be an ISO 8601 timestamp',
      );
    }
    // Deliberately no `responses.isEmpty` guard: a draft is partial by nature.
  }

  @override
  Future<ExecutionResult<String>> execute(
    QuestionnaireSubmissionPayload input,
    ActionContext ctx,
  ) async {
    if (ctx.principal is! UserPrincipal) {
      throw StateError(
        'checkpointing a questionnaire requires an identified participant',
      );
    }
    return ExecutionResult<String>(
      result: input.instanceId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: input.instanceId,
          entryType: '${input.questionnaireType}_survey',
          eventType: 'checkpoint',
          data: input.toJson(),
        ),
      ],
    );
  }
}
