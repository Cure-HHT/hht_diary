// Verifies: DIARY-GUI-calendar-day-view/A — a "no nosebleeds" day and an
//   "unknown" day are distinguishable in the materialized canonical view, so the
//   calendar colors/labels them correctly (no_epistaxis -> noNosebleed, not the
//   unknown fallback).
//
// Regression for the calendar bug where every dateless day-marker rendered as
// "unknown" (yellow / "I don't know"): the canonical view row dropped the
// event's entryType, and no_epistaxis_event / unknown_day_event have identical
// {date} payloads, so DiaryEntryRow.fromViewRow could not tell them apart. The
// existing widget tests missed it by constructing DiaryEntryRow with an explicit
// entryType; this drives the REAL projection end to end.
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'no-nosebleed and unknown day markers materialize with distinct entryType '
    'and day status',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'marker-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final backend = SembastBackend(database: db);
      final rt = await bootstrapDiaryScope(
        backend: backend,
        deviceId: 'D',
        softwareVersion: 'clinical_diary@0.0.0-test',
        localUserId: 'P',
      );

      expect(
        await rt.scope.actionSubmitter.submit(
          const ActionSubmission(
            actionName: 'record_no_epistaxis_day',
            rawInput: {'date': '2025-10-15'},
          ),
        ),
        isA<DispatchSuccess<Object?>>(),
      );
      expect(
        await rt.scope.actionSubmitter.submit(
          const ActionSubmission(
            actionName: 'record_unknown_day',
            rawInput: {'date': '2025-10-16'},
          ),
        ),
        isA<DispatchSuccess<Object?>>(),
      );

      // Read the canonical rows the way the calendar does: via the view +
      // DiaryEntryRow.fromViewRow (NOT by hand-constructing the row).
      final rawRows = await backend.findViewRows(diaryEntriesViewName);
      final rows = rawRows.map(DiaryEntryRow.fromViewRow).toList();

      final noBleed = rows.firstWhere((r) => r.localDate == '2025-10-15');
      final unknown = rows.firstWhere((r) => r.localDate == '2025-10-16');

      // The lib now stamps entryType onto the row, so the two markers are
      // distinguishable (previously both inferred as unknown_day_event).
      expect(noBleed.entryType, 'no_epistaxis_event');
      expect(unknown.entryType, 'unknown_day_event');

      final view = DiaryView(finalized: rows, incomplete: const []);
      expect(view.dayStatus('2025-10-15'), DayStatus.noNosebleed);
      expect(view.dayStatus('2025-10-16'), DayStatus.unknown);

      await rt.dispose();
    },
  );
}
