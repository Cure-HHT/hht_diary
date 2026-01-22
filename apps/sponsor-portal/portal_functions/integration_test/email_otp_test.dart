// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Integration tests for email OTP handlers
// Requires PostgreSQL database with schema applied

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  // Test user data
  const testUserId = '99992000-0000-0000-0000-000000000001';
  const testUserEmail = 'otp-test@email-otp-test.example.com';
  const testUserFirebaseUid = 'firebase-otp-test-uid-12345';

  const testInactiveUserId = '99992000-0000-0000-0000-000000000002';
  const testInactiveEmail = 'inactive@email-otp-test.example.com';
  const testInactiveFirebaseUid = 'firebase-inactive-uid-12345';

  const testNoUserFirebaseUid = 'firebase-no-user-uid-12345';

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

    // Initialize email service (won't actually send emails in test)
    final emailConfig = EmailConfig(
      senderEmail: 'test@test.com',
      enabled: false, // Disable actual email sending
    );
    await EmailService.instance.initialize(emailConfig);

    // Clean up any previous test data
    final db = Database.instance;
    await db.execute(
      'DELETE FROM email_otp_codes WHERE user_id IN (@userId::uuid, @inactiveId::uuid)',
      parameters: {'userId': testUserId, 'inactiveId': testInactiveUserId},
    );
    await db.execute(
      'DELETE FROM email_rate_limits WHERE email LIKE @pattern',
      parameters: {'pattern': '%@email-otp-test.example.com'},
    );
    await db.execute(
      'DELETE FROM portal_user_roles WHERE user_id IN (@userId::uuid, @inactiveId::uuid)',
      parameters: {'userId': testUserId, 'inactiveId': testInactiveUserId},
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@email-otp-test.example.com'},
    );

    // Create active test user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'OTP Test User', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testUserId,
        'email': testUserEmail,
        'firebaseUid': testUserFirebaseUid,
      },
    );

    // Add Investigator role
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Investigator')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testUserId},
    );

    // Create inactive test user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Inactive Test User', @firebaseUid, 'pending')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testInactiveUserId,
        'email': testInactiveEmail,
        'firebaseUid': testInactiveFirebaseUid,
      },
    );
  });

  tearDownAll(() async {
    // Clean up test data
    final db = Database.instance;
    await db.execute(
      'DELETE FROM email_otp_codes WHERE user_id IN (@userId::uuid, @inactiveId::uuid)',
      parameters: {'userId': testUserId, 'inactiveId': testInactiveUserId},
    );
    await db.execute(
      'DELETE FROM email_rate_limits WHERE email LIKE @pattern',
      parameters: {'pattern': '%@email-otp-test.example.com'},
    );
    await db.execute(
      'DELETE FROM portal_user_roles WHERE user_id IN (@userId::uuid, @inactiveId::uuid)',
      parameters: {'userId': testUserId, 'inactiveId': testInactiveUserId},
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@email-otp-test.example.com'},
    );

    await Database.instance.close();
  });

  /// Create a mock emulator token for testing
  String createMockEmulatorToken(String uid, String email) {
    final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': uid,
          'user_id': uid,
          'email': email,
          'email_verified': true,
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }),
      ),
    );
    return '$header.$payload.';
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
      headers: {'content-type': 'application/json', ...?headers},
    );
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final body = await response.readAsString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('sendEmailOtpHandler', () {
    test('returns 401 for missing authorization', () async {
      final request = createPostRequest('/api/v1/portal/auth/send-otp', {});

      final response = await sendEmailOtpHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 for invalid token', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/send-otp',
        {},
        headers: {'authorization': 'Bearer invalid-token'},
      );

      final response = await sendEmailOtpHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 404 for user not in database', () async {
      final token = createMockEmulatorToken(
        testNoUserFirebaseUid,
        'nouser@example.com',
      );
      final request = createPostRequest(
        '/api/v1/portal/auth/send-otp',
        {},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await sendEmailOtpHandler(request);

      expect(response.statusCode, equals(404));
      final json = await getResponseJson(response);
      expect(json['error'], contains('not found'));
    });

    test('returns 403 for inactive user', () async {
      final token = createMockEmulatorToken(
        testInactiveFirebaseUid,
        testInactiveEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/auth/send-otp',
        {},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await sendEmailOtpHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], contains('not active'));
    });

    test('returns 500 when email service not ready (active user)', () async {
      // Email service is disabled in test setup, so this should fail
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/send-otp',
        {},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await sendEmailOtpHandler(request);

      // Should fail at email sending step
      expect(response.statusCode, equals(500));
      final json = await getResponseJson(response);
      expect(json['error'], contains('email'));
    });

    test('returns 429 when rate limited', () async {
      // Insert rate limit records to trigger rate limiting
      final db = Database.instance;
      final now = DateTime.now().toUtc();

      // Add 3 rate limit records within 15 minutes
      for (var i = 0; i < 3; i++) {
        await db.execute(
          '''
          INSERT INTO email_rate_limits (email, email_type, sent_at)
          VALUES (@email, 'otp', @sentAt)
          ''',
          parameters: {
            'email': testUserEmail,
            'sentAt': now.subtract(Duration(minutes: i)).toIso8601String(),
          },
        );
      }

      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/send-otp',
        {},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await sendEmailOtpHandler(request);

      expect(response.statusCode, equals(429));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Too many'));
      expect(json['retry_after'], equals(900));
    });
  });

  group('verifyEmailOtpHandler', () {
    test('returns 401 for missing authorization', () async {
      final request = createPostRequest('/api/v1/portal/auth/verify-otp', {
        'code': '123456',
      });

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 400 for missing code', () async {
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/verify-otp',
        {},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Missing code'));
    });

    test('returns 400 for invalid code format', () async {
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);

      // Test various invalid formats
      final invalidCodes = ['12345', '1234567', 'abcdef', '12 345'];
      for (final code in invalidCodes) {
        final request = createPostRequest(
          '/api/v1/portal/auth/verify-otp',
          {'code': code},
          headers: {'authorization': 'Bearer $token'},
        );

        final response = await verifyEmailOtpHandler(request);

        expect(
          response.statusCode,
          equals(400),
          reason: 'Code "$code" should return 400',
        );
      }
    });

    test('returns 400 for invalid JSON body', () async {
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/portal/auth/verify-otp'),
        body: 'not json',
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
        },
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid JSON'));
    });

    test('returns 404 for user not in database', () async {
      final token = createMockEmulatorToken(
        testNoUserFirebaseUid,
        'nouser@example.com',
      );
      final request = createPostRequest(
        '/api/v1/portal/auth/verify-otp',
        {'code': '123456'},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(404));
    });

    test('returns 422 for invalid OTP code (no matching code in DB)', () async {
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/verify-otp',
        {'code': '999999'}, // Valid format but wrong code
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(422));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid'));
    });

    test('successfully verifies valid OTP code', () async {
      // First, insert a valid OTP code directly into the database
      final db = Database.instance;
      final code = '123456';
      final codeHash = hashOtpCode(code);
      // Use UTC to match PostgreSQL's NOW() function
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));

      await db.execute(
        '''
        INSERT INTO email_otp_codes (user_id, code_hash, expires_at)
        VALUES (@userId::uuid, @codeHash, @expiresAt)
        ''',
        parameters: {
          'userId': testUserId,
          'codeHash': codeHash,
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      // Now verify the code
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/verify-otp',
        {'code': code},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['email_otp_verified'], isTrue);
    });

    test('returns 410 for expired OTP code', () async {
      // Insert an expired OTP code
      final db = Database.instance;
      final code = '654321';
      final codeHash = hashOtpCode(code);
      // Use UTC and subtract more time to avoid any timezone edge cases
      final expiresAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );

      await db.execute(
        '''
        INSERT INTO email_otp_codes (user_id, code_hash, expires_at)
        VALUES (@userId::uuid, @codeHash, @expiresAt)
        ''',
        parameters: {
          'userId': testUserId,
          'codeHash': codeHash,
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      // Try to verify the expired code
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/verify-otp',
        {'code': code},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(410));
      final json = await getResponseJson(response);
      expect(json['error'], contains('expired'));
      expect(json['expired'], isTrue);
    });

    test('returns 403 for max failed attempts exceeded', () async {
      // Insert a valid OTP code with max attempts already reached
      final db = Database.instance;
      final code = '111222';
      final codeHash = hashOtpCode(code);
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));

      await db.execute(
        '''
        INSERT INTO email_otp_codes (user_id, code_hash, expires_at, attempts)
        VALUES (@userId::uuid, @codeHash, @expiresAt, 5)
        ''',
        parameters: {
          'userId': testUserId,
          'codeHash': codeHash,
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      // Try to verify with the correct code but max attempts already reached
      final token = createMockEmulatorToken(testUserFirebaseUid, testUserEmail);
      final request = createPostRequest(
        '/api/v1/portal/auth/verify-otp',
        {'code': code},
        headers: {'authorization': 'Bearer $token'},
      );

      final response = await verifyEmailOtpHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Too many failed attempts'));
      expect(json['max_attempts_reached'], isTrue);
    });
  });

  group('OTP utility functions', () {
    test('generateOtpCode generates 6-digit codes', () {
      for (var i = 0; i < 10; i++) {
        final code = generateOtpCode();
        expect(code.length, equals(6));
        expect(RegExp(r'^\d{6}$').hasMatch(code), isTrue);
      }
    });

    test('hashOtpCode produces consistent SHA-256 hashes', () {
      final hash1 = hashOtpCode('123456');
      final hash2 = hashOtpCode('123456');
      final hash3 = hashOtpCode('654321');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.length, equals(64)); // SHA-256 hex length
    });
  });
}
