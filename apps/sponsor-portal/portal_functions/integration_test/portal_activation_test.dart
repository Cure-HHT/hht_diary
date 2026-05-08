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
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-functions-integration-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );
  });
  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
  });
  // Test user data - using fixed UUIDs for reproducibility
  const testDevAdminId = '99991000-0000-0000-0000-000000000001';
  const testDevAdminEmail = 'devadmin@activation-test.example.com';
  const testDevAdminFirebaseUid = 'firebase-devadmin-uid-12345';

  const testPendingUserId = '99991000-0000-0000-0000-000000000002';
  const testPendingUserEmail = 'pending@activation-test.example.com';
  const testActivationCode = 'TEST1-ACT01';

  const testAlreadyActiveUserId = '99991000-0000-0000-0000-000000000003';
  const testAlreadyActiveEmail = 'active@activation-test.example.com';
  const testAlreadyActiveFirebaseUid = 'firebase-active-uid-12345';
  const testAlreadyActiveCode = 'TEST2-ACT02';

  const testExpiredUserId = '99991000-0000-0000-0000-000000000004';
  const testExpiredUserEmail = 'expired@activation-test.example.com';
  const testExpiredCode = 'TEST3-EXPR3';

  // Developer Admin pending user (for Dev-Admin happy path)
  const testDevAdminPendingId = '99991000-0000-0000-0000-000000000005';
  const testDevAdminPendingEmail =
      'devadmin-pending@activation-test.example.com';
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
      ON CONFLICT (LOWER(email)) DO NOTHING
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
      ON CONFLICT (LOWER(email)) DO NOTHING
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
      ON CONFLICT (LOWER(email)) DO NOTHING
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
      ON CONFLICT (LOWER(email)) DO NOTHING
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
      ON CONFLICT (LOWER(email)) DO NOTHING
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
      // Full email returned for Firebase account creation
      expect(json['email'], isNotNull);
      expect(json['email'], isNot(contains('***')));
      // Masked email returned for display in UI
      expect(json['maskedEmail'], isNotNull);
      expect(json['maskedEmail'], contains('***'));
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
    // CUR-1296: handler shape changed from bearer-token-driven (token.email
    // had to match row.email; MFA claim from token gated dev-admin path) to
    // server-owned: POST {code, password}, no bearer. The handler stamps
    // firebase_uid + flips status in one TX; client signs in with the
    // password it just sent. Tests below exercise the new shape.

    // Skipped: bearer-based "email mismatch" test removed — there is no
    // bearer on /portal/activate under CUR-1296 (REQ-d00166-A), and so no
    // email pivot to mismatch from.

    test('returns 400 code_invalid for unknown activation code', () async {
      // REQ-d00166-B: unknown code -> 400 code_invalid.
      final request = createPostRequest('/api/v1/portal/activate', {
        'code': 'WRONG-CODE1',
        'password': 'new-password-12345',
      });
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['code'], equals('code_invalid'));
    });

    test(
      'Developer Admin MFA enrollment gate (REQ-d00166-B)',
      skip:
          'Gate is informational-only until portal_users.totp_enrolled_at '
          'lands; un-skip when the column + UI are wired.',
      () async {
        // Tracker for the deferred Dev-Admin TOTP enforcement at
        // portal_activation.dart:196-207. Re-enable when totp_enrolled_at
        // is added to the schema and the /activate/2fa page writes to it.
      },
    );

    test('non-admin activates (no MFA gate)', () async {
      // REQ-d00166-C+D: happy path for a non-admin pending row.
      // Stamps firebase_uid, flips status to active, returns 200 + roles.
      // Email-OTP MFA is enforced at sign-in time, not here.
      final request = createPostRequest('/api/v1/portal/activate', {
        'code': testActivationCode,
        'password': 'new-password-12345',
      });
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['ok'], isTrue);
      expect(json['roles'], isList);

      // Verify side effects: firebase_uid stamped, status flipped.
      final db = Database.instance;
      final row = await db.execute(
        'SELECT status, firebase_uid FROM portal_users WHERE email = @e',
        parameters: {'e': testPendingUserEmail},
      );
      expect(row.first[0], equals('active'));
      expect(row.first[1], isNotNull);
    });

    test('returns 400 code_expired for expired activation code', () async {
      // REQ-d00166-B: expired code -> 400 code_expired.
      final request = createPostRequest('/api/v1/portal/activate', {
        'code': testExpiredCode,
        'password': 'new-password-12345',
      });
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['code'], equals('code_expired'));
    });

    test('returns 200 already_active=true for already-active user', () async {
      // REQ-d00166-E: idempotent retry-after-success. The handler keeps
      // activation_code in place after a successful activation so a retry
      // with the same code lands on the same row, sees status='active',
      // and short-circuits with already_active=true (no second IdP write).
      final request = createPostRequest('/api/v1/portal/activate', {
        'code': testAlreadyActiveCode,
        'password': 'new-password-12345',
      });
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['ok'], isTrue);
      expect(json['already_active'], isTrue);
    });

    test('Developer Admin activates successfully', () async {
      // Dev-Admin happy path. Same shape as non-admin under the current
      // handler — the TOTP enforcement gate is deferred (see the skipped
      // test above and portal_activation.dart:196-207).
      final request = createPostRequest('/api/v1/portal/activate', {
        'code': testDevAdminPendingCode,
        'password': 'new-password-12345',
      });
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['ok'], isTrue);
      expect(json['roles'], contains('Developer Admin'));
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
      // Use the expired-code pending fixture: pending user whose code
      // has expired is a real re-issue case. Active users are rejected
      // by the active-user guard (covered by the 409 test below).
      final token = createMockEmulatorToken(
        testDevAdminFirebaseUid,
        testDevAdminEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'user_id': testExpiredUserId},
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

    test('returns 409 already_active when target is already active', () async {
      // Regenerating an activation code for an active user would
      // silently flip status back to 'pending' and lock the user
      // out (requirePortalAuth gates on status='active'). The
      // handler must refuse before the destructive UPDATE.
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

      expect(response.statusCode, equals(409));
      final json = await getResponseJson(response);
      expect(json['code'], equals('already_active'));
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
      // Target a non-active user (pending+expired): regenerate-code is
      // refused for active users (409 already_active) by design — see
      // the dedicated 409 test above. The intent here is the
      // by-email-vs-by-user_id lookup branch.
      final token = createMockEmulatorToken(
        testDevAdminFirebaseUid,
        testDevAdminEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'email': testExpiredUserEmail},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['user']['email'], equals(testExpiredUserEmail));
    });

    test('can generate code by email regardless of case', () async {
      // Pins the case-insensitive lookup at portal_activation.dart so a
      // regression to case-sensitive `WHERE email = @email` would fail here.
      // Target a non-active user (pending+expired) for the same reason
      // as the previous test.
      final token = createMockEmulatorToken(
        testDevAdminFirebaseUid,
        testDevAdminEmail,
      );
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        {'email': testExpiredUserEmail.toUpperCase()},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      // DB returns the row's stored case; we just want the match to work.
      expect(
        (json['user']['email'] as String).toLowerCase(),
        equals(testExpiredUserEmail.toLowerCase()),
      );
    });
  });
}
