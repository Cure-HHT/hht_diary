// Verifies: DIARY-DEV-reactive-read-path/B+C
// Verifies: DIARY-PRD-day-disposition/A+C — soleMarkerOn returns the lone
//   day-marker (the convert-on-add tombstone target) only for a single-marker
//   day; null when the day has a nosebleed, multiple entries, or is empty.
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntryRow _ep(String id, String start) => DiaryEntryRow(
  aggregateId: id,
  entryType: 'epistaxis_event',
  data: EpistaxisEventPayload(
    startTime: start,
    startTimeZone: 'UTC',
    startTimeUtcOffset: '+00:00',
    participantId: 'P-test',
  ).toJson(),
);
DiaryEntryRow _marker(String id, String date, String type) => DiaryEntryRow(
  aggregateId: id,
  entryType: type,
  data: {'date': date, 'participantId': 'P-test'},
);
DiaryEntryRow _survey(String id, String completedAt) => DiaryEntryRow(
  aggregateId: id,
  entryType: 'nose_hht_survey',
  data: QuestionnaireSubmissionPayload(
    instanceId: 'inst-$id',
    questionnaireType: 'nose_hht',
    schemaVersion: 's1',
    contentVersion: 'c1',
    guiVersion: 'g1',
    completedAt: completedAt,
    responses: const {'q1': QuestionResponse(value: 0, displayLabel: 'None')},
  ).toJson(),
);

void main() {
  test(
    'splices finalized + incomplete; derives entries/dayStatus/incomplete',
    () {
      final view = DiaryView(
        finalized: [
          _ep('e1', '2025-10-15T10:00:00.000Z'),
          _marker('m1', '2025-10-14', 'no_epistaxis_event'),
        ],
        incomplete: [_ep('e2', '2025-10-16T09:00:00.000Z')],
      );
      expect(view.entries.map((v) => v.aggregateId), containsAll(['e1', 'm1']));
      expect(view.entries.every((v) => v.isComplete), isTrue);
      expect(view.incompleteEntries.single.aggregateId, 'e2');
      expect(view.incompleteEntries.single.isComplete, isFalse);
      expect(view.dayStatus('2025-10-15'), DayStatus.nosebleed);
      expect(view.dayStatus('2025-10-14'), DayStatus.noNosebleed);
      expect(
        view.dayStatus('2025-10-16'),
        DayStatus.incomplete,
      ); // from checkpoint
      expect(view.dayStatus('2025-10-13'), DayStatus.notRecorded);
      expect(view.hadNosebleedOn('2025-10-15'), isTrue);
    },
  );

  test('entriesOn returns finalized entries for a given local date', () {
    final view = DiaryView(
      finalized: [_ep('e1', '2025-10-15T10:00:00.000Z')],
      incomplete: const [],
    );
    expect(view.entriesOn('2025-10-15').single.aggregateId, 'e1');
    expect(view.entriesOn('2025-10-14'), isEmpty);
  });

  test('recent returns only entries in the given days', () {
    final view = DiaryView(
      finalized: [
        _ep('e1', '2025-10-15T10:00:00.000Z'),
        _ep('e2', '2025-10-14T10:00:00.000Z'),
        _ep('e3', '2025-10-10T10:00:00.000Z'),
      ],
      incomplete: const [],
    );
    final recent = view.recent(['2025-10-15', '2025-10-14']);
    expect(recent.map((v) => v.aggregateId), containsAll(['e1', 'e2']));
    expect(recent.map((v) => v.aggregateId), isNot(contains('e3')));
  });

  group('soleMarkerOn', () {
    test('single marker → returns it', () {
      final view = DiaryView(
        finalized: [
          _marker('P:2025-10-14', '2025-10-14', 'no_epistaxis_event'),
        ],
        incomplete: const [],
      );
      final m = view.soleMarkerOn('2025-10-14');
      expect(m, isA<DayMarkerView>());
      expect(m!.aggregateId, 'P:2025-10-14');
      expect(m.entryType, 'no_epistaxis_event');
    });

    test('marker + completed survey → returns the marker (survey ignored)', () {
      // A dated `<id>_survey` shares the day with a lone day-marker. Surveys are
      // non-clinical and irrelevant to marker-replacement, so soleMarkerOn must
      // still yield the marker (the convert-on-add tombstone target).
      final view = DiaryView(
        finalized: [
          _marker('P:2025-10-14', '2025-10-14', 'no_epistaxis_event'),
          _survey('s1', '2025-10-14T11:00:00.000Z'),
        ],
        incomplete: const [],
      );
      final m = view.soleMarkerOn('2025-10-14');
      expect(m, isA<DayMarkerView>());
      expect(m!.aggregateId, 'P:2025-10-14');
      expect(m.entryType, 'no_epistaxis_event');
    });

    test('marker + nosebleed → null', () {
      final view = DiaryView(
        finalized: [
          _marker('P:2025-10-14', '2025-10-14', 'no_epistaxis_event'),
          _ep('e1', '2025-10-14T10:00:00.000Z'),
        ],
        incomplete: const [],
      );
      expect(view.soleMarkerOn('2025-10-14'), isNull);
    });

    test('two markers → null', () {
      final view = DiaryView(
        finalized: [
          _marker('P:2025-10-14', '2025-10-14', 'no_epistaxis_event'),
          _marker('P:2025-10-14#b', '2025-10-14', 'unknown_day_event'),
        ],
        incomplete: const [],
      );
      expect(view.soleMarkerOn('2025-10-14'), isNull);
    });

    test('empty day → null', () {
      final view = DiaryView(finalized: const [], incomplete: const []);
      expect(view.soleMarkerOn('2025-10-14'), isNull);
    });

    test('nosebleed only → null', () {
      final view = DiaryView(
        finalized: [_ep('e1', '2025-10-14T10:00:00.000Z')],
        incomplete: const [],
      );
      expect(view.soleMarkerOn('2025-10-14'), isNull);
    });
  });
}
