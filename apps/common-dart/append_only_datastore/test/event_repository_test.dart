// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
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
          eventType: 'TestEvent',
          data: {'key': 'value'},
          userId: 'user-456',
          deviceId: 'device-789',
        );

        expect(event.eventId, isNotEmpty);
        expect(event.aggregateId, equals('aggregate-123'));
        expect(event.eventType, equals('TestEvent'));
        expect(event.data, equals({'key': 'value'}));
        expect(event.userId, equals('user-456'));
        expect(event.deviceId, equals('device-789'));
        expect(event.sequenceNumber, equals(1));
        expect(event.eventHash, isNotEmpty);
        expect(event.previousEventHash, isNull);
        expect(event.syncedAt, isNull);
      });

      test('assigns sequential sequence numbers', () async {
        final event1 = await repository.append(
          aggregateId: 'aggregate-1',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final event2 = await repository.append(
          aggregateId: 'aggregate-2',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final event3 = await repository.append(
          aggregateId: 'aggregate-1',
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
          eventType: 'Event1',
          data: {'seq': 1},
          userId: 'user',
          deviceId: 'device',
        );

        final event2 = await repository.append(
          aggregateId: 'aggregate-1',
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
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
          clientTimestamp: clientTime,
        );

        expect(event.clientTimestamp, equals(clientTime.toUtc()));
      });
    });

    group('getEventsForAggregate', () {
      test('returns events for specific aggregate', () async {
        await repository.append(
          aggregateId: 'aggregate-A',
          eventType: 'Event1',
          data: {'id': 'A1'},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-B',
          eventType: 'Event2',
          data: {'id': 'B1'},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
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
          eventType: 'Event1',
          data: {'order': 1},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
          eventType: 'Event2',
          data: {'order': 2},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
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
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-2',
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
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-2',
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
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        final event2 = await repository.append(
          aggregateId: 'aggregate-2',
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
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(await repository.getUnsyncedCount(), equals(1));

        final event2 = await repository.append(
          aggregateId: 'aggregate-2',
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
          eventType: 'Event1',
          data: {'seq': 1},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-1',
          eventType: 'Event2',
          data: {'seq': 2},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-1',
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
    });

    group('getAllEvents', () {
      test('returns all events in sequence order', () async {
        await repository.append(
          aggregateId: 'aggregate-A',
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-B',
          eventType: 'Event2',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        await repository.append(
          aggregateId: 'aggregate-A',
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
          eventType: 'Event1',
          data: {},
          userId: 'user',
          deviceId: 'device',
        );

        expect(await repository.getLatestSequenceNumber(), equals(1));

        await repository.append(
          aggregateId: 'aggregate-2',
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
        eventType: 'NosebleedRecorded',
        sequenceNumber: 42,
        data: {'severity': 'mild', 'duration': 10},
        metadata: {'source': 'mobile'},
        userId: 'user-789',
        deviceId: 'device-abc',
        clientTimestamp: DateTime.utc(2024, 1, 15, 10, 30),
        serverTimestamp: DateTime.utc(2024, 1, 15, 10, 30, 5),
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
      expect(restored.userId, equals(original.userId));
      expect(restored.deviceId, equals(original.deviceId));
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
        eventType: 'Test',
        sequenceNumber: 1,
        data: {},
        metadata: {},
        userId: 'user',
        deviceId: 'device',
        clientTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        eventHash: 'hash',
        syncedAt: null,
      );

      final synced = StoredEvent(
        key: 2,
        eventId: 'event-2',
        aggregateId: 'agg-1',
        aggregateType: 'Test',
        eventType: 'Test',
        sequenceNumber: 2,
        data: {},
        metadata: {},
        userId: 'user',
        deviceId: 'device',
        clientTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        eventHash: 'hash2',
        syncedAt: DateTime.now(),
      );

      expect(unsynced.isSynced, isFalse);
      expect(synced.isSynced, isTrue);
    });
  });
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
