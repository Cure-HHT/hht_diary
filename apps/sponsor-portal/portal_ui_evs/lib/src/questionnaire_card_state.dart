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
    this.finalizedAt,
    this.nextStudyEvent,
    this.endEvent,
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

  /// When the most-recent finalize was folded (the `updatedAt` stamp of the
  /// [finalizedStudyEvent] row). Rendered next to the "Last:" cycle in the
  /// after-finalize / Closed body so the coordinator sees the finalization
  /// date and time. Null when no finalized row exists.
  ///
  /// Implements: REQ-CAL-p00023/T
  final DateTime? finalizedAt;

  /// The next cycle's study event after an after-finalize (e.g.
  /// `'Cycle 2 Day 1'` when [finalizedStudyEvent] is `'Cycle 1 Day 1'`). Shown
  /// as the "Next: …" line with a Not-Sent badge on the after-finalize card.
  /// Null for a terminal Closed row or when the finalized cycle is unparseable.
  ///
  /// Implements: REQ-CAL-p00023/T
  final String? nextStudyEvent;

  /// The terminal close marker on a Closed card (`'end_of_treatment'` /
  /// `'end_of_study'`), surfaced so the card can render the combined
  /// "Closed · End of Treatment/Study" badge. Null for non-terminal rows.
  final String? endEvent;

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

/// The next cycle's canonical study-event string after finalizing [studyEvent]
/// (e.g. `'Cycle 1 Day 1'` -> `'Cycle 2 Day 1'`). Returns null when the input
/// carries no parseable `Cycle N Day 1`, so callers can guard the "Next: …"
/// line. Exposed for the after-finalize card and unit tests.
///
/// Implements: REQ-CAL-p00023/T
String? nextCycleStudyEvent(String? studyEvent) {
  final n = _parseCycleNumber(studyEvent);
  return n == null ? null : 'Cycle ${n + 1} Day 1';
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
///  * Else if a finalized (closed) row with a non-null endEvent (terminal
///    close: End of Treatment / End of Study) exists -> Closed, no actions,
///    with the endEvent surfaced for the combined badge
///    (DIARY-BASE-questionnaire-finalization/E).
///  * Else if a finalized (closed) row exists -> Not Sent (after-finalize):
///    the type can be re-sent as the next cycle -> [startNextCycle], with the
///    latest finalized cycle surfaced as [finalizedStudyEvent]
///    (DIARY-BASE-questionnaire-finalization/D).
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
    // Implements: DIARY-BASE-questionnaire-finalization/D+E — a terminal close
    //   (any finalized row with a non-null endEvent) -> Closed with no further
    //   actions and the endEvent surfaced for the combined badge (E); a
    //   non-terminal finalize -> Not Sent (after-finalize) + Start Next Cycle (D).
    final terminal = <QuestionnaireInstance>[
      for (final r in finalized)
        if (r.endEvent != null) r,
    ];
    if (terminal.isNotEmpty) {
      final t = terminal.first;
      return QuestionnaireCardState(
        status: QuestionnaireInstanceStatus.closed,
        finalizedStudyEvent: t.studyEvent,
        // Implements: REQ-CAL-p00023/T — surface the terminal finalize time.
        finalizedAt: t.finalizedAt,
        endEvent: t.endEvent,
        actions: const <QuestionnaireCardAction>[],
      );
    }
    return QuestionnaireCardState(
      status: QuestionnaireInstanceStatus.notSent,
      finalizedStudyEvent: latest.studyEvent,
      // Implements: REQ-CAL-p00023/T — the finalization date/time and the
      //   next cycle to send, shown on the after-finalize card.
      finalizedAt: latest.finalizedAt,
      nextStudyEvent: nextCycleStudyEvent(latest.studyEvent),
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
