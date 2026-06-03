// Verifies: DIARY-PRD-entry-overlap-resolution/A
// Verifies: DIARY-GUI-entry-overlap-resolution/A
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A finalized epistaxis row with an explicit `updatedAt` recency stamp.
DiaryEntryRow _ep(
  String id,
  String start,
  String? end, {
  required String updatedAt,
}) {
  final data = EpistaxisEventPayload(
    startTime: start,
    startTimeZone: 'UTC',
    startTimeUtcOffset: '+00:00',
    endTime: end,
    endTimeZone: end == null ? null : 'UTC',
    endTimeUtcOffset: end == null ? null : '+00:00',
  ).toJson();
  data['updatedAt'] = updatedAt;
  return DiaryEntryRow(
    aggregateId: id,
    entryType: 'epistaxis_event',
    data: data,
  );
}

DiaryView _view(List<DiaryEntryRow> finalized) =>
    DiaryView(finalized: finalized, incomplete: const []);

void main() {
  test(
    'surfaces an overlapping pair, pre-existing left / just-touched right',
    () {
      final view = _view([
        _ep(
          'older',
          '2025-10-15T13:00:00.000Z',
          '2025-10-15T14:00:00.000Z',
          updatedAt: '2025-10-15T14:00:00.000Z',
        ),
        _ep(
          'newer',
          '2025-10-15T13:30:00.000Z',
          '2025-10-15T13:45:00.000Z',
          updatedAt: '2025-10-15T15:00:00.000Z',
        ),
      ]);
      final pairs = overlapPairs(view);
      expect(pairs, hasLength(1));
      expect(pairs.single.preExisting.aggregateId, 'older');
      expect(pairs.single.justTouched.aggregateId, 'newer');
    },
  );

  test('non-overlapping rows yield no pair', () {
    final view = _view([
      _ep(
        'a',
        '2025-10-15T10:00:00.000Z',
        '2025-10-15T11:00:00.000Z',
        updatedAt: '2025-10-15T11:00:00.000Z',
      ),
      _ep(
        'b',
        '2025-10-15T12:00:00.000Z',
        '2025-10-15T13:00:00.000Z',
        updatedAt: '2025-10-15T13:00:00.000Z',
      ),
    ]);
    expect(overlapPairs(view), isEmpty);
  });

  test('ignores non-epistaxis rows', () {
    final marker = DiaryEntryRow(
      aggregateId: 'm',
      entryType: 'no_epistaxis_event',
      data: const DayMarkerPayload(date: '2025-10-15').toJson()
        ..['updatedAt'] = '2025-10-15T13:30:00.000Z',
    );
    final view = _view([
      _ep(
        'a',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      marker,
    ]);
    expect(overlapPairs(view), isEmpty);
  });

  test('open-ended entry is a point at its start (touching != overlap)', () {
    final view = _view([
      _ep(
        'a',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _ep(
        'open',
        '2025-10-15T14:00:00.000Z',
        null,
        updatedAt: '2025-10-15T15:00:00.000Z',
      ),
    ]);
    expect(overlapPairs(view), isEmpty);
  });

  test('three-way pile-up yields the overlapping pairs', () {
    final view = _view([
      _ep(
        'a',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T13:40:00.000Z',
        updatedAt: '2025-10-15T13:40:00.000Z',
      ),
      _ep(
        'b',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T14:10:00.000Z',
        updatedAt: '2025-10-15T14:10:00.000Z',
      ),
      _ep(
        'c',
        '2025-10-15T14:00:00.000Z',
        '2025-10-15T14:30:00.000Z',
        updatedAt: '2025-10-15T14:30:00.000Z',
      ),
    ]);
    final keys = overlapPairs(view)
        .map((p) => '${p.preExisting.aggregateId}-${p.justTouched.aggregateId}')
        .toSet();
    expect(keys, {'a-b', 'b-c'});
  });

  test('orders by updatedAt, not aggregateId', () {
    // 'zzz' was touched EARLIER than 'aaa', so 'zzz' is preExisting even though
    // its id sorts AFTER 'aaa'. This guards the recency-key read: if the wrong
    // key were read both rows collapse to epoch and the tie-break on id would
    // (wrongly) make 'aaa' preExisting.
    final view = _view([
      _ep(
        'zzz',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _ep(
        'aaa',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T13:45:00.000Z',
        updatedAt: '2025-10-15T16:00:00.000Z',
      ),
    ]);
    final pair = overlapPairs(view).single;
    expect(pair.preExisting.aggregateId, 'zzz');
    expect(pair.justTouched.aggregateId, 'aaa');
  });

  test('equal updatedAt breaks deterministically on aggregateId', () {
    // Same recency: the lexicographically smaller id is preExisting (left),
    // the larger is justTouched (right). Order of insertion does not matter.
    final view = _view([
      _ep(
        'zzz',
        '2025-10-15T13:30:00.000Z',
        '2025-10-15T13:45:00.000Z',
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
      _ep(
        'aaa',
        '2025-10-15T13:00:00.000Z',
        '2025-10-15T14:00:00.000Z',
        updatedAt: '2025-10-15T14:00:00.000Z',
      ),
    ]);
    final pair = overlapPairs(view).single;
    expect(pair.preExisting.aggregateId, 'aaa');
    expect(pair.justTouched.aggregateId, 'zzz');
  });
}
