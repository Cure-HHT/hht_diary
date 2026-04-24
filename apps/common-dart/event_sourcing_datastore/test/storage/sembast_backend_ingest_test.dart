// IMPLEMENTS REQUIREMENTS:
//   REQ-d00115-H: Chain 2 tail read (readIngestTail / readIngestTailInTxn)
//   REQ-d00115-I: Ingest sequence counter (nextIngestSequenceNumber)
//   REQ-d00145-D: Idempotency check (findEventByIdInTxn)
//   REQ-d00145-E: Destination-role persistence (appendIngestedEvent)

import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('SembastBackend ingest-side methods', () {
    var pathCounter = 0;

    Future<SembastBackend> openBackend() async {
      pathCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'ingest-$pathCounter.db',
      );
      return SembastBackend(database: db);
    }

    test('nextIngestSequenceNumber returns 1 on first call, then 2', () async {
      final backend = await openBackend();
      try {
        await backend.transaction((txn) async {
          final first = await backend.nextIngestSequenceNumber(txn);
          final second = await backend.nextIngestSequenceNumber(txn);
          expect(first, equals(1));
          expect(second, equals(2));
        });
      } finally {
        await backend.close();
      }
    });

    test('readIngestTail returns (0, null) on an empty backend', () async {
      final backend = await openBackend();
      try {
        final tail = await backend.readIngestTail();
        expect(tail.$1, equals(0));
        expect(tail.$2, isNull);
      } finally {
        await backend.close();
      }
    });

    test('appendIngestedEvent advances the Chain 2 tail', () async {
      final backend = await openBackend();
      try {
        final event = _fakeIngestedEvent(
          eventId: 'e1',
          ingestSeq: 1,
          eventHash: 'hash-at-rest',
        );
        await backend.transaction((txn) async {
          await backend.appendIngestedEvent(txn, event);
        });
        final tail = await backend.readIngestTail();
        expect(tail.$1, equals(1));
        expect(tail.$2, equals('hash-at-rest'));
      } finally {
        await backend.close();
      }
    });

    test('findEventByIdInTxn returns null when event_id is absent', () async {
      final backend = await openBackend();
      try {
        await backend.transaction((txn) async {
          final found = await backend.findEventByIdInTxn(txn, 'nope');
          expect(found, isNull);
        });
      } finally {
        await backend.close();
      }
    });

    test(
      'findEventByIdInTxn returns the event when present (ingested path)',
      () async {
        final backend = await openBackend();
        try {
          final event = _fakeIngestedEvent(
            eventId: 'e2',
            ingestSeq: 1,
            eventHash: 'some-hash',
          );
          await backend.transaction((txn) async {
            await backend.appendIngestedEvent(txn, event);
          });
          await backend.transaction((txn) async {
            final found = await backend.findEventByIdInTxn(txn, 'e2');
            expect(found, isNotNull);
            expect(found!.eventId, equals('e2'));
          });
        } finally {
          await backend.close();
        }
      },
    );

    test('readIngestTailInTxn reflects writes in same transaction', () async {
      final backend = await openBackend();
      try {
        final event = _fakeIngestedEvent(
          eventId: 'e3',
          ingestSeq: 1,
          eventHash: 'in-txn-hash',
        );
        await backend.transaction((txn) async {
          final tailBefore = await backend.readIngestTailInTxn(txn);
          expect(tailBefore.$1, equals(0));
          expect(tailBefore.$2, isNull);
          await backend.appendIngestedEvent(txn, event);
          final tailAfter = await backend.readIngestTailInTxn(txn);
          expect(tailAfter.$1, equals(1));
          expect(tailAfter.$2, equals('in-txn-hash'));
        });
      } finally {
        await backend.close();
      }
    });
  });
}

/// Build a fake ingested [StoredEvent] whose `metadata.provenance` list
/// ends with a receiver entry carrying the given [ingestSeq] as
/// `ingest_sequence_number`. The event's `eventHash` is set to
/// [eventHash] so Chain 2 tail tracking can be verified independently
/// of hash-computation logic.
StoredEvent _fakeIngestedEvent({
  required String eventId,
  required int ingestSeq,
  required String eventHash,
}) {
  // The receiver ProvenanceEntry shape expected by appendIngestedEvent:
  // last entry in provenance must have `ingest_sequence_number` set.
  final receiverEntry = <String, Object?>{
    'role': 'receiver',
    'device_id': 'test-receiver',
    'ingest_sequence_number': ingestSeq,
    'ingested_at': DateTime.utc(2026, 4, 24).toIso8601String(),
  };
  final metadata = <String, dynamic>{
    'provenance': [receiverEntry],
  };
  return StoredEvent(
    key: 0,
    eventId: eventId,
    aggregateId: 'agg-ingest-1',
    aggregateType: 'DiaryEntry',
    entryType: 'epistaxis_event',
    eventType: 'finalized',
    sequenceNumber: 0,
    data: const <String, dynamic>{},
    metadata: metadata,
    initiator: const UserInitiator('u-test'),
    clientTimestamp: DateTime.utc(2026, 4, 24),
    eventHash: eventHash,
  );
}
