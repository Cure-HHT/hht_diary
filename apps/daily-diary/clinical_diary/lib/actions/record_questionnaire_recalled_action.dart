// Implements: DIARY-DEV-inbound-event-on-receipt/B
import 'package:clinical_diary/read/questionnaire_recall_projection.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Records that the portal recalled a questionnaire instance (device-observed).
///
/// Emits one `questionnaire_recalled` event on the device-local
/// `questionnaire_recall_local` aggregate. The event is NOT shared with the
/// portal's aggregate space; it exists solely to feed the device-local
/// `questionnaire_recall` view consumed by the home screen and the open flow
/// screen. Input: `{instance_id, study_event}`.
// Implements: DIARY-DEV-inbound-event-on-receipt/B
// Implements: DIARY-DEV-action-write-path/A
class RecordQuestionnaireRecalledAction
    extends Action<Map<String, Object?>, String> {
  const RecordQuestionnaireRecalledAction();

  @override
  String get name => 'record_questionnaire_recalled';

  @override
  String get description =>
      'Record that the portal recalled a questionnaire (device-observed).';

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
          eventType: 'finalized',
          data: <String, Object?>{
            'instance_id': instanceId,
            'study_event': input['study_event'],
          },
        ),
      ],
    );
  }
}
