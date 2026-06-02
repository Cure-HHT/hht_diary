// Verifies: DIARY-DEV-reactive-read-path/B — tombstoned (deleted) entries do not
//   contribute to any materialized view. A day whose entries are all deleted
//   reads as never-recorded, so the calendar offers the empty-day 3-choice page
//   again (routes on entriesOn + incompleteEntriesOn, both empty).
//
// End-to-end through the REAL projections: record -> delete -> the day is clear.
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test("deleting a day's only entry clears it from every view", () async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'tombstone-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final backend = SembastBackend(database: db);
    final rt = await bootstrapDiaryScope(
      backend: backend,
      deviceId: 'D',
      softwareVersion: 'clinical_diary@0.0.0-test',
      localUserId: 'P',
    );

    Future<DiaryView> readView() async {
      final finalized = (await backend.findViewRows(
        diaryEntriesViewName,
      )).map(DiaryEntryRow.fromViewRow).toList();
      final incomplete = (await backend.findViewRows(
        diaryIncompleteViewName,
      )).map(DiaryEntryRow.fromViewRow).toList();
      return DiaryView(finalized: finalized, incomplete: incomplete);
    }

    // Record a "no nosebleed" marker on 2025-10-15.
    final recorded = await rt.scope.actionSubmitter.submit(
      const ActionSubmission(
        actionName: 'record_no_epistaxis_day',
        rawInput: {'date': '2025-10-15'},
      ),
    );
    final aggregateId =
        (recorded as DispatchSuccess<Object?>).result! as String;

    var view = await readView();
    expect(view.dayStatus('2025-10-15'), DayStatus.noNosebleed);
    expect(view.entriesOn('2025-10-15'), isNotEmpty);

    // Delete it.
    expect(
      await rt.scope.actionSubmitter.submit(
        ActionSubmission(
          actionName: 'delete_entry',
          rawInput: {
            'aggregateId': aggregateId,
            'entryType': 'no_epistaxis_event',
            'changeReason': 'entered-in-error',
          },
        ),
      ),
      isA<DispatchSuccess<Object?>>(),
    );

    // The day is now clear in every view — as if nothing was ever logged.
    view = await readView();
    expect(view.entriesOn('2025-10-15'), isEmpty);
    expect(view.incompleteEntriesOn('2025-10-15'), isEmpty);
    expect(view.incompleteDates, isNot(contains('2025-10-15')));
    expect(view.dayStatus('2025-10-15'), DayStatus.notRecorded);

    await rt.dispose();
  });
}
