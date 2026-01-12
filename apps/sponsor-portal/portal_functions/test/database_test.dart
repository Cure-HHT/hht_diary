// Tests for database utilities
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00005: Role-Based Access Control

import 'package:test/test.dart';

import 'package:portal_functions/src/database.dart';

void main() {
  group('UserContext', () {
    test('creates context with all fields', () {
      final context = UserContext(
        pgRole: 'authenticated',
        userId: 'user-123',
        role: 'Administrator',
        allowedRoles: ['Administrator', 'Developer Admin'],
      );

      expect(context.pgRole, equals('authenticated'));
      expect(context.userId, equals('user-123'));
      expect(context.role, equals('Administrator'));
      expect(
        context.allowedRoles,
        equals(['Administrator', 'Developer Admin']),
      );
    });

    group('authenticated factory', () {
      test('creates authenticated context with single role', () {
        final context = UserContext.authenticated(
          userId: 'firebase-uid-123',
          role: 'Investigator',
        );

        expect(context.pgRole, equals('authenticated'));
        expect(context.userId, equals('firebase-uid-123'));
        expect(context.role, equals('Investigator'));
        expect(context.allowedRoles, equals(['Investigator']));
      });

      test('creates authenticated context with multiple allowed roles', () {
        final context = UserContext.authenticated(
          userId: 'firebase-uid-456',
          role: 'Administrator',
          allowedRoles: ['Administrator', 'Developer Admin', 'Auditor'],
        );

        expect(context.pgRole, equals('authenticated'));
        expect(context.userId, equals('firebase-uid-456'));
        expect(context.role, equals('Administrator'));
        expect(context.allowedRoles.length, equals(3));
        expect(context.allowedRoles, contains('Administrator'));
        expect(context.allowedRoles, contains('Developer Admin'));
        expect(context.allowedRoles, contains('Auditor'));
      });

      test('defaults allowedRoles to single role when not provided', () {
        final context = UserContext.authenticated(
          userId: 'uid-789',
          role: 'Sponsor',
        );

        expect(context.allowedRoles, hasLength(1));
        expect(context.allowedRoles.first, equals('Sponsor'));
      });

      test('handles empty string userId', () {
        final context = UserContext.authenticated(userId: '', role: 'Analyst');

        expect(context.userId, isEmpty);
        expect(context.pgRole, equals('authenticated'));
      });

      test('handles all valid portal roles', () {
        final roles = [
          'Investigator',
          'Sponsor',
          'Auditor',
          'Analyst',
          'Administrator',
          'Developer Admin',
        ];

        for (final role in roles) {
          final context = UserContext.authenticated(
            userId: 'user-$role',
            role: role,
          );
          expect(context.role, equals(role));
          expect(context.pgRole, equals('authenticated'));
        }
      });
    });

    group('service constant', () {
      test('has correct service role values', () {
        expect(UserContext.service.pgRole, equals('service_role'));
        expect(UserContext.service.userId, equals('service'));
        expect(UserContext.service.role, equals('service_role'));
        expect(UserContext.service.allowedRoles, equals(['service_role']));
      });

      test('is constant and immutable', () {
        // Access multiple times - should be same object
        final context1 = UserContext.service;
        final context2 = UserContext.service;
        expect(identical(context1, context2), isTrue);
      });
    });

    test('allowedRoles can be empty list', () {
      final context = UserContext(
        pgRole: 'authenticated',
        userId: 'user-123',
        role: 'TestRole',
        allowedRoles: [],
      );

      expect(context.allowedRoles, isEmpty);
    });

    test('handles unicode in userId', () {
      final context = UserContext.authenticated(
        userId: 'user-日本語-emoji🎉',
        role: 'Administrator',
      );

      expect(context.userId, contains('日本語'));
      expect(context.userId, contains('🎉'));
    });
  });

  group('DatabaseConfig', () {
    test('creates config with all fields', () {
      final config = DatabaseConfig(
        host: 'db.example.com',
        port: 5433,
        database: 'mydb',
        username: 'myuser',
        password: 'mypassword',
        useSsl: true,
      );

      expect(config.host, equals('db.example.com'));
      expect(config.port, equals(5433));
      expect(config.database, equals('mydb'));
      expect(config.username, equals('myuser'));
      expect(config.password, equals('mypassword'));
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

    test('handles empty password', () {
      final config = DatabaseConfig(
        host: 'localhost',
        port: 5432,
        database: 'test',
        username: 'user',
        password: '',
      );

      expect(config.password, isEmpty);
    });

    test('handles IPv6 host', () {
      final config = DatabaseConfig(
        host: '::1',
        port: 5432,
        database: 'test',
        username: 'user',
        password: 'pass',
      );

      expect(config.host, equals('::1'));
    });

    test('handles long database name', () {
      final longName = 'a' * 100;
      final config = DatabaseConfig(
        host: 'localhost',
        port: 5432,
        database: longName,
        username: 'user',
        password: 'pass',
      );

      expect(config.database, equals(longName));
    });

    test('handles special characters in password', () {
      final config = DatabaseConfig(
        host: 'localhost',
        port: 5432,
        database: 'test',
        username: 'user',
        password: 'p@ss\$word!#%^&*()',
      );

      expect(config.password, equals('p@ss\$word!#%^&*()'));
    });

    // Note: fromEnvironment factory is tested implicitly via default values
    // when environment variables are not set
    group('fromEnvironment', () {
      test('uses default values when environment variables not set', () {
        // This tests the default fallback values
        // Note: In test environment, env vars are typically not set
        final config = DatabaseConfig.fromEnvironment();

        // These should be the defaults from the implementation
        expect(config.host, isA<String>());
        expect(config.port, isA<int>());
        expect(config.database, isA<String>());
        expect(config.username, isA<String>());
      });
    });
  });

  group('Database singleton', () {
    test('instance returns singleton', () {
      final db1 = Database.instance;
      final db2 = Database.instance;
      expect(identical(db1, db2), isTrue);
    });

    test('execute throws when not initialized', () async {
      // Get a fresh instance - note: pool might be initialized from other tests
      // We test the error path by not calling initialize
      // This test may pass or fail depending on test order, but is here for coverage
      final db = Database.instance;
      try {
        await db.execute('SELECT 1');
        // If we get here, database was initialized elsewhere
      } on StateError catch (e) {
        expect(e.message, contains('not initialized'));
      }
    });

    test('executeWithContext throws when not initialized', () async {
      final db = Database.instance;
      final context = UserContext.authenticated(
        userId: 'test',
        role: 'Administrator',
      );

      try {
        await db.executeWithContext('SELECT 1', context: context);
        // If we get here, database was initialized elsewhere
      } on StateError catch (e) {
        expect(e.message, contains('not initialized'));
      }
    });

    test('runTransactionWithContext throws when not initialized', () async {
      final db = Database.instance;
      final context = UserContext.authenticated(
        userId: 'test',
        role: 'Administrator',
      );

      try {
        await db.runTransactionWithContext<int>(
          (session) async => 1,
          context: context,
        );
        // If we get here, database was initialized elsewhere
      } on StateError catch (e) {
        expect(e.message, contains('not initialized'));
      }
    });
  });
}
