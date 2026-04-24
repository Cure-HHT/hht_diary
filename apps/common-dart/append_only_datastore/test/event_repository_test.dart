// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_memory.dart';

void main() {
  group('EventRepository', () {
    late DatabaseProvider databaseProvider;
    late EventRepository repository;

    setUp(() async {
      // Use in-memory database for tests
      databaseProvider = _TestDatabaseProvider();
      await databaseProvider.initialize();
      repository = EventRepository(databaseProvider: databaseProvider);
    });

    tearDown(() async {
      await databaseProvider.close();
    });

    group('append', () {
      test('creates event with all required fields', () async {
        final event = await repository.append(
          aggregateId: 'aggregate-123',
          entryType: 'epistaxis_event',
          eventType: 'TestEvent',
          data: {'key': 'value'},
          userId: 'user-456',
          deviceId: 'device-789',
        );

        expect(event.eventId, isNotEmpty);
        expect(event.aggregateId, equals('aggregate-123'));
        expect(event.entryType, equals('epistaxis_event'));
        expect(event.eventType, equals('TestEvent'));
        expect(event.data, equals({'key': 'value'}));
        // Phase 4.4: userId wrapped internally into UserInitiator;
        // deviceId stamped into metadata.provenance[0].identifier.
        expect(event.initiator, equals(const UserInitiator('user-456')));
        final prov =
            (event.metadata['provenance'] as List).first
                as Map<String, Object?>;
        expect(prov['identifier'], equals('device-789'));
        expect(event.sequenceNumber, equals(1));
        expect(event.eventHash, isNotEmpty);
        expect(event.previousEventHash, isNull);
        expect(event.syncedAt, isNull);
      });

      // Verifies: REQ-d00118-A — append() requires entry_type as a first-
      // class parameter and the resulting StoredEvent round-trips it.
      test('REQ-d00118-A: entryType round-trips through append', () async {
        final event = await repository.append(
          aggregateId: 'aggregate-123',
          entryType: 'nose_hht_survey',
          eventType: 'finalized',
          data: const <String, dynamic>{},
          userId: 'u',
          deviceId: 'd',
        );
        expect(event.entryType, equals('nose_hht_survey'));

        final fromStore = (await repository.getAllEvents()).single;
        expect(fromStore.entryType, equals('nose_hht_survey'));
      });

      test('assigns sequential sequence numbers', () async {
        final event1 = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final event2 = await repository.append(
          aggregateId: 'aggregate-2',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final event3 = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event3',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(event1.sequenceNumber, equals(1));
        expect(event2.sequenceNumber, equals(2));
        expect(event3.sequenceNumber, equals(3));
      });

      test('creates hash chain with previous event hash', () async {
        final event1 = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {'seq': 1},
          userId: 'user',
          deviceId: 'device',
        );

        final event2 = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {'seq': 2},
          userId: 'user',
          deviceId: 'device',
        );

        expect(event1.previousEventHash, isNull);
        expect(event2.previousEventHash, equals(event1.eventHash));
      });

      test('uses provided client timestamp', () async {
        final clientTime = DateTime(2024, 1, 15, 10, 30);

        final event = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
          clientTimestamp: clientTime,
        );

        expect(event.clientTimestamp, equals(clientTime.toUtc()));
      });

      // Verifies: REQ-d00118-B — the persisted event record SHALL NOT carry
      // a server_timestamp field. StoredEvent.toMap() must not emit that key.
      test(
        'REQ-d00118-B: no server_timestamp on StoredEvent.toMap output',
        () async {
          final event = await repository.append(
            aggregateId: 'aggregate-1',
            entryType: 'epistaxis_event',
            eventType: 'Event1',
            data: {},
            userId: 'user',
            deviceId: 'device',
          );
          final map = event.toMap();
          expect(map.containsKey('server_timestamp'), isFalse);
          expect(map.containsKey('entry_type'), isTrue);
        },
      );
    });

    group('getEventsForAggregate', () {
      test('returns events for specific aggregate', () async {
        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {'id': 'A1'},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-B',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {'id': 'B1'},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event3',
          data: {'id': 'A2'},
          userId: 'user',
          deviceId: 'device',
        );

        final eventsA = await repository.getEventsForAggregate('aggregate-A');
        final eventsB = await repository.getEventsForAggregate('aggregate-B');

        expect(eventsA.length, equals(2));
        expect(eventsA[0].data['id'], equals('A1'));
        expect(eventsA[1].data['id'], equals('A2'));

        expect(eventsB.length, equals(1));
        expect(eventsB[0].data['id'], equals('B1'));
      });

      test('returns events in sequence order', () async {
        // Add events in non-sequential order to different aggregates
        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {'order': 1},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {'order': 2},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event3',
          data: {'order': 3},
          userId: 'user',
          deviceId: 'device',
        );

        final events = await repository.getEventsForAggregate('aggregate-A');

        expect(events[0].sequenceNumber, lessThan(events[1].sequenceNumber));
        expect(events[1].sequenceNumber, lessThan(events[2].sequenceNumber));
      });

      test('returns empty list for non-existent aggregate', () async {
        final events = await repository.getEventsForAggregate(
          'non-existent-aggregate',
        );
        expect(events, isEmpty);
      });
    });

    group('getUnsyncedEvents', () {
      test('returns all events when none are synced', () async {
        await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-2',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final unsynced = await repository.getUnsyncedEvents();
        expect(unsynced.length, equals(2));
      });

      test('excludes synced events', () async {
        final event1 = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-2',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        // Mark first event as synced
        await repository.markEventsSynced([event1.eventId]);

        final unsynced = await repository.getUnsyncedEvents();
        expect(unsynced.length, equals(1));
        expect(unsynced[0].eventType, equals('Event2'));
      });
    });

    group('markEventsSynced', () {
      test('updates synced_at timestamp', () async {
        final event = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(event.isSynced, isFalse);

        await repository.markEventsSynced([event.eventId]);

        final events = await repository.getAllEvents();
        expect(events[0].isSynced, isTrue);
        expect(events[0].syncedAt, isNotNull);
      });

      test('handles multiple event IDs', () async {
        final event1 = await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final event2 = await repository.append(
          aggregateId: 'aggregate-2',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.markEventsSynced([event1.eventId, event2.eventId]);

        final unsynced = await repository.getUnsyncedEvents();
        expect(unsynced, isEmpty);
      });

      test('handles empty list gracefully', () async {
        // Should not throw
        await repository.markEventsSynced([]);
      });
    });

    group('getUnsyncedCount', () {
      test('returns correct count', () async {
        expect(await repository.getUnsyncedCount(), equals(0));

        await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(await repository.getUnsyncedCount(), equals(1));

        final event2 = await repository.append(
          aggregateId: 'aggregate-2',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(await repository.getUnsyncedCount(), equals(2));

        await repository.markEventsSynced([event2.eventId]);

        expect(await repository.getUnsyncedCount(), equals(1));
      });
    });

    group('verifyIntegrity', () {
      test('returns true for valid chain', () async {
        await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {'seq': 1},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {'seq': 2},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event3',
          data: {'seq': 3},
          userId: 'user',
          deviceId: 'device',
        );

        final isValid = await repository.verifyIntegrity();
        expect(isValid, isTrue);
      });

      test('returns true for empty database', () async {
        final isValid = await repository.verifyIntegrity();
        expect(isValid, isTrue);
      });

      // Verifies: REQ-p00004-I — chain tampering is detectable. Mutating
      // entry_type on a stored record must break the hash chain because
      // entry_type is included in the canonical hash input (REQ-d00118-A).
      test(
        'tampering with entry_type makes verifyIntegrity return false',
        () async {
          await repository.append(
            aggregateId: 'agg-1',
            entryType: 'epistaxis_event',
            eventType: 'Event1',
            data: const <String, dynamic>{'seq': 1},
            userId: 'user',
            deviceId: 'device',
          );
          expect(await repository.verifyIntegrity(), isTrue);

          // Tamper: rewrite the first record's entry_type directly through
          // the underlying Sembast store, bypassing EventRepository's
          // append-only API.
          final eventStore = sembast.intMapStoreFactory.store('events');
          final record = (await eventStore.find(
            databaseProvider.database,
            finder: sembast.Finder(limit: 1),
          )).single;
          final tampered = Map<String, Object?>.from(record.value);
          tampered['entry_type'] = 'nose_hht_survey';
          await eventStore
              .record(record.key)
              .put(databaseProvider.database, tampered);

          expect(await repository.verifyIntegrity(), isFalse);
        },
      );

      // Verifies: REQ-d00120 — event_hash is produced by SHA-256 over the
      // RFC 8785 canonical JSON bytes of the event's identity fields. A
      // cross-platform verifier implementing RFC 8785 must be able to
      // recompute the same digest from the received fields. This test
      // pins the wiring: appending an event with known fields must
      // produce a hash equal to what an independent caller would get by
      // running canonicalizeBytes + sha256 over the same identity-field
      // subset.
      test(
        'REQ-d00120: event_hash matches SHA-256(JCS(identityFields))',
        () async {
          final clientTs = DateTime.utc(2026, 4, 22, 15, 30);
          final event = await repository.append(
            aggregateId: 'agg-1',
            entryType: 'epistaxis_event',
            eventType: 'finalized',
            data: const <String, dynamic>{'intensity': 'mild', 'notes': 'stub'},
            userId: 'u-1',
            deviceId: 'd-1',
            clientTimestamp: clientTs,
          );

          // Independently re-compute the expected hash per the Phase 4.4
          // identity-field set (REQ-d00120-B revised): event_id,
          // aggregate_id, entry_type, event_type, sequence_number, data,
          // initiator, flow_token, client_timestamp, previous_event_hash,
          // metadata. device_id lives in metadata.provenance[0] and is
          // covered transitively.
          final expectedBytes = canonicalizeBytes(<String, Object?>{
            'event_id': event.eventId,
            'aggregate_id': 'agg-1',
            'entry_type': 'epistaxis_event',
            'event_type': 'finalized',
            'sequence_number': event.sequenceNumber,
            'data': const <String, dynamic>{
              'intensity': 'mild',
              'notes': 'stub',
            },
            'initiator': const <String, Object?>{
              'type': 'user',
              'user_id': 'u-1',
            },
            'flow_token': null,
            'client_timestamp': clientTs.toIso8601String(),
            'previous_event_hash': null,
            'metadata': event.metadata,
          });
          final expected = sha256.convert(expectedBytes).toString();
          expect(event.eventHash, equals(expected));
        },
      );

      test(
        'tampering with event data makes verifyIntegrity return false',
        () async {
          await repository.append(
            aggregateId: 'agg-1',
            entryType: 'epistaxis_event',
            eventType: 'Event1',
            data: const <String, dynamic>{'severity': 'mild'},
            userId: 'user',
            deviceId: 'device',
          );

          final eventStore = sembast.intMapStoreFactory.store('events');
          final record = (await eventStore.find(
            databaseProvider.database,
            finder: sembast.Finder(limit: 1),
          )).single;
          final tampered = Map<String, Object?>.from(record.value);
          tampered['data'] = const <String, Object?>{'severity': 'severe'};
          await eventStore
              .record(record.key)
              .put(databaseProvider.database, tampered);

          expect(await repository.verifyIntegrity(), isFalse);
        },
      );
    });

    group('getAllEvents', () {
      test('returns all events in sequence order', () async {
        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-B',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
          entryType: 'epistaxis_event',
          eventType: 'Event3',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final events = await repository.getAllEvents();

        expect(events.length, equals(3));
        expect(events[0].sequenceNumber, equals(1));
        expect(events[1].sequenceNumber, equals(2));
        expect(events[2].sequenceNumber, equals(3));
      });
    });

    group('getLatestSequenceNumber', () {
      test('returns 0 for empty database', () async {
        final seq = await repository.getLatestSequenceNumber();
        expect(seq, equals(0));
      });

      test('returns latest sequence number', () async {
        await repository.append(
          aggregateId: 'aggregate-1',
          entryType: 'epistaxis_event',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(await repository.getLatestSequenceNumber(), equals(1));

        await repository.append(
          aggregateId: 'aggregate-2',
          entryType: 'epistaxis_event',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(await repository.getLatestSequenceNumber(), equals(2));
      });
    });
  });

  group('StoredEvent', () {
    test('toMap and fromMap roundtrip preserves data', () {
      final original = StoredEvent(
        key: 1,
        eventId: 'event-123',
        aggregateId: 'aggregate-456',
        aggregateType: 'DiaryEntry',
        entryType: 'epistaxis_event',
        eventType: 'NosebleedRecorded',
        sequenceNumber: 42,
        data: {'severity': 'mild', 'duration': 10},
        metadata: {'source': 'mobile'},
        initiator: const UserInitiator('user-789'),
        flowToken: 'invite:ABC',
        clientTimestamp: DateTime.utc(2024, 1, 15, 10, 30),
        eventHash: 'abc123hash',
        previousEventHash: 'xyz789hash',
        syncedAt: DateTime.utc(2024, 1, 15, 10, 35),
      );

      final map = original.toMap();
      final restored = StoredEvent.fromMap(map, 1);

      expect(restored.eventId, equals(original.eventId));
      expect(restored.aggregateId, equals(original.aggregateId));
      expect(restored.eventType, equals(original.eventType));
      expect(restored.sequenceNumber, equals(original.sequenceNumber));
      expect(restored.data, equals(original.data));
      expect(restored.metadata, equals(original.metadata));
      expect(restored.initiator, equals(original.initiator));
      expect(restored.flowToken, equals(original.flowToken));
      expect(restored.eventHash, equals(original.eventHash));
      expect(restored.previousEventHash, equals(original.previousEventHash));
      expect(restored.isSynced, equals(original.isSynced));
    });

    test('isSynced returns correct value', () {
      final unsynced = StoredEvent(
        key: 1,
        eventId: 'event-1',
        aggregateId: 'agg-1',
        aggregateType: 'Test',
        entryType: 'epistaxis_event',
        eventType: 'Test',
        sequenceNumber: 1,
        data: {},
        metadata: {},
        initiator: const UserInitiator('user'),
        clientTimestamp: DateTime.now(),
        eventHash: 'hash',
      );

      final synced = StoredEvent(
        key: 2,
        eventId: 'event-2',
        aggregateId: 'agg-1',
        aggregateType: 'Test',
        entryType: 'epistaxis_event',
        eventType: 'Test',
        sequenceNumber: 2,
        data: {},
        metadata: {},
        initiator: const UserInitiator('user'),
        clientTimestamp: DateTime.now(),
        eventHash: 'hash2',
        syncedAt: DateTime.now(),
      );

      expect(unsynced.isSynced, isFalse);
      expect(synced.isSynced, isTrue);
    });
  });

  group('EventRepository <-> StorageBackend delegation', () {
    // Verifies the core Task 9 claim: EventRepository.append actually goes
    // through StorageBackend.transaction / nextSequenceNumber / appendEvent.
    // Without this test, a future developer who added a Sembast shortcut
    // inside EventRepository would pass every other test — the delegation
    // path is not otherwise observable.
    test('append() calls backend.transaction/nextSeq/appendEvent', () async {
      final databaseProvider = _TestDatabaseProvider();
      await databaseProvider.initialize();
      addTearDown(databaseProvider.close);

      final spy = _SpyBackend(
        delegate: SembastBackend(database: databaseProvider.database),
      );
      final repo = EventRepository(
        databaseProvider: databaseProvider,
        backend: spy,
      );

      await repo.append(
        aggregateId: 'agg-1',
        entryType: 'epistaxis_event',
        eventType: 'finalized',
        data: const <String, dynamic>{},
        userId: 'u',
        deviceId: 'd',
      );

      expect(spy.transactionCalls, 1);
      expect(spy.nextSequenceNumberCalls, 1);
      expect(spy.appendEventCalls, 1);
    });

    test(
      'getEventsForAggregate routes through backend.findEventsForAggregate',
      () async {
        final databaseProvider = _TestDatabaseProvider();
        await databaseProvider.initialize();
        addTearDown(databaseProvider.close);

        final spy = _SpyBackend(
          delegate: SembastBackend(database: databaseProvider.database),
        );
        final repo = EventRepository(
          databaseProvider: databaseProvider,
          backend: spy,
        );

        await repo.getEventsForAggregate('agg-x');
        expect(spy.findEventsForAggregateCalls, 1);
      },
    );

    test(
      'getLatestSequenceNumber routes through backend.readSequenceCounter',
      () async {
        final databaseProvider = _TestDatabaseProvider();
        await databaseProvider.initialize();
        addTearDown(databaseProvider.close);

        final spy = _SpyBackend(
          delegate: SembastBackend(database: databaseProvider.database),
        );
        final repo = EventRepository(
          databaseProvider: databaseProvider,
          backend: spy,
        );

        expect(await repo.getLatestSequenceNumber(), 0);
        expect(spy.readSequenceCounterCalls, 1);
      },
    );

    // Verifies that concurrent append() calls serialize through the backend
    // transaction and produce a single well-formed hash chain. The previous-
    // hash read happens inside the same transaction that will append, so the
    // second append always sees the first append's committed hash — no fork,
    // no silent gap — even under interleaved Future scheduling.
    test('concurrent append() produces a coherent hash chain', () async {
      final databaseProvider = _TestDatabaseProvider();
      await databaseProvider.initialize();
      addTearDown(databaseProvider.close);

      final repo = EventRepository(databaseProvider: databaseProvider);

      final results = await Future.wait(<Future<StoredEvent>>[
        repo.append(
          aggregateId: 'agg-1',
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: const <String, dynamic>{'i': 1},
          userId: 'u',
          deviceId: 'd',
        ),
        repo.append(
          aggregateId: 'agg-2',
          entryType: 'epistaxis_event',
          eventType: 'finalized',
          data: const <String, dynamic>{'i': 2},
          userId: 'u',
          deviceId: 'd',
        ),
      ]);

      expect(results.length, 2);
      final all = await repo.getAllEvents();
      expect(all.length, 2);
      // Sequence numbers are 1 and 2 regardless of which append "won" first.
      final seqs = all.map((e) => e.sequenceNumber).toList()..sort();
      expect(seqs, [1, 2]);
      // Second event's previous_event_hash equals the first event's hash.
      final bySeq = {for (final e in all) e.sequenceNumber: e};
      expect(bySeq[1]!.previousEventHash, isNull);
      expect(bySeq[2]!.previousEventHash, equals(bySeq[1]!.eventHash));
      expect(await repo.verifyIntegrity(), isTrue);
    });
  });
}

/// Delegating spy: forwards every StorageBackend call to its delegate while
/// recording the count of invocations on each method. Used in the
/// delegation tests to confirm EventRepository routes through the backend
/// rather than touching Sembast directly.
class _SpyBackend extends StorageBackend {
  _SpyBackend({required this.delegate});
  final StorageBackend delegate;

  int transactionCalls = 0;
  int appendEventCalls = 0;
  int findEventsForAggregateCalls = 0;
  int findAllEventsCalls = 0;
  int findAllEventsInTxnCalls = 0;
  int nextSequenceNumberCalls = 0;
  int readSequenceCounterCalls = 0;
  int readLatestEventHashCalls = 0;

  @override
  Future<T> transaction<T>(Future<T> Function(Txn txn) body) {
    transactionCalls += 1;
    return delegate.transaction(body);
  }

  @override
  Future<AppendResult> appendEvent(Txn txn, StoredEvent event) {
    appendEventCalls += 1;
    return delegate.appendEvent(txn, event);
  }

  @override
  Future<List<StoredEvent>> findEventsForAggregate(String aggregateId) {
    findEventsForAggregateCalls += 1;
    return delegate.findEventsForAggregate(aggregateId);
  }

  @override
  Future<List<StoredEvent>> findEventsForAggregateInTxn(
    Txn txn,
    String aggregateId,
  ) => delegate.findEventsForAggregateInTxn(txn, aggregateId);

  @override
  Future<List<StoredEvent>> findAllEvents({int? afterSequence, int? limit}) {
    findAllEventsCalls += 1;
    return delegate.findAllEvents(afterSequence: afterSequence, limit: limit);
  }

  @override
  Future<List<StoredEvent>> findAllEventsInTxn(
    Txn txn, {
    int? afterSequence,
    int? limit,
  }) {
    findAllEventsInTxnCalls += 1;
    return delegate.findAllEventsInTxn(
      txn,
      afterSequence: afterSequence,
      limit: limit,
    );
  }

  @override
  Future<int> nextSequenceNumber(Txn txn) {
    nextSequenceNumberCalls += 1;
    return delegate.nextSequenceNumber(txn);
  }

  @override
  Future<String?> readLatestEventHash(Txn txn) {
    readLatestEventHashCalls += 1;
    return delegate.readLatestEventHash(txn);
  }

  @override
  Future<int> readSequenceCounter() {
    readSequenceCounterCalls += 1;
    return delegate.readSequenceCounter();
  }

  @override
  Future<int> readSchemaVersion() => delegate.readSchemaVersion();
  @override
  Future<void> writeSchemaVersion(Txn txn, int version) =>
      delegate.writeSchemaVersion(txn, version);
  @override
  Future<void> upsertEntry(Txn txn, DiaryEntry entry) =>
      delegate.upsertEntry(txn, entry);
  @override
  Future<void> clearEntries(Txn txn) => delegate.clearEntries(txn);
  @override
  Future<List<DiaryEntry>> findEntries({
    String? entryType,
    bool? isComplete,
    bool? isDeleted,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => delegate.findEntries(
    entryType: entryType,
    isComplete: isComplete,
    isDeleted: isDeleted,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );
  @override
  Future<DiaryEntry?> readEntryInTxn(Txn txn, String entryId) =>
      delegate.readEntryInTxn(txn, entryId);
  @override
  Future<Map<String, dynamic>?> readViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
  ) => delegate.readViewRowInTxn(txn, viewName, key);
  @override
  Future<void> upsertViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
    Map<String, dynamic> row,
  ) => delegate.upsertViewRowInTxn(txn, viewName, key, row);
  @override
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key) =>
      delegate.deleteViewRowInTxn(txn, viewName, key);
  @override
  Future<List<Map<String, dynamic>>> findViewRows(
    String viewName, {
    int? limit,
    int? offset,
  }) => delegate.findViewRows(viewName, limit: limit, offset: offset);
  @override
  Future<void> clearViewInTxn(Txn txn, String viewName) =>
      delegate.clearViewInTxn(txn, viewName);
  @override
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  ) => delegate.enqueueFifo(destinationId, batch, wirePayload);
  @override
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch,
    WirePayload wirePayload,
  ) => delegate.enqueueFifoTxn(txn, destinationId, batch, wirePayload);
  @override
  Future<FifoEntry?> readFifoHead(String destinationId) =>
      delegate.readFifoHead(destinationId);
  @override
  Future<void> appendAttempt(
    String destinationId,
    String entryId,
    AttemptResult attempt,
  ) => delegate.appendAttempt(destinationId, entryId, attempt);
  @override
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  ) => delegate.markFinal(destinationId, entryId, status);
  @override
  Future<bool> anyFifoExhausted() => delegate.anyFifoExhausted();
  @override
  Future<List<WedgedFifoSummary>> wedgedFifos() => delegate.wedgedFifos();
  @override
  Future<int> readFillCursor(String destinationId) =>
      delegate.readFillCursor(destinationId);
  @override
  Future<void> writeFillCursor(String destinationId, int sequenceNumber) =>
      delegate.writeFillCursor(destinationId, sequenceNumber);
  @override
  Future<void> writeFillCursorTxn(
    Txn txn,
    String destinationId,
    int sequenceNumber,
  ) => delegate.writeFillCursorTxn(txn, destinationId, sequenceNumber);
  @override
  Future<DestinationSchedule?> readSchedule(String destinationId) =>
      delegate.readSchedule(destinationId);
  @override
  Future<void> writeSchedule(
    String destinationId,
    DestinationSchedule schedule,
  ) => delegate.writeSchedule(destinationId, schedule);
  @override
  Future<void> writeScheduleTxn(
    Txn txn,
    String destinationId,
    DestinationSchedule schedule,
  ) => delegate.writeScheduleTxn(txn, destinationId, schedule);
  @override
  Future<void> deleteScheduleTxn(Txn txn, String destinationId) =>
      delegate.deleteScheduleTxn(txn, destinationId);
  @override
  Future<void> deleteFifoStoreTxn(Txn txn, String destinationId) =>
      delegate.deleteFifoStoreTxn(txn, destinationId);
  @override
  Future<FifoEntry?> readFifoRow(String destinationId, String entryId) =>
      delegate.readFifoRow(destinationId, entryId);
  @override
  Future<void> setFinalStatusTxn(
    Txn txn,
    String destinationId,
    String entryId,
    FinalStatus? status,
  ) => delegate.setFinalStatusTxn(txn, destinationId, entryId, status);
  @override
  Future<int> deleteNullRowsAfterSequenceInQueueTxn(
    Txn txn,
    String destinationId,
    int afterSequenceInQueue,
  ) => delegate.deleteNullRowsAfterSequenceInQueueTxn(
    txn,
    destinationId,
    afterSequenceInQueue,
  );
}

/// Test database provider that uses in-memory Sembast database.
class _TestDatabaseProvider extends DatabaseProvider {
  _TestDatabaseProvider()
    : _dbName = 'test_${DateTime.now().microsecondsSinceEpoch}.db',
      super(
        config: DatastoreConfig.development(
          deviceId: 'test-device',
          userId: 'test-user',
        ),
      );

  final String _dbName;
  Database? _testDatabase;

  @override
  Database get database {
    if (_testDatabase == null) {
      throw StateError('Test database not initialized');
    }
    return _testDatabase!;
  }

  @override
  bool get isInitialized => _testDatabase != null;

  @override
  Future<void> initialize() async {
    // Use unique name for each test to ensure isolation
    _testDatabase = await databaseFactoryMemory.openDatabase(_dbName);
  }

  @override
  Future<void> close() async {
    if (_testDatabase != null) {
      await _testDatabase!.close();
      // Delete the database to clean up
      await databaseFactoryMemory.deleteDatabase(_dbName);
      _testDatabase = null;
    }
  }

  @override
  Future<void> deleteDatabase() async {
    await close();
  }
}
