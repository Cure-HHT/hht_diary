// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//
// Integration tests for portal activation handlers
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
  const testDevAdminId = '99991000-0000-0000-0000-000000000001';
  const testDevAdminEmail = 'devadmin@activation-test.example.com';
  const testDevAdminFirebaseUid = 'firebase-devadmin-uid-12345';

  const testPendingUserId = '99991000-0000-0000-0000-000000000002';
  const testPendingUserEmail = 'pending@activation-test.example.com';
  const testPendingUserFirebaseUid = 'firebase-pending-uid-12345';
  const testActivationCode = 'TEST1-ACT01';

  const testAlreadyActiveUserId = '99991000-0000-0000-0000-000000000003';
  const testAlreadyActiveEmail = 'active@activation-test.example.com';
  const testAlreadyActiveCode = 'TEST2-ACT02';

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
      '''DELETE FROM portal_user_roles WHERE user_id IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid)
         OR assigned_by IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid)''',
      parameters: {
        'devAdminId': testDevAdminId,
        'pendingId': testPendingUserId,
        'activeId': testAlreadyActiveUserId,
      },
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@activation-test.example.com'},
    );

    // Create test Developer Admin user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Test Dev Admin', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testDevAdminId,
        'email': testDevAdminEmail,
        'firebaseUid': testDevAdminFirebaseUid,
      },
    );

    // Add Developer Admin role
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Developer Admin')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testDevAdminId},
    );

    // Create test pending user with activation code
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, status, activation_code, activation_code_expires_at)
      VALUES (@id::uuid, @email, 'Test Pending User', 'pending', @code, @expiry)
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testPendingUserId,
        'email': testPendingUserEmail,
        'code': testActivationCode,
        'expiry': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      },
    );

    // Create test already-active user with activation code
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, status, activation_code)
      VALUES (@id::uuid, @email, 'Test Already Active', 'active', @code)
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testAlreadyActiveUserId,
        'email': testAlreadyActiveEmail,
        'code': testAlreadyActiveCode,
      },
    );
  });

  tearDownAll(() async {
    // Clean up test data (order matters for foreign keys)
    final db = Database.instance;
    await db.execute(
      '''DELETE FROM portal_user_roles WHERE user_id IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid)
         OR assigned_by IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid)''',
      parameters: {
        'devAdminId': testDevAdminId,
        'pendingId': testPendingUserId,
        'activeId': testAlreadyActiveUserId,
      },
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@activation-test.example.com'},
    );

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

  group('validateActivationCodeHandler', () {
    test('returns valid for existing activation code', () async {
      final request = createGetRequest(
        '/api/v1/portal/activate/$testActivationCode',
      );
      final response = await validateActivationCodeHandler(
        request,
        testActivationCode,
      );

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['valid'], isTrue);
      expect(json['email'], isNotNull);
      // Email should be masked
      expect(json['email'], contains('***'));
    });

    test('returns 401 for non-existent activation code', () async {
      final request = createGetRequest('/api/v1/portal/activate/INVALID-CODE');
      final response = await validateActivationCodeHandler(
        request,
        'INVALID-CODE',
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid activation code'));
    });

    test('returns 400 for already activated account', () async {
      final request = createGetRequest(
        '/api/v1/portal/activate/$testAlreadyActiveCode',
      );
      final response = await validateActivationCodeHandler(
        request,
        testAlreadyActiveCode,
      );

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('already activated'));
    });
  });

  group('activateUserHandler', () {
    test('returns 403 for email mismatch', () async {
      // Try to activate with a different email than the one in the DB
      final token = createMockEmulatorToken(
        'wrong-uid-12345',
        'wrong@example.com',
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': testActivationCode},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Email does not match'));
    });

    test('returns 401 for invalid activation code', () async {
      final token = createMockEmulatorToken(
        testPendingUserFirebaseUid,
        testPendingUserEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': 'WRONG-CODE1'},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid activation code'));
    });

    test('successfully activates user with matching email', () async {
      // Use proper email and uid for the pending user
      final token = createMockEmulatorToken(
        testPendingUserFirebaseUid,
        testPendingUserEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': testActivationCode},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['user'], isNotNull);
      expect(json['user']['status'], equals('active'));
    });
  });

  group('generateActivationCodeHandler', () {
    test('returns 403 for non-Developer Admin', () async {
      // Create a token for a non-admin user
      final token = createMockEmulatorToken(
        'non-admin-uid',
        'nonadmin@example.com',
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'email': 'newuser@example.com'},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Developer Admin'));
    });

    test('Developer Admin can generate activation code', () async {
      final token = createMockEmulatorToken(
        testDevAdminFirebaseUid,
        testDevAdminEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'user_id': testAlreadyActiveUserId},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['activation_code'], isNotNull);
      expect(
        json['activation_code'],
        matches(RegExp(r'^[A-Z0-9]{5}-[A-Z0-9]{5}$')),
      );
      expect(json['expires_at'], isNotNull);
    });

    test('returns 404 for non-existent user', () async {
      final token = createMockEmulatorToken(
        testDevAdminFirebaseUid,
        testDevAdminEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'user_id': '00000000-0000-0000-0000-000000000000'},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(404));
      final json = await getResponseJson(response);
      expect(json['error'], contains('not found'));
    });

    test('can generate code by email', () async {
      final token = createMockEmulatorToken(
        testDevAdminFirebaseUid,
        testDevAdminEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'email': testAlreadyActiveEmail},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['user']['email'], equals(testAlreadyActiveEmail));
    });
  });
}
