// Verifies: DIARY-PRD-entry-overlap-resolution
import 'package:clinical_diary/read/diary_read.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntryRow _ep(String id, String start, String? end) => DiaryEntryRow(
  aggregateId: id,
  entryType: 'epistaxis_event',
  data: EpistaxisEventPayload(
    startTime: start,
    startTimeZone: 'UTC',
    startTimeUtcOffset: '+00:00',
    participantId: 'P-test',
    endTime: end,
    endTimeZone: end == null ? null : 'UTC',
    endTimeUtcOffset: end == null ? null : '+00:00',
  ).toJson(),
);

void main() {
  test('returns entries whose time range intersects the candidate', () {
    final rows = [
      _ep('a', '2025-10-15T10:00:00.000Z', '2025-10-15T11:00:00.000Z'),
      _ep('b', '2025-10-15T12:00:00.000Z', '2025-10-15T13:00:00.000Z'),
    ];
    final hits = overlappingEpistaxisEntries(
      rows,
      DateTime.parse('2025-10-15T10:30:00.000Z'),
      DateTime.parse('2025-10-15T10:45:00.000Z'),
    );
    expect(hits.map((r) => r.aggregateId), ['a']);
  });

  test('excludes the entry being edited', () {
    final rows = [
      _ep('a', '2025-10-15T10:00:00.000Z', '2025-10-15T11:00:00.000Z'),
    ];
    final hits = overlappingEpistaxisEntries(
      rows,
      DateTime.parse('2025-10-15T10:30:00.000Z'),
      DateTime.parse('2025-10-15T10:45:00.000Z'),
      excludeAggregateId: 'a',
    );
    expect(hits, isEmpty);
  });
}
