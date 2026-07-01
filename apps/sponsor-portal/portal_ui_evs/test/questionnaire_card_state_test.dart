// Verifies: DIARY-BASE-questionnaire-manage-modal/E — resolveCardState maps the
//   non-tombstoned (participant,type) rows to the correct status + action set
//   per the per-status action matrix.
// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/A — at most one active
//   questionnaire of a type: an open instance takes precedence over finalized.
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/questionnaire_card_state.dart';
import 'package:portal_ui_evs/src/questionnaire_instance.dart';

QuestionnaireInstance _inst({
  required String instanceId,
  required QuestionnaireInstanceStatus status,
  String? studyEvent,
  String? endEvent,
  DateTime? finalizedAt,
  String type = 'nose_hht',
  String participantId = 'P-1',
}) => QuestionnaireInstance(
  instanceId: instanceId,
  participantId: participantId,
  type: type,
  studyEvent: studyEvent,
  status: status,
  endEvent: endEvent,
  finalizedAt: finalizedAt,
);

void main() {
  group('resolveCardState', () {
    test('no rows -> Not Sent (never sent) + [sendNow]', () {
      final s = resolveCardState(const <QuestionnaireInstance>[]);

      expect(s.status, QuestionnaireInstanceStatus.notSent);
      expect(s.actions, <QuestionnaireCardAction>[
        QuestionnaireCardAction.sendNow,
      ]);
      expect(s.currentInstanceId, isNull);
      expect(s.currentStudyEvent, isNull);
      expect(s.finalizedStudyEvent, isNull);
    });

    test('one assigned row -> Sent + [callBack] + current id/studyEvent', () {
      final s = resolveCardState(<QuestionnaireInstance>[
        _inst(
          instanceId: 'inst-1',
          status: QuestionnaireInstanceStatus.sent,
          studyEvent: 'Cycle 1 Day 1',
        ),
      ]);

      expect(s.status, QuestionnaireInstanceStatus.sent);
      expect(s.actions, <QuestionnaireCardAction>[
        QuestionnaireCardAction.callBack,
      ]);
      expect(s.currentInstanceId, 'inst-1');
      expect(s.currentStudyEvent, 'Cycle 1 Day 1');
      expect(s.finalizedStudyEvent, isNull);
    });

    test(
      'one finalized (closed) row -> Not Sent-after-finalize + [startNextCycle]',
      () {
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 1 Day 1',
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.notSent);
        expect(s.actions, <QuestionnaireCardAction>[
          QuestionnaireCardAction.startNextCycle,
        ]);
        expect(s.finalizedStudyEvent, 'Cycle 1 Day 1');
        expect(s.currentInstanceId, isNull);
      },
    );

    test(
      'finalized terminal close (endEvent) -> Closed + no actions + endEvent',
      () {
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 3 Day 1',
            endEvent: 'end_of_treatment',
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.closed);
        expect(s.actions, isEmpty);
        expect(s.endEvent, 'end_of_treatment');
        expect(s.finalizedStudyEvent, 'Cycle 3 Day 1');
      },
    );

    test(
      'a terminal finalize among non-terminal finalizes -> Closed (no Start Next Cycle)',
      () {
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 1 Day 1',
          ),
          _inst(
            instanceId: 'inst-2',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 2 Day 1',
            endEvent: 'end_of_study',
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.closed);
        expect(s.actions, isEmpty);
        expect(s.endEvent, 'end_of_study');
      },
    );

    test('open instance wins over finalized (coordinator/A)', () {
      final s = resolveCardState(<QuestionnaireInstance>[
        _inst(
          instanceId: 'inst-final',
          status: QuestionnaireInstanceStatus.closed,
          studyEvent: 'Cycle 1 Day 1',
        ),
        _inst(
          instanceId: 'inst-open',
          status: QuestionnaireInstanceStatus.sent,
          studyEvent: 'Cycle 2 Day 1',
        ),
      ]);

      expect(s.status, QuestionnaireInstanceStatus.sent);
      expect(s.actions, <QuestionnaireCardAction>[
        QuestionnaireCardAction.callBack,
      ]);
      expect(s.currentInstanceId, 'inst-open');
      expect(s.currentStudyEvent, 'Cycle 2 Day 1');
    });

    test(
      'after-finalize surfaces finalizedAt + next cycle (assertion T)',
      () {
        // Verifies: DIARY-BASE-questionnaire-finalization/D — the after-finalize card state carries the
        //   finalization timestamp and the next cycle to send.
        final finalizedAt = DateTime(2024, 10, 13, 17);
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 1 Day 1',
            finalizedAt: finalizedAt,
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.notSent);
        expect(s.finalizedStudyEvent, 'Cycle 1 Day 1');
        expect(s.finalizedAt, finalizedAt);
        expect(s.nextStudyEvent, 'Cycle 2 Day 1');
      },
    );

    test(
      'terminal Closed surfaces finalizedAt but no next cycle (assertion T)',
      () {
        // Verifies: DIARY-BASE-questionnaire-finalization/D — a terminal close still records the
        //   finalization time; there is no next cycle to send.
        final finalizedAt = DateTime(2024, 10, 13, 17);
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 3 Day 1',
            endEvent: 'end_of_treatment',
            finalizedAt: finalizedAt,
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.closed);
        expect(s.finalizedAt, finalizedAt);
        expect(s.nextStudyEvent, isNull);
      },
    );

    test('nextCycleStudyEvent increments a parseable cycle, else null', () {
      // Verifies: DIARY-BASE-questionnaire-finalization/D — the next-cycle helper.
      expect(nextCycleStudyEvent('Cycle 1 Day 1'), 'Cycle 2 Day 1');
      expect(nextCycleStudyEvent('Cycle 11 Day 1'), 'Cycle 12 Day 1');
      expect(nextCycleStudyEvent(null), isNull);
      expect(nextCycleStudyEvent('Screening'), isNull);
    });

    test('latest finalized cycle selected when multiple finalized', () {
      final s = resolveCardState(<QuestionnaireInstance>[
        _inst(
          instanceId: 'inst-1',
          status: QuestionnaireInstanceStatus.closed,
          studyEvent: 'Cycle 1 Day 1',
        ),
        _inst(
          instanceId: 'inst-3',
          status: QuestionnaireInstanceStatus.closed,
          studyEvent: 'Cycle 3 Day 1',
        ),
        _inst(
          instanceId: 'inst-2',
          status: QuestionnaireInstanceStatus.closed,
          studyEvent: 'Cycle 2 Day 1',
        ),
      ]);

      expect(s.status, QuestionnaireInstanceStatus.notSent);
      expect(s.actions, <QuestionnaireCardAction>[
        QuestionnaireCardAction.startNextCycle,
      ]);
      expect(s.finalizedStudyEvent, 'Cycle 3 Day 1');
    });

    test(
      'finalized rows with an unparseable study_event still yield startNextCycle',
      () {
        // A finalized row whose study_event is null (cycle tracking disabled)
        // is still after-finalize; finalizedStudyEvent falls back to the row's
        // (null) study_event when no Cycle N is parseable.
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.notSent);
        expect(s.actions, <QuestionnaireCardAction>[
          QuestionnaireCardAction.startNextCycle,
        ]);
      },
    );

    group('forward-compat statuses (not yet produced by the view)', () {
      test('readyToReview -> [finalize, callBack]', () {
        final s = resolveCardState(<QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.readyToReview,
            studyEvent: 'Cycle 1 Day 1',
          ),
        ]);

        expect(s.status, QuestionnaireInstanceStatus.readyToReview);
        expect(s.actions, <QuestionnaireCardAction>[
          QuestionnaireCardAction.finalize,
          QuestionnaireCardAction.callBack,
        ]);
        expect(s.currentInstanceId, 'inst-1');
        expect(s.currentStudyEvent, 'Cycle 1 Day 1');
      });
    });

    group('QuestionnaireCardAction labels', () {
      test('each action exposes a display label', () {
        expect(QuestionnaireCardAction.sendNow.label, 'Send Now');
        expect(
          QuestionnaireCardAction.startNextCycle.label,
          'Start Next Cycle',
        );
        expect(QuestionnaireCardAction.callBack.label, 'Call Back');
        expect(QuestionnaireCardAction.finalize.label, 'Finalize');
      });
    });
  });
}
