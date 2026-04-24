// IMPLEMENTS REQUIREMENTS:
//   REQ-d00145-D: Idempotency check — duplicate-received path
//   REQ-d00145-I: ingest.duplicate_received audit event under ingest-audit aggregate
//   REQ-d00115-J: batchContext=null for process-local ingestEvent path

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
    'ingest-dup-$_dbCounter.db',
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
  group('EventStore.ingestEvent — duplicate (REQ-d00145-D)', () {
    test('second ingest of identical event returns duplicate outcome and '
        'does not mutate the stored subject', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        // Originate event.
        final e = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-dup',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e, isNotNull);

        // First ingest — should be ingested.
        final first = await dest.store.ingestEvent(e!);
        expect(first.outcome, equals(IngestOutcome.ingested));
        final hashAfterFirst = first.resultHash;

        // Read stored copy after first ingest.
        final storedAfterFirst = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e.eventId),
        );

        // Second ingest of same event — should be duplicate.
        final second = await dest.store.ingestEvent(e);
        expect(second.outcome, equals(IngestOutcome.duplicate));
        // Result hash is unchanged (stored copy not mutated).
        expect(second.resultHash, equals(hashAfterFirst));
        expect(second.eventId, equals(e.eventId));

        // Stored subject is identical after second ingest.
        final storedAfterSecond = await dest.backend.transaction(
          (txn) async => dest.backend.findEventByIdInTxn(txn, e.eventId),
        );
        expect(
          storedAfterSecond!.eventHash,
          equals(storedAfterFirst!.eventHash),
        );
        final provBefore =
            storedAfterFirst.metadata['provenance'] as List<Object?>;
        final provAfter =
            storedAfterSecond.metadata['provenance'] as List<Object?>;
        expect(provAfter.length, equals(provBefore.length));
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test(
      'duplicate ingest emits ingest.duplicate_received under ingest-audit aggregate',
      () async {
        final orig = await _openStore(hopId: 'mobile-device');
        final dest = await _openStore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          final e = await orig.store.append(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-dup2',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {'answers': {}},
            initiator: const UserInitiator('u1'),
          );
          expect(e, isNotNull);

          await dest.store.ingestEvent(e!);
          await dest.store.ingestEvent(e);

          // Query the ingest-audit aggregate.
          const auditAggId = 'ingest-audit:portal-server';
          final auditEvents = await dest.backend.findEventsForAggregate(
            auditAggId,
          );
          expect(auditEvents, hasLength(1));
          expect(
            auditEvents.first.eventType,
            equals('ingest.duplicate_received'),
          );
          expect(auditEvents.first.data['subject_event_id'], equals(e.eventId));
        } finally {
          await orig.close();
          await dest.close();
        }
      },
    );

    test('duplicate_received event carries batchContext absent (null) for '
        'ingestEvent path (REQ-d00115-J)', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        final e = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-dup3',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e, isNotNull);

        await dest.store.ingestEvent(e!);
        await dest.store.ingestEvent(e);

        // The audit event's provenance[0].batchContext must be absent/null.
        const auditAggId = 'ingest-audit:portal-server';
        final auditEvents = await dest.backend.findEventsForAggregate(
          auditAggId,
        );
        expect(auditEvents, hasLength(1));

        final prov = (auditEvents.first.metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(prov, hasLength(1));
        expect(prov[0].containsKey('batch_context'), isFalse);
      } finally {
        await orig.close();
        await dest.close();
      }
    });

    test('consecutive re-ingests emit one duplicate_received each', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        final e = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-dup4',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e, isNotNull);

        await dest.store.ingestEvent(e!);
        await dest.store.ingestEvent(e);
        await dest.store.ingestEvent(e);

        const auditAggId = 'ingest-audit:portal-server';
        final auditEvents = await dest.backend.findEventsForAggregate(
          auditAggId,
        );
        expect(
          auditEvents,
          hasLength(2),
        ); // Two re-ingests => two audit events.
      } finally {
        await orig.close();
        await dest.close();
      }
    });
  });
}
