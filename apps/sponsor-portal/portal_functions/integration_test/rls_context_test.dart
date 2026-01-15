// IMPLEMENTS REQUIREMENTS:
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00005: Role-Based Access Control
//   REQ-p00014: Least Privilege Access
//
// Integration tests for RLS (Row-Level Security) context enforcement
// Verifies that database access is properly restricted based on user context
//
// These tests ensure the same security behavior in local dev and production
// since GCP Cloud SQL (unlike Supabase) requires explicit session context setting.

@TestOn('vm')
library;

import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:postgres/postgres.dart' show Sql;
import 'package:test/test.dart';

void main() {
  late DatabaseConfig config;

  // Test user data - created during setup, cleaned up after
  // Use deterministic UUIDs based on test namespace to avoid collisions
  const testAdminId = '00000000-0000-4000-a000-000000000001';
  const testInvestigatorId = '00000000-0000-4000-a000-000000000002';
  const testAdminFirebaseUid = 'firebase-admin-test-uid';
  const testInvestigatorFirebaseUid = 'firebase-investigator-test-uid';
  final testAdminEmail =
      'admin-test-${DateTime.now().millisecondsSinceEpoch}@example.com';
  final testInvestigatorEmail =
      'inv-test-${DateTime.now().millisecondsSinceEpoch}@example.com';

  setUpAll(() async {
    // Get database configuration from environment
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

    // Create test users for RLS tests
    // Use plain execute (postgres superuser) for test setup to bypass RLS
    await Database.instance.execute(
      '''
      INSERT INTO portal_users (id, firebase_uid, email, name, role, status)
      VALUES
        (@adminId::uuid, @adminFirebaseUid, @adminEmail, 'Test Admin', 'Administrator', 'active'),
        (@invId::uuid, @invFirebaseUid, @invEmail, 'Test Investigator', 'Investigator', 'active')
      ON CONFLICT (email) DO UPDATE SET
        firebase_uid = EXCLUDED.firebase_uid,
        name = EXCLUDED.name,
        role = EXCLUDED.role,
        status = EXCLUDED.status
      ''',
      parameters: {
        'adminId': testAdminId,
        'adminFirebaseUid': testAdminFirebaseUid,
        'adminEmail': testAdminEmail,
        'invId': testInvestigatorId,
        'invFirebaseUid': testInvestigatorFirebaseUid,
        'invEmail': testInvestigatorEmail,
      },
    );
  });

  tearDownAll(() async {
    // Clean up test users
    // Use plain execute (postgres superuser) for test cleanup to bypass RLS
    await Database.instance.execute(
      '''
      DELETE FROM portal_users
      WHERE id IN (@adminId::uuid, @invId::uuid)
      ''',
      parameters: {'adminId': testAdminId, 'invId': testInvestigatorId},
    );

    await Database.instance.close();
  });

  group('Session Context Variables', () {
    test('executeWithContext sets app.user_id correctly', () async {
      const testUserId = 'test-context-user-id';

      final result = await Database.instance.executeWithContext(
        "SELECT current_setting('app.user_id', true) as user_id",
        context: UserContext.authenticated(
          userId: testUserId,
          role: 'Administrator',
        ),
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testUserId));
    });

    test('executeWithContext sets app.role correctly', () async {
      const testRole = 'Investigator';

      final result = await Database.instance.executeWithContext(
        "SELECT current_setting('app.role', true) as role",
        context: UserContext.authenticated(userId: 'some-user', role: testRole),
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testRole));
    });

    test('executeWithContext sets app.allowed_roles correctly', () async {
      final allowedRoles = ['Administrator', 'Auditor'];

      final result = await Database.instance.executeWithContext(
        "SELECT current_setting('app.allowed_roles', true) as roles",
        context: UserContext.authenticated(
          userId: 'some-user',
          role: 'Administrator',
          allowedRoles: allowedRoles,
        ),
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals('Administrator,Auditor'));
    });

    test('service context sets service_role', () async {
      final result = await Database.instance.executeWithContext(
        "SELECT current_setting('app.role', true) as role",
        context: UserContext.service,
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals('service_role'));
    });

    test('current_user_id() function returns correct value', () async {
      const testUserId = 'function-test-user-id';

      final result = await Database.instance.executeWithContext(
        "SELECT current_user_id() as user_id",
        context: UserContext.authenticated(
          userId: testUserId,
          role: 'Administrator',
        ),
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testUserId));
    });

    test('current_user_role() function returns correct value', () async {
      const testRole = 'Auditor';

      final result = await Database.instance.executeWithContext(
        "SELECT current_user_role() as role",
        context: UserContext.authenticated(userId: 'some-user', role: testRole),
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(testRole));
    });
  });

  group('Service Context Access', () {
    test('service context can read all portal_users', () async {
      final result = await Database.instance.executeWithContext(
        'SELECT id, email, role::text FROM portal_users',
        context: UserContext.service,
      );

      // Should see at least our test users
      expect(result.length, greaterThanOrEqualTo(2));
    });

    test(
      'service context can update portal_users (firebase_uid linking)',
      () async {
        const newFirebaseUid = 'updated-firebase-uid';

        await Database.instance.executeWithContext(
          '''
        UPDATE portal_users
        SET firebase_uid = @firebaseUid, updated_at = now()
        WHERE id = @userId::uuid
        ''',
          parameters: {'userId': testAdminId, 'firebaseUid': newFirebaseUid},
          context: UserContext.service,
        );

        // Verify update
        final result = await Database.instance.executeWithContext(
          'SELECT firebase_uid FROM portal_users WHERE id = @userId::uuid',
          parameters: {'userId': testAdminId},
          context: UserContext.service,
        );

        expect(result.first[0], equals(newFirebaseUid));

        // Restore original firebase_uid
        await Database.instance.executeWithContext(
          '''
        UPDATE portal_users
        SET firebase_uid = @firebaseUid, updated_at = now()
        WHERE id = @userId::uuid
        ''',
          parameters: {
            'userId': testAdminId,
            'firebaseUid': testAdminFirebaseUid,
          },
          context: UserContext.service,
        );
      },
    );
  });

  group('Authenticated Context - Administrator Role', () {
    test('Administrator can see all portal users via RLS policy', () async {
      final adminContext = UserContext.authenticated(
        userId: testAdminFirebaseUid,
        role: 'Administrator',
      );

      final result = await Database.instance.executeWithContext(
        'SELECT id, email, role::text FROM portal_users',
        context: adminContext,
      );

      // Administrator should see all users (via portal_users_admin_auditor_select policy)
      expect(result.length, greaterThanOrEqualTo(2));
    });

    test('Administrator can create portal users', () async {
      const newUserId = '00000000-0000-4000-a000-000000000099';
      final newEmail =
          'new-user-${DateTime.now().millisecondsSinceEpoch}@example.com';

      // Clean up any leftover test data from previous failed runs
      await Database.instance.execute(
        'DELETE FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': newUserId},
      );

      final adminContext = UserContext.authenticated(
        userId: testAdminFirebaseUid,
        role: 'Administrator',
      );

      await Database.instance.executeWithContext(
        '''
        INSERT INTO portal_users (id, email, name, role, status)
        VALUES (@userId::uuid, @email, 'New Test User', 'Auditor', 'active')
        ''',
        parameters: {'userId': newUserId, 'email': newEmail},
        context: adminContext,
      );

      // Verify creation
      final result = await Database.instance.executeWithContext(
        'SELECT email FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': newUserId},
        context: adminContext,
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], equals(newEmail));

      // Clean up - use plain execute to bypass RLS
      await Database.instance.execute(
        'DELETE FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': newUserId},
      );
    });
  });

  group('Authenticated Context - Investigator Role', () {
    test('Investigator can see their own record via RLS policy', () async {
      final invContext = UserContext.authenticated(
        userId: testInvestigatorFirebaseUid,
        role: 'Investigator',
      );

      final result = await Database.instance.executeWithContext(
        '''
        SELECT id, email, role::text FROM portal_users
        WHERE firebase_uid = @firebaseUid
        ''',
        parameters: {'firebaseUid': testInvestigatorFirebaseUid},
        context: invContext,
      );

      // Should see their own record
      expect(result.length, equals(1));
      expect(result.first[1], equals(testInvestigatorEmail));
    });

    test(
      'Investigator cannot see all portal users (RLS denies access)',
      () async {
        final invContext = UserContext.authenticated(
          userId: testInvestigatorFirebaseUid,
          role: 'Investigator',
        );

        final result = await Database.instance.executeWithContext(
          'SELECT id, email FROM portal_users',
          context: invContext,
        );

        // Investigator should only see their own record (via portal_users_self_select)
        // They do NOT have portal_users_admin_auditor_select policy access
        expect(result.length, equals(1));
        expect(result.first[1], equals(testInvestigatorEmail));
      },
    );

    test('Investigator cannot insert portal users (RLS denies)', () async {
      final invContext = UserContext.authenticated(
        userId: testInvestigatorFirebaseUid,
        role: 'Investigator',
      );

      // This should fail due to RLS policy portal_users_admin_insert
      expect(
        () => Database.instance.executeWithContext('''
          INSERT INTO portal_users (id, email, name, role, status)
          VALUES (gen_random_uuid(), 'unauthorized@example.com', 'Unauthorized', 'Auditor', 'active')
          ''', context: invContext),
        throwsA(anything),
      );
    });
  });

  group('Authenticated Context - Auditor Role', () {
    test('Auditor can see all portal users (read-only access)', () async {
      final auditorContext = UserContext.authenticated(
        userId: 'auditor-firebase-uid',
        role: 'Auditor',
      );

      final result = await Database.instance.executeWithContext(
        'SELECT id, email, role::text FROM portal_users',
        context: auditorContext,
      );

      // Auditor should see all users via portal_users_admin_auditor_select
      expect(result.length, greaterThanOrEqualTo(2));
    });

    test('Auditor cannot insert portal users (RLS denies)', () async {
      final auditorContext = UserContext.authenticated(
        userId: 'auditor-firebase-uid',
        role: 'Auditor',
      );

      expect(
        () => Database.instance.executeWithContext('''
          INSERT INTO portal_users (id, email, name, role, status)
          VALUES (gen_random_uuid(), 'audit-attempt@example.com', 'Audit Attempt', 'Investigator', 'active')
          ''', context: auditorContext),
        throwsA(anything),
      );
    });
  });

  group('Context Isolation Between Queries', () {
    test('context does not leak between executeWithContext calls', () async {
      // First query with admin context
      final adminResult = await Database.instance.executeWithContext(
        "SELECT current_user_role() as role",
        context: UserContext.authenticated(
          userId: 'admin-user',
          role: 'Administrator',
        ),
      );
      expect(adminResult.first[0], equals('Administrator'));

      // Second query with investigator context
      final invResult = await Database.instance.executeWithContext(
        "SELECT current_user_role() as role",
        context: UserContext.authenticated(
          userId: 'inv-user',
          role: 'Investigator',
        ),
      );
      expect(invResult.first[0], equals('Investigator'));

      // Third query with service context
      final serviceResult = await Database.instance.executeWithContext(
        "SELECT current_user_role() as role",
        context: UserContext.service,
      );
      expect(serviceResult.first[0], equals('service_role'));
    });

    test('plain execute() does not have user context set', () async {
      // First set context via executeWithContext
      await Database.instance.executeWithContext(
        "SELECT 1",
        context: UserContext.authenticated(
          userId: 'some-user',
          role: 'Administrator',
        ),
      );

      // Then use plain execute() - context should NOT persist
      final result = await Database.instance.execute(
        "SELECT current_setting('app.role', true) as role",
      );

      // Should be empty/null since no context was set for this query
      expect(result.first[0], anyOf(isNull, isEmpty));
    });
  });

  group('RLS Helper Functions Existence', () {
    test('current_user_id function exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT 1 FROM pg_proc p
          JOIN pg_namespace n ON p.pronamespace = n.oid
          WHERE p.proname = 'current_user_id' AND n.nspname = 'public'
        ) as exists
      ''');

      expect(result.first[0], isTrue);
    });

    test('current_user_role function exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT 1 FROM pg_proc p
          JOIN pg_namespace n ON p.pronamespace = n.oid
          WHERE p.proname = 'current_user_role' AND n.nspname = 'public'
        ) as exists
      ''');

      expect(result.first[0], isTrue);
    });

    test('current_user_allowed_roles function exists', () async {
      final result = await Database.instance.execute('''
        SELECT EXISTS (
          SELECT 1 FROM pg_proc p
          JOIN pg_namespace n ON p.pronamespace = n.oid
          WHERE p.proname = 'current_user_allowed_roles' AND n.nspname = 'public'
        ) as exists
      ''');

      expect(result.first[0], isTrue);
    });
  });

  group('runTransactionWithContext', () {
    test('sets all context variables within transaction', () async {
      const testUserId = 'transaction-test-user';
      const testRole = 'Administrator';
      final allowedRoles = ['Administrator', 'Auditor'];

      final result = await Database.instance
          .runTransactionWithContext<Map<String, String?>>(
            (session) async {
              // Query all context variables within the same transaction
              final userIdResult = await session.execute(
                Sql("SELECT current_setting('app.user_id', true)"),
              );
              final roleResult = await session.execute(
                Sql("SELECT current_setting('app.role', true)"),
              );
              final allowedRolesResult = await session.execute(
                Sql("SELECT current_setting('app.allowed_roles', true)"),
              );

              return {
                'user_id': userIdResult.first[0] as String?,
                'role': roleResult.first[0] as String?,
                'allowed_roles': allowedRolesResult.first[0] as String?,
              };
            },
            context: UserContext.authenticated(
              userId: testUserId,
              role: testRole,
              allowedRoles: allowedRoles,
            ),
          );

      expect(result['user_id'], equals(testUserId));
      expect(result['role'], equals(testRole));
      expect(result['allowed_roles'], equals('Administrator,Auditor'));
    });

    test(
      'transaction can perform multiple queries with same context',
      () async {
        final adminContext = UserContext.authenticated(
          userId: testAdminFirebaseUid,
          role: 'Administrator',
        );

        final count = await Database.instance.runTransactionWithContext<int>((
          session,
        ) async {
          // First query
          final result1 = await session.execute(
            Sql.named(
              'SELECT COUNT(*) FROM portal_users WHERE role::text = @role',
            ),
            parameters: {'role': 'Administrator'},
          );

          // Second query in same transaction
          final result2 = await session.execute(
            Sql.named(
              'SELECT COUNT(*) FROM portal_users WHERE role::text = @role',
            ),
            parameters: {'role': 'Investigator'},
          );

          return (result1.first[0] as int) + (result2.first[0] as int);
        }, context: adminContext);

        // Should have counted users from both queries
        expect(count, greaterThanOrEqualTo(2));
      },
    );

    test('transaction rolls back on error', () async {
      const tempUserId = '00000000-0000-4000-a000-000000000098';
      final tempEmail =
          'rollback-test-${DateTime.now().millisecondsSinceEpoch}@example.com';

      final adminContext = UserContext.authenticated(
        userId: testAdminFirebaseUid,
        role: 'Administrator',
      );

      // Clean up any leftover data
      await Database.instance.execute(
        'DELETE FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': tempUserId},
      );

      try {
        await Database.instance.runTransactionWithContext<void>((
          session,
        ) async {
          // Insert a user
          await session.execute(
            Sql.named('''
                INSERT INTO portal_users (id, email, name, role, status)
                VALUES (@userId::uuid, @email, 'Temp User', 'Auditor', 'active')
              '''),
            parameters: {'userId': tempUserId, 'email': tempEmail},
          );

          // Force an error to trigger rollback
          throw Exception('Intentional error for rollback test');
        }, context: adminContext);
        fail('Expected exception to be thrown');
      } catch (e) {
        expect(e.toString(), contains('Intentional error'));
      }

      // Verify the user was NOT created due to rollback
      final result = await Database.instance.execute(
        'SELECT id FROM portal_users WHERE id = @userId::uuid',
        parameters: {'userId': tempUserId},
      );

      expect(result, isEmpty);
    });

    test('service context works within transaction', () async {
      final result = await Database.instance.runTransactionWithContext<String>((
        session,
      ) async {
        final queryResult = await session.execute(
          Sql("SELECT current_setting('app.role', true)"),
        );
        return queryResult.first[0] as String;
      }, context: UserContext.service);

      expect(result, equals('service_role'));
    });
  });

  group('RLS Policies Existence', () {
    test('portal_users table has RLS enabled', () async {
      final result = await Database.instance.execute('''
        SELECT relrowsecurity
        FROM pg_class
        WHERE relname = 'portal_users'
      ''');

      expect(result.isNotEmpty, isTrue);
      expect(result.first[0], isTrue);
    });

    test('portal_users has expected RLS policies', () async {
      final result = await Database.instance.execute('''
        SELECT polname
        FROM pg_policy
        WHERE polrelid = 'portal_users'::regclass
        ORDER BY polname
      ''');

      final policyNames = result.map((r) => r[0] as String).toList();

      // Verify expected policies exist
      expect(policyNames, contains('portal_users_admin_auditor_select'));
      expect(policyNames, contains('portal_users_self_select'));
      expect(policyNames, contains('portal_users_admin_insert'));
      expect(policyNames, contains('portal_users_admin_update'));
      expect(policyNames, contains('portal_users_service_all'));
    });
  });
}
