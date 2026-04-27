import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<EventStore> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'append-versioning-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final ds = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'demo-device',
      softwareVersion: 'test',
    ),
    entryTypes: <EntryTypeDefinition>[
      const EntryTypeDefinition(
        id: 'demo_note',
        registeredVersion: 5,
        name: 'demo_note',
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
  group('REQ-d00141-B,E: EventStore.append stamps version fields', () {
    // Verifies: REQ-d00141-B
    test(
      'REQ-d00141-B: caller-supplied entry_type_version is stamped verbatim',
      () async {
        final es = await _bootstrap();
        final stored = await es.append(
          entryType: 'demo_note',
          entryTypeVersion:
              3, // caller picks 3 even though registry registers 5
          aggregateId: 'a-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const <String, Object?>{'answers': <String, Object?>{}},
          initiator: const UserInitiator('u-1'),
        );
        expect(stored, isNotNull);
        expect(stored!.entryTypeVersion, 3);
      },
    );

    // Verifies: REQ-d00141-E
    test(
      'REQ-d00141-E: lib_format_version stamped from currentLibFormatVersion',
      () async {
        final es = await _bootstrap();
        final stored = await es.append(
          entryType: 'demo_note',
          entryTypeVersion: 5,
          aggregateId: 'a-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const <String, Object?>{'answers': <String, Object?>{}},
          initiator: const UserInitiator('u-1'),
        );
        expect(stored, isNotNull);
        expect(stored!.libFormatVersion, StoredEvent.currentLibFormatVersion);
      },
    );

    // Verifies: REQ-d00141-F
    test(
      'REQ-d00141-F: append does NOT validate entryTypeVersion against registry',
      () async {
        // Registry says registeredVersion=5; caller passes 99. append should accept.
        final es = await _bootstrap();
        final stored = await es.append(
          entryType: 'demo_note',
          entryTypeVersion: 99,
          aggregateId: 'a-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const <String, Object?>{'answers': <String, Object?>{}},
          initiator: const UserInitiator('u-1'),
        );
        expect(stored, isNotNull);
        expect(stored!.entryTypeVersion, 99);
      },
    );
  });
}
