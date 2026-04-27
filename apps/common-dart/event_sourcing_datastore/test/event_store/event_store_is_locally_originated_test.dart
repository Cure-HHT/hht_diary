// IMPLEMENTS REQUIREMENTS:
//   REQ-d00154-B: EventStore.isLocallyOriginated compares on install
//                 identifier, not hop class.
//
// Convention: per-test `// Verifies: REQ-d00154-B — <prose>` annotations and
// the assertion ID `REQ-d00154-B` at the start of each test description.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<EventStore> _bootstrap({
  required String identifier,
  String hopId = 'mobile-device',
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'is-locally-originated-${DateTime.now().microsecondsSinceEpoch}-'
    '$identifier.db',
  );
  final backend = SembastBackend(database: db);
  final ds = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: Source(
      hopId: hopId,
      identifier: identifier,
      softwareVersion: 'clinical_diary@1.0.0',
    ),
    entryTypes: <EntryTypeDefinition>[
      const EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 1,
        name: 'Epistaxis Event',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      ),
    ],
    destinations: const <Destination>[],
    materializers: const <Materializer>[],
    initialViewTargetVersions: const <String, Map<String, int>>{},
  );
  return ds.eventStore;
}

void main() {
  // Verifies: REQ-d00154-B — a locally-appended event is recognized as local
  // because its provenance[0].identifier matches the EventStore's
  // source.identifier.
  test('REQ-d00154-B: locally-appended event is recognized as local', () async {
    final eventStore = await _bootstrap(identifier: 'install-A');
    final appended = await eventStore.append(
      entryType: 'epistaxis_event',
      entryTypeVersion: 1,
      aggregateId: 'agg-1',
      aggregateType: 'DiaryEntry',
      eventType: 'finalized',
      data: const <String, Object?>{
        'answers': <String, Object?>{'severity': 'mild'},
      },
      initiator: const UserInitiator('u1'),
    );
    expect(appended, isNotNull);
    expect(eventStore.isLocallyOriginated(appended!), isTrue);
  });

  // Verifies: REQ-d00154-B — an event whose provenance[0].identifier is from
  // a different install of the same hop class is NOT locally originated. The
  // comparison is on install identity, not hop class.
  test(
    'REQ-d00154-B: different install identifier is NOT locally originated',
    () async {
      // Local install is install-A; ingested event came from install-B (a
      // different mobile device).
      final localStore = await _bootstrap(identifier: 'install-A');
      final foreignStore = await _bootstrap(identifier: 'install-B');

      final foreign = await foreignStore.append(
        entryType: 'epistaxis_event',
        entryTypeVersion: 1,
        aggregateId: 'agg-foreign',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const <String, Object?>{
          'answers': <String, Object?>{'severity': 'mild'},
        },
        initiator: const UserInitiator('u2'),
      );
      expect(foreign, isNotNull);
      // Both originate on hopId 'mobile-device' but distinct installs:
      // foreign event must NOT be considered local on install-A's store.
      expect(localStore.isLocallyOriginated(foreign!), isFalse);
    },
  );
}
