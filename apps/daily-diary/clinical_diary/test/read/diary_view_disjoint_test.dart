// Verifies: DIARY-DEV-reactive-read-path/B — finalized and incomplete are kept
//   disjoint by aggregate id, so a finalized aggregate is never ALSO reported as
//   incomplete (a stale checkpoint row that lingers after finalize is ignored).
//   This is what stops the home list from rendering one aggregate in both a
//   finalized and an incomplete group, where the shared scroll-to GlobalKey
//   would collide ("Duplicate keys found").
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntryRow _epi(String id, String startIso) => DiaryEntryRow(
  aggregateId: id,
  entryType: 'epistaxis_event',
  data: <String, Object?>{
    'startTime': startIso,
    'startTimeZone': 'UTC',
    'startTimeUtcOffset': '+00:00',
  },
);

void main() {
  test(
    'an aggregate present in both finalized and incomplete is finalized-only',
    () {
      // X is finalized but a stale checkpoint row for X also lingers in the
      // incomplete view; Y is a genuine open draft.
      final view = DiaryView(
        finalized: [_epi('X', '2025-05-31T16:00:00.000Z')],
        incomplete: [
          _epi('X', '2025-05-31T16:00:00.000Z'),
          _epi('Y', '2025-05-30T10:00:00.000Z'),
        ],
      );

      // X dropped from incomplete (only the genuine draft Y remains).
      expect(view.incompleteEntries.map((e) => e.aggregateId).toList(), ['Y']);
      expect(view.incompleteEntriesOn('2025-05-31'), isEmpty);
      expect(view.incompleteDates, isNot(contains('2025-05-31')));
      expect(view.incompleteDates, contains('2025-05-30'));

      // X is finalized exactly once; its day reads as a finalized nosebleed.
      expect(view.entries.where((e) => e.aggregateId == 'X').length, 1);
      expect(view.dayStatus('2025-05-31'), DayStatus.nosebleed);
      // Y's day is still incomplete.
      expect(view.dayStatus('2025-05-30'), DayStatus.incomplete);
    },
  );
}
