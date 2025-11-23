import 'package:flutter_test/flutter_test.dart';
import 'package:append_only_datastore/append_only_datastore.dart';

void main() {
  group('DatastoreConfig', () {
    test('creates production config with required fields', () {
      final config = DatastoreConfig.production(
        deviceId: 'test-device-123',
        userId: 'test-user-456',
        syncServerUrl: 'https://api.example.com',
        encryptionKey: 'test-key-789',
      );

      expect(config.deviceId, equals('test-device-123'));
      expect(config.userId, equals('test-user-456'));
      expect(config.syncServerUrl, equals('https://api.example.com'));
      expect(config.enableEncryption, isTrue);
      expect(config.encryptionKey, equals('test-key-789'));
    });

    test('creates development config with defaults', () {
      final config = DatastoreConfig.development(
        deviceId: 'dev-device-123',
        userId: 'dev-user-456',
      );

      expect(config.deviceId, equals('dev-device-123'));
      expect(config.userId, equals('dev-user-456'));
      expect(config.databaseName, contains('dev'));
      expect(config.enableTelemetry, isTrue);
    });

    test('enables encryption when encryption key provided', () {
      final config = DatastoreConfig.development(
        deviceId: 'test-device',
        encryptionKey: 'test-key',
      );

      expect(config.enableEncryption, isTrue);
      expect(config.encryptionKey, equals('test-key'));
    });

    test('copyWith creates new instance with updated values', () {
      final original = DatastoreConfig.development(deviceId: 'device-1');

      final updated = original.copyWith(
        deviceId: 'device-2',
        userId: 'user-123',
      );

      expect(updated.deviceId, equals('device-2'));
      expect(updated.userId, equals('user-123'));
      expect(original.deviceId, equals('device-1')); // Original unchanged
    });
  });

  group('DatastoreException', () {
    test('DatabaseException contains message', () {
      final exception = DatabaseException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.toString(), contains('DatabaseException'));
      expect(exception.toString(), contains('Test error'));
    });

    test('SignatureException indicates security alert', () {
      final exception = SignatureException(
        'Invalid signature',
        eventId: 'event-123',
      );

      expect(exception.message, equals('Invalid signature'));
      expect(exception.eventId, equals('event-123'));
      expect(exception.toString(), contains('🚨 SECURITY ALERT'));
    });
  });

  group('SyncStatus', () {
    test('has correct message for each status', () {
      expect(SyncStatus.idle.message, equals('Ready to sync'));
      expect(SyncStatus.syncing.message, equals('Syncing...'));
      expect(SyncStatus.synced.message, equals('All changes synced'));
      expect(SyncStatus.error.message, equals('Sync failed'));
    });

    test('isActive returns true only for syncing', () {
      expect(SyncStatus.idle.isActive, isFalse);
      expect(SyncStatus.syncing.isActive, isTrue);
      expect(SyncStatus.synced.isActive, isFalse);
      expect(SyncStatus.error.isActive, isFalse);
    });

    test('hasError returns true only for error', () {
      expect(SyncStatus.idle.hasError, isFalse);
      expect(SyncStatus.syncing.hasError, isFalse);
      expect(SyncStatus.synced.hasError, isFalse);
      expect(SyncStatus.error.hasError, isTrue);
    });
  });
}
