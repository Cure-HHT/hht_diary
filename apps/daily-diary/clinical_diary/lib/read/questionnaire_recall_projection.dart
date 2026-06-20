// Implements: DIARY-DEV-inbound-event-on-receipt/B
import 'package:event_sourcing/event_sourcing.dart';

/// View name for the device-local questionnaire recall projection.
const String questionnaireRecallViewName = 'questionnaire_recall';

/// Aggregate type for device-local recall records (distinct from the shared
/// questionnaire_instance aggregate type so recall rows never mix with status
/// rows from the portal's lifecycle events).
const String questionnaireRecallLocalAggregateType =
    'questionnaire_recall_local';

/// Folds `questionnaire_recalled` events (eventType `finalized`) into one row
/// per recalled instance. A `tombstone` event (eventType `tombstone`) removes
/// the row when the participant acknowledges the recall dialog (Task 11).
// Implements: DIARY-DEV-inbound-event-on-receipt/B
const TableProjectionSpec questionnaireRecallProjection = TableProjectionSpec(
  viewName: questionnaireRecallViewName,
  interest: SubscriptionFilter(
    aggregateTypes: {questionnaireRecallLocalAggregateType},
    eventTypes: {'finalized', 'tombstone'},
  ),
  insertEventTypes: {'finalized'},
  removeEventTypes: {'tombstone'},
  rowKey: AggregateIdKey(),
  rowData: SelectedFields(['instance_id', 'study_event']),
);

/// Typed view of one `questionnaire_recall` row.
///
/// Present in the view for as long as the participant has not acknowledged the
/// recall notification. Removed by the ack action (Task 11) via a `tombstone`
/// event on the same aggregate.
// Implements: DIARY-DEV-inbound-event-on-receipt/B
class QuestionnaireRecallRow {
  const QuestionnaireRecallRow({required this.instanceId, this.studyEvent});

  factory QuestionnaireRecallRow.fromViewRow(Map<String, Object?> row) =>
      QuestionnaireRecallRow(
        instanceId: row['aggregateId']! as String,
        studyEvent: row['study_event'] as String?,
      );

  /// The recalled questionnaire instance id.
  final String instanceId;

  /// The study event label associated with the instance (e.g. "Cycle 4 Day 1"),
  /// or `null` when the portal did not provide one.
  final String? studyEvent;
}
