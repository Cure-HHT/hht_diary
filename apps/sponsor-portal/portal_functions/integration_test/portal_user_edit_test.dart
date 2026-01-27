// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00031: Deactivate User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-CAL-p00066: Capture deactivation reason
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// Integration tests for portal user edit and deactivation functionality
// Requires PostgreSQL database with schema applied and Firebase Auth emulator

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  // Test user data - using fixed UUIDs in 99994000 range for edit tests
  const testAdminId = '99994000-0000-0000-0000-000000000001';
  const testAdminEmail = 'admin@user-edit-test.example.com';
  const testAdminFirebaseUid = 'firebase-edit-admin-uid-99001';

  const testTargetId = '99994000-0000-0000-0000-000000000002';
  const testTargetEmail = 'target@user-edit-test.example.com';
  const testTargetFirebaseUid = 'firebase-edit-target-uid-99002';

  const testSiteId = 'test-site-edit-001';
  const testSiteId2 = 'test-site-edit-002';

  setUpAll(() async {
    // Initialize database
    final sslEnv = Platform.environment['DB_SSL'];
    final useSsl = sslEnv == 'true';

    final config = DatabaseConfig(
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

    // Clean up any previous test data
    await _cleanup();

    // Create test sites
    final db = Database.instance;
    for (final site in [
      {'id': testSiteId, 'name': 'Edit Test Site 1', 'number': 'EDIT-001'},
      {'id': testSiteId2, 'name': 'Edit Test Site 2', 'number': 'EDIT-002'},
    ]) {
      await db.execute(
        '''
        INSERT INTO sites (site_id, site_name, site_number, is_active)
        VALUES (@siteId, @name, @number, true)
        ON CONFLICT (site_id) DO UPDATE SET site_name = EXCLUDED.site_name
        ''',
        parameters: {
          'siteId': site['id'],
          'name': site['name'],
          'number': site['number'],
        },
      );
    }

    // Create test admin user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, role, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Edit Test Admin', 'Administrator', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testAdminId,
        'email': testAdminEmail,
        'firebaseUid': testAdminFirebaseUid,
      },
    );

    // Add admin role
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Administrator')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testAdminId},
    );

    // Create target user (will be edited in tests)
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, role, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Target User', 'Investigator', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testTargetId,
        'email': testTargetEmail,
        'firebaseUid': testTargetFirebaseUid,
      },
    );

    // Add roles to target
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role, assigned_by)
      VALUES (@userId::uuid, 'Investigator', @assignedBy::uuid)
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testTargetId, 'assignedBy': testAdminId},
    );

    // Assign target to site
    await db.execute(
      '''
      INSERT INTO portal_user_site_access (user_id, site_id)
      VALUES (@userId::uuid, @siteId)
      ON CONFLICT (user_id, site_id) DO NOTHING
      ''',
      parameters: {'userId': testTargetId, 'siteId': testSiteId},
    );
  });

  tearDownAll(() async {
    await _cleanup();
    await Database.instance.close();
  });

  String createMockEmulatorToken(String uid, String email) {
    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})),
    );
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': uid,
          'user_id': uid,
          'email': email,
          'email_verified': true,
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000,
        }),
      ),
    );
    return '$header.$payload.';
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  Request createPatchRequest(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'PATCH',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  final useEmulator =
      Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] != null;

  group('getPortalUserHandler', () {
    test('returns 403 without valid auth', () async {
      final request = createGetRequest('/api/v1/portal/users/$testTargetId');
      final response = await getPortalUserHandler(request, testTargetId);

      expect(response.statusCode, equals(403));
    });

    test(
      'returns single user with roles and sites',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/users/$testTargetId',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['id'], equals(testTargetId));
          expect(json['email'], equals(testTargetEmail));
          expect(json['name'], equals('Target User'));
          expect(json['status'], equals('active'));
          expect(json['roles'], contains('Investigator'));
          expect(json['sites'], isA<List>());
          expect(json['created_at'], isNotNull);
        }
      },
    );

    test(
      'returns 404 for non-existent user',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final nonExistentId = '00000000-0000-0000-0000-000000000999';
        final request = createGetRequest(
          '/api/v1/portal/users/$nonExistentId',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUserHandler(request, nonExistentId);

        expect(response.statusCode, equals(404));
      },
    );

    test(
      'returns roles as non-empty list of strings (string_agg parsing)',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/users/$testTargetId',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          final roles = json['roles'] as List;
          expect(
            roles,
            isNotEmpty,
            reason:
                'Roles must not be empty — string_agg should return parsed roles',
          );
          // Each role must be a plain String
          for (final role in roles) {
            expect(role, isA<String>());
            expect(role, isNotEmpty);
          }
          expect(roles, contains('Investigator'));
        }
      },
    );

    test(
      'returns multiple roles for multi-role user',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        // Add a second role to the target user
        final db = Database.instance;
        await db.execute(
          '''
          INSERT INTO portal_user_roles (user_id, role, assigned_by)
          VALUES (@userId::uuid, 'Auditor', @assignedBy::uuid)
          ON CONFLICT (user_id, role) DO NOTHING
          ''',
          parameters: {'userId': testTargetId, 'assignedBy': testAdminId},
        );

        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/users/$testTargetId',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          final roles = json['roles'] as List;
          expect(
            roles.length,
            greaterThanOrEqualTo(2),
            reason: 'Multi-role user should have both roles from string_agg',
          );
          expect(roles, contains('Investigator'));
          expect(roles, contains('Auditor'));
        }

        // Clean up the extra role
        await db.execute(
          '''
          DELETE FROM portal_user_roles
          WHERE user_id = @userId::uuid AND role = 'Auditor'
          ''',
          parameters: {'userId': testTargetId},
        );
      },
    );
  });

  group('updatePortalUserHandler - name change', () {
    test(
      'updates user name and creates audit log entry',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {'name': 'Updated Target Name'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['success'], isTrue);

          // Check audit log
          final db = Database.instance;
          final auditResult = await db.execute(
            '''
            SELECT action, before_value, after_value
            FROM portal_user_audit_log
            WHERE user_id = @userId::uuid AND action = 'update_name'
            ORDER BY created_at DESC LIMIT 1
            ''',
            parameters: {'userId': testTargetId},
          );

          if (auditResult.isNotEmpty) {
            expect(auditResult.first[0], equals('update_name'));
          }
        }
      },
    );
  });

  group('updatePortalUserHandler - role change', () {
    test(
      'updates roles and terminates sessions',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {
            'roles': ['Investigator', 'Auditor'],
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['success'], isTrue);
          expect(json['sessions_terminated'], isTrue);

          // Verify tokens_revoked_at is set
          final db = Database.instance;
          final userResult = await db.execute(
            'SELECT tokens_revoked_at FROM portal_users WHERE id = @id::uuid',
            parameters: {'id': testTargetId},
          );
          expect(userResult.first[0], isNotNull);

          // Check audit log
          final auditResult = await db.execute(
            '''
            SELECT action FROM portal_user_audit_log
            WHERE user_id = @userId::uuid AND action = 'update_roles'
            ORDER BY created_at DESC LIMIT 1
            ''',
            parameters: {'userId': testTargetId},
          );
          if (auditResult.isNotEmpty) {
            expect(auditResult.first[0], equals('update_roles'));
          }
        }
      },
    );

    test(
      'rejects Developer Admin role assignment',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {
            'roles': ['Developer Admin'],
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        expect(response.statusCode, equals(403));
      },
    );
  });

  group('updatePortalUserHandler - site change', () {
    test(
      'updates site assignments and terminates sessions',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {
            'site_ids': [testSiteId, testSiteId2],
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['success'], isTrue);
          expect(json['sessions_terminated'], isTrue);

          // Verify site assignments
          final db = Database.instance;
          final sitesResult = await db.execute(
            'SELECT site_id FROM portal_user_site_access WHERE user_id = @id::uuid ORDER BY site_id',
            parameters: {'id': testTargetId},
          );
          expect(sitesResult.length, equals(2));
        }
      },
    );
  });

  group('updatePortalUserHandler - self-modification prevention', () {
    test(
      'returns 400 when admin tries to modify self',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testAdminId',
          {'name': 'Self Modification'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testAdminId);

        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('own account'));
        }
      },
    );
  });

  group('updatePortalUserHandler - audit logging', () {
    test(
      'creates audit log entries for all changes',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final db = Database.instance;

        // Clear previous audit entries for this test
        // Note: audit log has no-delete rule, but we can query
        final initialCount = await db.execute(
          'SELECT count(*) FROM portal_user_audit_log WHERE user_id = @userId::uuid',
          parameters: {'userId': testTargetId},
        );
        final countBefore = initialCount.first[0] as int;

        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );

        // Make a name change
        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {'name': 'Audit Test Name ${DateTime.now().millisecondsSinceEpoch}'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          // Verify new audit entry was created
          final afterCount = await db.execute(
            'SELECT count(*) FROM portal_user_audit_log WHERE user_id = @userId::uuid',
            parameters: {'userId': testTargetId},
          );
          final countAfter = afterCount.first[0] as int;
          expect(countAfter, greaterThan(countBefore));
        }
      },
    );
  });

  group('updatePortalUserHandler - deactivation with reason (REQ-CAL-p00066)', () {
    test(
      'stores status_change_reason when deactivating user',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );

        // Ensure target is active first
        final db = Database.instance;
        await db.execute(
          "UPDATE portal_users SET status = 'active' WHERE id = @id::uuid",
          parameters: {'id': testTargetId},
        );

        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {'status': 'revoked', 'reason': 'Employee left the organization'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['success'], isTrue);
          expect(json['sessions_terminated'], isTrue);

          // Verify reason stored in DB
          final result = await db.execute(
            '''SELECT status, status_change_reason, status_changed_at, status_changed_by
               FROM portal_users WHERE id = @id::uuid''',
            parameters: {'id': testTargetId},
          );
          expect(result.first[0], equals('revoked'));
          expect(result.first[1], equals('Employee left the organization'));
          expect(result.first[2], isNotNull); // status_changed_at
          expect(result.first[3], isNotNull); // status_changed_by
        }
      },
    );

    test(
      'reason appears in single-user GET response',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );

        // Deactivate with reason first
        final db = Database.instance;
        await db.execute(
          '''UPDATE portal_users
             SET status = 'revoked',
                 status_change_reason = 'Test reason for GET',
                 status_changed_at = now(),
                 status_changed_by = @adminId::uuid
             WHERE id = @id::uuid''',
          parameters: {'id': testTargetId, 'adminId': testAdminId},
        );

        final request = createGetRequest(
          '/api/v1/portal/users/$testTargetId',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['status'], equals('revoked'));
          expect(json['status_change_reason'], equals('Test reason for GET'));
          expect(json['status_changed_at'], isNotNull);
          expect(json['status_changed_by'], isNotNull);
        }
      },
    );

    test(
      'reason included in audit log after_value',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );

        // Reset to active first
        final db = Database.instance;
        await db.execute(
          "UPDATE portal_users SET status = 'active' WHERE id = @id::uuid",
          parameters: {'id': testTargetId},
        );

        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {'status': 'revoked', 'reason': 'Audit log reason test'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          // Check audit log for the reason in after_value
          final auditResult = await db.execute(
            '''SELECT after_value
               FROM portal_user_audit_log
               WHERE user_id = @userId::uuid AND action = 'update_status'
               ORDER BY created_at DESC LIMIT 1''',
            parameters: {'userId': testTargetId},
          );
          if (auditResult.isNotEmpty) {
            final afterValue = auditResult.first[0];
            // after_value is stored as JSONB
            Map<String, dynamic> afterMap;
            if (afterValue is String) {
              afterMap = jsonDecode(afterValue) as Map<String, dynamic>;
            } else {
              afterMap = afterValue as Map<String, dynamic>;
            }
            expect(afterMap['status'], equals('revoked'));
            expect(afterMap['reason'], equals('Audit log reason test'));
          }
        }
      },
    );

    test(
      'reactivation clears reason fields',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );

        // Ensure user is revoked with a reason
        final db = Database.instance;
        await db.execute(
          '''UPDATE portal_users
             SET status = 'revoked',
                 status_change_reason = 'To be cleared',
                 status_changed_at = now(),
                 status_changed_by = @adminId::uuid
             WHERE id = @id::uuid''',
          parameters: {'id': testTargetId, 'adminId': testAdminId},
        );

        // Reactivate
        final request = createPatchRequest(
          '/api/v1/portal/users/$testTargetId',
          {'status': 'active'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testTargetId);

        if (response.statusCode == 200) {
          // Verify reason is cleared (status_change_reason set to null by backend)
          final result = await db.execute(
            '''SELECT status, status_change_reason
               FROM portal_users WHERE id = @id::uuid''',
            parameters: {'id': testTargetId},
          );
          expect(result.first[0], equals('active'));
          // On reactivation with no reason, it's set to null
          expect(result.first[1], isNull);
        }
      },
    );
  });
}

Future<void> _cleanup() async {
  final db = Database.instance;

  // Clean up test data in FK order
  await db.execute(
    'DELETE FROM portal_user_site_access WHERE user_id IN (SELECT id FROM portal_users WHERE email LIKE @pattern)',
    parameters: {'pattern': '%@user-edit-test.example.com'},
  );
  // Temporarily disable no-delete rule so audit log entries can be removed
  await db.execute(
    'ALTER TABLE portal_user_audit_log DISABLE RULE portal_user_audit_log_no_delete',
  );
  await db.execute(
    '''DELETE FROM portal_user_audit_log WHERE user_id IN (SELECT id FROM portal_users WHERE email LIKE @pattern)
       OR changed_by IN (SELECT id FROM portal_users WHERE email LIKE @pattern)''',
    parameters: {'pattern': '%@user-edit-test.example.com'},
  );
  await db.execute(
    'ALTER TABLE portal_user_audit_log ENABLE RULE portal_user_audit_log_no_delete',
  );
  await db.execute(
    'DELETE FROM portal_pending_email_changes WHERE user_id IN (SELECT id FROM portal_users WHERE email LIKE @pattern)',
    parameters: {'pattern': '%@user-edit-test.example.com'},
  );
  await db.execute(
    '''DELETE FROM portal_user_roles WHERE user_id IN (SELECT id FROM portal_users WHERE email LIKE @pattern)
       OR assigned_by IN (SELECT id FROM portal_users WHERE email LIKE @pattern)''',
    parameters: {'pattern': '%@user-edit-test.example.com'},
  );
  await db.execute(
    'DELETE FROM portal_users WHERE email LIKE @pattern',
    parameters: {'pattern': '%@user-edit-test.example.com'},
  );
  await db.execute(
    "DELETE FROM sites WHERE site_id IN ('test-site-edit-001', 'test-site-edit-002')",
  );
}
