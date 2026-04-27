import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/materialization/diary_entries_materializer.dart';
import 'package:event_sourcing_datastore/src/materialization/entry_promoter.dart';
import 'package:event_sourcing_datastore/src/materialization/rebuild.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/map_entry_type_definition_lookup.dart';

void main() {
  group('rebuildMaterializedView', () {
    late SembastBackend backend;
    var counter = 0;

    setUp(() async {
      counter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'rebuild-$counter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    EntryTypeDefinition defFor(String id, {String? effectiveDatePath}) =>
        EntryTypeDefinition(
          id: id,
          registeredVersion: 1,
          name: id,
          widgetId: 'epistaxis_form_v1',
          widgetConfig: const <String, Object?>{},
          effectiveDatePath: effectiveDatePath,
        );

    MapEntryTypeDefinitionLookup lookupFor(List<EntryTypeDefinition> defs) =>
        MapEntryTypeDefinitionLookup.fromDefinitions(defs);

    Future<int> appendEventViaBackend({
      required String eventId,
      required String aggregateId,
      required String entryType,
      required String eventType,
      required Map<String, dynamic> data,
      required DateTime clientTimestamp,
    }) async {
      final result = await backend.transaction<int>((txn) async {
        final seq = await backend.nextSequenceNumber(txn);
        final appended = await backend.appendEvent(
          txn,
          StoredEvent(
            key: 0,
            eventId: eventId,
            aggregateId: aggregateId,
            aggregateType: 'DiaryEntry',
            entryType: entryType,
            entryTypeVersion: 1,
            libFormatVersion: 1,
            eventType: eventType,
            sequenceNumber: seq,
            data: data,
            metadata: const <String, dynamic>{},
            initiator: const UserInitiator('u1'),
            clientTimestamp: clientTimestamp,
            eventHash: 'hash-$eventId',
          ),
        );
        return appended.sequenceNumber;
      });
      return result;
    }

    // Verifies: REQ-d00121-G+H — empty event log produces an empty view and
    // a zero aggregate count.
    test(
      'REQ-d00121-G+H: empty event log → returns 0, diary_entries stays empty',
      () async {
        final lookup = lookupFor([defFor('epistaxis_event')]);

        final count = await rebuildMaterializedView(backend, lookup);

        expect(count, 0);
        expect(await backend.findEntries(), isEmpty);
      },
    );

    // Verifies: REQ-d00121-G+H — per-aggregate fold lands the final row from
    // the last event; count reflects one distinct aggregate_id.
    test('REQ-d00121-G+H: three events on one aggregate → returns 1; final row '
        'reflects last event', () async {
      await appendEventViaBackend(
        eventId: 'e1',
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'checkpoint',
        data: <String, dynamic>{
          'answers': <String, Object?>{'startTime': '2026-04-22T10:00:00Z'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
      );
      await appendEventViaBackend(
        eventId: 'e2',
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{
            'startTime': '2026-04-22T10:00:00Z',
            'intensity': 'mild',
          },
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:30:00Z'),
      );
      await appendEventViaBackend(
        eventId: 'e3',
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{
            'startTime': '2026-04-22T10:00:00Z',
            'intensity': 'moderate',
          },
        },
        clientTimestamp: DateTime.parse('2026-04-22T11:00:00Z'),
      );

      final count = await rebuildMaterializedView(
        backend,
        lookupFor([defFor('epistaxis_event', effectiveDatePath: 'startTime')]),
      );

      expect(count, 1);
      final rows = await backend.findEntries();
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.entryId, 'agg-1');
      expect(row.isComplete, isTrue);
      expect(row.isDeleted, isFalse);
      expect(row.latestEventId, 'e3');
      expect(row.currentAnswers['intensity'], 'moderate');
    });

    // Verifies: REQ-d00121-H — returned count equals the number of distinct
    // aggregate_id values in the rebuilt view.
    test('REQ-d00121-H: two events on agg A, one on agg B → returns 2; both '
        'rows present', () async {
      await appendEventViaBackend(
        eventId: 'a1',
        aggregateId: 'agg-A',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{'intensity': 'mild'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
      );
      await appendEventViaBackend(
        eventId: 'a2',
        aggregateId: 'agg-A',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{'intensity': 'severe'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:30:00Z'),
      );
      await appendEventViaBackend(
        eventId: 'b1',
        aggregateId: 'agg-B',
        entryType: 'nose_hht_survey',
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{'q1': 'yes'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T11:00:00Z'),
      );

      final count = await rebuildMaterializedView(
        backend,
        lookupFor([defFor('epistaxis_event'), defFor('nose_hht_survey')]),
      );

      expect(count, 2);
      final rows = await backend.findEntries();
      expect(rows.length, 2);
      final byId = {for (final r in rows) r.entryId: r};
      expect(byId.containsKey('agg-A'), isTrue);
      expect(byId.containsKey('agg-B'), isTrue);
      expect(byId['agg-A']!.currentAnswers['intensity'], 'severe');
      expect(byId['agg-B']!.currentAnswers['q1'], 'yes');
    });

    // Verifies: REQ-d00121-D — tombstone fold lands an is_deleted=true row
    // in the rebuilt view; row is not pruned.
    test(
      'REQ-d00121-D: tombstone event → aggregate row has is_deleted=true and '
      'remains in the view',
      () async {
        await appendEventViaBackend(
          eventId: 'e1',
          aggregateId: 'agg-1',
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: <String, dynamic>{
            'answers': <String, Object?>{'intensity': 'mild'},
          },
          clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
        );
        await appendEventViaBackend(
          eventId: 'e2',
          aggregateId: 'agg-1',
          entryType: 'epistaxis_event',
          eventType: 'tombstone',
          data: <String, dynamic>{'answers': <String, Object?>{}},
          clientTimestamp: DateTime.parse('2026-04-22T10:30:00Z'),
        );

        final count = await rebuildMaterializedView(
          backend,
          lookupFor([defFor('epistaxis_event')]),
        );

        expect(count, 1);
        final rows = await backend.findEntries();
        expect(rows.length, 1);
        expect(rows.single.isDeleted, isTrue);
        expect(rows.single.currentAnswers['intensity'], 'mild');
      },
    );

    // Verifies: REQ-d00121-G — rebuild replaces the entire diary_entries
    // store; prior contents are not read as input and rows not derivable
    // from the event log are dropped.
    test('REQ-d00121-G: rebuild removes prior diary_entries rows that are not '
        'derivable from the event log', () async {
      // Seed diary_entries with garbage not backed by any event.
      await backend.transaction((txn) async {
        await backend.upsertEntry(
          txn,
          _garbageEntry('garbage-1', 'not_an_entry_type'),
        );
        await backend.upsertEntry(
          txn,
          _garbageEntry('garbage-2', 'still_not_valid'),
        );
      });
      // One legitimate event on agg-1.
      await appendEventViaBackend(
        eventId: 'e1',
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{'intensity': 'mild'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
      );

      // Two garbage rows exist prior to rebuild. The event-log append
      // does not populate diary_entries — only the rebuild (or the Phase-5
      // write path) writes materialized rows — so pre-rebuild findEntries
      // returns only the two garbage rows seeded above.
      expect((await backend.findEntries()).length, 2);

      final count = await rebuildMaterializedView(
        backend,
        lookupFor([defFor('epistaxis_event')]),
      );

      expect(count, 1);
      final rows = await backend.findEntries();
      expect(rows.length, 1);
      expect(rows.single.entryId, 'agg-1');
      expect(rows.map((r) => r.entryId), isNot(contains('garbage-1')));
      expect(rows.map((r) => r.entryId), isNot(contains('garbage-2')));
    });

    // Verifies: REQ-d00121-G+H — rebuild is idempotent; the view and the
    // count are identical across consecutive runs with the same event log.
    test(
      'REQ-d00121-G+H: rebuild is idempotent — running twice yields the same '
      'result',
      () async {
        await appendEventViaBackend(
          eventId: 'e1',
          aggregateId: 'agg-1',
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: <String, dynamic>{
            'answers': <String, Object?>{'intensity': 'mild'},
          },
          clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
        );
        final lookup = lookupFor([defFor('epistaxis_event')]);

        final firstCount = await rebuildMaterializedView(backend, lookup);
        final afterFirst = await backend.findEntries();

        final secondCount = await rebuildMaterializedView(backend, lookup);
        final afterSecond = await backend.findEntries();

        expect(firstCount, secondCount);
        expect(afterFirst.length, afterSecond.length);
        expect(afterFirst.single, equals(afterSecond.single));
      },
    );

    // Verifies: REQ-d00121-G — the fold step requires every event's
    // entry_type to resolve via lookup; an unknown type halts the rebuild
    // loudly rather than silently dropping events from the rebuilt view.
    test(
      'REQ-d00121-G: unknown entry_type in the event log raises StateError — '
      'data integrity failure surfaced loudly',
      () async {
        await appendEventViaBackend(
          eventId: 'e1',
          aggregateId: 'agg-1',
          entryType: 'never_registered_type',
          eventType: 'finalized',
          data: <String, dynamic>{
            'answers': <String, Object?>{'intensity': 'mild'},
          },
          clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
        );

        expect(
          () => rebuildMaterializedView(
            backend,
            lookupFor([defFor('epistaxis_event')]),
          ),
          throwsStateError,
        );
      },
    );

    // Verifies: REQ-d00121-G+H — chunked streaming read preserves the "read
    // all events ordered by sequence_number, fold through DiaryEntriesMaterializer.foldPure"
    // contract across chunk boundaries; final view and count are unaffected
    // by the chunking.
    test('REQ-d00121-G+H: event log larger than the streaming chunk size is '
        'rebuilt correctly — no events are dropped or double-counted at chunk '
        'boundaries, per-aggregate fold order is preserved', () async {
      // 1,250 events — comfortably larger than the 500-event chunk, with
      // a partial trailing chunk. Two aggregates, interleaved, so a naive
      // chunk implementation that resets per-aggregate state per chunk
      // would produce a wrong final row.
      const totalEvents = 1250;
      for (var i = 0; i < totalEvents; i++) {
        final aggregateId = (i.isEven) ? 'agg-even' : 'agg-odd';
        final isLast = i == totalEvents - 1 || i == totalEvents - 2;
        await appendEventViaBackend(
          eventId: 'ev-$i',
          aggregateId: aggregateId,
          entryType: 'epistaxis_event',
          eventType: isLast ? 'finalized' : 'checkpoint',
          data: <String, dynamic>{
            'answers': <String, Object?>{'index': i},
          },
          clientTimestamp: DateTime.utc(
            2026,
            4,
            22,
            10,
          ).add(Duration(seconds: i)),
        );
      }

      final count = await rebuildMaterializedView(
        backend,
        lookupFor([defFor('epistaxis_event')]),
      );
      expect(count, 2);

      final rows = await backend.findEntries();
      final byId = {for (final r in rows) r.entryId: r};
      // Each aggregate's final event (indices 1249 for agg-odd and 1248
      // for agg-even) wrote `{'index': N}` into current_answers. Verify
      // the fold walked the entire log: the stored row reflects the LAST
      // event for each aggregate, not any earlier chunk's state.
      expect(byId['agg-odd']!.currentAnswers['index'], 1249);
      expect(byId['agg-even']!.currentAnswers['index'], 1248);
      expect(byId['agg-odd']!.isComplete, isTrue);
      expect(byId['agg-even']!.isComplete, isTrue);
    });
  });

  group('rebuildView (parameterized) — REQ-d00140-D', () {
    late SembastBackend backend;
    var counter = 0;

    setUp(() async {
      counter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'rebuild-param-$counter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    EntryTypeDefinition defFor(String id) => EntryTypeDefinition(
      id: id,
      registeredVersion: 1,
      name: id,
      widgetId: 'w',
      widgetConfig: const <String, Object?>{},
    );

    MapEntryTypeDefinitionLookup lookupFor(List<EntryTypeDefinition> defs) =>
        MapEntryTypeDefinitionLookup.fromDefinitions(defs);

    Future<void> appendEvent({
      required String eventId,
      required String aggregateId,
      required String entryType,
      required String eventType,
      required Map<String, dynamic> data,
      required DateTime clientTimestamp,
    }) async {
      await backend.transaction<void>((txn) async {
        final seq = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(
          txn,
          StoredEvent(
            key: 0,
            eventId: eventId,
            aggregateId: aggregateId,
            aggregateType: 'DiaryEntry',
            entryType: entryType,
            entryTypeVersion: 1,
            libFormatVersion: 1,
            eventType: eventType,
            sequenceNumber: seq,
            data: data,
            metadata: const <String, dynamic>{},
            initiator: const UserInitiator('u1'),
            clientTimestamp: clientTimestamp,
            eventHash: 'hash-$eventId',
          ),
        );
      });
    }

    // Verifies: REQ-d00140-D — strict-superset failure raises ArgumentError
    // when a previously-registered entry type is omitted from the supplied
    // map, and no destructive write happens.
    test('REQ-d00140-D: strict-superset failure on missing existing entry '
        'type', () async {
      // Seed an existing target-version entry.
      await backend.transaction((txn) async {
        await backend.writeViewTargetVersionInTxn(
          txn,
          'diary_entries',
          'epistaxis_event',
          1,
        );
        await backend.writeViewTargetVersionInTxn(
          txn,
          'diary_entries',
          'nose_hht_survey',
          1,
        );
      });
      const m = DiaryEntriesMaterializer(promoter: identityPromoter);
      await expectLater(
        rebuildView(
          m,
          backend,
          lookupFor([defFor('epistaxis_event'), defFor('nose_hht_survey')]),
          // 'nose_hht_survey' missing → strict-superset violation.
          targetVersionByEntryType: const <String, int>{'epistaxis_event': 1},
        ),
        throwsArgumentError,
      );
      // Existing entries remain.
      final stored = await backend.transaction<Map<String, int>>(
        (txn) async =>
            backend.readAllViewTargetVersionsInTxn(txn, 'diary_entries'),
      );
      expect(stored.containsKey('nose_hht_survey'), isTrue);
    });

    // Verifies: REQ-d00140-D — adding a new entry type during rebuild is
    // allowed (strict superset).
    test('REQ-d00140-D: superset accept — new entry type added', () async {
      await backend.transaction((txn) async {
        await backend.writeViewTargetVersionInTxn(
          txn,
          'diary_entries',
          'epistaxis_event',
          1,
        );
      });
      await appendEvent(
        eventId: 'e1',
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: const <String, dynamic>{
          'answers': <String, Object?>{'intensity': 'mild'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
      );
      const m = DiaryEntriesMaterializer(promoter: identityPromoter);
      final processed = await rebuildView(
        m,
        backend,
        lookupFor([defFor('epistaxis_event'), defFor('newcomer_type')]),
        targetVersionByEntryType: const <String, int>{
          'epistaxis_event': 1,
          'newcomer_type': 2, // brand new — allowed
        },
      );
      expect(processed, 1);
      final stored = await backend.transaction<Map<String, int>>(
        (txn) async =>
            backend.readAllViewTargetVersionsInTxn(txn, 'diary_entries'),
      );
      expect(stored, <String, int>{'epistaxis_event': 1, 'newcomer_type': 2});
    });

    // Verifies: REQ-d00140-D — running rebuild twice with the same map
    // produces the same view rows (idempotent).
    test('REQ-d00140-D: idempotent rebuild', () async {
      await appendEvent(
        eventId: 'e1',
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: const <String, dynamic>{
          'answers': <String, Object?>{'intensity': 'mild'},
        },
        clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
      );
      const m = DiaryEntriesMaterializer(promoter: identityPromoter);
      final lookup = lookupFor([defFor('epistaxis_event')]);
      const map = <String, int>{'epistaxis_event': 1};
      final first = await rebuildView(
        m,
        backend,
        lookup,
        targetVersionByEntryType: map,
      );
      final firstRows = await backend.findEntries();
      final second = await rebuildView(
        m,
        backend,
        lookup,
        targetVersionByEntryType: map,
      );
      final secondRows = await backend.findEntries();
      expect(first, second);
      expect(firstRows.length, secondRows.length);
      expect(firstRows.single.toJson(), equals(secondRows.single.toJson()));
    });

    // Verifies: REQ-d00140-D — an event in the log whose entry_type is not
    // in the supplied map raises ArgumentError. Every materialized event
    // needs a target version to promote toward.
    test(
      'REQ-d00140-D: unmapped event entry-type raises ArgumentError',
      () async {
        await appendEvent(
          eventId: 'e1',
          aggregateId: 'agg-1',
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: const <String, dynamic>{
            'answers': <String, Object?>{'intensity': 'mild'},
          },
          clientTimestamp: DateTime.parse('2026-04-22T10:00:00Z'),
        );
        const m = DiaryEntriesMaterializer(promoter: identityPromoter);
        await expectLater(
          rebuildView(
            m,
            backend,
            lookupFor([defFor('epistaxis_event')]),
            // Map is non-empty, but does not cover the event's entry_type.
            // Strict-superset check passes (no existing rows), but the
            // per-event lookup fails.
            targetVersionByEntryType: const <String, int>{'unrelated': 1},
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

DiaryEntry _garbageEntry(String entryId, String entryType) => DiaryEntry(
  entryId: entryId,
  entryType: entryType,
  effectiveDate: DateTime.utc(2000),
  currentAnswers: const <String, Object?>{'garbage': true},
  isComplete: true,
  isDeleted: false,
  latestEventId: 'does-not-exist',
  updatedAt: DateTime.utc(2000),
);
