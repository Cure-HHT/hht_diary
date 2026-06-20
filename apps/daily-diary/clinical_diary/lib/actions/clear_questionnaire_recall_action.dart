// Implements: DIARY-DEV-inbound-event-on-receipt/C — clearing the device-local
//   recall row is the second step of acknowledgeRecall: a `tombstone` event on
//   `questionnaire_recall_local`/instanceId removes the row from the
//   questionnaire_recall view (per the projection's removeEventTypes).
import 'package:clinical_diary/read/questionnaire_recall_projection.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Per-app diary Action: tombstone the device-local recall row so the
/// `questionnaire_recall` projection removes it. Emits a `tombstone` event on
/// `questionnaire_recall_local`/instanceId.
///
/// Input: `{instance_id}`.
/// Output: the instance_id.
// Implements: DIARY-DEV-inbound-event-on-receipt/C
class ClearQuestionnaireRecallAction
    extends Action<Map<String, Object?>, String> {
  const ClearQuestionnaireRecallAction();

  @override
  String get name => 'clear_questionnaire_recall';

  @override
  String get description =>
      'Tombstone the device-local recall row (questionnaire_recall view) after '
      'the participant has acknowledged the recall notification.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_recall'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) => raw;

  @override
  void validate(Map<String, Object?> input) {
    if (input['instance_id'] is! String ||
        (input['instance_id'] as String).isEmpty) {
      throw ArgumentError.value(
        input['instance_id'],
        'instance_id',
        'must be set',
      );
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    final instanceId = input['instance_id'] as String;
    return ExecutionResult<String>(
      result: instanceId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: questionnaireRecallLocalAggregateType,
          aggregateId: instanceId,
          entryType: 'questionnaire_recalled',
          eventType: 'tombstone',
          data: const <String, Object?>{},
        ),
      ],
    );
  }
}
