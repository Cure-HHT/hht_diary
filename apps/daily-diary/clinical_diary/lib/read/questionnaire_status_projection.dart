// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S — device-local
//   read layer for portal-driven questionnaire lifecycle. Folds
//   questionnaire_finalized / questionnaire_unlocked events (shared aggregate
//   type questionnaire_instance — same as the portal) into a per-instance row
//   so the read-only gate and task-sync logic key off a recorded event rather
//   than a transient REST status.
import 'package:event_sourcing/event_sourcing.dart';

/// View name for the device-observed questionnaire lifecycle projection.
const String questionnaireStatusViewName = 'questionnaire_status';

/// Shared aggregate type — same as the portal's, so device-emitted events
/// fold alongside future portal-propagated events under the same aggregate
/// identity.
const String questionnaireInstanceAggregateType = 'questionnaire_instance';

/// Folds `questionnaire_finalized` and `questionnaire_unlocked` events into a
/// per-instance row. The library stamps `row['entryType']` with the event's
/// entry type on every fold, so the row directly encodes the latest lifecycle
/// transition without additional payload fields.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
const AggregateProjectionSpec questionnaireStatusProjection =
    AggregateProjectionSpec(
      viewName: questionnaireStatusViewName,
      interest: SubscriptionFilter(
        aggregateTypes: {questionnaireInstanceAggregateType},
        eventTypes: {'questionnaire_finalized', 'questionnaire_unlocked'},
      ),
      tombstoneEventTypes: {},
    );

/// Typed view of one `questionnaire_status` row, reflecting the latest
/// lifecycle event observed by the device for a given questionnaire instance.
///
/// The library's `AggregateFold` stamps `row['entryType']` with the folding
/// event's entry type (`questionnaire_finalized` or `questionnaire_unlocked`),
/// so no separate payload field is needed to distinguish them.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
class QuestionnaireStatusRow {
  const QuestionnaireStatusRow({
    required this.instanceId,
    required this.entryType,
  });

  factory QuestionnaireStatusRow.fromViewRow(Map<String, Object?> row) {
    return QuestionnaireStatusRow(
      instanceId: row['aggregateId']! as String,
      entryType: row['entryType']! as String,
    );
  }

  final String instanceId;

  /// The entry type of the latest lifecycle event folded into this row
  /// (`questionnaire_finalized` or `questionnaire_unlocked`).
  final String entryType;

  /// True when the latest lifecycle event was `questionnaire_finalized`.
  bool get isFinalized => entryType == 'questionnaire_finalized';

  /// True when the latest lifecycle event was `questionnaire_unlocked`.
  bool get isUnlocked => entryType == 'questionnaire_unlocked';
}
