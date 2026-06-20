// Implements: DIARY-DEV-inbound-event-on-receipt/C — orchestrates the three
//   writes that constitute a recall acknowledgement from the participant's
//   device: outbound ack event, local recall-view tombstone, and optional
//   local survey tombstone.
// Implements: DIARY-DEV-outgoing-intent-correlation/D — the outbound ack
//   carries the instance_id so the portal can correlate the acknowledgement
//   back to the original recall-notice aggregate and remove it.

import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Acknowledges a questionnaire recall on behalf of the participant.
///
/// Three writes are dispatched in order:
///
/// 1. **Ack event** (`acknowledge_recall`): emits a
///    `questionnaire_recall_acked` / `finalized` event on the
///    `questionnaire_recall_notice` aggregate. The `SystemEventsDestination`
///    filter selects this aggregate type, so the event ships outbound to the
///    portal on the next sync cycle and the portal's recall-notice row
///    self-cleans.
///
/// 2. **Local recall clear** (`clear_questionnaire_recall`): tombstones the
///    device-local `questionnaire_recall_local`/[instanceId] aggregate so the
///    `questionnaire_recall` view (Task 6) removes the recall row and the
///    home screen stops showing the recall notification.
///
/// 3. **Survey tombstone** (`delete_entry`, optional): if the participant had
///    already submitted a survey for this [instanceId] (i.e. a `DiaryEntry`
///    row with aggregateId == [instanceId] exists in the diary entries view),
///    tombstone it with `changeReason: portal-withdrawn`. Recall wins even
///    over an already-submitted survey. When no local survey exists (the
///    survey was still in-progress or never opened), this step is silently
///    skipped — only the ack and clear are emitted.
///
/// [rt] must be the live composition root; it supplies both the action
/// submitter (via `rt.scope`) and the storage backend (via
/// `rt.bundle.eventStore.backend`) needed to resolve the survey's entryType.
///
/// Throws if either the ack or the clear dispatch fails.
// Implements: DIARY-DEV-inbound-event-on-receipt/C
// Implements: DIARY-DEV-outgoing-intent-correlation/D
Future<void> acknowledgeRecall(DiaryScopeRuntime rt, String instanceId) async {
  // Resolve the participant id from the active auth session. The diary scope
  // always has an identified UserPrincipal (enrolled id or stable device-local
  // id); an anonymous/null principal here means misconfiguration.
  final principal = rt.scope.authSession.principal;
  if (principal is! UserPrincipal) {
    throw StateError(
      'acknowledgeRecall: no identified principal — scope may be disposed '
      'or the auth session was not initialised.',
    );
  }
  final participantId = principal.userId;

  // 1. Emit the outbound ack event.
  final ackResult = await rt.scope.actionSubmitter.submit(
    ActionSubmission(
      actionName: 'acknowledge_recall',
      rawInput: <String, Object?>{
        'instance_id': instanceId,
        'participant_id': participantId,
        // flow_token is not stored device-side; the portal can correlate
        // solely on (participantId, instanceId). Omitted intentionally.
      },
    ),
  );
  if (ackResult is! DispatchSuccess<Object?>) {
    throw StateError(
      'acknowledgeRecall: acknowledge_recall dispatch failed: $ackResult',
    );
  }

  // 2. Tombstone the device-local recall view row.
  final clearResult = await rt.scope.actionSubmitter.submit(
    ActionSubmission(
      actionName: 'clear_questionnaire_recall',
      rawInput: <String, Object?>{'instance_id': instanceId},
    ),
  );
  if (clearResult is! DispatchSuccess<Object?>) {
    throw StateError(
      'acknowledgeRecall: clear_questionnaire_recall dispatch failed: '
      '$clearResult',
    );
  }

  // 3. Tombstone the local survey DiaryEntry — recall wins, including an
  //    already-submitted survey. Look up the row by aggregateId == instanceId
  //    in the diary entries view to discover the entryType.
  final surveyEntryType = await _resolveSurveyEntryType(rt, instanceId);
  if (surveyEntryType != null) {
    // Ignore failures here: if delete_entry rejects (e.g. lock-threshold
    // guard), the ack and clear have already been persisted. The portal
    // knows the recall was acknowledged; the stale local survey row is a
    // cosmetic concern only.
    await rt.scope.actionSubmitter.submit(
      ActionSubmission(
        actionName: 'delete_entry',
        rawInput: <String, Object?>{
          'aggregateId': instanceId,
          'entryType': surveyEntryType,
          'changeReason': DiaryChangeReason.portalWithdrawn.wire,
        },
      ),
    );
  }
}

/// Resolves the `entryType` of the local survey DiaryEntry for [instanceId],
/// or `null` when no submitted local survey exists.
///
/// The survey DiaryEntry row has aggregateId == instanceId and entryType of
/// the form `<questionnaire_type>_survey`. It is present only when the
/// participant has actually submitted the survey on this device (the
/// `DiaryEntry` aggregate for the instance exists in the entries view).
Future<String?> _resolveSurveyEntryType(
  DiaryScopeRuntime rt,
  String instanceId,
) async {
  final rows = await rt.bundle.eventStore.backend.findViewRows(
    diaryEntriesViewName,
  );
  for (final row in rows) {
    if (row['aggregateId'] == instanceId) {
      // entryType is stamped by the library's AggregateFold on the row.
      // Survey rows always have an explicit entryType (e.g. `qol_survey`).
      final entryType = row['entryType'] as String?;
      return entryType;
    }
  }
  return null; // no local survey for this instance
}
