// Pure card-state logic for the Manage Questionnaires modal. Given the
// non-tombstoned `questionnaire_instance` view rows for ONE (participant, type)
// pair, [resolveCardState] derives the card's display status, the cycle fields
// to show, and the exact action set per the per-status action matrix. No
// Flutter / I/O here — this is pure and unit-tested directly.
//
// Implements: DIARY-BASE-questionnaire-manage-modal/E
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/A

import 'package:meta/meta.dart';

import 'questionnaire_instance.dart';

/// An action the Study Coordinator can take on a questionnaire card. The label
/// is the button caption (mirrors [QuestionnaireInstanceStatus.label] /
/// `ParticipantAction.label` style).
enum QuestionnaireCardAction {
  sendNow('Send Now'),
  startNextCycle('Start Next Cycle'),
  callBack('Call Back'),
  finalize('Finalize');

  const QuestionnaireCardAction(this.label);

  /// Button label for display.
  final String label;
}

/// The resolved presentation state of one Questionnaire Card: the display
/// [status], the cycle fields to show inline, and the [actions] to render.
@immutable
class QuestionnaireCardState {
  const QuestionnaireCardState({
    required this.status,
    required this.actions,
    this.currentInstanceId,
    this.currentStudyEvent,
    this.finalizedStudyEvent,
  });

  /// Display status driving the matrix row.
  final QuestionnaireInstanceStatus status;

  /// The open instance's id, when an active (Sent / Ready-to-Review) instance
  /// exists. Carried so Call Back / Finalize can target it.
  final String? currentInstanceId;

  /// The open instance's study event (Current Cycle), when one exists.
  final String? currentStudyEvent;

  /// The most-recent finalized study event (Finalized Cycle), shown in the
  /// after-finalize (Not Sent) and Closed rows.
  final String? finalizedStudyEvent;

  /// The exact action buttons to render, in display order.
  final List<QuestionnaireCardAction> actions;
}

/// Parses the cycle number from a canonical study-event string (e.g.
/// `'Cycle 2 Day 1'` -> 2). Returns null for null / non-matching strings.
/// Mirrors `parseCycleNumber` in portal_server_evs/lib/src/next_cycle.dart.
int? _parseCycleNumber(String? studyEvent) {
  if (studyEvent == null) return null;
  final match = RegExp(r'^Cycle ([1-9]\d*) Day 1$').firstMatch(studyEvent);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

/// Resolves the [QuestionnaireCardState] for ONE (participant, type) from its
/// non-tombstoned `questionnaire_instance` view rows.
///
/// [rowsForType] — the delivered (non-tombstoned; called-back rows are removed
/// from the view) rows for a single participant + type. The caller groups by
/// type before calling.
///
/// Logic (per the per-status matrix):
///  * Any open instance (status == sent / readyToReview) takes precedence —
///    at most one active questionnaire of a type exists
///    (DIARY-BASE-questionnaire-coordinator-workflow/A). Sent -> [callBack];
///    Ready to Review -> [finalize, callBack].
///  * Else if a finalized (closed) row exists -> Not Sent (after-finalize):
///    the type can be re-sent as the next cycle -> [startNextCycle], with the
///    latest finalized cycle surfaced as [finalizedStudyEvent]. A genuinely
///    terminal Closed (End of Treatment / End of Study) -> no actions; that
///    arrives in Phase 4 (the view cannot produce a terminal end_event yet),
///    so a finalized non-terminal row yields Start Next Cycle for now.
///  * Else (no rows) -> Not Sent (never sent) -> [sendNow].
QuestionnaireCardState resolveCardState(
  List<QuestionnaireInstance> rowsForType,
) {
  // An open instance (Sent or Ready to Review) takes precedence: at most one
  // active questionnaire of a type may exist
  // (DIARY-BASE-questionnaire-coordinator-workflow/A).
  for (final r in rowsForType) {
    switch (r.status) {
      case QuestionnaireInstanceStatus.sent:
        return QuestionnaireCardState(
          status: QuestionnaireInstanceStatus.sent,
          currentInstanceId: r.instanceId,
          currentStudyEvent: r.studyEvent,
          actions: const <QuestionnaireCardAction>[
            QuestionnaireCardAction.callBack,
          ],
        );
      case QuestionnaireInstanceStatus.readyToReview:
        // Forward-compat (Phase 3 `<id>_survey` join not yet produced).
        return QuestionnaireCardState(
          status: QuestionnaireInstanceStatus.readyToReview,
          currentInstanceId: r.instanceId,
          currentStudyEvent: r.studyEvent,
          actions: const <QuestionnaireCardAction>[
            QuestionnaireCardAction.finalize,
            QuestionnaireCardAction.callBack,
          ],
        );
      case QuestionnaireInstanceStatus.notSent:
      case QuestionnaireInstanceStatus.closed:
      case QuestionnaireInstanceStatus.unknown:
        // Not an open instance — handled below.
        break;
    }
  }

  // No open instance. If any finalized (closed) row exists, the type is
  // after-finalize: re-sendable as the next cycle. Pick the latest finalized
  // cycle for the Finalized Cycle display.
  final finalized = <QuestionnaireInstance>[
    for (final r in rowsForType)
      if (r.status == QuestionnaireInstanceStatus.closed) r,
  ];
  if (finalized.isNotEmpty) {
    QuestionnaireInstance latest = finalized.first;
    int maxCycle = _parseCycleNumber(latest.studyEvent) ?? 0;
    for (final r in finalized.skip(1)) {
      final n = _parseCycleNumber(r.studyEvent) ?? 0;
      if (n > maxCycle) {
        maxCycle = n;
        latest = r;
      }
    }
    return QuestionnaireCardState(
      status: QuestionnaireInstanceStatus.notSent,
      finalizedStudyEvent: latest.studyEvent,
      actions: const <QuestionnaireCardAction>[
        QuestionnaireCardAction.startNextCycle,
      ],
    );
  }

  // No rows at all (or only unknown/unrecognised) -> never sent.
  return const QuestionnaireCardState(
    status: QuestionnaireInstanceStatus.notSent,
    actions: <QuestionnaireCardAction>[QuestionnaireCardAction.sendNow],
  );
}
