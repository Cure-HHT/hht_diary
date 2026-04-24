// IMPLEMENTS REQUIREMENTS:
//   REQ-d00115-J: BatchContext fields stored on each ingested event allow
//                 auditors to associate events with their originating batch.
//
// NOTE (DONE_WITH_CONCERNS — Risk 7):
//   Full wire-bytes reconstruction (re-encoding stored events into a new
//   BatchEnvelope and verifying sha256 == stored batchWireBytesHash) depends
//   on canonicalization purity: the event maps decoded from the wire envelope
//   must be byte-for-byte equivalent to the re-built maps derived from stored
//   events. In practice, JSON round-tripping through sembast can change map
//   types (e.g., Map<String,dynamic> vs Map<Object?,Object?>), causing
//   JCS-canonical output to differ. Design spec §7 Risk 7 acknowledges this
//   and permits a simplified assertion: "stored events' BatchContext all agree
//   on batchId / batchWireBytesHash" without full round-trip verification.
//   The full reconstruction property is deferred to an integration test or
//   Phase 4.10+ when canonicalization is audited end-to-end.

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
}) {
  return BatchEnvelope(
    batchFormatVersion: '1',
    batchId: const Uuid().v4(),
    senderHop: senderHop,
    senderIdentifier: senderIdentifier,
    senderSoftwareVersion: senderSoftwareVersion,
    sentAt: DateTime.now().toUtc(),
    events: events.map((e) => Map<String, Object?>.from(e.toMap())).toList(),
  );
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
  });
}
