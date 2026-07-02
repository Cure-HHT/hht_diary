// Implements: DIARY-DEV-outgoing-intent-correlation/D — the acknowledge_recall
//   action emits a `questionnaire_recall_acked` event (eventType `finalized`) on
//   the `questionnaire_recall_notice` aggregate, routing the ack OUTBOUND via
//   SystemEventsDestination so the portal's recall-notice row self-cleans.
import 'package:event_sourcing/event_sourcing.dart';

/// Aggregate type that echoes the portal's recall-notice aggregate (shared
/// namespace). The ack event rides on this same aggregate so SystemEvents
/// Destination's filter picks it up and ships it outbound.
const String questionnaireRecallNoticeAggregateType =
    'questionnaire_recall_notice';

/// Per-app diary Action: emit a `questionnaire_recall_acked` (eventType
/// `finalized`) event on the shared `questionnaire_recall_notice` aggregate,
/// signalling to the portal that the participant has acknowledged the recall.
///
/// Input: `{instance_id, participant_id}`.
/// Output: the composite aggregateId `{participantId}:recall:{instanceId}`.
// Implements: DIARY-DEV-outgoing-intent-correlation/D
// Implements: DIARY-DEV-inbound-event-on-receipt/C
class AcknowledgeRecallAction extends Action<Map<String, Object?>, String> {
  const AcknowledgeRecallAction();

  @override
  String get name => 'acknowledge_recall';

  @override
  String get description =>
      'Acknowledge that the participant has seen the recall notification — '
      'emits an outbound questionnaire_recall_acked event (finalized) so the '
      'portal recall-notice row self-cleans.';

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
    if (input['participant_id'] is! String ||
        (input['participant_id'] as String).isEmpty) {
      throw ArgumentError.value(
        input['participant_id'],
        'participant_id',
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
    final participantId = input['participant_id'] as String;
    final flowToken = input['flow_token'] as String?;
    final aggregateId = '$participantId:recall:$instanceId';
    return ExecutionResult<String>(
      result: aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: questionnaireRecallNoticeAggregateType,
          aggregateId: aggregateId,
          entryType: 'questionnaire_recall_acked',
          eventType: 'finalized',
          data: <String, Object?>{
            'instance_id': instanceId,
            'participant_id': participantId,
            'flow_token': flowToken,
            'acked_at': ctx.requestStartedAt.toUtc().toIso8601String(),
          },
        ),
      ],
    );
  }
}

// CUR-1557 test (b): clinical_diary code change; expect selective run of only clinical_diary.
