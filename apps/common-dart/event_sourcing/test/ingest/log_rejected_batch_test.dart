// IMPLEMENTS REQUIREMENTS:
//   REQ-d00145-H: EventStore.logRejectedBatch — caller-composed rejection audit
//   REQ-d00145-I: ingest.batch_rejected event under ingest-audit aggregate
//   REQ-d00145-J: batch_context null for rejection (no decoded batch)

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
  String hopId = 'portal-server',
  String identifier = 'portal-1',
  String softwareVersion = 'portal@0.1.0',
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'rejected-batch-$_dbCounter.db',
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
  group('EventStore.logRejectedBatch (REQ-d00145-H+I+J)', () {
    test(
      'emits exactly one ingest.batch_rejected event under ingest-audit aggregate',
      () async {
        final dest = await _openStore();
        try {
          final bytes = Uint8List.fromList(utf8.encode('garbage bytes'));
          await dest.store.logRejectedBatch(
            bytes,
            wireFormat: 'esd/batch@1',
            reason: 'decodeFailure',
            failedEventId: null,
            errorDetail: 'test: invalid envelope',
          );

          final auditEvents = await dest.backend.findEventsForAggregate(
            'ingest-audit:portal-server',
          );
          expect(auditEvents, hasLength(1));
          expect(auditEvents[0].eventType, equals('ingest.batch_rejected'));
          expect(
            auditEvents[0].aggregateId,
            equals('ingest-audit:portal-server'),
          );
        } finally {
          await dest.close();
        }
      },
    );

    test('data.wire_bytes round-trips via base64', () async {
      final dest = await _openStore();
      try {
        final bytes = Uint8List.fromList(utf8.encode('some binary content'));
        await dest.store.logRejectedBatch(
          bytes,
          wireFormat: 'esd/batch@1',
          reason: 'decodeFailure',
        );

        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        expect(auditEvents, hasLength(1));

        final data = auditEvents[0].data;
        final decoded = base64Decode(data['wire_bytes'] as String);
        expect(decoded, equals(bytes));
      } finally {
        await dest.close();
      }
    });

    test('data fields: wire_format, byte_length, wire_bytes_hash, reason, '
        'failed_event_id, error_detail all match arguments', () async {
      final dest = await _openStore();
      try {
        final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
        final expectedHash = sha256.convert(bytes).toString();

        await dest.store.logRejectedBatch(
          bytes,
          wireFormat: 'esd/batch@1',
          reason: 'identityMismatch',
          failedEventId: 'event-id-xyz',
          errorDetail: 'hash collision detail',
        );

        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        expect(auditEvents, hasLength(1));
        final data = auditEvents[0].data;

        expect(data['wire_format'], equals('esd/batch@1'));
        expect(data['byte_length'], equals(4));
        expect(data['wire_bytes_hash'], equals(expectedHash));
        expect(data['reason'], equals('identityMismatch'));
        expect(data['failed_event_id'], equals('event-id-xyz'));
        expect(data['error_detail'], equals('hash collision detail'));
      } finally {
        await dest.close();
      }
    });

    test('provenance[0]: hop matches source, arrival_hash null, '
        'batch_context absent/null, ingest_sequence_number populated '
        'on first call (empty log)', () async {
      final dest = await _openStore(hopId: 'portal-server');
      try {
        final bytes = Uint8List.fromList([0xAA, 0xBB]);
        await dest.store.logRejectedBatch(
          bytes,
          wireFormat: 'esd/batch@1',
          reason: 'decodeFailure',
        );

        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        expect(auditEvents, hasLength(1));

        final prov = (auditEvents[0].metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(prov, hasLength(1));

        final p0 = prov[0];
        expect(p0['hop'], equals('portal-server'));
        expect(p0['arrival_hash'], isNull);
        // previous_ingest_hash is null on first call (empty ingest log)
        expect(p0['previous_ingest_hash'], isNull);
        // ingest_sequence_number is non-null and non-zero
        expect(p0['ingest_sequence_number'], isNotNull);
        expect(p0['ingest_sequence_number'], greaterThan(0));
        // batch_context is absent (no decoded batch associated)
        expect(p0.containsKey('batch_context'), isFalse);
      } finally {
        await dest.close();
      }
    });

    test('two consecutive calls emit two events; second previous_ingest_hash '
        'equals first stored event_hash (Chain 2 thread)', () async {
      final dest = await _openStore();
      try {
        final bytes1 = Uint8List.fromList(utf8.encode('first garbage'));
        final bytes2 = Uint8List.fromList(utf8.encode('second garbage'));

        await dest.store.logRejectedBatch(
          bytes1,
          wireFormat: 'esd/batch@1',
          reason: 'decodeFailure',
          errorDetail: 'first error',
        );
        await dest.store.logRejectedBatch(
          bytes2,
          wireFormat: 'esd/batch@1',
          reason: 'decodeFailure',
          errorDetail: 'second error',
        );

        final auditEvents = await dest.backend.findEventsForAggregate(
          'ingest-audit:portal-server',
        );
        expect(auditEvents, hasLength(2));

        // Both events are batch_rejected.
        expect(auditEvents[0].eventType, equals('ingest.batch_rejected'));
        expect(auditEvents[1].eventType, equals('ingest.batch_rejected'));

        // Second event's previous_ingest_hash == first event's event_hash.
        final prov0 = (auditEvents[0].metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();
        final prov1 = (auditEvents[1].metadata['provenance'] as List<Object?>)
            .cast<Map<String, Object?>>();

        expect(prov0[0]['previous_ingest_hash'], isNull);
        expect(
          prov1[0]['previous_ingest_hash'],
          equals(auditEvents[0].eventHash),
        );
      } finally {
        await dest.close();
      }
    });

    test(
      'failedEventId and errorDetail default to null when omitted',
      () async {
        final dest = await _openStore();
        try {
          final bytes = Uint8List.fromList([0xFF]);
          await dest.store.logRejectedBatch(
            bytes,
            wireFormat: 'esd/batch@1',
            reason: 'decodeFailure',
          );

          final auditEvents = await dest.backend.findEventsForAggregate(
            'ingest-audit:portal-server',
          );
          expect(auditEvents, hasLength(1));

          final data = auditEvents[0].data;
          expect(data['failed_event_id'], isNull);
          expect(data['error_detail'], isNull);
        } finally {
          await dest.close();
        }
      },
    );
  });
}
