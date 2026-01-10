// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00008: User Account Management
//
// Integration tests for database operations
// Requires PostgreSQL database to be running

@TestOn('vm')
library;

import 'dart:io';

import 'package:diary_functions/diary_functions.dart';
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

    test('study_enrollments table exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = 'study_enrollments'
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

  group('App Users CRUD Operations', () {
    final testUserId = 'test-${DateTime.now().millisecondsSinceEpoch}';
    final testUsername = 'testuser_${DateTime.now().millisecondsSinceEpoch}';
    final testAuthCode = generateAuthCode();
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';

    test('can insert app_user', () async {
      await Database.instance.execute(
        '''
        INSERT INTO app_users (user_id, username, password_hash, auth_code, app_uuid)
        VALUES (@userId, @username, @passwordHash, @authCode, @appUuid)
        ''',
        parameters: {
          'userId': testUserId,
          'username': testUsername,
          'passwordHash': testPasswordHash,
          'authCode': testAuthCode,
          'appUuid': 'test-app-uuid',
        },
      );

      // Verify insert
      final result = await Database.instance.execute(
        'SELECT user_id, username FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testUserId));
      expect(result.first[1], equals(testUsername));
    });

    test('can query app_user by username', () async {
      final result = await Database.instance.execute(
        'SELECT user_id, auth_code FROM app_users WHERE username = @username',
        parameters: {'username': testUsername},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testUserId));
      expect(result.first[1], equals(testAuthCode));
    });

    test('can query app_user by auth_code', () async {
      final result = await Database.instance.execute(
        'SELECT user_id, username FROM app_users WHERE auth_code = @authCode',
        parameters: {'authCode': testAuthCode},
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testUserId));
    });

    test('can update app_user password', () async {
      const newPasswordHash =
          '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b';

      await Database.instance.execute(
        '''
        UPDATE app_users
        SET password_hash = @newPasswordHash, updated_at = now()
        WHERE user_id = @userId
        ''',
        parameters: {'userId': testUserId, 'newPasswordHash': newPasswordHash},
      );

      // Verify update
      final result = await Database.instance.execute(
        'SELECT password_hash FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );

      expect(result.first[0], equals(newPasswordHash));
    });

    test('can update last_active_at', () async {
      await Database.instance.execute(
        'UPDATE app_users SET last_active_at = now() WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );

      final result = await Database.instance.execute(
        'SELECT last_active_at FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );

      expect(result.first[0], isNotNull);
    });

    test('username uniqueness is enforced', () async {
      expect(
        () => Database.instance.execute(
          '''
          INSERT INTO app_users (user_id, username, auth_code)
          VALUES (@userId, @username, @authCode)
          ''',
          parameters: {
            'userId': 'another-id',
            'username': testUsername, // Same username
            'authCode': generateAuthCode(),
          },
        ),
        throwsA(anything), // Should throw due to unique constraint
      );
    });

    test('auth_code uniqueness is enforced', () async {
      expect(
        () => Database.instance.execute(
          '''
          INSERT INTO app_users (user_id, username, auth_code)
          VALUES (@userId, @username, @authCode)
          ''',
          parameters: {
            'userId': 'another-id-2',
            'username': 'different_username',
            'authCode': testAuthCode, // Same auth_code
          },
        ),
        throwsA(anything), // Should throw due to unique constraint
      );
    });

    test('cleanup: delete test user', () async {
      await Database.instance.execute(
        'DELETE FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );

      final result = await Database.instance.execute(
        'SELECT user_id FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );

      expect(result.isEmpty, isTrue);
    });
  });

  group('SQL Injection Protection', () {
    test('parameterized queries prevent injection in SELECT', () async {
      // Attempt SQL injection via username parameter
      const maliciousInput = "'; DROP TABLE app_users; --";

      final result = await Database.instance.execute(
        'SELECT user_id FROM app_users WHERE username = @username',
        parameters: {'username': maliciousInput},
      );

      // Should return empty result, not drop the table
      expect(result.isEmpty, isTrue);

      // Verify table still exists
      final tableCheck = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'app_users'
        )
        ''');
      expect(tableCheck.first[0], isTrue);
    });

    test('parameterized queries handle UNION injection attempts', () async {
      const maliciousInput = "' UNION SELECT password_hash FROM app_users --";

      final result = await Database.instance.execute(
        'SELECT user_id FROM app_users WHERE username = @username',
        parameters: {'username': maliciousInput},
      );

      // Should return empty result, not leaked data
      expect(result.isEmpty, isTrue);
    });

    test('parameterized queries handle OR injection attempts', () async {
      const maliciousInput = "' OR '1'='1";

      final result = await Database.instance.execute(
        'SELECT user_id FROM app_users WHERE username = @username',
        parameters: {'username': maliciousInput},
      );

      // Should return empty (no user with that literal username), not all users
      expect(result.isEmpty, isTrue);
    });
  });
}
