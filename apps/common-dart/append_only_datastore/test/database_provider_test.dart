// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('DatabaseProvider', () {
    late _TestDatabaseProvider provider;

    setUp(() {
      provider = _TestDatabaseProvider();
    });

    tearDown(() async {
      if (provider.isInitialized) {
        await provider.close();
      }
    });

    group('initialization', () {
      test('isInitialized returns false before initialize', () {
        expect(provider.isInitialized, isFalse);
      });

      test('isInitialized returns true after initialize', () async {
        await provider.initialize();
        expect(provider.isInitialized, isTrue);
      });

      test('initialize creates database', () async {
        await provider.initialize();
        expect(provider.database, isNotNull);
        expect(provider.database, isA<Database>());
      });

      test('initialize is idempotent', () async {
        await provider.initialize();
        final db1 = provider.database;

        await provider.initialize();
        final db2 = provider.database;

        expect(identical(db1, db2), isTrue);
      });
    });

    group('database getter', () {
      test('throws StateError when not initialized', () {
        expect(
          () => provider.database,
          throwsStateError,
        );
      });

      test('returns database after initialization', () async {
        await provider.initialize();
        expect(provider.database, isNotNull);
      });
    });

    group('close', () {
      test('closes database connection', () async {
        await provider.initialize();
        expect(provider.isInitialized, isTrue);

        await provider.close();
        expect(provider.isInitialized, isFalse);
      });

      test('can be called multiple times safely', () async {
        await provider.initialize();

        await provider.close();
        await provider.close();
        await provider.close();

        expect(provider.isInitialized, isFalse);
      });

      test('can reinitialize after close', () async {
        await provider.initialize();
        await provider.close();

        await provider.initialize();
        expect(provider.isInitialized, isTrue);
      });
    });

    group('deleteDatabase', () {
      test('deletes database and closes connection', () async {
        await provider.initialize();
        expect(provider.isInitialized, isTrue);

        await provider.deleteDatabase();
        expect(provider.isInitialized, isFalse);
      });

      test('can reinitialize after delete', () async {
        await provider.initialize();
        await provider.deleteDatabase();

        await provider.initialize();
        expect(provider.isInitialized, isTrue);
      });
    });

    group('config', () {
      test('provides access to configuration', () {
        expect(provider.config, isNotNull);
        expect(provider.config.deviceId, equals('test-device'));
      });
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
    if (_testDatabase != null) {
      return; // Already initialized
    }
    _testDatabase = await databaseFactoryMemory.openDatabase(_dbName);
  }

  @override
  Future<void> close() async {
    if (_testDatabase != null) {
      await _testDatabase!.close();
      _testDatabase = null;
    }
  }

  @override
  Future<void> deleteDatabase() async {
    await close();
    await databaseFactoryMemory.deleteDatabase(_dbName);
  }
}
