// Verifies: DIARY-DEV-reactive-read-path/B+C
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
  ).toJson(),
);
DiaryEntryRow _marker(String id, String date, String type) =>
    DiaryEntryRow(aggregateId: id, entryType: type, data: {'date': date});

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
}
