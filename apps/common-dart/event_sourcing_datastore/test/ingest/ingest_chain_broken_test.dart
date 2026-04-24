// IMPLEMENTS REQUIREMENTS:
//   REQ-d00145-C: Chain 1 verification failure throws IngestChainBroken
//                  with hopIndex equal to the tampered position.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

var _dbCounter = 0;

class _Fixture {
  _Fixture({required this.store, required this.backend});
  final EventStore store;
  final SembastBackend backend;
  Future<void> close() => backend.close();
}

Future<_Fixture> _openStore({
  String hopId = 'mobile-device',
  String identifier = 'device-1',
  String softwareVersion = 'clinical_diary@1.0.0',
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'ingest-chain-$_dbCounter.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry()
    ..register(
      const EntryTypeDefinition(
        id: 'epistaxis_event',
        version: '1',
        name: 'Epistaxis Event',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_redacted',
        version: '1',
        name: 'SC Redacted',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_compacted',
        version: '1',
        name: 'SC Compacted',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_purged',
        version: '1',
        name: 'SC Purged',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    );
  final securityContexts = SembastSecurityContextStore(backend: backend);
  final store = EventStore(
    backend: backend,
    entryTypes: registry,
    source: Source(
      hopId: hopId,
      identifier: identifier,
      softwareVersion: softwareVersion,
    ),
    securityContexts: securityContexts,
  );
  return _Fixture(store: store, backend: backend);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventStore.ingestEvent — chain broken (REQ-d00145-C)', () {
    test('ingesting event with tampered arrival_hash at hop 1 throws '
        'IngestChainBroken with hopIndex=1', () async {
      // Simulate a 2-hop chain:
      //   originator → intermediate → (attempt to go to) third
      //
      // Step 1: originator produces an event.
      // Step 2: intermediate ingests it (provenance grows to length 2).
      // Step 3: tamper provenance[1].arrival_hash on the intermediate copy.
      // Step 4: third destination tries to ingest the tampered event → throws.

      final orig = await _openStore(
        hopId: 'mobile-device',
        identifier: 'device-1',
      );
      final inter = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );
      final third = await _openStore(
        hopId: 'archive-server',
        identifier: 'archive-1',
        softwareVersion: 'archive@0.1.0',
      );

      try {
        // 1. Originate.
        final original = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-chain',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(original, isNotNull);

        // 2. Intermediate ingests — stored copy has 2-entry provenance.
        final outcome1 = await inter.store.ingestEvent(original!);
        expect(outcome1.outcome, equals(IngestOutcome.ingested));

        // Read the intermediate's stored copy.
        final intermediateStored = await inter.backend.transaction(
          (txn) async =>
              inter.backend.findEventByIdInTxn(txn, original.eventId),
        );
        expect(
          intermediateStored!.metadata['provenance'] as List<Object?>,
          hasLength(2),
        );

        // 3. Build tampered copy: corrupt provenance[1].arrival_hash.
        final tamperedMap = intermediateStored.toMap();
        final metadataOrig = tamperedMap['metadata'] as Map<String, Object?>;
        final metadata = Map<String, Object?>.from(metadataOrig);
        final provList = (metadata['provenance'] as List<Object?>).toList();
        final hop1 = Map<String, Object?>.from(
          provList[1] as Map<String, Object?>,
        );
        hop1['arrival_hash'] = 'tampered-arrival-hash-00000000000000000000';
        provList[1] = hop1;
        metadata['provenance'] = provList;
        tamperedMap['metadata'] = metadata;
        final tampered = StoredEvent.fromMap(tamperedMap, 0);

        // 4. Third destination must throw IngestChainBroken at hopIndex=1.
        await expectLater(
          () => third.store.ingestEvent(tampered),
          throwsA(
            isA<IngestChainBroken>()
                .having((e) => e.eventId, 'eventId', original.eventId)
                .having((e) => e.hopIndex, 'hopIndex', 1),
          ),
        );

        // No side effects: third's ingest tail is empty.
        final tail = await third.backend.readIngestTail();
        expect(tail.$1, equals(0));
        expect(tail.$2, isNull);
      } finally {
        await orig.close();
        await inter.close();
        await third.close();
      }
    });

    test('hand-crafted event with missing arrival_hash at hop 1 throws '
        'IngestChainBroken with hopIndex=1', () async {
      // Construct a synthetic 2-hop provenance where provenance[1] has
      // no arrival_hash key (null-equivalent for a receiver entry).
      final dest = await _openStore(hopId: 'portal-server');

      try {
        final now = DateTime.utc(2026, 4, 24, 12);
        final provenanceList = [
          <String, Object?>{
            'hop': 'mobile-device',
            'received_at': now.toIso8601String(),
            'identifier': 'device-1',
            'software_version': 'clinical_diary@1.0.0',
          },
          <String, Object?>{
            // Missing 'arrival_hash' — invalid for a receiver hop.
            'hop': 'intermediate',
            'received_at': now.toIso8601String(),
            'identifier': 'intermediate-1',
            'software_version': 'intermediate@1.0.0',
          },
        ];
        final metadata = <String, Object?>{
          'change_reason': 'initial',
          'provenance': provenanceList,
        };
        final recordMap = <String, Object?>{
          'event_id': 'test-chain-null-arrival',
          'aggregate_id': 'agg-chain-null',
          'aggregate_type': 'DiaryEntry',
          'entry_type': 'epistaxis_event',
          'event_type': 'finalized',
          'sequence_number': 1,
          'data': const <String, Object?>{},
          'metadata': metadata,
          'initiator': const <String, Object?>{'type': 'user', 'user_id': 'u1'},
          'flow_token': null,
          'client_timestamp': now.toIso8601String(),
          'previous_event_hash': null,
          'event_hash': 'some-hash-value-for-test',
        };
        final syntheticEvent = StoredEvent.fromMap(recordMap, 0);

        await expectLater(
          () => dest.store.ingestEvent(syntheticEvent),
          throwsA(
            isA<IngestChainBroken>().having((e) => e.hopIndex, 'hopIndex', 1),
          ),
        );
      } finally {
        await dest.close();
      }
    });
  });
}
