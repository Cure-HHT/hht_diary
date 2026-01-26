// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// Integration test for JNY-portal-admin-02: Admin Modifies User Access
//
// This test validates the complete user edit journey:
// 1. Admin logs in and lists users
// 2. Admin gets a single user's details
// 3. Admin edits user name
// 4. Admin changes user roles and sites
// 5. System terminates active sessions (tokens_revoked_at set)
// 6. Audit log entries are created for all changes
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

  late bool useDevIdentity;

  // Admin user - seeded dev admin
  const adminEmail = 'mike.bushe@anspar.org';
  final adminPassword = Platform.environment['DEV_ADMIN_PASSWORD'] ?? 'curehht';

  // User to be created and then modified
  const targetUserEmail = 'edit.target@user-edit-test.example.com';
  const targetUserName = 'Edit Target User';

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

    useDevIdentity = TestConfig.useDevIdentity;

    if (useDevIdentity) {
      identityAuth = IdentityPlatformAuth();
      firebaseAuth = null;
      stderr.writeln(
        'Using GCP Identity Platform (project: ${TestConfig.identityProjectId})',
      );
    } else {
      firebaseAuth = FirebaseEmulatorAuth();
      identityAuth = null;
      stderr.writeln(
        'Using Firebase emulator (${TestConfig.firebaseEmulatorHost})',
      );
    }

    apiClient = TestPortalApiClient();

    final healthy = await apiClient.healthCheck();
    if (!healthy) {
      fail(
        'Portal server not running at ${TestConfig.portalServerUrl}. '
        'Start with: ./tool/run_local.sh',
      );
    }
  });

  tearDownAll(() async {
    await db.cleanupEditTestData();
    await db.close();
    apiClient.close();
  });

  group('JNY-portal-admin-02: Admin Modifies User Access', () {
    late String adminToken;
    late List<String> availableSiteIds;
    late String targetUserId;

    setUp(() async {
      // Clean up any previous test data
      await db.cleanupEditTestData();

      // Sign in as admin
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
      expect(sitesResult.statusCode, equals(200));
      final sites = sitesResult.body['sites'] as List;
      availableSiteIds = sites.map((s) => s['site_id'] as String).toList();
      if (availableSiteIds.isEmpty) {
        fail('No sites available. Run: ./tool/run_local.sh --reset');
      }

      // Create the target user to be edited
      final createResult = await apiClient.createUser(
        idToken: adminToken,
        name: targetUserName,
        email: targetUserEmail,
        roles: ['Investigator'],
        siteIds: [availableSiteIds.first],
      );
      expect(
        createResult.statusCode,
        equals(201),
        reason: 'Target user creation should succeed',
      );
      targetUserId = createResult.body['id'] as String;
    });

    test('Step 1: Admin can get single user details', () async {
      final result = await apiClient.getUser(adminToken, targetUserId);

      expect(result.statusCode, equals(200));
      expect(result.body['id'], equals(targetUserId));
      expect(result.body['email'], equals(targetUserEmail));
      expect(result.body['name'], equals(targetUserName));
      expect(result.body['status'], equals('pending'));
      expect(result.body['roles'], contains('Investigator'));
      expect(result.body['sites'], isA<List>());
      expect(result.body['created_at'], isNotNull);
    });

    test('Step 2: Admin edits user name', () async {
      const newName = 'Updated Target Name';
      final result = await apiClient.updateUser(
        idToken: adminToken,
        userId: targetUserId,
        name: newName,
      );

      expect(result.statusCode, equals(200));
      expect(result.body['success'], isTrue);

      // Verify name was updated
      final userResult = await apiClient.getUser(adminToken, targetUserId);
      expect(userResult.statusCode, equals(200));
      expect(userResult.body['name'], equals(newName));

      // Verify audit log entry
      final auditLog = await db.getAuditLog(targetUserId);
      final nameChange = auditLog.firstWhere(
        (e) => e['action'] == 'update_name',
        orElse: () => {},
      );
      expect(
        nameChange,
        isNotEmpty,
        reason: 'Audit log should have name change entry',
      );
    });

    test('Step 3: Admin changes roles and sessions are terminated', () async {
      final result = await apiClient.updateUser(
        idToken: adminToken,
        userId: targetUserId,
        roles: ['Investigator', 'Auditor'],
      );

      expect(result.statusCode, equals(200));
      expect(result.body['success'], isTrue);
      expect(
        result.body['sessions_terminated'],
        isTrue,
        reason: 'Role changes should trigger session termination',
      );

      // Verify tokens_revoked_at is set
      final revokedAt = await db.getTokensRevokedAt(targetUserId);
      expect(
        revokedAt,
        isNotNull,
        reason: 'tokens_revoked_at should be set after role change',
      );

      // Verify roles were updated
      final userResult = await apiClient.getUser(adminToken, targetUserId);
      expect(userResult.statusCode, equals(200));
      expect(
        userResult.body['roles'],
        containsAll(['Investigator', 'Auditor']),
      );

      // Verify audit log
      final auditLog = await db.getAuditLog(targetUserId);
      final roleChange = auditLog.firstWhere(
        (e) => e['action'] == 'update_roles',
        orElse: () => {},
      );
      expect(
        roleChange,
        isNotEmpty,
        reason: 'Audit log should have role change entry',
      );
    });

    test('Step 4: Admin changes site assignments', () async {
      // Assign to a different site (or multiple)
      final newSites = availableSiteIds.length > 1
          ? [availableSiteIds[0], availableSiteIds[1]]
          : [availableSiteIds[0]];

      final result = await apiClient.updateUser(
        idToken: adminToken,
        userId: targetUserId,
        siteIds: newSites,
      );

      expect(result.statusCode, equals(200));
      expect(result.body['success'], isTrue);

      // Only flagged as terminated if sites actually changed
      if (newSites.length > 1 || newSites.first != availableSiteIds.first) {
        expect(result.body['sessions_terminated'], isTrue);
      }
    });

    test('Step 5: Self-modification is prevented', () async {
      // Get admin's user ID from /me
      final meResult = await apiClient.getMe(adminToken);
      expect(meResult.statusCode, equals(200));
      final adminUserId = meResult.body['id'] as String;

      // Try to modify self
      final result = await apiClient.updateUser(
        idToken: adminToken,
        userId: adminUserId,
        name: 'Self Modified',
      );

      expect(
        result.statusCode,
        equals(400),
        reason: 'Admin should not be able to modify own account',
      );
      expect(result.body['error'], contains('own account'));
    });

    test('Step 6: Non-existent user returns 404', () async {
      final result = await apiClient.getUser(
        adminToken,
        '00000000-0000-0000-0000-000000000999',
      );

      expect(result.statusCode, equals(404));
    });

    test('Step 7: Full edit journey - name + roles + sites', () async {
      // Single PATCH with name, roles, and sites
      final newSites = availableSiteIds.length > 1
          ? [availableSiteIds[1]]
          : [availableSiteIds[0]];

      final result = await apiClient.updateUser(
        idToken: adminToken,
        userId: targetUserId,
        name: 'Journey Updated Name',
        roles: ['Auditor'],
        siteIds: newSites,
      );

      expect(result.statusCode, equals(200));
      expect(result.body['success'], isTrue);

      // Verify all changes
      final userResult = await apiClient.getUser(adminToken, targetUserId);
      expect(userResult.statusCode, equals(200));
      expect(userResult.body['name'], equals('Journey Updated Name'));
      expect(userResult.body['roles'], contains('Auditor'));
    });
  });
}
