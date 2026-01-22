// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: First Admin Provisioning
//   REQ-CAL-p00043: Password Requirements
//   REQ-CAL-p00062: Activation Link Expiration
//   REQ-CAL-p00071: 2FA Setup During Activation
//
// Integration test for JNY-portal-admin-00: First Admin Activation
//
// This test validates the complete activation journey:
// 1. First admin receives activation email (simulated by creating pending user)
// 2. Clicks activation link (validated via API)
// 3. Sets password in Firebase
// 4. Completes 2FA setup (email OTP for non-dev-admin)
// 5. Account becomes active
//
// Prerequisites:
// - PostgreSQL database running with schema applied
// - Auth: Either Firebase emulator (default) or GCP Identity Platform (--dev mode)
// - Portal server running on localhost:8080

@TestOn('vm')
@Tags(['api'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  late TestDatabase db;
  late FirebaseEmulatorAuth? firebaseAuth;
  late IdentityPlatformAuth? identityAuth;
  late TestPortalApiClient apiClient;

  // Flag for which auth mode we're using
  late bool useDevIdentity;

  // Test user data
  const testEmail = 'lisa.chen@integration-test.example.com';
  const testName = 'Dr. Lisa Chen';
  const testPassword = 'SecureP@ssw0rd123';

  /// Helper to create user in auth provider
  Future<({String uid, String idToken})?> createAuthUser({
    required String email,
    required String password,
  }) async {
    if (useDevIdentity) {
      return await identityAuth!.createUser(email: email, password: password);
    } else {
      return await firebaseAuth!.createUser(email: email, password: password);
    }
  }

  /// Helper to sign in to auth provider
  Future<({String uid, String idToken})?> signInAuthUser({
    required String email,
    required String password,
  }) async {
    if (useDevIdentity) {
      return await identityAuth!.signIn(email: email, password: password);
    } else {
      return await firebaseAuth!.signIn(email: email, password: password);
    }
  }

  setUpAll(() async {
    db = TestDatabase();
    await db.connect();

    // Determine auth mode based on environment
    useDevIdentity = TestConfig.useDevIdentity;

    if (useDevIdentity) {
      // Use real GCP Identity Platform
      identityAuth = IdentityPlatformAuth();
      firebaseAuth = null;
      stderr.writeln(
        'Using GCP Identity Platform (project: ${TestConfig.identityProjectId})',
      );
    } else {
      // Use Firebase emulator
      firebaseAuth = FirebaseEmulatorAuth();
      identityAuth = null;
      stderr.writeln(
        'Using Firebase emulator (${TestConfig.firebaseEmulatorHost})',
      );
    }

    apiClient = TestPortalApiClient();

    // Verify server is running
    final healthy = await apiClient.healthCheck();
    if (!healthy) {
      fail(
        'Portal server not running at ${TestConfig.portalServerUrl}. '
        'Start with: ./tool/run_local.sh',
      );
    }
  });

  tearDownAll(() async {
    await db.cleanupTestData();
    await db.close();
    apiClient.close();
  });

  group('JNY-portal-admin-00: First Admin Activation', () {
    late String activationCode;

    // Use setUpAll to create the user ONCE for all tests in this group
    // Tests run sequentially and share state (activation persists)
    setUpAll(() async {
      // Clean up any previous test data
      await db.cleanupTestData();

      // Create a pending admin user (simulates ops team provisioning)
      final result = await db.createPendingAdminUser(
        email: testEmail,
        name: testName,
      );
      activationCode = result.activationCode;
    });

    test('Step 1-2: Activation email contains valid link', () async {
      // In production, user receives email with activation link.
      // Here we verify the activation code is valid.
      final result = await apiClient.validateActivationCode(activationCode);

      expect(
        result['valid'],
        isTrue,
        reason: 'Activation code should be valid',
      );
      expect(
        result['email'],
        contains('***'),
        reason: 'Email should be masked for security',
      );
    });

    test('Step 3-6: User sets password in Identity Platform', () async {
      // Create auth account with the test email and password
      // This simulates user clicking link and setting password
      final authResult = await createAuthUser(
        email: testEmail,
        password: testPassword,
      );

      expect(authResult, isNotNull, reason: 'Should create auth user');
      expect(authResult!.uid, isNotEmpty, reason: 'Should have UID');
      expect(authResult.idToken, isNotEmpty, reason: 'Should have ID token');
    });

    test(
      'Step 7-9: Complete activation with email OTP (non-dev-admin)',
      () async {
        // Sign in to auth provider to get fresh token
        final authResult = await signInAuthUser(
          email: testEmail,
          password: testPassword,
        );
        expect(authResult, isNotNull, reason: 'Should sign in');

        // Activate the portal account
        // For Administrator (not Developer Admin), email OTP is used
        final activateResult = await apiClient.activateUser(
          code: activationCode,
          idToken: authResult!.idToken,
        );

        expect(
          activateResult.statusCode,
          equals(200),
          reason: 'Activation should succeed',
        );
        expect(activateResult.body['success'], isTrue);
        expect(activateResult.body['user'], isNotNull);
        expect(activateResult.body['user']['status'], equals('active'));
        expect(
          activateResult.body['user']['mfa_type'],
          equals('email_otp'),
          reason: 'Administrator uses email OTP, not TOTP',
        );
      },
    );

    test('Step 10: Activated user can access admin dashboard', () async {
      // Sign in to get fresh token
      final authResult = await signInAuthUser(
        email: testEmail,
        password: testPassword,
      );
      expect(authResult, isNotNull);

      // Fetch user info - should now be authorized
      final meResult = await apiClient.getMe(authResult!.idToken);

      expect(
        meResult.statusCode,
        equals(200),
        reason: 'Activated user should be authorized',
      );
      expect(meResult.body['email'], equals(testEmail));
      expect(meResult.body['status'], equals('active'));
    });

    test('Step 11: Admin can view user list', () async {
      final authResult = await signInAuthUser(
        email: testEmail,
        password: testPassword,
      );
      expect(authResult, isNotNull);

      // As admin, should be able to get user list
      final usersResult = await apiClient.getUsers(authResult!.idToken);

      expect(
        usersResult.statusCode,
        equals(200),
        reason: 'Admin should access user list',
      );
      expect(usersResult.body['users'], isA<List>());
    });

    test('Activation link cannot be reused', () async {
      // User was already activated in "Step 7-9" test above.
      // Activation codes are one-time use - the code is deleted after activation.
      // Trying to reuse the same code should fail with "Invalid" (code not found).

      final authResult = await signInAuthUser(
        email: testEmail,
        password: testPassword,
      );

      // Try to use the same activation code again (already consumed)
      final secondActivation = await apiClient.activateUser(
        code: activationCode,
        idToken: authResult!.idToken,
      );

      // Code was deleted after first use, so returns 401 "Invalid"
      expect(
        secondActivation.statusCode,
        equals(401),
        reason: 'Consumed activation code should be rejected as invalid',
      );
      expect(
        secondActivation.body['error'].toString().toLowerCase(),
        contains('invalid'),
      );
    });

    test('Expired activation code is rejected', () async {
      // Create user with expired activation code
      const expiredEmail = 'expired.admin@integration-test.example.com';
      await db.execute(
        '''
        INSERT INTO portal_users (email, name, status, activation_code, activation_code_expires_at)
        VALUES (@email, 'Expired Admin', 'pending', 'EXPR1-TEST1', @expiry)
      ''',
        parameters: {
          'email': expiredEmail,
          'expiry': DateTime.now().subtract(const Duration(days: 1)),
        },
      );

      // Create auth user
      final authResult = await createAuthUser(
        email: expiredEmail,
        password: testPassword,
      );

      // Try to activate with expired code
      final activateResult = await apiClient.activateUser(
        code: 'EXPR1-TEST1',
        idToken: authResult!.idToken,
      );

      expect(
        activateResult.statusCode,
        equals(401),
        reason: 'Expired code should be rejected',
      );
      expect(
        activateResult.body['error'].toString().toLowerCase(),
        contains('expired'),
      );
    });

    test('Invalid activation code is rejected', () async {
      final authResult = await signInAuthUser(
        email: testEmail,
        password: testPassword,
      );

      final activateResult = await apiClient.activateUser(
        code: 'INVALID-CODE',
        idToken: authResult!.idToken,
      );

      expect(
        activateResult.statusCode,
        equals(401),
        reason: 'Invalid code should be rejected',
      );
      expect(
        activateResult.body['error'].toString().toLowerCase(),
        contains('invalid'),
      );
    });
  });
}
