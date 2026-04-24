// IMPLEMENTS REQUIREMENTS:
//   REQ-d00145-G: ingestEvent process-local per-event semantics
//   REQ-d00145-K: originator identity fields preserved verbatim
//   REQ-d00120-E: event_hash recomputed on receiver provenance append
//   REQ-d00115-G: arrival_hash == wire event_hash at reception hop
//   REQ-d00115-H: previous_ingest_hash null on first-ever ingest
//   REQ-d00115-I: ingest_sequence_number monotonically increasing

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
  DateTime? now,
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'ingest-happy-$_dbCounter.db',
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
    clock: now == null ? null : () => now,
  );
  return _Fixture(store: store, backend: backend);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventStore.ingestEvent — happy path (REQ-d00145-G)', () {
    test('new event is stored with receiver provenance and rehashed', () async {
      final orig = await _openStore(
        hopId: 'mobile-device',
        identifier: 'device-1',
      );
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // 1. Originate an event.
        final original = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {
            'answers': {'severity': 'mild'},
          },
          initiator: const UserInitiator('u1'),
        );
        expect(original, isNotNull);
        final h0 = original!.eventHash;

        // 2. Ingest at destination.
        final outcome = await dest.store.ingestEvent(original);
        expect(outcome.outcome, equals(IngestOutcome.ingested));
        expect(outcome.eventId, equals(original.eventId));

        // 3. Read the stored copy from destination.
        final stored = await dest.backend.transaction((txn) async {
          return dest.backend.findEventByIdInTxn(txn, original.eventId);
        });
        expect(stored, isNotNull);

        // 4a. stored.metadata.provenance has 2 entries.
        final provenance = (stored!.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(provenance, hasLength(2));

        // 4b. provenance[0] equals original's provenance[0].
        final origProv = (original.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(provenance[0], equals(origProv[0]));

        // 4c. provenance[1].hop == destination's hopId.
        expect(provenance[1]['hop'], equals('portal-server'));

        // 4d. arrival_hash == H0.
        expect(provenance[1]['arrival_hash'], equals(h0));

        // 4e. previous_ingest_hash is null (first-ever ingest).
        expect(provenance[1]['previous_ingest_hash'], isNull);

        // 4f. ingest_sequence_number == 1.
        expect(provenance[1]['ingest_sequence_number'], equals(1));

        // 4g. batch_context is null (process-local — key not emitted).
        expect(provenance[1].containsKey('batch_context'), isFalse);

        // 4h. stored.event_hash differs from H0 (rehashed).
        expect(stored.eventHash, isNot(equals(h0)));

        // 4i–l. originator identity fields preserved.
        expect(stored.eventId, equals(original.eventId));
        expect(stored.aggregateId, equals(original.aggregateId));
        expect(stored.sequenceNumber, equals(original.sequenceNumber));
        expect(stored.previousEventHash, equals(original.previousEventHash));
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test(
      'ingestEvent returns PerEventIngestOutcome with outcome=ingested',
      () async {
        final orig = await _openStore(hopId: 'mobile-device');
        final dest = await _openStore(hopId: 'portal-server');

        try {
          final original = await orig.store.append(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-2',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {'answers': {}},
            initiator: const UserInitiator('u1'),
          );
          expect(original, isNotNull);

          final outcome = await dest.store.ingestEvent(original!);

          expect(outcome.outcome, equals(IngestOutcome.ingested));
          expect(outcome.eventId, equals(original.eventId));
          // resultHash must differ from the originator's hash (it's rehashed).
          expect(outcome.resultHash, isNot(equals(original.eventHash)));
        } finally {
          await orig.close();
          await dest.close();
        }
      },
    );

    test('second unique event gets ingestSequenceNumber=2 and '
        'previousIngestHash=first stored hash', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(hopId: 'portal-server');

      try {
        // Originate two distinct events.
        final e1 = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-seq1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        final e2 = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-seq2',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );

        final outcome1 = await dest.store.ingestEvent(e1!);
        final outcome2 = await dest.store.ingestEvent(e2!);

        expect(outcome1.outcome, equals(IngestOutcome.ingested));
        expect(outcome2.outcome, equals(IngestOutcome.ingested));

        // Verify stored copies.
        final stored1 = await dest.backend.transaction((txn) async {
          return dest.backend.findEventByIdInTxn(txn, e1.eventId);
        });
        final stored2 = await dest.backend.transaction((txn) async {
          return dest.backend.findEventByIdInTxn(txn, e2.eventId);
        });

        final prov1 = (stored1!.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        final prov2 = (stored2!.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();

        // First event: ingest_sequence_number=1, previous=null.
        expect(prov1.last['ingest_sequence_number'], equals(1));
        expect(prov1.last['previous_ingest_hash'], isNull);

        // Second event: ingest_sequence_number=2, previous=stored1.eventHash.
        expect(prov2.last['ingest_sequence_number'], equals(2));
        expect(prov2.last['previous_ingest_hash'], equals(stored1.eventHash));
      } finally {
        await orig.close();
        await dest.close();
      }
    });
  });
}
