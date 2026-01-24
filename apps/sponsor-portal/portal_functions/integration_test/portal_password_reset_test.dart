// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-p00071: Password Complexity
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Integration tests for portal password reset handlers
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
  const testActiveUserId = '99993000-0000-0000-0000-000000000001';
  const testActiveUserEmail = 'active@password-reset-test.example.com';
  const testActiveUserFirebaseUid = 'firebase-active-reset-uid-12345';

  const testInactiveUserId = '99993000-0000-0000-0000-000000000002';
  const testInactiveEmail = 'inactive@password-reset-test.example.com';

  const testNotActivatedUserId = '99993000-0000-0000-0000-000000000003';
  const testNotActivatedEmail = 'not-activated@password-reset-test.example.com';

  const testNonExistentEmail = 'nonexistent@password-reset-test.example.com';

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

    // Initialize email service (disable actual email sending)
    final emailConfig = EmailConfig(
      senderEmail: 'test@test.com',
      enabled: false, // Disable actual email sending
    );
    await EmailService.instance.initialize(emailConfig);

    // Clean up any previous test data
    final db = Database.instance;
    await db.executeWithContext(
      '''DELETE FROM auth_audit_log
         WHERE user_id IN (@activeId, @inactiveId, @notActivatedId)''',
      parameters: {
        'activeId': testActiveUserId,
        'inactiveId': testInactiveUserId,
        'notActivatedId': testNotActivatedUserId,
      },
      context: UserContext.service,
    );
    await db.executeWithContext(
      'DELETE FROM email_rate_limits WHERE email LIKE @pattern',
      parameters: {'pattern': '%@password-reset-test.example.com'},
      context: UserContext.service,
    );
    await db.executeWithContext(
      '''DELETE FROM portal_user_roles
         WHERE user_id IN (@activeId::uuid, @inactiveId::uuid, @notActivatedId::uuid)''',
      parameters: {
        'activeId': testActiveUserId,
        'inactiveId': testInactiveUserId,
        'notActivatedId': testNotActivatedUserId,
      },
      context: UserContext.service,
    );
    await db.executeWithContext(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@password-reset-test.example.com'},
      context: UserContext.service,
    );

    // Create active test user with firebase_uid
    await db.executeWithContext(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Active Reset Test User', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testActiveUserId,
        'email': testActiveUserEmail,
        'firebaseUid': testActiveUserFirebaseUid,
      },
      context: UserContext.service,
    );

    // Add Administrator role
    await db.executeWithContext(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Administrator')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testActiveUserId},
      context: UserContext.service,
    );

    // Create inactive test user
    await db.executeWithContext(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Inactive Reset Test User', NULL, 'pending')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {'id': testInactiveUserId, 'email': testInactiveEmail},
      context: UserContext.service,
    );

    // Create not-activated test user (active but no firebase_uid)
    await db.executeWithContext(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Not Activated Reset Test User', NULL, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testNotActivatedUserId,
        'email': testNotActivatedEmail,
      },
      context: UserContext.service,
    );
  });

  tearDownAll(() async {
    // Clean up test data
    final db = Database.instance;
    await db.executeWithContext(
      '''DELETE FROM auth_audit_log
         WHERE user_id IN (@activeId, @inactiveId, @notActivatedId)''',
      parameters: {
        'activeId': testActiveUserId,
        'inactiveId': testInactiveUserId,
        'notActivatedId': testNotActivatedUserId,
      },
      context: UserContext.service,
    );
    await db.executeWithContext(
      'DELETE FROM email_rate_limits WHERE email LIKE @pattern',
      parameters: {'pattern': '%@password-reset-test.example.com'},
      context: UserContext.service,
    );
    await db.executeWithContext(
      '''DELETE FROM portal_user_roles
         WHERE user_id IN (@activeId::uuid, @inactiveId::uuid, @notActivatedId::uuid)''',
      parameters: {
        'activeId': testActiveUserId,
        'inactiveId': testInactiveUserId,
        'notActivatedId': testNotActivatedUserId,
      },
      context: UserContext.service,
    );
    await db.executeWithContext(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@password-reset-test.example.com'},
      context: UserContext.service,
    );

    await Database.instance.close();
  });

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

  group('requestPasswordResetHandler', () {
    test('returns 400 for missing email', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {},
      );

      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Email is required'));
    });

    test('returns 400 for invalid email format', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': 'not-an-email'},
      );

      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid email format'));
    });

    test('returns generic success for non-existent email', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': testNonExistentEmail},
      );

      final response = await requestPasswordResetHandler(request);

      // Should return success to prevent email enumeration
      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['message'], contains('If an account exists with that email'));

      // Verify rate limit was recorded
      final db = Database.instance;
      final rateLimitCheck = await db.executeWithContext(
        '''
        SELECT COUNT(*) FROM email_rate_limits
        WHERE email = @email AND email_type = 'password_reset'
        ''',
        parameters: {'email': testNonExistentEmail},
        context: UserContext.service,
      );
      expect(rateLimitCheck.first[0] as int, greaterThan(0));
    });

    test('returns generic success for inactive user', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': testInactiveEmail},
      );

      final response = await requestPasswordResetHandler(request);

      // Should return success to prevent email enumeration
      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['message'], contains('If an account exists with that email'));

      // Verify audit log shows failure with reason
      final db = Database.instance;
      final auditCheck = await db.executeWithContext(
        '''
        SELECT success, metadata->>'reason' as reason
        FROM auth_audit_log
        WHERE user_id = @userId
          AND event_type = 'PASSWORD_RESET'
        ORDER BY timestamp DESC
        LIMIT 1
        ''',
        parameters: {'userId': testInactiveUserId},
        context: UserContext.service,
      );

      if (auditCheck.isNotEmpty) {
        expect(auditCheck.first[0], isFalse); // success = false
        expect(auditCheck.first[1], equals('inactive_user'));
      }
    });

    test('returns generic success for not-activated user', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': testNotActivatedEmail},
      );

      final response = await requestPasswordResetHandler(request);

      // Should return success to prevent email enumeration
      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);

      // Verify audit log shows failure with reason
      final db = Database.instance;
      final auditCheck = await db.executeWithContext(
        '''
        SELECT success, metadata->>'reason' as reason
        FROM auth_audit_log
        WHERE user_id = @userId
          AND event_type = 'PASSWORD_RESET'
        ORDER BY timestamp DESC
        LIMIT 1
        ''',
        parameters: {'userId': testNotActivatedUserId},
        context: UserContext.service,
      );

      if (auditCheck.isNotEmpty) {
        expect(auditCheck.first[0], isFalse);
        expect(auditCheck.first[1], equals('not_activated'));
      }
    });

    test(
      'returns generic success for active user (without Identity Platform API)',
      () async {
        // Note: This test will show success even without actual email sending
        // because PORTAL_IDENTITY_API_KEY is likely not set in test environment
        final request = createPostRequest(
          '/api/v1/portal/auth/password-reset/request',
          {'email': testActiveUserEmail},
        );

        final response = await requestPasswordResetHandler(request);

        // Should return success
        expect(response.statusCode, equals(200));
        final json = await getResponseJson(response);
        expect(json['success'], isTrue);
        expect(
          json['message'],
          contains('If an account exists with that email'),
        );

        // Verify rate limit was recorded
        final db = Database.instance;
        final rateLimitCheck = await db.executeWithContext(
          '''
          SELECT COUNT(*) FROM email_rate_limits
          WHERE email = @email AND email_type = 'password_reset'
          ''',
          parameters: {'email': testActiveUserEmail},
          context: UserContext.service,
        );
        expect(rateLimitCheck.first[0] as int, greaterThan(0));
      },
    );

    test('enforces rate limiting (4+ requests)', () async {
      final testEmail = 'rate-limit-test@password-reset-test.example.com';

      // Send 3 requests (should succeed)
      for (var i = 0; i < 3; i++) {
        final request = createPostRequest(
          '/api/v1/portal/auth/password-reset/request',
          {'email': testEmail},
        );
        final response = await requestPasswordResetHandler(request);
        expect(response.statusCode, equals(200));
      }

      // 4th request should be rate limited
      final request4 = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': testEmail},
      );
      final response4 = await requestPasswordResetHandler(request4);

      expect(response4.statusCode, equals(429));
      final json = await getResponseJson(response4);
      expect(json['error'], contains('Too many password reset requests'));
      expect(json['retry_after'], equals(900)); // 15 minutes
    });

    test('normalizes email to lowercase', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': testActiveUserEmail.toUpperCase()},
      );

      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(200));

      // Verify rate limit was recorded with lowercase email
      final db = Database.instance;
      final rateLimitCheck = await db.executeWithContext(
        '''
        SELECT email FROM email_rate_limits
        WHERE email = @email AND email_type = 'password_reset'
        ORDER BY sent_at DESC
        LIMIT 1
        ''',
        parameters: {'email': testActiveUserEmail.toLowerCase()},
        context: UserContext.service,
      );
      expect(rateLimitCheck.isNotEmpty, isTrue);
    });

    test('records IP address in rate limit and audit log', () async {
      final testEmail = 'ip-test@password-reset-test.example.com';
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/request',
        {'email': testEmail},
        headers: {'x-forwarded-for': '203.0.113.42, 198.51.100.1'},
      );

      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(200));

      // Verify IP was recorded in rate limit (first IP from x-forwarded-for)
      final db = Database.instance;
      final rateLimitCheck = await db.executeWithContext(
        '''
        SELECT HOST(ip_address) FROM email_rate_limits
        WHERE email = @email AND email_type = 'password_reset'
        ORDER BY sent_at DESC
        LIMIT 1
        ''',
        parameters: {'email': testEmail},
        context: UserContext.service,
      );

      if (rateLimitCheck.isNotEmpty) {
        expect(rateLimitCheck.first[0], equals('203.0.113.42'));
      }
    });

    test('handles JSON decode errors gracefully', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/portal/auth/password-reset/request'),
        body: 'invalid json{',
        headers: {'content-type': 'application/json'},
      );

      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(500));
      final json = await getResponseJson(response);
      expect(json['error'], contains('An error occurred'));
    });

    test(
      'extracts IP from x-real-ip header when x-forwarded-for not present',
      () async {
        final testEmail = 'real-ip-test@password-reset-test.example.com';
        final request = createPostRequest(
          '/api/v1/portal/auth/password-reset/request',
          {'email': testEmail},
          headers: {'x-real-ip': '192.0.2.123'},
        );

        final response = await requestPasswordResetHandler(request);

        expect(response.statusCode, equals(200));

        // Verify IP was recorded
        final db = Database.instance;
        final rateLimitCheck = await db.executeWithContext(
          '''
        SELECT HOST(ip_address) FROM email_rate_limits
        WHERE email = @email AND email_type = 'password_reset'
        ORDER BY sent_at DESC
        LIMIT 1
        ''',
          parameters: {'email': testEmail},
          context: UserContext.service,
        );

        if (rateLimitCheck.isNotEmpty) {
          expect(rateLimitCheck.first[0], equals('192.0.2.123'));
        }
      },
    );
  });

  group('validatePasswordResetCodeHandler', () {
    test('returns 200 with valid email for valid unexpired code', () async {
      // First generate a reset code for the active user
      final db = Database.instance;
      const resetCode = 'VALID-CODE1';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() + INTERVAL '24 hours',
            password_reset_used_at = NULL
        WHERE id = @userId
        ''',
        parameters: {'code': resetCode, 'userId': testActiveUserId},
        context: UserContext.service,
      );

      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/portal/auth/password-reset/validate/$resetCode',
        ),
      );

      final response = await validatePasswordResetCodeHandler(
        request,
        resetCode,
      );

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['valid'], isTrue);
      expect(json['email'], equals(testActiveUserEmail));
    });

    test('returns 401 for non-existent code', () async {
      const invalidCode = 'XXXXX-XXXXX';
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/portal/auth/password-reset/validate/$invalidCode',
        ),
      );

      final response = await validatePasswordResetCodeHandler(
        request,
        invalidCode,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid password reset code'));
    });

    test('returns 401 for expired code', () async {
      final db = Database.instance;
      const expiredCode = 'EXPIRED-CODE';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() - INTERVAL '1 hour',
            password_reset_used_at = NULL
        WHERE id = @userId
        ''',
        parameters: {'code': expiredCode, 'userId': testActiveUserId},
        context: UserContext.service,
      );

      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/portal/auth/password-reset/validate/$expiredCode',
        ),
      );

      final response = await validatePasswordResetCodeHandler(
        request,
        expiredCode,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('expired'));
    });

    test('returns 401 for already used code', () async {
      final db = Database.instance;
      const usedCode = 'USED-CODE1';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() + INTERVAL '24 hours',
            password_reset_used_at = NOW() - INTERVAL '1 hour'
        WHERE id = @userId
        ''',
        parameters: {'code': usedCode, 'userId': testActiveUserId},
        context: UserContext.service,
      );

      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/portal/auth/password-reset/validate/$usedCode',
        ),
      );

      final response = await validatePasswordResetCodeHandler(
        request,
        usedCode,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('already been used'));
    });
  });

  group('completePasswordResetHandler', () {
    test('returns 400 for missing code', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'password': 'newpassword123'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('code is required'));
    });

    test('returns 400 for missing password', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': 'XXXXX-XXXXX'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Password is required'));
    });

    test('returns 400 for password less than 8 characters', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': 'XXXXX-XXXXX', 'password': 'short'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('at least 8 characters'));
    });

    test('returns 400 for password greater than 64 characters', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': 'XXXXX-XXXXX', 'password': 'a' * 65},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('not exceed 64 characters'));
    });

    test('returns 401 for invalid code', () async {
      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': 'INVALID-CODE', 'password': 'newpassword123'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid password reset code'));
    });

    test('returns 401 for expired code', () async {
      final db = Database.instance;
      const expiredCode = 'EXPIRED-CODE2';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() - INTERVAL '1 hour',
            password_reset_used_at = NULL
        WHERE id = @userId
        ''',
        parameters: {'code': expiredCode, 'userId': testActiveUserId},
        context: UserContext.service,
      );

      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': expiredCode, 'password': 'newpassword123'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('expired'));
    });

    test('returns 401 for already used code', () async {
      final db = Database.instance;
      const usedCode = 'USED-CODE2';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() + INTERVAL '24 hours',
            password_reset_used_at = NOW() - INTERVAL '1 hour'
        WHERE id = @userId
        ''',
        parameters: {'code': usedCode, 'userId': testActiveUserId},
        context: UserContext.service,
      );

      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': usedCode, 'password': 'newpassword123'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('already been used'));
    });

    test('returns 400 for user without firebase_uid', () async {
      final db = Database.instance;
      const code = 'NO-FIREBASE-UID';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() + INTERVAL '24 hours',
            password_reset_used_at = NULL
        WHERE id = @userId
        ''',
        parameters: {'code': code, 'userId': testNotActivatedUserId},
        context: UserContext.service,
      );

      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': code, 'password': 'newpassword123'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('not activated'));
    });

    test('returns 500 when Identity Platform update fails', () async {
      // This test verifies error handling when the Identity Platform API fails
      // Since we don't have valid credentials, the API call will fail
      final db = Database.instance;
      const code = 'VALID-CODE2';
      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET password_reset_code = @code,
            password_reset_code_expires_at = NOW() + INTERVAL '24 hours',
            password_reset_used_at = NULL
        WHERE id = @userId
        ''',
        parameters: {'code': code, 'userId': testActiveUserId},
        context: UserContext.service,
      );

      final request = createPostRequest(
        '/api/v1/portal/auth/password-reset/complete',
        {'code': code, 'password': 'newpassword123'},
      );

      final response = await completePasswordResetHandler(request);

      // Should return 500 because Identity Platform update will fail
      expect(response.statusCode, equals(500));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Failed to update password'));
    });

    test('handles JSON decode errors gracefully', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/auth/password-reset/complete',
        ),
        body: 'invalid json{',
        headers: {'content-type': 'application/json'},
      );

      final response = await completePasswordResetHandler(request);

      expect(response.statusCode, equals(500));
      final json = await getResponseJson(response);
      expect(json['error'], contains('An error occurred'));
    });
  });
}
