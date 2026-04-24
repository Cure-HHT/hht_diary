// IMPLEMENTS REQUIREMENTS:
//   REQ-d00115-J: BatchContext fields stored on each ingested event allow
//                 auditors to associate events with their originating batch.

import 'package:crypto/crypto.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
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
    'batch-reconstruct-$_dbCounter.db',
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

BatchEnvelope _buildEnvelope(
  List<StoredEvent> events, {
  required String senderHop,
  required String senderIdentifier,
  required String senderSoftwareVersion,
  DateTime? sentAt,
}) {
  return BatchEnvelope(
    batchFormatVersion: '1',
    batchId: const Uuid().v4(),
    senderHop: senderHop,
    senderIdentifier: senderIdentifier,
    senderSoftwareVersion: senderSoftwareVersion,
    sentAt: sentAt ?? DateTime.now().toUtc(),
    events: events.map((e) => Map<String, Object?>.from(e.toMap())).toList(),
  );
}

/// Recursively rekey a deserialized value so all Map spines are
/// `Map<String, Object?>` rather than `Map<dynamic, dynamic>`. Values
/// are NOT deep-converted — only the map type wrappers change. This
/// ensures JCS canonicalization (which uses `.keys` and `.toString()`)
/// produces byte-identical output regardless of how sembast typed the
/// round-tripped maps.
Object? _rekey(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _rekey(entry.value),
    };
  }
  if (value is List) {
    return value.map(_rekey).toList();
  }
  return value;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Batch reconstruction (REQ-d00115-J; design §2.3)', () {
    test('all stored events from an ingested batch agree on batchId and '
        'batchWireBytesHash', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // 1. Originate 3 events.
        final events = <StoredEvent>[];
        for (var i = 0; i < 3; i++) {
          final e = await orig.store.append(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-recon-$i',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: <String, Object?>{
              'answers': <String, Object?>{'idx': i},
            },
            initiator: const UserInitiator('u1'),
          );
          expect(e, isNotNull);
          events.add(e!);
        }

        // 2. Build envelope and encode → bytes.
        final envelope = _buildEnvelope(
          events,
          senderHop: 'mobile-device',
          senderIdentifier: 'device-1',
          senderSoftwareVersion: 'clinical_diary@1.0.0',
        );
        final bytes = envelope.encode();
        final wireBytesHash = sha256.convert(bytes).toString();

        // 3. Ingest at destination.
        final result = await dest.store.ingestBatch(
          bytes,
          wireFormat: BatchEnvelope.wireFormat,
        );
        expect(result.events, hasLength(3));

        // 4. Query stored subjects and extract batchContext from each.
        final storedBatchContexts = <BatchContext>[];
        for (final e in events) {
          final stored = await dest.backend.transaction(
            (txn) async => dest.backend.findEventByIdInTxn(txn, e.eventId),
          );
          expect(stored, isNotNull);

          final prov = (stored!.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          expect(prov.last.containsKey('batch_context'), isTrue);

          final bc = BatchContext.fromJson(
            Map<String, Object?>.from(prov.last['batch_context'] as Map),
          );
          storedBatchContexts.add(bc);
        }

        // 5. All events agree on batchId and batchWireBytesHash.
        for (final bc in storedBatchContexts) {
          expect(
            bc.batchId,
            equals(envelope.batchId),
            reason: 'batchId must match for all events',
          );
          expect(
            bc.batchWireBytesHash,
            equals(wireBytesHash),
            reason: 'batchWireBytesHash must match for all events',
          );
          expect(bc.batchWireFormat, equals(BatchEnvelope.wireFormat));
          expect(bc.batchSize, equals(3));
        }

        // 6. batchPositions are 0, 1, 2 (ordered as sent).
        final positions = storedBatchContexts
            .map((bc) => bc.batchPosition)
            .toList();
        expect(positions, equals([0, 1, 2]));
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test('batchWireBytesHash is sha256(encoded bytes)', () async {
      // This test directly verifies the hash value stored in batchContext
      // equals sha256 of the exact bytes passed to ingestBatch.
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        final e = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-hash-check',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e, isNotNull);

        final envelope = _buildEnvelope(
          [e!],
          senderHop: 'mobile-device',
          senderIdentifier: 'device-1',
          senderSoftwareVersion: 'clinical_diary@1.0.0',
        );
        final bytes = envelope.encode();
        final expectedHash = sha256.convert(bytes).toString();

        await dest.store.ingestBatch(
          bytes,
          wireFormat: BatchEnvelope.wireFormat,
        );

        final stored = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e.eventId),
        );
        final prov = (stored!.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        final bc = BatchContext.fromJson(
          Map<String, Object?>.from(prov.last['batch_context'] as Map),
        );

        expect(bc.batchWireBytesHash, equals(expectedHash));
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test('full round-trip: strip receiver hop → re-encode → '
        'sha256 matches batchWireBytesHash (Risk 7 resolved)', () async {
      // This test performs the complete reconstruction to confirm that
      // JCS canonicalization is stable across the sembast storage
      // round-trip. Approach:
      //   1. Build envelope with N events + fixed sentAt → encode → sha256.
      //   2. ingestBatch at destination.
      //   3. Query stored subjects in batch_position order.
      //   4. Strip each event's receiver-hop provenance entry and restore
      //      event_hash = arrival_hash (= the originator's event_hash).
      //   5. Re-encode into a new BatchEnvelope with the original envelope
      //      metadata (batchId, senderHop, sentAt captured in step 1).
      //   6. Assert sha256(reconstructed) == stored batchWireBytesHash.
      const n = 3;
      final sentAt = DateTime.utc(2026, 4, 21, 12, 0, 0);
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // 1. Originate N events.
        final events = <StoredEvent>[];
        for (var i = 0; i < n; i++) {
          final e = await orig.store.append(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-fullrecon-$i',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: <String, Object?>{
              'answers': <String, Object?>{'idx': i},
            },
            initiator: const UserInitiator('u1'),
          );
          expect(e, isNotNull);
          events.add(e!);
        }

        // 2. Build envelope with fixed sentAt so reconstruction is
        //    deterministic.
        final envelope = _buildEnvelope(
          events,
          senderHop: 'mobile-device',
          senderIdentifier: 'device-1',
          senderSoftwareVersion: 'clinical_diary@1.0.0',
          sentAt: sentAt,
        );
        final originalBytes = envelope.encode();
        final expectedWireBytesHash = sha256.convert(originalBytes).toString();

        // 3. Ingest at destination.
        final result = await dest.store.ingestBatch(
          originalBytes,
          wireFormat: BatchEnvelope.wireFormat,
        );
        expect(result.events, hasLength(n));

        // 4. Query stored subjects ordered by batch_position.
        //    We query by event_id from the original events list, then sort.
        final storedWithBc =
            <
              ({StoredEvent event, BatchContext bc, Map<String, Object?> prov})
            >[];
        for (final e in events) {
          final stored = await dest.backend.transaction(
            (txn) async => dest.backend.findEventByIdInTxn(txn, e.eventId),
          );
          expect(stored, isNotNull, reason: 'event ${e.eventId} must exist');

          final provList = (stored!.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          expect(provList.length, equals(2), reason: 'must have 2 hop entries');

          final receiverEntry = provList.last;
          expect(
            receiverEntry.containsKey('batch_context'),
            isTrue,
            reason: 'receiver entry must carry batch_context',
          );

          final bc = BatchContext.fromJson(
            Map<String, Object?>.from(receiverEntry['batch_context'] as Map),
          );
          storedWithBc.add((event: stored, bc: bc, prov: receiverEntry));
        }

        // Sort by batch_position to match original send order.
        storedWithBc.sort(
          (a, b) => a.bc.batchPosition.compareTo(b.bc.batchPosition),
        );

        // 5. Reconstruct each event map as it was on the wire.
        final reconstructedEventMaps = <Map<String, Object?>>[];
        for (final entry in storedWithBc) {
          final stored = entry.event;
          final receiverEntry = entry.prov;

          // arrival_hash is the event_hash the receiver saw on the wire,
          // i.e., the originator's event_hash before any receiver mutation.
          final arrivalHash = receiverEntry['arrival_hash'] as String?;
          expect(
            arrivalHash,
            isNotNull,
            reason: 'receiver entry must carry arrival_hash',
          );

          // Strip the receiver hop (last provenance entry).
          final fullProv = (stored.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          final strippedProv = fullProv.sublist(0, fullProv.length - 1);

          // Rebuild metadata with stripped provenance.
          final strippedMeta = <String, Object?>{
            ...stored.metadata,
            'provenance': strippedProv,
          };

          // Build the event map as it was on the wire: same fields as
          // StoredEvent.toMap() but with stripped provenance and the
          // originator's event_hash restored.
          final wireEventMap = <String, Object?>{
            ...stored.toMap(),
            'metadata': strippedMeta,
            'event_hash': arrivalHash,
          };

          // Apply _rekey to ensure Map spines are Map<String, Object?>
          // regardless of how sembast typed the deserialized values.
          reconstructedEventMaps.add(
            Map<String, Object?>.from(_rekey(wireEventMap) as Map),
          );
        }

        // 6. Reconstruct the BatchEnvelope.
        final reconstructed = BatchEnvelope(
          batchFormatVersion: '1',
          batchId: envelope.batchId,
          senderHop: envelope.senderHop,
          senderIdentifier: envelope.senderIdentifier,
          senderSoftwareVersion: envelope.senderSoftwareVersion,
          sentAt: envelope.sentAt,
          events: reconstructedEventMaps,
        );

        // 7. Encode and compute sha256.
        final reconstructedBytes = reconstructed.encode();
        final reconstructedHash = sha256.convert(reconstructedBytes).toString();

        // 8. Assert that reconstructed hash matches the stored
        //    batchWireBytesHash (which equals sha256(originalBytes)).
        expect(reconstructedHash, equals(expectedWireBytesHash));

        // Also confirm via the stored BatchContext.
        for (final entry in storedWithBc) {
          expect(
            entry.bc.batchWireBytesHash,
            equals(reconstructedHash),
            reason: 'all stored events must agree on batchWireBytesHash',
          );
        }
      } finally {
        await orig.close();
        await dest.close();
      }
    });
  });
}
