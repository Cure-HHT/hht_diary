// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00029: Create User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-CAL-p00062: Activation Link Expiration
//
// Integration test for JNY-portal-admin-01: Admin Creates New User
//
// This test validates the complete user creation journey:
// 1. Admin logs into portal
// 2. Admin creates a new Investigator with site assignment
// 3. System sends activation email (captured via API response)
// 4. New user's account shows "Pending Activation" status
// 5. New user receives activation code and activates account
// 6. New user can now access the portal
//
// Prerequisites:
// - PostgreSQL database running with schema applied
// - Auth: Either Firebase emulator (default) or GCP Identity Platform (--dev mode)
// - Portal server running on localhost:8080
// - Sites seeded in database (callisto seed data)

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

  // Admin user - seeded dev admin
  const adminEmail = 'mike.bushe@anspar.org';
  // Password from environment or default (must match seed_identity_users.js)
  final adminPassword = Platform.environment['DEV_ADMIN_PASSWORD'] ?? 'curehht';

  // New user to be created (Sarah Martinez - Investigator)
  const newUserEmail = 'sarah.martinez@integration-test.example.com';
  const newUserName = 'Sarah Martinez';
  const newUserPassword = 'SecureP@ssw0rd456';

  // CRA user test
  const craUserEmail = 'james.wilson@integration-test.example.com';
  const craUserName = 'James Wilson';

  // Multi-role user test
  const multiRoleUserEmail = 'multi.role@integration-test.example.com';
  const multiRoleUserName = 'Multi Role User';

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

  group('JNY-portal-admin-01: Admin Creates New User', () {
    late String adminToken;
    late List<String> availableSiteIds;

    setUp(() async {
      // Clean up test users (but not seeded dev admins)
      await db.cleanupTestData();

      // Sign in as admin (seeded dev admin)
      final authResult = await signInAuthUser(
        email: adminEmail,
        password: adminPassword,
      );

      if (authResult == null) {
        final authType = useDevIdentity
            ? 'Identity Platform'
            : 'Firebase emulator';
        fail(
          'Could not sign in as admin. Is $authType running '
          'with seeded users? Run: ./tool/run_local.sh --reset',
        );
      }

      adminToken = authResult.idToken;

      // Fetch available sites
      final sitesResult = await apiClient.getSites(adminToken);
      expect(
        sitesResult.statusCode,
        equals(200),
        reason: 'Should fetch sites for user creation',
      );

      final sites = sitesResult.body['sites'] as List;
      availableSiteIds = sites.map((s) => s['site_id'] as String).toList();

      if (availableSiteIds.isEmpty) {
        fail('No sites available. Run: ./tool/run_local.sh --reset');
      }
    });

    test('Step 1: Admin can log in and access dashboard', () async {
      final meResult = await apiClient.getMe(adminToken);

      expect(meResult.statusCode, equals(200));
      expect(meResult.body['email'], equals(adminEmail));
      // Dev admin has Developer Admin role
      expect(
        meResult.body['roles'],
        anyOf(contains('Developer Admin'), contains('Administrator')),
      );
    });

    test('Step 2-7: Admin creates Investigator with site', () async {
      // Create new user with Investigator role and site assignment
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: newUserName,
        email: newUserEmail,
        roles: ['Investigator'],
        siteIds: [availableSiteIds.first],
      );

      expect(
        createResult.statusCode,
        equals(201),
        reason: 'User creation should succeed',
      );
      expect(createResult.body['id'], isNotEmpty);
      expect(createResult.body['email'], equals(newUserEmail));
      expect(createResult.body['name'], equals(newUserName));
      expect(createResult.body['status'], equals('pending'));
      expect(createResult.body['roles'], contains('Investigator'));

      // Activation code is returned (for testing, bypasses email)
      expect(createResult.body['activation_code'], isNotNull);
      expect(
        createResult.body['activation_code'],
        matches(RegExp(r'^[A-Z0-9]{5}-[A-Z0-9]{5}$')),
      );
    });

    test('Step 8-9: New user shows Pending Activation status', () async {
      // Create the user first
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: newUserName,
        email: newUserEmail,
        roles: ['Investigator'],
        siteIds: [availableSiteIds.first],
      );
      expect(createResult.statusCode, equals(201));

      // Check user appears in user list with pending status
      final usersResult = await apiClient.getUsers(adminToken);
      expect(usersResult.statusCode, equals(200));

      final users = usersResult.body['users'] as List;
      final newUser = users.firstWhere(
        (u) => u['email'] == newUserEmail,
        orElse: () => null,
      );

      expect(newUser, isNotNull, reason: 'New user should appear in list');
      expect(newUser['status'], equals('pending'));
      expect(newUser['name'], equals(newUserName));
    });

    test('Step 10-12: New user activates and becomes active', () async {
      // Create user and get activation code
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: newUserName,
        email: newUserEmail,
        roles: ['Investigator'],
        siteIds: [availableSiteIds.first],
      );
      final activationCode = createResult.body['activation_code'] as String;

      // Create auth account for new user
      final newUserAuth = await createAuthUser(
        email: newUserEmail,
        password: newUserPassword,
      );
      expect(newUserAuth, isNotNull);

      // Activate the account
      final activateResult = await apiClient.activateUser(
        code: activationCode,
        idToken: newUserAuth!.idToken,
      );

      expect(activateResult.statusCode, equals(200));
      expect(activateResult.body['success'], isTrue);
      expect(activateResult.body['user']['status'], equals('active'));

      // New user can now access portal
      final newUserToken = (await signInAuthUser(
        email: newUserEmail,
        password: newUserPassword,
      ))!.idToken;

      final meResult = await apiClient.getMe(newUserToken);
      expect(meResult.statusCode, equals(200));
      expect(meResult.body['email'], equals(newUserEmail));
      expect(meResult.body['status'], equals('active'));
    });

    test('Sponsor role can be created without site', () async {
      // Sponsor role (CRA in Callisto) does not require site assignment
      // Note: CRA maps to Auditor system role, Sponsor is for sponsor-level oversight
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: craUserName,
        email: craUserEmail,
        roles: ['Sponsor'],
        // No siteIds required for Sponsor role
      );

      expect(
        createResult.statusCode,
        equals(201),
        reason: 'Sponsor without site should succeed',
      );
      expect(createResult.body['roles'], contains('Sponsor'));
    });

    test('Site-based role without site is rejected', () async {
      // Try to create Investigator without sites
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: 'No Site User',
        email: 'nosite@integration-test.example.com',
        roles: ['Investigator'],
        // No siteIds
      );

      expect(
        createResult.statusCode,
        equals(400),
        reason: 'Investigator without site should fail',
      );
      expect(
        createResult.body['error'].toString().toLowerCase(),
        contains('site'),
      );
    });

    test('Administrator role does not require site', () async {
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: 'Admin User',
        email: 'admin.user@integration-test.example.com',
        roles: ['Administrator'],
        // No siteIds needed for admin
      );

      expect(
        createResult.statusCode,
        equals(201),
        reason: 'Administrator without site should succeed',
      );
    });

    test('Multi-role user creation with Investigator + Auditor', () async {
      // User with multiple roles (one requires sites, one doesn't)
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: multiRoleUserName,
        email: multiRoleUserEmail,
        roles: ['Investigator', 'Auditor'],
        siteIds: [availableSiteIds.first], // Required for Investigator
      );

      expect(createResult.statusCode, equals(201));
      expect(
        createResult.body['roles'],
        containsAll(['Investigator', 'Auditor']),
      );
    });

    test('Duplicate email is rejected', () async {
      // Create first user
      await apiClient.createUser(
        idToken: adminToken,
        name: newUserName,
        email: newUserEmail,
        roles: ['Investigator'],
        siteIds: [availableSiteIds.first],
      );

      // Try to create another user with same email
      final duplicateResult = await apiClient.createUser(
        idToken: adminToken,
        name: 'Duplicate User',
        email: newUserEmail,
        roles: ['Auditor'],
      );

      expect(
        duplicateResult.statusCode,
        equals(409),
        reason: 'Duplicate email should be rejected',
      );
      expect(
        duplicateResult.body['error'].toString().toLowerCase(),
        contains('email'),
      );
    });

    test('Invalid role is rejected', () async {
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: 'Invalid Role User',
        email: 'invalid.role@integration-test.example.com',
        roles: ['SuperAdmin'], // Invalid role
      );

      expect(createResult.statusCode, equals(400));
      expect(createResult.body['error'], contains('Invalid role'));
    });

    test('Email activation response includes email_sent status', () async {
      // When email service is configured, response should indicate status
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: newUserName,
        email: newUserEmail,
        roles: ['Investigator'],
        siteIds: [availableSiteIds.first],
      );

      expect(createResult.statusCode, equals(201));
      // email_sent field indicates whether activation email was sent
      expect(
        createResult.body.containsKey('email_sent'),
        isTrue,
        reason: 'Response should include email_sent status',
      );
    });
  });
}
