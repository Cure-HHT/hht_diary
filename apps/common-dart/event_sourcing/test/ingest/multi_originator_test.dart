// IMPLEMENTS REQUIREMENTS:
//   REQ-d00115-H: previous_ingest_hash threads across originators (Chain 2)
//   REQ-d00115-I: ingest_sequence_number monotone across originators
//   REQ-d00120-E: event_hash recomputed on each receiver provenance append
//   REQ-d00146-A: verifyEventChain passes for every ingested event
//   REQ-d00146-C: verifyIngestChain walks Chain 2 spanning all originators

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
  required String hopId,
  String? identifier,
  String softwareVersion = 'clinical_diary@1.0.0',
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'multi-orig-$_dbCounter.db',
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
      identifier: identifier ?? hopId,
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

/// Read the stored event for [eventId] from [fixture].
Future<StoredEvent> _fetchStored(_Fixture fixture, String eventId) async {
  final stored = await fixture.backend.transaction(
    (txn) async => fixture.backend.findEventByIdInTxn(txn, eventId),
  );
  expect(stored, isNotNull, reason: 'event $eventId not found in destination');
  return stored!;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Multi-originator ingest (REQ-d00115-H+I, REQ-d00120-E, REQ-d00146-A+C)', () {
    // -----------------------------------------------------------------------
    // Test 1: per-event interleaved ingest from two originators
    // -----------------------------------------------------------------------
    test(
      'per-event interleaved ingest threads Chain 2 across two originators',
      () async {
        // Three EventStore instances with distinct hopIds and unique databases.
        final originatorA = await _openStore(
          hopId: 'mobile-device-A',
          identifier: 'device-AAA',
        );
        final originatorB = await _openStore(
          hopId: 'mobile-device-B',
          identifier: 'device-BBB',
        );
        final destination = await _openStore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          // A originates eA1, eA2 under aggregate aggA.
          final eA1 = await originatorA.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggA',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'step': 1},
            },
            initiator: const UserInitiator('u1'),
          );
          final eA2 = await originatorA.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggA',
            aggregateType: 'DiaryEntry',
            eventType: 'checkpoint',
            data: const {
              'answers': {'step': 2},
            },
            initiator: const UserInitiator('u1'),
          );

          // B originates eB1, eB2 under aggregate aggB.
          final eB1 = await originatorB.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggB',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'step': 1},
            },
            initiator: const UserInitiator('u2'),
          );
          final eB2 = await originatorB.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggB',
            aggregateType: 'DiaryEntry',
            eventType: 'checkpoint',
            data: const {
              'answers': {'step': 2},
            },
            initiator: const UserInitiator('u2'),
          );

          expect(eA1, isNotNull);
          expect(eA2, isNotNull);
          expect(eB1, isNotNull);
          expect(eB2, isNotNull);

          // Destination ingests one at a time, interleaved across originators.
          final outA1 = await destination.store.ingestEvent(eA1!);
          final outB1 = await destination.store.ingestEvent(eB1!);
          final outA2 = await destination.store.ingestEvent(eA2!);
          final outB2 = await destination.store.ingestEvent(eB2!);

          expect(outA1.outcome, equals(IngestOutcome.ingested));
          expect(outB1.outcome, equals(IngestOutcome.ingested));
          expect(outA2.outcome, equals(IngestOutcome.ingested));
          expect(outB2.outcome, equals(IngestOutcome.ingested));

          // Fetch all four stored events from the destination.
          final storedA1 = await _fetchStored(destination, eA1.eventId);
          final storedB1 = await _fetchStored(destination, eB1.eventId);
          final storedA2 = await _fetchStored(destination, eA2.eventId);
          final storedB2 = await _fetchStored(destination, eB2.eventId);

          // Helper: extract receiver provenance entry (last entry) from stored event.
          Map<String, Object?> receiverProv(StoredEvent e) {
            final provList = (e.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            return provList.last;
          }

          final provA1 = receiverProv(storedA1);
          final provB1 = receiverProv(storedB1);
          final provA2 = receiverProv(storedA2);
          final provB2 = receiverProv(storedB2);

          // Assertion: monotone ingest_sequence_numbers 1..4.
          expect(provA1['ingest_sequence_number'], equals(1));
          expect(provB1['ingest_sequence_number'], equals(2));
          expect(provA2['ingest_sequence_number'], equals(3));
          expect(provB2['ingest_sequence_number'], equals(4));

          // Assertion: Chain 2 threads through interleaved originators.
          // seq1: previous_ingest_hash is null (first ingest).
          expect(provA1['previous_ingest_hash'], isNull);
          // seq2: previous_ingest_hash == storedA1.eventHash.
          expect(provB1['previous_ingest_hash'], equals(storedA1.eventHash));
          // seq3: previous_ingest_hash == storedB1.eventHash.
          expect(provA2['previous_ingest_hash'], equals(storedB1.eventHash));
          // seq4: previous_ingest_hash == storedA2.eventHash.
          expect(provB2['previous_ingest_hash'], equals(storedA2.eventHash));

          // Assertion: arrival_hash == originator's event_hash before receiver
          // appended its provenance entry.
          expect(provA1['arrival_hash'], equals(eA1.eventHash));
          expect(provB1['arrival_hash'], equals(eB1.eventHash));
          expect(provA2['arrival_hash'], equals(eA2.eventHash));
          expect(provB2['arrival_hash'], equals(eB2.eventHash));

          // Assertion: event_hash is recomputed on receiver (differs from
          // originator's hash).
          expect(storedA1.eventHash, isNot(equals(eA1.eventHash)));
          expect(storedB1.eventHash, isNot(equals(eB1.eventHash)));
          expect(storedA2.eventHash, isNot(equals(eA2.eventHash)));
          expect(storedB2.eventHash, isNot(equals(eB2.eventHash)));

          // Assertion: each stored event's sequence_number is the
          // destination's locally-assigned seq (1..4 in ingest order).
          // The originator's wire-supplied sequence_number is preserved on
          // the receiver-hop ProvenanceEntry as origin_sequence_number.
          expect(storedA1.sequenceNumber, equals(1));
          expect(storedB1.sequenceNumber, equals(2));
          expect(storedA2.sequenceNumber, equals(3));
          expect(storedB2.sequenceNumber, equals(4));
          expect(provA1['origin_sequence_number'], equals(eA1.sequenceNumber));
          expect(provB1['origin_sequence_number'], equals(eB1.sequenceNumber));
          expect(provA2['origin_sequence_number'], equals(eA2.sequenceNumber));
          expect(provB2['origin_sequence_number'], equals(eB2.sequenceNumber));
          // The originator's per-aggregate seq counter is independently
          // monotone (1, 2 from each).
          expect(eA1.sequenceNumber, equals(1));
          expect(eA2.sequenceNumber, equals(2));
          expect(eB1.sequenceNumber, equals(1));
          expect(eB2.sequenceNumber, equals(2));

          // Assertion: originator identity preserved verbatim.
          expect(storedA1.aggregateId, equals(eA1.aggregateId));
          expect(storedB1.aggregateId, equals(eB1.aggregateId));

          // Assertion: Chain 2 (verifyIngestChain) returns ok=true.
          final ingestVerdict = await destination.store.verifyIngestChain();
          expect(
            ingestVerdict.ok,
            isTrue,
            reason: 'verifyIngestChain failures: ${ingestVerdict.failures}',
          );
          expect(ingestVerdict.failures, isEmpty);

          // Assertion: Chain 1 (verifyEventChain) passes for every stored event.
          for (final stored in [storedA1, storedB1, storedA2, storedB2]) {
            final verdict = await destination.store.verifyEventChain(stored);
            expect(
              verdict.ok,
              isTrue,
              reason:
                  'verifyEventChain failed for ${stored.eventId}: '
                  '${verdict.failures}',
            );
          }
        } finally {
          await originatorA.close();
          await originatorB.close();
          await destination.close();
        }
      },
    );

    // -----------------------------------------------------------------------
    // Test 2: batched ingest from two originators
    // -----------------------------------------------------------------------
    test(
      'ingestBatch from originator A then B threads Chain 2 across both batches',
      () async {
        final originatorA = await _openStore(
          hopId: 'mobile-device-A',
          identifier: 'device-AAA',
        );
        final originatorB = await _openStore(
          hopId: 'mobile-device-B',
          identifier: 'device-BBB',
        );
        final destination = await _openStore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          // A originates eA1, eA2.
          final eA1 = await originatorA.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggA-batch',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'q': 'a1'},
            },
            initiator: const UserInitiator('u1'),
          );
          final eA2 = await originatorA.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggA-batch',
            aggregateType: 'DiaryEntry',
            eventType: 'checkpoint',
            data: const {
              'answers': {'q': 'a2'},
            },
            initiator: const UserInitiator('u1'),
          );

          // B originates eB1, eB2.
          final eB1 = await originatorB.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggB-batch',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'q': 'b1'},
            },
            initiator: const UserInitiator('u2'),
          );
          final eB2 = await originatorB.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'aggB-batch',
            aggregateType: 'DiaryEntry',
            eventType: 'checkpoint',
            data: const {
              'answers': {'q': 'b2'},
            },
            initiator: const UserInitiator('u2'),
          );

          expect(eA1, isNotNull);
          expect(eA2, isNotNull);
          expect(eB1, isNotNull);
          expect(eB2, isNotNull);

          // A builds and encodes a batch envelope [eA1, eA2].
          final envelopeA = _buildEnvelope(
            [eA1!, eA2!],
            senderHop: 'mobile-device-A',
            senderIdentifier: 'device-AAA',
            senderSoftwareVersion: 'clinical_diary@1.0.0',
          );
          final bytesA = envelopeA.encode();

          // B builds and encodes a batch envelope [eB1, eB2].
          final envelopeB = _buildEnvelope(
            [eB1!, eB2!],
            senderHop: 'mobile-device-B',
            senderIdentifier: 'device-BBB',
            senderSoftwareVersion: 'clinical_diary@1.0.0',
          );
          final bytesB = envelopeB.encode();

          // Destination ingests A's batch, then B's batch.
          final resultA = await destination.store.ingestBatch(
            bytesA,
            wireFormat: BatchEnvelope.wireFormat,
          );
          final resultB = await destination.store.ingestBatch(
            bytesB,
            wireFormat: BatchEnvelope.wireFormat,
          );

          // Assertion: each ingestBatch result carries its own batchId and
          // 2 ingested outcomes.
          expect(resultA.batchId, equals(envelopeA.batchId));
          expect(resultA.events, hasLength(2));
          for (final o in resultA.events) {
            expect(o.outcome, equals(IngestOutcome.ingested));
          }
          expect(resultB.batchId, equals(envelopeB.batchId));
          expect(resultB.events, hasLength(2));
          for (final o in resultB.events) {
            expect(o.outcome, equals(IngestOutcome.ingested));
          }

          // Fetch all four stored events from destination.
          final storedA1 = await _fetchStored(destination, eA1.eventId);
          final storedA2 = await _fetchStored(destination, eA2.eventId);
          final storedB1 = await _fetchStored(destination, eB1.eventId);
          final storedB2 = await _fetchStored(destination, eB2.eventId);

          // Helper: extract receiver provenance entry (last entry).
          Map<String, Object?> receiverProv(StoredEvent e) {
            final provList = (e.metadata['provenance'] as List<Object?>)
                .cast<Map<String, Object?>>();
            return provList.last;
          }

          final provA1 = receiverProv(storedA1);
          final provA2 = receiverProv(storedA2);
          final provB1 = receiverProv(storedB1);
          final provB2 = receiverProv(storedB2);

          // Assertion: Chain 2 ingest_sequence_numbers 1..4 span both batches.
          // A's batch was ingested first: eA1=1, eA2=2.
          expect(provA1['ingest_sequence_number'], equals(1));
          expect(provA2['ingest_sequence_number'], equals(2));
          // B's batch ingested second: eB1=3, eB2=4.
          expect(provB1['ingest_sequence_number'], equals(3));
          expect(provB2['ingest_sequence_number'], equals(4));

          // Assertion: previous_ingest_hash threads across both batches.
          expect(provA1['previous_ingest_hash'], isNull);
          expect(provA2['previous_ingest_hash'], equals(storedA1.eventHash));
          expect(provB1['previous_ingest_hash'], equals(storedA2.eventHash));
          expect(provB2['previous_ingest_hash'], equals(storedB1.eventHash));

          // Assertion: batch_context carries the right batchId for each event.
          // eA1, eA2 belong to A's batch.
          final bcA1 = BatchContext.fromJson(
            Map<String, Object?>.from(provA1['batch_context'] as Map),
          );
          final bcA2 = BatchContext.fromJson(
            Map<String, Object?>.from(provA2['batch_context'] as Map),
          );
          expect(bcA1.batchId, equals(envelopeA.batchId));
          expect(bcA2.batchId, equals(envelopeA.batchId));
          expect(bcA1.batchSize, equals(2));
          expect(bcA2.batchSize, equals(2));
          expect(bcA1.batchPosition, equals(0));
          expect(bcA2.batchPosition, equals(1));

          // eB1, eB2 belong to B's batch.
          final bcB1 = BatchContext.fromJson(
            Map<String, Object?>.from(provB1['batch_context'] as Map),
          );
          final bcB2 = BatchContext.fromJson(
            Map<String, Object?>.from(provB2['batch_context'] as Map),
          );
          expect(bcB1.batchId, equals(envelopeB.batchId));
          expect(bcB2.batchId, equals(envelopeB.batchId));
          expect(bcB1.batchSize, equals(2));
          expect(bcB2.batchSize, equals(2));
          expect(bcB1.batchPosition, equals(0));
          expect(bcB2.batchPosition, equals(1));

          // Assertion: no batch-level audit events emitted (alt design:
          // batch_context on each event IS the audit trail).
          final allAuditEvents = await destination.backend
              .findEventsForAggregate('ingest-audit:portal-server');
          expect(
            allAuditEvents
                .where((e) => e.eventType == 'ingest.batch_received')
                .toList(),
            isEmpty,
          );

          // Assertion: Chain 2 (verifyIngestChain) returns ok=true.
          final ingestVerdict = await destination.store.verifyIngestChain();
          expect(
            ingestVerdict.ok,
            isTrue,
            reason: 'verifyIngestChain failures: ${ingestVerdict.failures}',
          );
          expect(ingestVerdict.failures, isEmpty);

          // Assertion: Chain 1 (verifyEventChain) passes for every stored event.
          for (final stored in [storedA1, storedA2, storedB1, storedB2]) {
            final verdict = await destination.store.verifyEventChain(stored);
            expect(
              verdict.ok,
              isTrue,
              reason:
                  'verifyEventChain failed for ${stored.eventId}: '
                  '${verdict.failures}',
            );
          }
        } finally {
          await originatorA.close();
          await originatorB.close();
          await destination.close();
        }
      },
    );
  });
}
