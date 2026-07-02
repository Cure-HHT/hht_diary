import 'dart:async';
import 'dart:io';

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Post-commit reactor that bridges a diary questionnaire submission into the
/// portal's `questionnaire_instance` lifecycle.
///
/// When the diary submits a survey, a `DiaryEntry`/`finalized` event lands in
/// the portal event store with `entryType == '<type>_survey'` and an
/// `aggregateId` that EQUALS the questionnaire instance id (the diary's
/// `submit_questionnaire` action emits the portal-minted instance id from
/// `questionnaire_assigned`). The `finalized` eventType is GENERIC — it is also
/// emitted for epistaxis entries and day-markers — so the
/// `questionnaire_instance` projection cannot consume it directly without
/// polluting the view with every diary entry. This reactor filters by
/// `entryType` in code and, only for a *survey* finalized event that maps to a
/// live (non-tombstoned) instance row, emits a dedicated
/// `questionnaire_submission_received` event on the instance aggregate. The
/// projection folds that into the row, moving the instance to **Ready to
/// Review**.
///
/// Implements: DIARY-BASE-questionnaire-coordinator-workflow/G — when a
///   Participant submits a Questionnaire, the System changes its status to
///   Ready to Review. This reactor performs that status transition on the
///   portal side by folding the diary submission into the instance.
class QuestionnaireSubmissionReactor {
  QuestionnaireSubmissionReactor({
    required this.eventStore,
    required this.backend,
  });

  final EventStore eventStore;
  final StorageBackend backend;

  StreamSubscription<Update<StoredEvent>>? _sub;

  void start() {
    _sub = eventStore
        .subscribe<StoredEvent>(
      const SubscriptionFilter(
        aggregateTypes: {diaryEntryAggregateType},
        eventTypes: {'finalized'},
      ),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        // Fire-and-forget with a catchError backstop: a reactor failure must
        // NEVER surface as an unhandled async exception that crashes the server.
        unawaited(
            handleFinalized(update.value).catchError((Object e, StackTrace st) {
          stderr
              .writeln('QuestionnaireSubmissionReactor.handleFinalized failed '
                  '(continuing): $e\n$st');
        }));
      }
    }, onError: (Object e, StackTrace st) {
      stderr.writeln('QuestionnaireSubmissionReactor subscription error '
          '(continuing): $e\n$st');
    });
  }

  // Implements: DIARY-BASE-questionnaire-coordinator-workflow/G
  Future<void> handleFinalized(StoredEvent event) async {
    // Only survey entries map to a questionnaire instance. Epistaxis entries
    // and day-markers share the generic `finalized` eventType — ignore them so
    // the questionnaire_instance view is not polluted.
    final entryType = event.entryType;
    if (!entryType.endsWith('_survey')) return;

    // The survey event's aggregateId IS the questionnaire instance id.
    final instanceId = event.aggregateId;

    // Guard: only act on a live instance row. Find the questionnaire_instance
    // row for this instance. If absent, the survey has no portal instance (a
    // diary-initiated survey, or a called-back/tombstoned instance) — do NOT
    // create a phantom Ready-to-Review row.
    final rows = await backend.findViewRows('questionnaire_instance');
    Map<String, Object?>? row;
    for (final r in rows) {
      if (r['aggregateId'] == instanceId) {
        row = r;
        break;
      }
    }
    if (row == null) return;

    // Idempotency / no-regression: if the instance has already received a
    // submission, or has been finalized (Closed), do NOT re-emit. Never revert a
    // Closed instance back to Ready-to-Review.
    final latest = row['entryType'];
    // CUR-1539: `questionnaire_finalized` is the frozen legacy alias of
    // `questionnaire_locked` (rows folded from pre-rename event logs).
    if (latest == 'questionnaire_submission_received' ||
        latest == 'questionnaire_locked' ||
        latest == 'questionnaire_finalized') {
      return;
    }

    await eventStore.append(
      entryType: 'questionnaire_submission_received',
      aggregateType: 'questionnaire_instance',
      aggregateId: instanceId,
      eventType: 'questionnaire_submission_received',
      data: <String, Object?>{
        'completed_at': event.data['completed_at'],
        'questionnaire_type': event.data['questionnaire_type'],
      },
      initiator: const AutomationInitiator(service: 'questionnaire-submission'),
    );
  }

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}
