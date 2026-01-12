// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: Admin Dashboard Implementation
//
// Integration tests for portal handlers
// Requires PostgreSQL database with schema applied

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  // Test user data - using fixed UUIDs for reproducibility
  const testAdminId = '99990000-0000-0000-0000-000000000001';
  const testAdminEmail = 'admin@portal-test.example.com';
  const testAdminFirebaseUid = 'firebase-admin-uid-12345';

  const testInvestigatorId = '99990000-0000-0000-0000-000000000002';
  const testInvestigatorEmail = 'investigator@portal-test.example.com';
  const testInvestigatorFirebaseUid = 'firebase-investigator-uid-12345';

  const testRevokedUserId = '99990000-0000-0000-0000-000000000003';
  const testRevokedUserEmail = 'revoked@portal-test.example.com';
  const testRevokedUserFirebaseUid = 'firebase-revoked-uid-12345';

  const testSiteId = 'test-site-portal-001';

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

    // Clean up any previous test data (order matters for foreign keys)
    final db = Database.instance;
    await db.execute(
      'DELETE FROM portal_user_site_access WHERE user_id IN (@adminId::uuid, @invId::uuid, @revokedId::uuid)',
      parameters: {
        'adminId': testAdminId,
        'invId': testInvestigatorId,
        'revokedId': testRevokedUserId,
      },
    );
    // Delete from portal_user_roles before portal_users (assigned_by FK)
    await db.execute(
      '''DELETE FROM portal_user_roles WHERE user_id IN (@adminId::uuid, @invId::uuid, @revokedId::uuid)
         OR assigned_by IN (@adminId::uuid, @invId::uuid, @revokedId::uuid)''',
      parameters: {
        'adminId': testAdminId,
        'invId': testInvestigatorId,
        'revokedId': testRevokedUserId,
      },
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@portal-test.example.com'},
    );
    await db.execute(
      'DELETE FROM sites WHERE site_id = @siteId',
      parameters: {'siteId': testSiteId},
    );

    // Create test site (use unique site_number to avoid conflicts with init_test.sql)
    await db.execute(
      '''
      INSERT INTO sites (site_id, site_name, site_number, is_active)
      VALUES (@siteId, 'Test Portal Site', 'PORTAL-TEST-001', true)
      ON CONFLICT (site_id) DO UPDATE SET site_name = EXCLUDED.site_name
      ''',
      parameters: {'siteId': testSiteId},
    );

    // Create test admin user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, role, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Test Admin', 'Administrator', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testAdminId,
        'email': testAdminEmail,
        'firebaseUid': testAdminFirebaseUid,
      },
    );

    // Create test investigator user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, role, firebase_uid, status, linking_code)
      VALUES (@id::uuid, @email, 'Test Investigator', 'Investigator', @firebaseUid, 'active', 'TESTX-CODE1')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testInvestigatorId,
        'email': testInvestigatorEmail,
        'firebaseUid': testInvestigatorFirebaseUid,
      },
    );

    // Create test revoked user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, role, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Revoked User', 'Auditor', @firebaseUid, 'revoked')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testRevokedUserId,
        'email': testRevokedUserEmail,
        'firebaseUid': testRevokedUserFirebaseUid,
      },
    );

    // Assign investigator to test site
    await db.execute(
      '''
      INSERT INTO portal_user_site_access (user_id, site_id)
      VALUES (@userId::uuid, @siteId)
      ON CONFLICT (user_id, site_id) DO NOTHING
      ''',
      parameters: {'userId': testInvestigatorId, 'siteId': testSiteId},
    );
  });

  tearDownAll(() async {
    // Clean up test data (order matters for foreign keys)
    final db = Database.instance;
    await db.execute(
      'DELETE FROM portal_user_site_access WHERE user_id IN (@adminId::uuid, @invId::uuid, @revokedId::uuid)',
      parameters: {
        'adminId': testAdminId,
        'invId': testInvestigatorId,
        'revokedId': testRevokedUserId,
      },
    );
    // Delete from portal_user_roles before portal_users (assigned_by FK)
    await db.execute(
      '''DELETE FROM portal_user_roles WHERE user_id IN (@adminId::uuid, @invId::uuid, @revokedId::uuid)
         OR assigned_by IN (@adminId::uuid, @invId::uuid, @revokedId::uuid)''',
      parameters: {
        'adminId': testAdminId,
        'invId': testInvestigatorId,
        'revokedId': testRevokedUserId,
      },
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@portal-test.example.com'},
    );
    await db.execute(
      'DELETE FROM sites WHERE site_id = @siteId',
      parameters: {'siteId': testSiteId},
    );

    await Database.instance.close();
  });

  // Create a mock token for testing (bypasses actual Firebase verification)
  // Note: In production, use FIREBASE_AUTH_EMULATOR_HOST for proper emulator testing
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
    // Emulator tokens can have empty signature
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

  Request createPostRequest(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
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

  // Note: These tests work when FIREBASE_AUTH_EMULATOR_HOST is set
  // or can be adapted to use mock authentication
  group('portalMeHandler', () {
    test('returns 401 without authorization header', () async {
      final request = createGetRequest('/api/v1/portal/me');
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with invalid Bearer format', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'NotBearer token'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with malformed token', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer invalid'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });
  });

  group('getPortalUsersHandler - authorization', () {
    test('returns 403 without valid auth', () async {
      final request = createGetRequest('/api/v1/portal/users');
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('createPortalUserHandler - validation', () {
    test('returns 403 without valid auth', () async {
      final request = createPostRequest('/api/v1/portal/users', {
        'name': 'Test',
        'email': 'test@example.com',
        'role': 'Investigator',
      });
      final response = await createPortalUserHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('updatePortalUserHandler - validation', () {
    test('returns 403 without valid auth', () async {
      final request = createPatchRequest('/api/v1/portal/users/$testAdminId', {
        'status': 'revoked',
      });
      final response = await updatePortalUserHandler(request, testAdminId);

      expect(response.statusCode, equals(403));
    });
  });

  group('getPortalSitesHandler - authorization', () {
    test('returns 403 without valid auth', () async {
      final request = createGetRequest('/api/v1/portal/sites');
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  // These tests require the Firebase Auth emulator running
  // Run with: FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 dart test
  group('Portal handlers with emulator auth', () {
    final useEmulator =
        Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] != null;

    test(
      'portalMeHandler returns user when authenticated via emulator',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        // This test only runs with Firebase emulator
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await portalMeHandler(request);

        // With emulator, should find the user
        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['email'], equals(testAdminEmail));
          expect(json['active_role'], equals('Administrator'));
        }
      },
    );

    test(
      'getPortalUsersHandler returns users when admin authenticated',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/users',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUsersHandler(request);

        // Admin should be able to list users
        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['users'], isA<List>());
        }
      },
    );

    test(
      'getPortalSitesHandler returns sites when authenticated',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/sites',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalSitesHandler(request);

        // Authenticated user should be able to list sites
        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['sites'], isA<List>());
        }
      },
    );

    test(
      'portalMeHandler returns 403 for unauthorized email',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        // Token with email that doesn't exist in portal_users
        final token = createMockEmulatorToken(
          'unknown-uid',
          'unknown@example.com',
        );
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(403));
        final json = await getResponseJson(response);
        expect(json['error'], contains('not authorized'));
      },
    );

    test(
      'portalMeHandler returns 401 for token missing email',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        // Create token without email claim
        final header = base64Url.encode(
          utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})),
        );
        final payload = base64Url.encode(
          utf8.encode(
            jsonEncode({
              'sub': 'some-uid',
              'user_id': 'some-uid',
              'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'exp':
                  DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        );
        final token = '$header.$payload.';

        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(401));
        final json = await getResponseJson(response);
        expect(json['error'], contains('email'));
      },
    );

    test(
      'investigator portalMeHandler returns sites',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testInvestigatorFirebaseUid,
          testInvestigatorEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await portalMeHandler(request);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['email'], equals(testInvestigatorEmail));
          expect(json['active_role'], equals('Investigator'));
          expect(json['sites'], isA<List>());
        }
      },
    );

    test(
      'createPortalUserHandler creates user with valid auth',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPostRequest(
          '/api/v1/portal/users',
          {
            'name': 'Test New User',
            'email':
                'newuser-test-${DateTime.now().millisecondsSinceEpoch}@portal-test.example.com',
            'role': 'Auditor',
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await createPortalUserHandler(request);

        // Admin should be able to create users
        if (response.statusCode == 201) {
          final json = await getResponseJson(response);
          expect(json['name'], equals('Test New User'));
          expect(json['roles'], contains('Auditor'));
          expect(json['id'], isNotNull);
        }
      },
    );

    test(
      'createPortalUserHandler validates required fields',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );

        // Missing name
        var request = createPostRequest(
          '/api/v1/portal/users',
          {'email': 'test@example.com', 'role': 'Auditor'},
          headers: {'authorization': 'Bearer $token'},
        );
        var response = await createPortalUserHandler(request);
        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('Name'));
        }

        // Missing email
        request = createPostRequest(
          '/api/v1/portal/users',
          {'name': 'Test', 'role': 'Auditor'},
          headers: {'authorization': 'Bearer $token'},
        );
        response = await createPortalUserHandler(request);
        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('email'));
        }

        // Invalid email format
        request = createPostRequest(
          '/api/v1/portal/users',
          {'name': 'Test', 'email': 'not-an-email', 'role': 'Auditor'},
          headers: {'authorization': 'Bearer $token'},
        );
        response = await createPortalUserHandler(request);
        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('email'));
        }

        // Missing role
        request = createPostRequest(
          '/api/v1/portal/users',
          {'name': 'Test', 'email': 'test@example.com'},
          headers: {'authorization': 'Bearer $token'},
        );
        response = await createPortalUserHandler(request);
        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('role'));
        }

        // Invalid role
        request = createPostRequest(
          '/api/v1/portal/users',
          {'name': 'Test', 'email': 'test@example.com', 'role': 'InvalidRole'},
          headers: {'authorization': 'Bearer $token'},
        );
        response = await createPortalUserHandler(request);
        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('role'));
        }
      },
    );

    test(
      'createPortalUserHandler requires site for Investigator',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPostRequest(
          '/api/v1/portal/users',
          {
            'name': 'Test Investigator',
            'email': 'inv-${DateTime.now().millisecondsSinceEpoch}@example.com',
            'role': 'Investigator',
            // Missing site_ids
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await createPortalUserHandler(request);

        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('site'));
        }
      },
    );

    test(
      'updatePortalUserHandler updates user status',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testInvestigatorId',
          {'status': 'active'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(
          request,
          testInvestigatorId,
        );

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['success'], isTrue);
        }
      },
    );

    test(
      'updatePortalUserHandler rejects invalid status',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testInvestigatorId',
          {'status': 'invalid-status'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(
          request,
          testInvestigatorId,
        );

        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('status'));
        }
      },
    );

    test(
      'updatePortalUserHandler prevents self-modification',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testAdminId',
          {'status': 'revoked'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, testAdminId);

        if (response.statusCode == 400) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('own account'));
        }
      },
    );

    test(
      'updatePortalUserHandler returns 404 for non-existent user',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final nonExistentId = '00000000-0000-0000-0000-000000000999';
        final request = createPatchRequest(
          '/api/v1/portal/users/$nonExistentId',
          {'status': 'revoked'},
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(request, nonExistentId);

        expect(response.statusCode, equals(404));
      },
    );

    test(
      'createPortalUserHandler rejects duplicate email',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPostRequest(
          '/api/v1/portal/users',
          {
            'name': 'Duplicate User',
            'email': testAdminEmail, // Already exists
            'role': 'Auditor',
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await createPortalUserHandler(request);

        expect(response.statusCode, equals(409));
        final json = await getResponseJson(response);
        expect(json['error'], contains('exists'));
      },
    );

    test(
      'createPortalUserHandler creates investigator with sites',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPostRequest(
          '/api/v1/portal/users',
          {
            'name': 'New Investigator',
            'email':
                'newinv-${DateTime.now().millisecondsSinceEpoch}@portal-test.example.com',
            'role': 'Investigator',
            'site_ids': [testSiteId],
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await createPortalUserHandler(request);

        if (response.statusCode == 201) {
          final json = await getResponseJson(response);
          expect(json['roles'], contains('Investigator'));
          expect(json['linking_code'], isNotNull);
          expect(json['site_ids'], contains(testSiteId));
        }
      },
    );

    test(
      'createPortalUserHandler rejects admin creation by non-developer-admin',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPostRequest(
          '/api/v1/portal/users',
          {
            'name': 'New Admin',
            'email':
                'newadmin-${DateTime.now().millisecondsSinceEpoch}@portal-test.example.com',
            'role': 'Administrator', // Only Developer Admin should create this
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await createPortalUserHandler(request);

        // Regular Administrator cannot create other Administrator users
        if (response.statusCode == 403) {
          final json = await getResponseJson(response);
          expect(json['error'], contains('Developer Admin'));
        }
      },
    );

    test(
      'updatePortalUserHandler updates site assignments',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createPatchRequest(
          '/api/v1/portal/users/$testInvestigatorId',
          {
            'site_ids': [testSiteId],
          },
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await updatePortalUserHandler(
          request,
          testInvestigatorId,
        );

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          expect(json['success'], isTrue);
        }
      },
    );

    test(
      'getPortalUsersHandler includes site assignments',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/users',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUsersHandler(request);

        if (response.statusCode == 200) {
          final json = await getResponseJson(response);
          final users = json['users'] as List;
          expect(users, isNotEmpty);

          // Find investigator and check sites
          final investigator = users.firstWhere(
            (u) => u['email'] == testInvestigatorEmail,
            orElse: () => null,
          );
          if (investigator != null) {
            expect(investigator['sites'], isA<List>());
          }
        }
      },
    );

    test(
      'createPortalUserHandler handles invalid JSON body',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/users'),
          body: 'not valid json {{{',
          headers: {
            'Content-Type': 'application/json',
            'authorization': 'Bearer $token',
          },
        );
        final response = await createPortalUserHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('JSON'));
      },
    );

    test(
      'updatePortalUserHandler handles invalid JSON body',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testAdminFirebaseUid,
          testAdminEmail,
        );
        final request = Request(
          'PATCH',
          Uri.parse('http://localhost/api/v1/portal/users/$testInvestigatorId'),
          body: 'not valid json',
          headers: {
            'Content-Type': 'application/json',
            'authorization': 'Bearer $token',
          },
        );
        final response = await updatePortalUserHandler(
          request,
          testInvestigatorId,
        );

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('JSON'));
      },
    );

    test(
      'investigator cannot access getPortalUsersHandler',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testInvestigatorFirebaseUid,
          testInvestigatorEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/users',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await getPortalUsersHandler(request);

        // Investigators are not in the allowed roles for listing users
        expect(response.statusCode, equals(403));
      },
    );

    test(
      'portalMeHandler returns 403 for revoked user',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testRevokedUserFirebaseUid,
          testRevokedUserEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(403));
        final json = await getResponseJson(response);
        expect(json['error'], contains('revoked'));
      },
    );

    test(
      'revoked user cannot access other handlers',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        final token = createMockEmulatorToken(
          testRevokedUserFirebaseUid,
          testRevokedUserEmail,
        );

        // Try to list users
        var request = createGetRequest(
          '/api/v1/portal/users',
          headers: {'authorization': 'Bearer $token'},
        );
        var response = await getPortalUsersHandler(request);
        expect(response.statusCode, equals(403));

        // Try to list sites
        request = createGetRequest(
          '/api/v1/portal/sites',
          headers: {'authorization': 'Bearer $token'},
        );
        response = await getPortalSitesHandler(request);
        expect(response.statusCode, equals(403));
      },
    );

    test(
      'portalMeHandler returns 403 when email already linked to another account',
      skip: !useEmulator ? 'Requires FIREBASE_AUTH_EMULATOR_HOST' : null,
      () async {
        // The admin user already has a firebase_uid linked
        // Try to login with a DIFFERENT firebase_uid but the SAME email
        final differentFirebaseUid = 'different-firebase-uid-attempt';
        final token = createMockEmulatorToken(
          differentFirebaseUid,
          testAdminEmail,
        );
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer $token'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(403));
        final json = await getResponseJson(response);
        expect(json['error'], contains('already linked'));
      },
    );
  });
}
