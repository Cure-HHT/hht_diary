import 'dart:async';

import 'package:clinical_diary/read/questionnaire_status_projection.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Idempotently mints device-observed questionnaire lifecycle events from
/// portal-reported [Task] statuses.
///
/// The REST `/user/tasks` endpoint is a STATE POLL, not an event stream. Each
/// time the diary receives a synced task list it calls [reconcile] to ensure
/// exactly one lifecycle event is appended per instance transition — reading
/// the `questionnaire_status` view first to skip instances already recorded.
///
/// Produces:
/// - `record_questionnaire_finalized` for each task with `status == 'finalized'`
///   not already reflected in the `questionnaire_status` view.
/// - `record_questionnaire_unlocked` for each task with `status == 'unlocked'`
///   not already reflected (only when [enableUnlock] is `true`; defaults to
///   `false` for Callisto).
class QuestionnaireStatusSync {
  QuestionnaireStatusSync({
    required LocalScope scope,
    this.enableUnlock = false,
  }) : _scope = scope;

  final LocalScope _scope;

  /// When `true`, the symmetric `unlocked` branch is active: tasks with
  /// `status == 'unlocked'` will mint `record_questionnaire_unlocked` once.
  /// Defaults to `false` — leave as `false` for Callisto until the portal
  /// sends unlocked status.
  final bool enableUnlock;

  /// Reconciles [tasks] against the device-local `questionnaire_status` view.
  ///
  /// Reads the view once (one-shot mirror of `home_screen._readIncompleteRowsOnce`),
  /// builds the already-recorded sets, then dispatches the appropriate action
  /// for each task that represents a new transition.
  Future<void> reconcile(List<Task> tasks) async {
    // One-shot read of the questionnaire_status view: subscribe, collect
    // Snapshot rows until EndOfReplay, then cancel.
    final alreadyFinalized = <String>{};
    final alreadyUnlocked = <String>{};
    final completer = Completer<void>();
    late final StreamSubscription<Update<QuestionnaireStatusRow>> sub;
    sub = _scope.viewSource
        .watch<QuestionnaireStatusRow>(
          viewName: questionnaireStatusViewName,
          mapper: QuestionnaireStatusRow.fromViewRow,
        )
        .listen(
          (update) {
            switch (update) {
              case Snapshot<QuestionnaireStatusRow>(:final value):
                if (value != null) {
                  if (value.isFinalized) alreadyFinalized.add(value.instanceId);
                  if (value.isUnlocked) alreadyUnlocked.add(value.instanceId);
                }
              case EndOfReplay<QuestionnaireStatusRow>():
                if (!completer.isCompleted) completer.complete();
                unawaited(sub.cancel());
              default:
                break;
            }
          },
          onError: (Object e, StackTrace st) {
            if (!completer.isCompleted) completer.complete();
          },
        );
    await completer.future;

    // Dispatch lifecycle actions for instances not yet recorded.
    for (final task in tasks) {
      if (task.status == 'finalized' && !alreadyFinalized.contains(task.id)) {
        // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
        await _scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'record_questionnaire_finalized',
            rawInput: {'instance_id': task.id},
          ),
        );
        alreadyFinalized.add(task.id);
      }
      if (enableUnlock &&
          task.status == 'unlocked' &&
          !alreadyUnlocked.contains(task.id)) {
        await _scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'record_questionnaire_unlocked',
            rawInput: {'instance_id': task.id},
          ),
        );
        alreadyUnlocked.add(task.id);
      }
    }
  }
}
