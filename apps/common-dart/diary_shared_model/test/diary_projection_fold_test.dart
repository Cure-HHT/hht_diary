// Verifies: DIARY-DEV-shared-events-catalog/C+E
//
// End-to-end fold of the canonical diary-entries projection over a real
// in-memory EventStore: finalized events fold into rows, checkpoints are
// excluded (P6), and a tombstone deletes the row.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'dsm-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final entryTypes = EntryTypeRegistry()
    ..register(
      const EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 1,
        name: 'Epistaxis Event',
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'no_epistaxis_event',
        registeredVersion: 1,
        name: 'No Epistaxis Event',
      ),
    );
  final projections = ProjectionRegistry()..register(diaryEntriesProjection);
  return EventStore.open(
    storage: backend,
    entryTypes: entryTypes,
    source: const Source(
      hopId: 'mobile',
      identifier: 'test',
      softwareVersion: '0.0.0-test',
    ),
    securityContexts: SembastSecurityContextStore(backend: backend),
    projections: projections,
  );
}

Future<List<Update<Map<String, Object?>>>> _drain(EventStore store) async {
  final out = <Update<Map<String, Object?>>>[];
  final sub = store
      .subscribe<Map<String, Object?>>(
        const SubscriptionFilter(aggregateTypes: {diaryEntryAggregateType}),
        AggregateMode<Map<String, Object?>>(
          viewName: diaryEntriesViewName,
          mapper: (row) => row,
        ),
      )
      .listen(out.add);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  await sub.cancel();
  return out;
}

void main() {
  test(
    'DIARY-DEV-shared-events-catalog/C: finalized folds, checkpoint excluded',
    () async {
      final store = await _open();
      await store.append(
        entryType: 'epistaxis_event',
        aggregateType: diaryEntryAggregateType,
        aggregateId: 'e1',
        eventType: 'finalized',
        data: const EpistaxisEventPayload(
          startTime: '2025-10-15T14:30:00.000-05:00',
          startTimeZone: 'America/New_York',
          startTimeUtcOffset: '-05:00',
          intensity: NosebleedIntensity.dripping,
          participantId: 'P-test',
        ).toJson(),
        initiator: const UserInitiator('u1'),
      );
      // A checkpoint on a different aggregate must NOT enter the canonical view.
      await store.append(
        entryType: 'epistaxis_event',
        aggregateType: diaryEntryAggregateType,
        aggregateId: 'e2',
        eventType: 'checkpoint',
        data: const {
          'startTime': '2025-10-15T09:00:00.000-05:00',
          'participantId': 'P-test',
        },
        initiator: const UserInitiator('u1'),
      );

      final rows = (await _drain(store))
          .whereType<Snapshot<Map<String, Object?>>>()
          .map((s) => s.value)
          .whereType<Map<String, Object?>>()
          .toList();
      expect(rows.map((r) => r['aggregateId']), equals(['e1']));
      expect(rows.single['startTime'], '2025-10-15T14:30:00.000-05:00');
      await store.close();
    },
  );

  test(
    'DIARY-DEV-shared-events-catalog/C: tombstone deletes the row',
    () async {
      final store = await _open();
      await store.append(
        entryType: 'no_epistaxis_event',
        aggregateType: diaryEntryAggregateType,
        aggregateId: 'd1',
        eventType: 'finalized',
        data: const {'date': '2025-10-15', 'participantId': 'P-test'},
        initiator: const UserInitiator('u1'),
      );
      await store.append(
        entryType: 'no_epistaxis_event',
        aggregateType: diaryEntryAggregateType,
        aggregateId: 'd1',
        eventType: 'tombstone',
        data: const {},
        initiator: const UserInitiator('u1'),
      );
      final updates = await _drain(store);
      // After replay the row is gone — no surviving Snapshot for d1.
      final liveIds = updates
          .whereType<Snapshot<Map<String, Object?>>>()
          .map((s) => s.value)
          .whereType<Map<String, Object?>>()
          .map((v) => v['aggregateId'])
          .toSet();
      expect(liveIds, isNot(contains('d1')));
      await store.close();
    },
  );
}
