// IMPLEMENTS REQUIREMENTS:
//   REQ-d00145-D: identity-mismatch throws IngestIdentityMismatch;
//                  transaction rolls back — no side effects.

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
    'ingest-mismatch-$_dbCounter.db',
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
  group('EventStore.ingestEvent — identity mismatch (REQ-d00145-D)', () {
    test(
      'same event_id but different event_hash throws IngestIdentityMismatch',
      () async {
        final orig = await _openStore(hopId: 'mobile-device');
        final dest = await _openStore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          // 1. Originate an event and ingest it.
          final e1 = await orig.store.append(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-mismatch',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const {
              'answers': {'severity': 'mild'},
            },
            initiator: const UserInitiator('u1'),
          );
          expect(e1, isNotNull);
          await dest.store.ingestEvent(e1!);

          // 2. Build a tampered version: same event_id, different event_hash.
          final tamperedMap = e1.toMap();
          tamperedMap['event_hash'] =
              'totally-different-hash-abcdef1234567890ab';
          final tampered = StoredEvent.fromMap(tamperedMap, 0);

          // 3. Re-ingest with mismatched hash must throw.
          await expectLater(
            () => dest.store.ingestEvent(tampered),
            throwsA(
              isA<IngestIdentityMismatch>()
                  .having((e) => e.eventId, 'eventId', e1.eventId)
                  .having(
                    (e) => e.incomingHash,
                    'incomingHash',
                    'totally-different-hash-abcdef1234567890ab',
                  ),
            ),
          );

          // 4. No new events landed — tail seq is 1 (first ingest only).
          final tail = await dest.backend.readIngestTail();
          expect(tail.$1, equals(1));
        } finally {
          await orig.close();
          await dest.close();
        }
      },
    );

    test('identity mismatch: no ingest-audit events emitted '
        '(transaction rolled back)', () async {
      final orig = await _openStore(hopId: 'mobile-device');
      final dest = await _openStore(
        hopId: 'portal-server',
        identifier: 'portal-1',
        softwareVersion: 'portal@0.1.0',
      );

      try {
        final e1 = await orig.store.append(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-mismatch2',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(e1, isNotNull);
        await dest.store.ingestEvent(e1!);

        final tamperedMap = e1.toMap();
        tamperedMap['event_hash'] = 'bad-hash-0000000000000000000000000000';
        final tampered = StoredEvent.fromMap(tamperedMap, 0);

        // Should throw.
        Object? thrown;
        try {
          await dest.store.ingestEvent(tampered);
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isA<IngestIdentityMismatch>());

        // No ingest.duplicate_received events (throw path, not dup path).
        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        expect(auditEvents, isEmpty);
      } finally {
        await orig.close();
        await dest.close();
      }
    });
  });
}
