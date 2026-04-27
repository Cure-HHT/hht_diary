import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

Future<StoredEvent> _appendEvent(
  SembastBackend backend, {
  required String eventId,
  String aggregateId = 'agg-1',
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: 'DiaryEntry',
      entryType: 'epistaxis_event',
      entryTypeVersion: 1,
      libFormatVersion: 1,
      eventType: 'finalized',
      sequenceNumber: seq,
      data: const <String, dynamic>{},
      metadata: const <String, dynamic>{},
      initiator: const UserInitiator('u'),
      clientTimestamp: DateTime.utc(2026, 4, 22, 10),
      eventHash: 'hash-$eventId',
    );
    await backend.appendEvent(txn, event);
    return event;
  });
}

void main() {
  group('SembastBackend.findEventById', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('find-event-by-id-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00147-A — found id returns the stored event.
    test(
      'REQ-d00147-A: findEventById returns the stored event when present',
      () async {
        final appended = await _appendEvent(backend, eventId: 'evt-target');
        final result = await backend.findEventById('evt-target');
        expect(result, isNotNull);
        expect(result!.eventId, 'evt-target');
        expect(result.sequenceNumber, appended.sequenceNumber);
        expect(result.aggregateId, appended.aggregateId);
        expect(result.eventHash, appended.eventHash);
      },
    );

    // Verifies: REQ-d00147-A — absent id returns null (does NOT throw).
    test(
      'REQ-d00147-A: findEventById returns null when no event with that id exists',
      () async {
        await _appendEvent(backend, eventId: 'evt-other-1');
        await _appendEvent(backend, eventId: 'evt-other-2');
        final result = await backend.findEventById('evt-missing');
        expect(result, isNull);
      },
    );

    // Verifies: REQ-d00147-A — multiple events present, lookup picks the right one.
    test(
      'REQ-d00147-A: findEventById disambiguates among many stored events',
      () async {
        await _appendEvent(backend, eventId: 'evt-a');
        final target = await _appendEvent(backend, eventId: 'evt-target');
        await _appendEvent(backend, eventId: 'evt-c');
        final result = await backend.findEventById('evt-target');
        expect(result, isNotNull);
        expect(result!.sequenceNumber, target.sequenceNumber);
        expect(result.eventId, 'evt-target');
      },
    );
  });
}
