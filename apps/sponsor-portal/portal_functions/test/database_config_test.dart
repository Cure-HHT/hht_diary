// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Unit tests for database configuration

import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseConfig', () {
    test('constructor sets all properties', () {
      final config = DatabaseConfig(
        host: 'db.example.com',
        port: 5433,
        database: 'test_db',
        username: 'test_user',
        password: 'test_pass',
        useSsl: true,
      );

      expect(config.host, equals('db.example.com'));
      expect(config.port, equals(5433));
      expect(config.database, equals('test_db'));
      expect(config.username, equals('test_user'));
      expect(config.password, equals('test_pass'));
      expect(config.useSsl, isTrue);
    });

    test('useSsl defaults to true', () {
      final config = DatabaseConfig(
        host: 'localhost',
        port: 5432,
        database: 'test',
        username: 'user',
        password: 'pass',
      );

      expect(config.useSsl, isTrue);
    });

    test('useSsl can be set to false', () {
      final config = DatabaseConfig(
        host: 'localhost',
        port: 5432,
        database: 'test',
        username: 'user',
        password: 'pass',
        useSsl: false,
      );

      expect(config.useSsl, isFalse);
    });
  });

  group('Database Singleton', () {
    tearDown(() async {
      // Reset database state after each test
      await Database.instance.close();
    });

    test('instance returns same object', () {
      final db1 = Database.instance;
      final db2 = Database.instance;

      expect(identical(db1, db2), isTrue);
    });

    test('execute throws before initialization', () {
      expect(
        () => Database.instance.execute('SELECT 1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
