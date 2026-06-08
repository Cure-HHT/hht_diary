// Verifies: DIARY-PRD-day-disposition/A+C — converting a lone day-marker to a
//   nosebleed records the nosebleed AND tombstones the marker, leaving the day
//   nosebleed-only (a marker and a nosebleed never coexist). Adding a second
//   nosebleed to a day that already has one does NOT delete anything.
// Verifies: DIARY-PRD-day-disposition/B — marker↔marker re-disposition
//   (no_epistaxis → unknown) re-records on the shared day aggregate (latest-wins).
// Verifies: DIARY-PRD-day-disposition/D — adding a nosebleed to a day that already
//   has one does NOT tombstone/convert; a recorded nosebleed changes only by
//   edit/delete, never by re-disposition (one-way).
//
// Exercises the action sequence the shared re-disposition flow submits
// (recordNosebleedReplacingMarker: record_epistaxis_event then delete_entry on
// the marker) end-to-end through the REAL projections.
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late SembastBackend backend;
  late DiaryScopeRuntime rt;

  Future<DiaryView> readView() async {
    final finalized = (await backend.findViewRows(
      diaryEntriesViewName,
    )).map(DiaryEntryRow.fromViewRow).toList();
    final incomplete = (await backend.findViewRows(
      diaryIncompleteViewName,
    )).map(DiaryEntryRow.fromViewRow).toList();
    return DiaryView(finalized: finalized, incomplete: incomplete);
  }

  Future<String> submit(String action, Map<String, Object?> input) async {
    final r = await rt.scope.actionSubmitter.submit(
      ActionSubmission(actionName: action, rawInput: input),
    );
    return (r as DispatchSuccess<Object?>).result! as String;
  }

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'disp-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    backend = SembastBackend(database: db);
    rt = await bootstrapDiaryScope(
      backend: backend,
      deviceId: 'D',
      softwareVersion: 'clinical_diary@0.0.0-test',
      localUserId: 'P',
    );
  });

  tearDown(() async {
    await rt.dispose();
  });

  Map<String, Object?> epistaxisInput(String day) {
    final payload = EpistaxisEventPayload(
      startTime: '${day}T10:00:00.000Z',
      endTime: '${day}T10:05:00.000Z',
      startTimeZone: 'UTC',
      startTimeUtcOffset: '+00:00',
      participantId: 'P-test',
      endTimeZone: 'UTC',
      endTimeUtcOffset: '+00:00',
      intensity: NosebleedIntensity.dripping,
    );
    return payload.toJson();
  }

  test(
    'convert lone no_epistaxis marker → nosebleed: marker is gone',
    () async {
      const day = '2025-10-15';
      // Record the "No nosebleeds" marker.
      final markerId = await submit('record_no_epistaxis_day', {
        'date': day,
        'participantId': 'P',
      });

      var view = await readView();
      final marker = view.soleMarkerOn(day);
      expect(marker, isNotNull, reason: 'lone marker present before convert');

      // Convert: record a nosebleed, then tombstone the marker (what the shared
      // flow does on a successful save).
      final nbId = await submit('record_epistaxis_event', epistaxisInput(day));
      await submit('delete_entry', {
        'aggregateId': marker!.aggregateId,
        'entryType': marker.entryType,
        'changeReason': 'corrected',
      });
      expect(marker.aggregateId, markerId);

      view = await readView();
      final entries = view.entriesOn(day);
      expect(entries, hasLength(1));
      expect(entries.single.aggregateId, nbId);
      expect(entries.single.entryType, 'epistaxis_event');
      expect(view.dayStatus(day), DayStatus.nosebleed);
      expect(view.soleMarkerOn(day), isNull);
    },
  );

  test(
    'adding a nosebleed to a day with a nosebleed does not tombstone',
    () async {
      const day = '2025-10-16';
      final first = await submit('record_epistaxis_event', epistaxisInput(day));

      // soleMarkerOn is null (day already has a nosebleed) → the add handler
      // records WITHOUT a tombstone.
      var view = await readView();
      expect(view.soleMarkerOn(day), isNull);

      final second = await submit('record_epistaxis_event', {
        ...epistaxisInput(day),
        'startTime': '${day}T14:00:00.000Z',
        'endTime': '${day}T14:05:00.000Z',
      });

      view = await readView();
      final ids = view.entriesOn(day).map((e) => e.aggregateId).toSet();
      expect(ids, {
        first,
        second,
      }, reason: 'both nosebleeds remain; none deleted');
      expect(view.dayStatus(day), DayStatus.nosebleed);
    },
  );

  test('marker↔marker re-disposition: no_epistaxis → unknown', () async {
    const day = '2025-10-17';
    await submit('record_no_epistaxis_day', {
      'date': day,
      'participantId': 'P',
    });
    var view = await readView();
    expect(view.dayStatus(day), DayStatus.noNosebleed);

    // Re-record as "unknown" on the same shared day aggregate (latest-wins).
    await submit('record_unknown_day', {'date': day, 'participantId': 'P'});
    view = await readView();
    expect(view.dayStatus(day), DayStatus.unknown);
    // Still a single summary entry on the day (not two markers).
    expect(view.entriesOn(day), hasLength(1));
  });
}
