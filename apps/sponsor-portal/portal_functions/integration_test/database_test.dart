// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00024: Portal User Roles and Permissions
//
// Integration tests for database operations (portal staff)
// Requires PostgreSQL database to be running

@TestOn('vm')
library;

import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  late DatabaseConfig config;

  setUpAll(() async {
    // Get database configuration from environment
    // For local dev, default to no SSL (docker container doesn't support it)
    final sslEnv = Platform.environment['DB_SSL'];
    final useSsl = sslEnv == 'true';

    config = DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          'postgres',
      useSsl: useSsl,
    );

    await Database.instance.initialize(config);
  });

  tearDownAll(() async {
    await Database.instance.close();
  });

  group('Database Connection', () {
    test('can execute simple query', () async {
      final result = await Database.instance.execute('SELECT 1 as num');

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(1));
    });

    test('can execute query with named parameters', () async {
      final result = await Database.instance.execute(
        'SELECT @value::int as num',
        parameters: {'value': 42},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(42));
    });

    test('can execute query with multiple parameters', () async {
      final result = await Database.instance.execute(
        'SELECT @a::int + @b::int as sum',
        parameters: {'a': 10, 'b': 20},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(30));
    });

    test('handles null parameters', () async {
      final result = await Database.instance.execute(
        'SELECT @value::text as val',
        parameters: {'value': null},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], isNull);
    });

    test('handles string parameters with special characters', () async {
      const testString = "Test's \"special\" <chars> & more";
      final result = await Database.instance.execute(
        'SELECT @value::text as val',
        parameters: {'value': testString},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testString));
    });
  });

  group('Database Schema Verification', () {
    test('app_users table exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'app_users'
        ) as exists
        ''');

      expect(result.first[0], isTrue);
    });

    test('patient_linking_codes table exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'patient_linking_codes'
        ) as exists
        ''');

      expect(result.first[0], isTrue);
    });

    test('record_audit table exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'record_audit'
        ) as exists
        ''');

      expect(result.first[0], isTrue);
    });

    test('record_state table exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'record_state'
        ) as exists
        ''');

      expect(result.first[0], isTrue);
    });

    test('sites table exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'sites'
        ) as exists
        ''');

      expect(result.first[0], isTrue);
    });
  });

  group('Portal Users CRUD Operations', () {
    // Use a time-based but truncated UUID to ensure it's always valid (12 digits max)
    final timestamp = (DateTime.now().millisecondsSinceEpoch % 1000000000000)
        .toString()
        .padLeft(12, '0');
    final testUserId = '99990000-0000-0000-0000-$timestamp';
    final testEmail =
        'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
    const testName = 'Test User';

    test('can insert portal_user', () async {
      await Database.instance.execute(
        '''
        INSERT INTO portal_users (id, email, name, status)
        VALUES (@userId::uuid, @email, @name, 'pending')
        ''',
        parameters: {
          'userId': testUserId,
          'email': testEmail,
          'name': testName,
        },
      );

      // Verify insert
      final result = await Database.instance.execute(
        'SELECT id, email, name FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': testUserId},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[1], equals(testEmail));
      expect(result.first[2], equals(testName));
    });

    test('can query portal_user by email', () async {
      final result = await Database.instance.execute(
        'SELECT id, name, status FROM portal_users WHERE email = @email',
        parameters: {'email': testEmail},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testUserId));
      expect(result.first[2], equals('pending'));
    });

    test('can update portal_user status', () async {
      await Database.instance.execute(
        '''
        UPDATE portal_users
        SET status = 'active', updated_at = now()
        WHERE id = @userId::uuid
        ''',
        parameters: {'userId': testUserId},
      );

      final result = await Database.instance.execute(
        'SELECT status FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': testUserId},
      );

      expect(result.first[0], equals('active'));
    });

    test('email uniqueness is enforced', () async {
      expect(
        () => Database.instance.execute(
          '''
          INSERT INTO portal_users (email, name, status)
          VALUES (@email, @name, 'pending')
          ''',
          parameters: {
            'email': testEmail, // Same email
            'name': 'Another User',
          },
        ),
        throwsA(anything), // Should throw due to unique constraint
      );
    });

    test('cleanup: delete test user', () async {
      await Database.instance.execute(
        'DELETE FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': testUserId},
      );

      final result = await Database.instance.execute(
        'SELECT id FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': testUserId},
      );

      expect(result.isEmpty, isTrue);
    });
  });

  group('SQL Injection Protection', () {
    test('parameterized queries prevent injection in SELECT', () async {
      // Attempt SQL injection via email parameter
      const maliciousInput = "'; DROP TABLE portal_users; --";

      final result = await Database.instance.execute(
        'SELECT id FROM portal_users WHERE email = @email',
        parameters: {'email': maliciousInput},
      );

      // Should return empty result, not drop the table
      expect(result.isEmpty, isTrue);

      // Verify table still exists
      final tableCheck = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'portal_users'
        )
        ''');
      expect(tableCheck.first[0], isTrue);
    });

    test('parameterized queries handle UNION injection attempts', () async {
      const maliciousInput = "' UNION SELECT firebase_uid FROM portal_users --";

      final result = await Database.instance.execute(
        'SELECT id FROM portal_users WHERE email = @email',
        parameters: {'email': maliciousInput},
      );

      // Should return empty result, not leaked data
      expect(result.isEmpty, isTrue);
    });

    test('parameterized queries handle OR injection attempts', () async {
      const maliciousInput = "' OR '1'='1";

      final result = await Database.instance.execute(
        'SELECT id FROM portal_users WHERE email = @email',
        parameters: {'email': maliciousInput},
      );

      // Should return empty (no user with that literal email), not all users
      expect(result.isEmpty, isTrue);
    });
  });
}
