// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/N — backs the Review
//   Screen's submit Action by recording the submission as an event.
//   Refines: DIARY-PRD-questionnaire-portal-sent-rules
// Implements: DIARY-PRD-questionnaire-versioning/J+K+L — the submission records
//   the schema / content / gui version identifiers.
// Implements: DIARY-DEV-action-write-path/A — the write flows through the core
//   ActionDispatcher rather than a direct append.
//
// Diary per-app Action (diary_actions): finalize a questionnaire. Dispatched
// through the core ActionDispatcher and emits one finalized `<id>_survey` event
// on the survey-instance aggregate. The cross-wire payload contract lives in the
// shared model (QuestionnaireSubmissionPayload, decision 1d / surface D6): the
// portal-minted instance_id is carried through unchanged for portal-assigned
// surveys (diary-minted otherwise), the flowToken is echoed (P5), and responses
// are `question_id -> {value, display_label, normalized_label}`.
//
// Layering note (per-item design): `validate` does only PURE structural checks
// (instance/type present, ISO completed_at, at least one answered question).
// Per-question schema validation and the session-timeout / lock rules live in
// the questionnaire flow + submission-boundary guard, not here.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Finalizes a questionnaire as a `<id>_survey` / `finalized` event. Returns the
/// survey-instance aggregate id.
class SubmitQuestionnaireAction
    extends Action<QuestionnaireSubmissionPayload, String> {
  const SubmitQuestionnaireAction();

  @override
  String get name => 'submit_questionnaire';

  @override
  String get description =>
      'Participant submits a completed questionnaire (finalized <id>_survey).';

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
      throw FormatException('invalid questionnaire submission payload: $e');
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
    if (input.responses.isEmpty) {
      throw ArgumentError.value(
        input.responses,
        'responses',
        'a submission must answer at least one question',
      );
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    QuestionnaireSubmissionPayload input,
    ActionContext ctx,
  ) async {
    if (ctx.principal is! UserPrincipal) {
      throw StateError(
        'submitting a questionnaire requires an identified participant',
      );
    }
    return ExecutionResult<String>(
      result: input.instanceId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: input.instanceId,
          entryType: '${input.questionnaireType}_survey',
          eventType: 'finalized',
          data: input.toJson(),
        ),
      ],
    );
  }
}
