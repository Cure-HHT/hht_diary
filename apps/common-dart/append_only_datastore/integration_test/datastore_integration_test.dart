// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation
//
// Integration tests for Datastore singleton.
// These tests require Flutter bindings (path_provider) and must be run
// with `flutter test integration_test/` on a device or emulator.

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Datastore integration tests', () {
    tearDown(() async {
      // Clean up after each test
      if (Datastore.isInitialized) {
        await Datastore.instance.reset();
      }
    });

    group('initialize', () {
      testWidgets('initializes datastore with config', (tester) async {
        final datastore = await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(datastore, isNotNull);
        expect(Datastore.isInitialized, isTrue);
        expect(datastore.config.deviceId, equals('test-device'));
        expect(datastore.config.userId, equals('test-user'));
      });

      testWidgets('provides access to repository', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(Datastore.instance.repository, isNotNull);
        expect(Datastore.instance.repository, isA<EventRepository>());
      });

      testWidgets('provides access to databaseProvider', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(Datastore.instance.databaseProvider, isNotNull);
        expect(Datastore.instance.databaseProvider, isA<DatabaseProvider>());
      });

      testWidgets('reinitializes when called multiple times', (tester) async {
        final config1 = DatastoreConfig.development(
          deviceId: 'device-1',
          userId: 'user-1',
        );

        final config2 = DatastoreConfig.development(
          deviceId: 'device-2',
          userId: 'user-2',
        );

        await Datastore.initialize(config: config1);
        expect(Datastore.instance.config.deviceId, equals('device-1'));

        await Datastore.initialize(config: config2);
        expect(Datastore.instance.config.deviceId, equals('device-2'));
      });
    });

    group('instance', () {
      testWidgets('throws StateError when not initialized', (tester) async {
        expect(Datastore.isInitialized, isFalse);
        expect(() => Datastore.instance, throwsStateError);
      });

      testWidgets('returns same instance after initialization', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        final instance1 = Datastore.instance;
        final instance2 = Datastore.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('isInitialized', () {
      testWidgets('returns false before initialization', (tester) async {
        expect(Datastore.isInitialized, isFalse);
      });

      testWidgets('returns true after initialization', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(Datastore.isInitialized, isTrue);
      });

      testWidgets('returns false after reset', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        await Datastore.instance.reset();

        expect(Datastore.isInitialized, isFalse);
      });
    });

    group('reactive signals', () {
      testWidgets('syncStatus starts as idle', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(Datastore.instance.syncStatus.value, equals(SyncStatus.idle));
      });

      testWidgets('queueDepth starts at 0', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        // Give time for async queue depth update
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(Datastore.instance.queueDepth.value, equals(0));
      });

      testWidgets('lastSyncTime starts as null', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(Datastore.instance.lastSyncTime.value, isNull);
      });
    });

    group('reset', () {
      testWidgets('resets all signals to initial values', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        // Modify signals
        Datastore.instance.syncStatus.value = SyncStatus.syncing;
        Datastore.instance.queueDepth.value = 10;
        Datastore.instance.lastSyncTime.value = DateTime.now();

        await Datastore.instance.reset();

        // Reinitialize to check signals
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        expect(Datastore.instance.syncStatus.value, equals(SyncStatus.idle));
        expect(Datastore.instance.lastSyncTime.value, isNull);
      });
    });

    group('end-to-end', () {
      testWidgets('can append and query events', (tester) async {
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: 'test-device',
            userId: 'test-user',
          ),
        );

        // Append an event
        final event = await Datastore.instance.repository.append(
          aggregateId: 'diary-entry-1',
          eventType: 'NosebleedRecorded',
          data: {'severity': 'mild', 'duration': 10},
          userId: 'test-user',
          deviceId: 'test-device',
        );

        expect(event.eventId, isNotEmpty);
        expect(event.eventHash, isNotEmpty);

        // Query events
        final events = await Datastore.instance.repository.getAllEvents();
        expect(events, hasLength(1));
        expect(events.first.eventId, equals(event.eventId));

        // Verify integrity
        final isValid = await Datastore.instance.repository.verifyIntegrity();
        expect(isValid, isTrue);
      });
    });
  });
}
