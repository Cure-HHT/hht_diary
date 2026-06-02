// Verifies: DIARY-DEV-reactive-read-path/B
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<EventStore> _open() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'inc-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final entryTypes = EntryTypeRegistry()
    ..register(
      const EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 1,
        name: 'Epistaxis Event',
      ),
    );
  final projections = ProjectionRegistry()..register(diaryIncompleteProjection);
  return EventStore.open(
    storage: backend,
    entryTypes: entryTypes,
    source: const Source(
      hopId: 'mobile',
      identifier: 't',
      softwareVersion: '0',
    ),
    securityContexts: SembastSecurityContextStore(backend: backend),
    projections: projections,
  );
}

Future<Set<String>> _ids(EventStore store) async {
  final ids = <String>{};
  final sub = store
      .subscribe<Map<String, Object?>>(
        const SubscriptionFilter(aggregateTypes: {diaryEntryAggregateType}),
        AggregateMode<Map<String, Object?>>(
          viewName: diaryIncompleteViewName,
          mapper: (r) => r,
        ),
      )
      .listen((u) {
        if (u is Snapshot<Map<String, Object?>>) {
          final v = u.value;
          if (v != null) ids.add(v['aggregateId'] as String);
        }
      });
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await sub.cancel();
  return ids;
}

void main() {
  test(
    'checkpoint adds; finalized removes (disjoint from canonical)',
    () async {
      final store = await _open();
      await store.append(
        entryType: 'epistaxis_event',
        aggregateType: diaryEntryAggregateType,
        aggregateId: 'e1',
        eventType: 'checkpoint',
        data: const {'startTime': '2025-10-15T10:00:00.000Z'},
        initiator: const UserInitiator('u'),
      );
      expect(await _ids(store), contains('e1'));

      await store.append(
        entryType: 'epistaxis_event',
        aggregateType: diaryEntryAggregateType,
        aggregateId: 'e1',
        eventType: 'finalized',
        data: const {'startTime': '2025-10-15T10:00:00.000Z'},
        initiator: const UserInitiator('u'),
      );
      expect(await _ids(store), isNot(contains('e1')));
      await store.close();
    },
  );

  test('checkpoint adds; tombstone (delete) removes', () async {
    final store = await _open();
    await store.append(
      entryType: 'epistaxis_event',
      aggregateType: diaryEntryAggregateType,
      aggregateId: 'e2',
      eventType: 'checkpoint',
      data: const {'startTime': '2025-10-15T10:00:00.000Z'},
      initiator: const UserInitiator('u'),
    );
    expect(await _ids(store), contains('e2'));

    // Deleting an open draft must remove it from the incomplete view — a
    // tombstoned entry is gone, not "incomplete".
    await store.append(
      entryType: 'epistaxis_event',
      aggregateType: diaryEntryAggregateType,
      aggregateId: 'e2',
      eventType: 'tombstone',
      data: const {'changeReason': 'entered-in-error'},
      initiator: const UserInitiator('u'),
    );
    expect(await _ids(store), isNot(contains('e2')));
    await store.close();
  });
}
