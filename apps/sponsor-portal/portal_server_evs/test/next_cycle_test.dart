import 'package:portal_server_evs/src/next_cycle.dart';
import 'package:test/test.dart';

Map<String, Object?> row({
  required String entryType,
  String? studyEvent,
  String? endEvent,
}) =>
    {'entryType': entryType, 'study_event': studyEvent, 'end_event': endEvent};

void main() {
  test('no prior, tracking on, initial-selection off -> Cycle 1 Day 1', () {
    final r = computeNextCycle(
        existing: const [],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: false,
        requestedStudyEvent: null);
    expect(r, isA<NextCycleAuto>());
    expect((r as NextCycleAuto).studyEvent, 'Cycle 1 Day 1');
  });
  test('auto-increments past max locked cycle (incl. legacy alias rows)', () {
    // CUR-1539: the Cycle 1 row uses the frozen legacy alias
    // `questionnaire_finalized` (pre-rename logs); it must count as locked.
    final r = computeNextCycle(
        existing: [
          row(
              entryType: 'questionnaire_finalized',
              studyEvent: 'Cycle 1 Day 1'),
          row(entryType: 'questionnaire_locked', studyEvent: 'Cycle 2 Day 1'),
        ],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: false,
        requestedStudyEvent: null);
    expect((r as NextCycleAuto).studyEvent, 'Cycle 3 Day 1');
  });
  test('tracking disabled + a finalized instance -> blocked (single-use)', () {
    final r = computeNextCycle(
        existing: [row(entryType: 'questionnaire_locked', studyEvent: null)],
        cycleTrackingEnabled: false,
        requireInitialCycleSelection: false,
        requestedStudyEvent: null);
    expect(r, isA<NextCycleBlocked>());
  });
  test(
      'initial-selection required + no finalized cycle + none requested -> needsSelection',
      () {
    final r = computeNextCycle(
        existing: const [],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: true,
        requestedStudyEvent: null);
    expect(r, isA<NextCycleNeedsSelection>());
  });
  test('an active (non-finalized) instance -> blocked (duplicate open)', () {
    final r = computeNextCycle(
        existing: [
          row(entryType: 'questionnaire_assigned', studyEvent: 'Cycle 1 Day 1')
        ],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: false,
        requestedStudyEvent: null);
    expect(r, isA<NextCycleBlocked>());
  });
  test('a terminal-close finalized row (end_of_study) -> blocked', () {
    final r = computeNextCycle(
        existing: [
          row(
              entryType: 'questionnaire_locked',
              studyEvent: 'Cycle 2 Day 1',
              endEvent: 'end_of_study'),
        ],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: false,
        requestedStudyEvent: null);
    expect(r, isA<NextCycleBlocked>());
  });
  test('a non-terminal finalized row (end_event null) still auto-increments',
      () {
    final r = computeNextCycle(
        existing: [
          row(
              entryType: 'questionnaire_locked',
              studyEvent: 'Cycle 1 Day 1',
              endEvent: null),
        ],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: false,
        requestedStudyEvent: null);
    expect((r as NextCycleAuto).studyEvent, 'Cycle 2 Day 1');
  });
  test('requested study_event duplicating a finalized cycle -> blocked', () {
    final r = computeNextCycle(
        existing: [
          row(entryType: 'questionnaire_locked', studyEvent: 'Cycle 1 Day 1')
        ],
        cycleTrackingEnabled: true,
        requireInitialCycleSelection: true,
        requestedStudyEvent: 'Cycle 1 Day 1');
    expect(r, isA<NextCycleBlocked>());
  });
}
