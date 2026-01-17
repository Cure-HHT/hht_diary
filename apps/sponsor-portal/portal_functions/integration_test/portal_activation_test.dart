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
  const testAlreadyActiveFirebaseUid = 'firebase-active-uid-12345';
  const testAlreadyActiveCode = 'TEST2-ACT02';

  const testExpiredUserId = '99991000-0000-0000-0000-000000000004';
  const testExpiredUserEmail = 'expired@activation-test.example.com';
  const testExpiredCode = 'TEST3-EXPR3';

  // Developer Admin pending user (for MFA enrollment test)
  const testDevAdminPendingId = '99991000-0000-0000-0000-000000000005';
  const testDevAdminPendingEmail =
      'devadmin-pending@activation-test.example.com';
  const testDevAdminPendingFirebaseUid = 'firebase-devadmin-pending-uid';
  const testDevAdminPendingCode = 'TEST4-DADM4';

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
      '''DELETE FROM portal_user_roles WHERE user_id IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid, @expiredId::uuid, @devAdminPendingId::uuid)
         OR assigned_by IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid, @expiredId::uuid, @devAdminPendingId::uuid)''',
      parameters: {
        'devAdminId': testDevAdminId,
        'pendingId': testPendingUserId,
        'activeId': testAlreadyActiveUserId,
        'expiredId': testExpiredUserId,
        'devAdminPendingId': testDevAdminPendingId,
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

    // Create test pending user with activation code (non-admin, uses email OTP)
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

    // Add Administrator role to pending user (non-admin users don't need TOTP)
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Administrator')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testPendingUserId},
    );

    // Create test pending Developer Admin with activation code (requires TOTP)
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, status, activation_code, activation_code_expires_at)
      VALUES (@id::uuid, @email, 'Test Pending Dev Admin', 'pending', @code, @expiry)
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testDevAdminPendingId,
        'email': testDevAdminPendingEmail,
        'code': testDevAdminPendingCode,
        'expiry': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      },
    );

    // Add Developer Admin role to pending dev admin
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Developer Admin')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testDevAdminPendingId},
    );

    // Create test already-active user with activation code
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status, activation_code)
      VALUES (@id::uuid, @email, 'Test Already Active', @firebaseUid, 'active', @code)
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testAlreadyActiveUserId,
        'email': testAlreadyActiveEmail,
        'firebaseUid': testAlreadyActiveFirebaseUid,
        'code': testAlreadyActiveCode,
      },
    );

    // Create test user with expired activation code
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, status, activation_code, activation_code_expires_at)
      VALUES (@id::uuid, @email, 'Test Expired User', 'pending', @code, @expiry)
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testExpiredUserId,
        'email': testExpiredUserEmail,
        'code': testExpiredCode,
        'expiry': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
      },
    );
  });

  tearDownAll(() async {
    // Clean up test data (order matters for foreign keys)
    final db = Database.instance;
    await db.execute(
      '''DELETE FROM portal_user_roles WHERE user_id IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid, @expiredId::uuid, @devAdminPendingId::uuid)
         OR assigned_by IN (@devAdminId::uuid, @pendingId::uuid, @activeId::uuid, @expiredId::uuid, @devAdminPendingId::uuid)''',
      parameters: {
        'devAdminId': testDevAdminId,
        'pendingId': testPendingUserId,
        'activeId': testAlreadyActiveUserId,
        'expiredId': testExpiredUserId,
        'devAdminPendingId': testDevAdminPendingId,
      },
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@activation-test.example.com'},
    );

    await Database.instance.close();
  });

  String createMockEmulatorToken(
    String uid,
    String email, {
    bool mfaEnrolled = false,
  }) {
    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})),
    );
    final payloadData = {
      'sub': uid,
      'user_id': uid,
      'email': email,
      'email_verified': true,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    };

    // Add MFA claims if enrolled
    if (mfaEnrolled) {
      payloadData['firebase'] = {
        'sign_in_second_factor': 'totp',
        'second_factor_identifier': 'test-mfa-factor-id',
      };
    }

    final payload = base64Url.encode(utf8.encode(jsonEncode(payloadData)));
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

    test('returns 401 for expired activation code', () async {
      final request = createGetRequest(
        '/api/v1/portal/activate/$testExpiredCode',
      );
      final response = await validateActivationCodeHandler(
        request,
        testExpiredCode,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('expired'));
    });
  });

  group('activateUserHandler', () {
    test('returns 403 for email mismatch', () async {
      // Try to activate with a different email than the one in the DB
      final token = createMockEmulatorToken(
        'wrong-uid-12345',
        'wrong@example.com',
        mfaEnrolled: true,
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
        mfaEnrolled: true,
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

    test('returns 403 when Developer Admin MFA not enrolled', () async {
      // Developer Admin without MFA should be rejected (they require TOTP)
      final token = createMockEmulatorToken(
        testDevAdminPendingFirebaseUid,
        testDevAdminPendingEmail,
        mfaEnrolled: false,
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': testDevAdminPendingCode},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['mfa_required'], isTrue);
      expect(json['error'], contains('MFA enrollment required'));
    });

    test('non-admin activates without MFA (uses email OTP)', () async {
      // Non-admin users don't need TOTP - they use email OTP on login
      final token = createMockEmulatorToken(
        testPendingUserFirebaseUid,
        testPendingUserEmail,
        mfaEnrolled: false,
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
      expect(json['user']['mfa_type'], equals('email_otp'));
    });

    test('returns 401 for expired activation code', () async {
      // Try to activate with an expired code
      final token = createMockEmulatorToken(
        'firebase-expired-uid',
        testExpiredUserEmail,
        mfaEnrolled: true,
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': testExpiredCode},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('expired'));
    });

    test('returns 400 for already activated user', () async {
      // Try to activate a user that's already active
      final token = createMockEmulatorToken(
        testAlreadyActiveFirebaseUid,
        testAlreadyActiveEmail,
        mfaEnrolled: true,
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': testAlreadyActiveCode},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('already activated'));
    });

    test('Developer Admin activates successfully with MFA enrolled', () async {
      // Developer Admin with MFA enrolled should succeed
      final token = createMockEmulatorToken(
        testDevAdminPendingFirebaseUid,
        testDevAdminPendingEmail,
        mfaEnrolled: true,
      );
      final request = createPostRequest(
        '/api/v1/portal/activate',
        {'code': testDevAdminPendingCode},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['user'], isNotNull);
      expect(json['user']['status'], equals('active'));
      expect(json['user']['mfa_type'], equals('totp'));
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
