// IMPLEMENTS REQUIREMENTS:
//   REQ-d00145-A: EventStore.ingestBatch wire-side decode
//   REQ-d00145-B: esd/batch@1 wire format support
//   REQ-d00145-E: BatchContext stamped on receiver provenance entry
//   REQ-d00145-J: batch_context on duplicate_received audit event (REQ-d00115-J)

import 'dart:typed_data';

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
    'batch-happy-$_dbCounter.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry()
    ..register(
      const EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 1,
        name: 'Epistaxis Event',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_redacted',
        registeredVersion: 1,
        name: 'SC Redacted',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_compacted',
        registeredVersion: 1,
        name: 'SC Compacted',
        widgetId: '_system',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    ..register(
      const EntryTypeDefinition(
        id: 'security_context_purged',
        registeredVersion: 1,
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

/// Build a [BatchEnvelope] from a list of [StoredEvent]s with a fresh batchId.
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
  group('EventStore.ingestBatch — happy path (REQ-d00145-A+B+E)', () {
    test(
      '3-event batch stores 3 events with correct batch_context on each',
      () async {
        final orig = await _openStore(
          hopId: 'mobile-device',
          identifier: 'device-1',
          softwareVersion: 'clinical_diary@1.0.0',
        );
        final dest = await _openStore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          // 1. Originate 3 events.
          final e1 = await orig.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'agg-batch1',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'q': 'a1'},
            },
            initiator: const UserInitiator('u1'),
          );
          final e2 = await orig.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'agg-batch2',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'q': 'a2'},
            },
            initiator: const UserInitiator('u1'),
          );
          final e3 = await orig.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'agg-batch3',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'q': 'a3'},
            },
            initiator: const UserInitiator('u1'),
          );
          expect(e1, isNotNull);
          expect(e2, isNotNull);
          expect(e3, isNotNull);

          // 2. Build envelope and encode.
          final envelope = _buildEnvelope(
            [e1!, e2!, e3!],
            senderHop: 'mobile-device',
            senderIdentifier: 'device-1',
            senderSoftwareVersion: 'clinical_diary@1.0.0',
          );
          final bytes = envelope.encode();
          final expectedHash = sha256.convert(bytes).toString();

          // 3. Ingest at destination.
          final result = await dest.store.ingestBatch(
            bytes,
            wireFormat: BatchEnvelope.wireFormat,
          );

          // 4a. Result carries correct batchId and 3 outcomes.
          expect(result.batchId, equals(envelope.batchId));
          expect(result.events, hasLength(3));
          for (final outcome in result.events) {
            expect(outcome.outcome, equals(IngestOutcome.ingested));
          }

          // 4b. Each stored subject has batch_context with correct fields.
          final subjects = [e1, e2, e3];
          for (var i = 0; i < subjects.length; i++) {
            final stored = await dest.backend.transaction(
              (txn) async =>
                  dest.backend.findEventByIdInTxn(txn, subjects[i].eventId),
            );
            expect(stored, isNotNull, reason: 'event $i not found');

            final prov = (stored!.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(prov, hasLength(2));

            final receiverProv = prov.last;
            expect(receiverProv.containsKey('batch_context'), isTrue);

            final bc = BatchContext.fromJson(
              Map<String, Object?>.from(receiverProv['batch_context'] as Map),
            );
            expect(bc.batchId, equals(envelope.batchId));
            expect(bc.batchSize, equals(3));
            expect(bc.batchPosition, equals(i));
            expect(bc.batchWireFormat, equals(BatchEnvelope.wireFormat));
            expect(bc.batchWireBytesHash, equals(expectedHash));
          }

          // 4c. No ingest.batch_received event exists (alt design: batch_context
          //     IS the per-event audit trail; no batch-level wrapper event).
          final allBatchEvents = await dest.backend.findEventsForAggregate(
            'ingest-audit:portal-server',
          );
          expect(
            allBatchEvents
                .where((e) => e.eventType == 'ingest.batch_received')
                .toList(),
            isEmpty,
          );

          // 4d. Chain 2 is consistent: event at position 1 references position 0
          //     and position 2 references position 1 (previous_ingest_hash chain).
          final stored0 = await dest.backend.transaction(
            (txn) async => dest.backend.findEventByIdInTxn(txn, e1.eventId),
          );
          final stored1 = await dest.backend.transaction(
            (txn) async => dest.backend.findEventByIdInTxn(txn, e2.eventId),
          );
          final stored2 = await dest.backend.transaction(
            (txn) async => dest.backend.findEventByIdInTxn(txn, e3.eventId),
          );

          final prov0 = (stored0!.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          final prov1 = (stored1!.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          final prov2 = (stored2!.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();

          // First ingest: previous_ingest_hash null.
          expect(prov0.last['previous_ingest_hash'], isNull);
          // Second ingest: previous_ingest_hash == stored0.eventHash.
          expect(prov1.last['previous_ingest_hash'], equals(stored0.eventHash));
          // Third ingest: previous_ingest_hash == stored1.eventHash.
          expect(prov2.last['previous_ingest_hash'], equals(stored1.eventHash));
        } finally {
          await orig.close();
          await dest.close();
        }
      },
    );

    test('single-event batch (batchSize=1, batchPosition=0) works', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        final e = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-single-batch',
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

        final result = await dest.store.ingestBatch(
          bytes,
          wireFormat: BatchEnvelope.wireFormat,
        );

        expect(result.events, hasLength(1));
        expect(result.events[0].outcome, equals(IngestOutcome.ingested));

        // Verify BatchContext has batchSize=1, batchPosition=0.
        final stored = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e.eventId),
        );
        expect(stored, isNotNull);

        final prov = (stored!.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        final bc = BatchContext.fromJson(
          Map<String, Object?>.from(prov.last['batch_context'] as Map),
        );
        expect(bc.batchSize, equals(1));
        expect(bc.batchPosition, equals(0));
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test('batch with one duplicate + two new subjects: '
        'outcomes=[duplicate, ingested, ingested], '
        'dup marker carries batch_context (REQ-d00115-J)', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // 1. Originate 3 events.
        final e1 = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-dup-batch-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {
            'answers': {'q': 'pre-ingested'},
          },
          initiator: const UserInitiator('u1'),
        );
        final e2 = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-dup-batch-2',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        final e3 = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-dup-batch-3',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e1, isNotNull);
        expect(e2, isNotNull);
        expect(e3, isNotNull);

        // 2. Pre-ingest e1 at destination via process-local ingestEvent.
        await dest.store.ingestEvent(e1!);

        // 3. Build batch [e1, e2, e3] and ingest.
        final envelope = _buildEnvelope(
          [e1, e2!, e3!],
          senderHop: 'mobile-device',
          senderIdentifier: 'device-1',
          senderSoftwareVersion: 'clinical_diary@1.0.0',
        );
        final bytes = envelope.encode();
        final expectedHash = sha256.convert(bytes).toString();

        final result = await dest.store.ingestBatch(
          bytes,
          wireFormat: BatchEnvelope.wireFormat,
        );

        // 4a. outcomes: [duplicate, ingested, ingested].
        expect(result.events, hasLength(3));
        expect(result.events[0].outcome, equals(IngestOutcome.duplicate));
        expect(result.events[1].outcome, equals(IngestOutcome.ingested));
        expect(result.events[2].outcome, equals(IngestOutcome.ingested));

        // 4b. e2 and e3 are stored; e1 is unchanged.
        final storedE2 = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e2.eventId),
        );
        final storedE3 = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e3.eventId),
        );
        expect(storedE2, isNotNull);
        expect(storedE3, isNotNull);

        // 4c. One ingest.duplicate_received event emitted for e1.
        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        final dupEvents = auditEvents
            .where((e) => e.eventType == 'ingest.duplicate_received')
            .toList();
        expect(dupEvents, hasLength(1));
        expect(dupEvents[0].data['subject_event_id'], equals(e1.eventId));

        // 4d. duplicate_received event carries batchContext referencing
        //     this batch (REQ-d00115-J).
        final dupProv = (dupEvents[0].metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(dupProv, hasLength(1));
        expect(dupProv[0].containsKey('batch_context'), isTrue);

        final dupBc = BatchContext.fromJson(
          Map<String, Object?>.from(dupProv[0]['batch_context'] as Map),
        );
        expect(dupBc.batchId, equals(envelope.batchId));
        expect(dupBc.batchSize, equals(3));
        expect(dupBc.batchPosition, equals(0)); // e1 was at index 0
        expect(dupBc.batchWireBytesHash, equals(expectedHash));
        expect(dupBc.batchWireFormat, equals(BatchEnvelope.wireFormat));
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test('batch with identity-mismatching subject rolls back entirely '
        '(REQ-d00145-D)', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // 1. Originate e1 and pre-ingest it at destination.
        final e1 = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-mismatch-batch-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {
            'answers': {'q': 'original'},
          },
          initiator: const UserInitiator('u1'),
        );
        expect(e1, isNotNull);
        await dest.store.ingestEvent(e1!);

        // Capture destination's local sequence counter after first ingest.
        final seqBefore = await dest.backend.readSequenceCounter();

        // 2. Build tampered e1 (same event_id, different hash).
        final e1Map = e1.toMap();
        e1Map['event_hash'] = 'tampered-hash-abcdef1234567890abcdef123456';
        final e1Tampered = StoredEvent.fromMap(e1Map, 0);

        // 3. Originate two new events.
        final e2 = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-mismatch-batch-2',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        final e3 = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-mismatch-batch-3',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e2, isNotNull);
        expect(e3, isNotNull);

        // 4. Build batch [e2 (new), e1Tampered (mismatch), e3 (new)].
        final envelope = _buildEnvelope(
          [e2!, e1Tampered, e3!],
          senderHop: 'mobile-device',
          senderIdentifier: 'device-1',
          senderSoftwareVersion: 'clinical_diary@1.0.0',
        );
        final bytes = envelope.encode();

        // 5. ingestBatch must throw IngestIdentityMismatch.
        await expectLater(
          () => dest.store.ingestBatch(
            bytes,
            wireFormat: BatchEnvelope.wireFormat,
          ),
          throwsA(
            isA<IngestIdentityMismatch>().having(
              (e) => e.eventId,
              'eventId',
              e1.eventId,
            ),
          ),
        );

        // 6. Destination's local sequence counter is UNCHANGED (rollback).
        expect(await dest.backend.readSequenceCounter(), equals(seqBefore));

        // 7. e2 and e3 are NOT stored (rolled back).
        final storedE2 = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e2.eventId),
        );
        final storedE3 = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e3.eventId),
        );
        expect(storedE2, isNull);
        expect(storedE3, isNull);

        // 8. No duplicate_received audit events emitted.
        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        expect(auditEvents, isEmpty);
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test('unsupported wireFormat throws IngestDecodeFailure', () async {
      final dest = await _openStore(hopId: 'portal-server');

      try {
        await expectLater(
          () => dest.store.ingestBatch(
            // Any valid bytes — the format check fires first.
            Uint8List.fromList([0x7b, 0x7d]),
            wireFormat: 'esd/batch@99',
          ),
          throwsA(isA<IngestDecodeFailure>()),
        );
      } finally {
        await dest.close();
      }
    });
  });
}
