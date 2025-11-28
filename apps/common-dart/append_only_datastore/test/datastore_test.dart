// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation
//
// Unit tests for SyncStatus enum and Datastore static properties.
//
// NOTE: Tests requiring Datastore.initialize() need path_provider which
// uses platform channels. These require integration tests and are located
// in integration_test/datastore_integration_test.dart

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncStatus', () {
    group('message', () {
      test('idle returns "Ready to sync"', () {
        expect(SyncStatus.idle.message, equals('Ready to sync'));
      });

      test('syncing returns "Syncing..."', () {
        expect(SyncStatus.syncing.message, equals('Syncing...'));
      });

      test('synced returns "All changes synced"', () {
        expect(SyncStatus.synced.message, equals('All changes synced'));
      });

      test('error returns "Sync failed"', () {
        expect(SyncStatus.error.message, equals('Sync failed'));
      });
    });

    group('isActive', () {
      test('idle is not active', () {
        expect(SyncStatus.idle.isActive, isFalse);
      });

      test('syncing is active', () {
        expect(SyncStatus.syncing.isActive, isTrue);
      });

      test('synced is not active', () {
        expect(SyncStatus.synced.isActive, isFalse);
      });

      test('error is not active', () {
        expect(SyncStatus.error.isActive, isFalse);
      });
    });

    group('hasError', () {
      test('idle has no error', () {
        expect(SyncStatus.idle.hasError, isFalse);
      });

      test('syncing has no error', () {
        expect(SyncStatus.syncing.hasError, isFalse);
      });

      test('synced has no error', () {
        expect(SyncStatus.synced.hasError, isFalse);
      });

      test('error has error', () {
        expect(SyncStatus.error.hasError, isTrue);
      });
    });

    group('values', () {
      test('contains 4 values', () {
        expect(SyncStatus.values, hasLength(4));
      });

      test('contains expected values', () {
        expect(
          SyncStatus.values,
          containsAll([
            SyncStatus.idle,
            SyncStatus.syncing,
            SyncStatus.synced,
            SyncStatus.error,
          ]),
        );
      });
    });
  });

  group('Datastore static properties (without initialization)', () {
    test('isInitialized is false when not initialized', () {
      expect(Datastore.isInitialized, isFalse);
    });

    test('instance throws StateError when not initialized', () {
      expect(() => Datastore.instance, throwsStateError);
    });
  });
}
