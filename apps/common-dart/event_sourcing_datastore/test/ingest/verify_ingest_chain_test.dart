// IMPLEMENTS REQUIREMENTS:
//   REQ-d00146-C: verifyIngestChain — walks Chain 2 on destination log
//   REQ-d00146-D: non-throwing; returns ChainVerdict
//   REQ-d00146-E: ArgumentError when fromIngestSeq > toIngestSeq

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart' as sembast;
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
  String hopId = 'portal-server',
  String identifier = 'portal-1',
  String softwareVersion = 'portal@0.1.0',
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'verify-ingest-chain-$_dbCounter.db',
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

/// Produce [count] origin events from a throwaway originator store and
/// return them.
Future<List<StoredEvent>> _originate(int count) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'orig-$_dbCounter.db',
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
  final secCtx = SembastSecurityContextStore(backend: backend);
  final store = EventStore(
    backend: backend,
    entryTypes: registry,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'device-1',
      softwareVersion: 'clinical_diary@1.0.0',
    ),
    securityContexts: secCtx,
  );
  final events = <StoredEvent>[];
  for (var i = 0; i < count; i++) {
    final e = await store.append(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-orig-$i-$_dbCounter',
      aggregateType: 'DiaryEntry',
      eventType: 'finalized',
      data: <String, Object?>{'index': i},
      initiator: const UserInitiator('u1'),
    );
    events.add(e!);
  }
  await backend.close();
  return events;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventStore.verifyIngestChain (REQ-d00146-C)', () {
    test('returns ok=true over a clean sequence of ingests', () async {
      final dest = await _openStore();
      final origEvents = await _originate(3);

      try {
        for (final e in origEvents) {
          final outcome = await dest.store.ingestEvent(e);
          expect(outcome.outcome, equals(IngestOutcome.ingested));
        }

        final verdict = await dest.store.verifyIngestChain();
        expect(verdict.ok, isTrue);
        expect(verdict.failures, isEmpty);
      } finally {
        await dest.close();
      }
    });

    test(
      'returns ok=false when one previous_ingest_hash is tampered',
      () async {
        final dest = await _openStore();
        final origEvents = await _originate(3);

        try {
          for (final e in origEvents) {
            final outcome = await dest.store.ingestEvent(e);
            expect(outcome.outcome, equals(IngestOutcome.ingested));
          }

          // Verify clean first.
          final cleanVerdict = await dest.store.verifyIngestChain();
          expect(cleanVerdict.ok, isTrue);

          // Directly tamper e2's stored record (ingest_sequence_number == 2)
          // via sembast raw access. Ingested events live in 'ingested_events'
          // (separate from the origin 'events' store after the store split).
          final rawDb = dest.backend.debugDatabase();
          final eventStore = sembast.intMapStoreFactory.store(
            'ingested_events',
          );

          // Find the record with ingest_sequence_number == 2 (Sembast key == 2
          // because appendIngestedEvent uses ingestSeq as the key).
          final record = await eventStore.record(2).get(rawDb);
          expect(
            record,
            isNotNull,
            reason: 'event with ingest key 2 must exist',
          );

          final updated = Map<String, Object?>.from(record!);
          final metaOrig = updated['metadata'] as Map<String, Object?>;
          final meta = Map<String, Object?>.from(metaOrig);
          final provList = (meta['provenance'] as List<Object?>).toList();
          final lastHop = Map<String, Object?>.from(
            provList.last as Map<String, Object?>,
          );
          lastHop['previous_ingest_hash'] =
              'tampered-previous-ingest-hash-00000000000';
          provList[provList.length - 1] = lastHop;
          meta['provenance'] = provList;
          updated['metadata'] = meta;

          await rawDb.transaction((txn) async {
            await eventStore.record(2).put(txn, updated);
          });

          // Now verify — should detect one failure at seq 2.
          final verdict = await dest.store.verifyIngestChain();
          expect(verdict.ok, isFalse);
          expect(verdict.failures, hasLength(1));
          expect(verdict.failures.first.position, equals(2));
          expect(
            verdict.failures.first.kind,
            equals(ChainFailureKind.previousIngestHashMismatch),
          );
        } finally {
          await dest.close();
        }
      },
    );

    test('respects fromIngestSeq / toIngestSeq bounds', () async {
      // Ingest 5 events. Break #3 (seq 3). Verify range [1, 2] → ok=true
      // because the break is at seq 3 which is outside the walked range.
      final dest = await _openStore();
      final origEvents = await _originate(5);

      try {
        for (final e in origEvents) {
          final outcome = await dest.store.ingestEvent(e);
          expect(outcome.outcome, equals(IngestOutcome.ingested));
        }

        // Tamper seq 3. Ingested events live in 'ingested_events'
        // (separate from the origin 'events' store after the store split).
        final rawDb = dest.backend.debugDatabase();
        final eventStore = sembast.intMapStoreFactory.store('ingested_events');

        final record = await eventStore.record(3).get(rawDb);
        expect(record, isNotNull);

        final updated = Map<String, Object?>.from(record!);
        final metaOrig = updated['metadata'] as Map<String, Object?>;
        final meta = Map<String, Object?>.from(metaOrig);
        final provList = (meta['provenance'] as List<Object?>).toList();
        final lastHop = Map<String, Object?>.from(
          provList.last as Map<String, Object?>,
        );
        lastHop['previous_ingest_hash'] = 'tampered-at-seq-3';
        provList[provList.length - 1] = lastHop;
        meta['provenance'] = provList;
        updated['metadata'] = meta;

        await rawDb.transaction((txn) async {
          await eventStore.record(3).put(txn, updated);
        });

        // Walking 1..2 should be clean (tamper is at 3).
        final verdictClean = await dest.store.verifyIngestChain(
          fromIngestSeq: 1,
          toIngestSeq: 2,
        );
        expect(verdictClean.ok, isTrue);
        expect(verdictClean.failures, isEmpty);

        // Walking 1..5 should detect the failure at seq 3.
        final verdictFull = await dest.store.verifyIngestChain(
          fromIngestSeq: 1,
          toIngestSeq: 5,
        );
        expect(verdictFull.ok, isFalse);
        expect(verdictFull.failures, hasLength(1));
        expect(verdictFull.failures.first.position, equals(3));
      } finally {
        await dest.close();
      }
    });

    test('throws ArgumentError when fromIngestSeq > toIngestSeq', () async {
      final dest = await _openStore();

      try {
        await expectLater(
          () => dest.store.verifyIngestChain(fromIngestSeq: 5, toIngestSeq: 3),
          throwsArgumentError,
        );
      } finally {
        await dest.close();
      }
    });
  });
}
