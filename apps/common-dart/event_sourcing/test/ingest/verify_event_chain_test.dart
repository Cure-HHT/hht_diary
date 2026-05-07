// IMPLEMENTS REQUIREMENTS:
//   REQ-d00146-A: verifyEventChain — public Chain-1 verifier on EventStore
//   REQ-d00146-B: ChainVerdict shape; non-throwing contract
//   REQ-d00146-D: verifyEventChain does not throw; returns ChainVerdict
//   REQ-d00146-E: ok=true trivially for origin-only (length-1 provenance)

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
    'verify-event-chain-$_dbCounter.db',
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventStore.verifyEventChain (REQ-d00146-A+B)', () {
    test('returns ok=true for a well-formed ingested event', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // 1. Originate an event.
        final original = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-verify-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(original, isNotNull);

        // 2. Ingest at destination.
        final outcome = await dest.store.ingestEvent(original!);
        expect(outcome.outcome, equals(IngestOutcome.ingested));

        // 3. Read stored copy.
        final stored = await dest.backend.transaction((txn) async {
          return dest.backend.findEventByIdInTxn(txn, original.eventId);
        });
        expect(stored, isNotNull);

        // 4. verifyEventChain → ok=true.
        final verdict = await dest.store.verifyEventChain(stored!);
        expect(verdict.ok, isTrue);
        expect(verdict.failures, isEmpty);
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test(
      'returns ok=false with one ChainFailure when arrival_hash is tampered',
      () async {
        final orig = await _openStore(hopId: 'mobile-device');
        final dest = await _openStore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          final original = await orig.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'agg-tamper-1',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {'answers': {}},
            initiator: const UserInitiator('u1'),
          );
          expect(original, isNotNull);

          await dest.store.ingestEvent(original!);

          final stored = await dest.backend.transaction((txn) async {
            return dest.backend.findEventByIdInTxn(txn, original.eventId);
          });
          expect(stored, isNotNull);

          // Tamper provenance[1].arrival_hash.
          final tamperedMap = stored!.toMap();
          final metaOrig = tamperedMap['metadata'] as Map<String, Object?>;
          final meta = Map<String, Object?>.from(metaOrig);
          final provList = (meta['provenance'] as List<Object?>).toList();
          final hop1 = Map<String, Object?>.from(
            provList[1] as Map<String, Object?>,
          );
          hop1['arrival_hash'] = 'tampered-wrong-hash-000000000000000000000';
          provList[1] = hop1;
          meta['provenance'] = provList;
          tamperedMap['metadata'] = meta;
          final tampered = StoredEvent.fromMap(
            tamperedMap,
            stored.sequenceNumber,
          );

          final verdict = await dest.store.verifyEventChain(tampered);
          expect(verdict.ok, isFalse);
          expect(verdict.failures, hasLength(1));
          expect(verdict.failures.first.position, equals(1));
          expect(
            verdict.failures.first.kind,
            equals(ChainFailureKind.arrivalHashMismatch),
          );
          // expectedHash is the tampered (stored but wrong) value.
          expect(
            verdict.failures.first.expectedHash,
            equals('tampered-wrong-hash-000000000000000000000'),
          );
          // actualHash is the recomputed (correct) value.
          expect(verdict.failures.first.actualHash, isNotEmpty);
        } finally {
          await orig.close();
          await dest.close();
        }
      },
    );

    test('does not throw on a corrupted chain — returns verdict', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        final original = await orig.store.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'agg-nothrow-1',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(original, isNotNull);

        await dest.store.ingestEvent(original!);

        final stored = await dest.backend.transaction((txn) async {
          return dest.backend.findEventByIdInTxn(txn, original.eventId);
        });
        expect(stored, isNotNull);

        // Build corrupted copy.
        final tamperedMap = stored!.toMap();
        final metaOrig = tamperedMap['metadata'] as Map<String, Object?>;
        final meta = Map<String, Object?>.from(metaOrig);
        final provList = (meta['provenance'] as List<Object?>).toList();
        final hop1 = Map<String, Object?>.from(
          provList[1] as Map<String, Object?>,
        );
        hop1['arrival_hash'] = 'corrupted';
        provList[1] = hop1;
        meta['provenance'] = provList;
        tamperedMap['metadata'] = meta;
        final corrupted = StoredEvent.fromMap(
          tamperedMap,
          stored.sequenceNumber,
        );

        // Must not throw — returns a verdict.
        final ChainVerdict verdict;
        try {
          verdict = await dest.store.verifyEventChain(corrupted);
        } catch (e) {
          fail('verifyEventChain must not throw; got: $e');
        }
        expect(verdict.ok, isFalse);
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test(
      'returns ok=true on an origin-only event (length-1 provenance)',
      () async {
        final orig = await _openStore(hopId: 'mobile-device');

        try {
          final event = await orig.store.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'agg-origin-only',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {'answers': {}},
            initiator: const UserInitiator('u1'),
          );
          expect(event, isNotNull);

          // Origin event has exactly one provenance entry — no hop links to verify.
          final provenance = (event!.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          expect(provenance, hasLength(1));

          final verdict = await orig.store.verifyEventChain(event);
          expect(verdict.ok, isTrue);
          expect(verdict.failures, isEmpty);
        } finally {
          await orig.close();
        }
      },
    );
  });
}
