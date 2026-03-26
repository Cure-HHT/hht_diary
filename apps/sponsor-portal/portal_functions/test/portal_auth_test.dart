// Tests for portal authentication
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-p00024: Portal User Roles and Permissions

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/database.dart';
import 'package:portal_functions/src/identity_platform.dart';
import 'package:portal_functions/src/portal_auth.dart';

void main() {
  group('PortalUser construction', () {
    test('creates user with all fields', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: 'firebase-456',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator', 'Developer Admin'],
        activeRole: 'Administrator',
        status: 'active',
        sites: [
          {'site_id': 'site-1', 'site_name': 'Test Site'},
        ],
      );

      expect(user.id, equals('user-123'));
      expect(user.firebaseUid, equals('firebase-456'));
      expect(user.email, equals('test@example.com'));
      expect(user.name, equals('Test User'));
      expect(user.roles, equals(['Administrator', 'Developer Admin']));
      expect(user.activeRole, equals('Administrator'));
      expect(user.status, equals('active'));
      expect(user.sites, hasLength(1));
    });

    test('creates user with minimal required fields', () {
      final user = PortalUser(
        id: 'user-min',
        email: 'min@example.com',
        name: 'Minimal',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
      );

      expect(user.id, equals('user-min'));
      expect(user.firebaseUid, isNull);
      expect(user.sites, isEmpty);
    });

    test('sites defaults to empty list when not provided', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test',
        roles: ['Auditor'],
        activeRole: 'Auditor',
        status: 'active',
      );

      expect(user.sites, isEmpty);
      expect(user.sites, isA<List<Map<String, dynamic>>>());
    });
  });

  group('PortalUser', () {
    test('toJson includes all required fields', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: 'firebase-456',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
        sites: [],
      );

      final json = user.toJson();

      expect(json['id'], equals('user-123'));
      expect(json['email'], equals('test@example.com'));
      expect(json['name'], equals('Test User'));
      expect(json['roles'], equals(['Administrator']));
      expect(json['active_role'], equals('Administrator'));
      expect(json['status'], equals('active'));
      expect(json['sites'], isEmpty);
    });

    test('toJson includes sites when present', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'investigator@example.com',
        name: 'Test Investigator',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
        sites: [
          {'site_id': 'site-1', 'site_name': 'Site One', 'site_number': 'S001'},
          {'site_id': 'site-2', 'site_name': 'Site Two', 'site_number': 'S002'},
        ],
      );

      final json = user.toJson();

      expect(json['sites'], hasLength(2));
      expect(json['sites'][0]['site_id'], equals('site-1'));
      expect(json['sites'][1]['site_name'], equals('Site Two'));
    });

    test('toJson does not include firebaseUid', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: 'secret-firebase-uid',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      final json = user.toJson();

      // firebaseUid should NOT be in the JSON response (security)
      expect(json.containsKey('firebaseUid'), isFalse);
      expect(json.containsKey('firebase_uid'), isFalse);
    });

    test('firebaseUid can be null', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: null,
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      expect(user.firebaseUid, isNull);
    });

    test('sites defaults to empty list', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      expect(user.sites, isEmpty);
    });

    test('all role values are supported', () {
      final roles = [
        'Investigator',
        'Sponsor',
        'Auditor',
        'Analyst',
        'Administrator',
        'Developer Admin',
      ];

      for (final role in roles) {
        final user = PortalUser(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          roles: [role],
          activeRole: role,
          status: 'active',
        );

        expect(user.roles, contains(role));
        expect(user.activeRole, equals(role));
        expect(user.toJson()['roles'], contains(role));
        expect(user.toJson()['active_role'], equals(role));
      }
    });

    test('status values are supported', () {
      final statuses = ['active', 'revoked', 'pending'];

      for (final status in statuses) {
        final user = PortalUser(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          roles: ['Administrator'],
          activeRole: 'Administrator',
          status: status,
        );

        expect(user.status, equals(status));
        expect(user.toJson()['status'], equals(status));
      }
    });

    test('hasRole returns true for role in list', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator', 'Developer Admin'],
        activeRole: 'Administrator',
        status: 'active',
      );

      expect(user.hasRole('Administrator'), isTrue);
      expect(user.hasRole('Developer Admin'), isTrue);
      expect(user.hasRole('Investigator'), isFalse);
    });

    test('isAdmin returns true for admin roles', () {
      final adminUser = PortalUser(
        id: 'user-123',
        email: 'admin@example.com',
        name: 'Admin',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      final devAdminUser = PortalUser(
        id: 'user-456',
        email: 'devadmin@example.com',
        name: 'Dev Admin',
        roles: ['Developer Admin'],
        activeRole: 'Developer Admin',
        status: 'active',
      );

      final nonAdminUser = PortalUser(
        id: 'user-789',
        email: 'investigator@example.com',
        name: 'Investigator',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
      );

      expect(adminUser.isAdmin, isTrue);
      expect(devAdminUser.isAdmin, isTrue);
      expect(nonAdminUser.isAdmin, isFalse);
    });

    test('isDeveloperAdmin returns true only for Developer Admin role', () {
      final devAdminUser = PortalUser(
        id: 'user-456',
        email: 'devadmin@example.com',
        name: 'Dev Admin',
        roles: ['Developer Admin'],
        activeRole: 'Developer Admin',
        status: 'active',
      );

      final adminUser = PortalUser(
        id: 'user-123',
        email: 'admin@example.com',
        name: 'Admin',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      final investigatorUser = PortalUser(
        id: 'user-789',
        email: 'investigator@example.com',
        name: 'Investigator',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
      );

      expect(devAdminUser.isDeveloperAdmin, isTrue);
      expect(adminUser.isDeveloperAdmin, isFalse);
      expect(investigatorUser.isDeveloperAdmin, isFalse);
    });

    test('emailOtpRequired returns correct value for role', () {
      final devAdminUser = PortalUser(
        id: 'user-dev',
        email: 'devadmin@example.com',
        name: 'Dev Admin',
        roles: ['Developer Admin'],
        activeRole: 'Developer Admin',
        status: 'active',
      );

      final investigatorUser = PortalUser(
        id: 'user-inv',
        email: 'investigator@example.com',
        name: 'Investigator',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
      );

      final adminUser = PortalUser(
        id: 'user-admin',
        email: 'admin@example.com',
        name: 'Admin',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      // Developer Admin uses TOTP, not email OTP
      expect(devAdminUser.emailOtpRequired, isFalse);
      // Other roles use email OTP
      expect(investigatorUser.emailOtpRequired, isTrue);
      expect(adminUser.emailOtpRequired, isTrue);
    });

    test('mfaType is included in toJson', () {
      final userWithMfa = PortalUser(
        id: 'user-mfa',
        email: 'mfa@example.com',
        name: 'MFA User',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
        mfaType: 'totp',
      );

      final userWithoutMfa = PortalUser(
        id: 'user-no-mfa',
        email: 'nomfa@example.com',
        name: 'No MFA User',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      // When mfaType is explicitly set, it should be returned
      expect(userWithMfa.toJson()['mfa_type'], equals('totp'));

      // When mfaType is null, toJson should use getMfaTypeForRole
      final json = userWithoutMfa.toJson();
      expect(json.containsKey('mfa_type'), isTrue);
      expect(json['mfa_type'], isNotNull);
    });

    test('email_otp_required is included in toJson', () {
      final devAdmin = PortalUser(
        id: 'user-1',
        email: 'devadmin@example.com',
        name: 'Dev Admin',
        roles: ['Developer Admin'],
        activeRole: 'Developer Admin',
        status: 'active',
      );

      final investigator = PortalUser(
        id: 'user-2',
        email: 'investigator@example.com',
        name: 'Investigator',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
      );

      // Developer Admin does not require email OTP
      expect(devAdmin.toJson()['email_otp_required'], isFalse);

      // Investigator requires email OTP
      expect(investigator.toJson()['email_otp_required'], isTrue);
    });
  });

  // Helper to create test requests
  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('portalMeHandler authorization', () {
    test('returns 401 without authorization header', () async {
      final request = createGetRequest('/api/v1/portal/me');
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with empty authorization header', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': ''},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test(
      'returns 401 with malformed Bearer token (no space after Bearer)',
      () async {
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'BearerNoSpace'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(401));
      },
    );

    test('returns 401 with Bearer and empty token', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer '},
      );
      final response = await portalMeHandler(request);

      // Empty token should fail validation
      expect(response.statusCode, equals(401));
    });

    test('returns 401 with Basic auth instead of Bearer', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with invalid token format', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer not-a-valid-jwt'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with token missing kid', () async {
      // Token with valid structure but no kid in header
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], isNotNull);
    });
  });

  group('PortalUser toJson edge cases', () {
    test('toJson with complex site data', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Investigator'],
        activeRole: 'Investigator',
        status: 'active',
        sites: [
          {
            'site_id': 'site-1',
            'site_name': 'Hospital A',
            'site_number': 'S001',
            'extra_data': {'key': 'value'},
          },
        ],
      );

      final json = user.toJson();
      expect(json['sites'], hasLength(1));
      expect(json['sites'][0]['site_id'], equals('site-1'));
      expect(json['sites'][0]['extra_data'], isA<Map>());
    });

    test('toJson with empty string values', () {
      final user = PortalUser(
        id: '',
        email: '',
        name: '',
        roles: [''],
        activeRole: '',
        status: '',
      );

      final json = user.toJson();
      expect(json['id'], isEmpty);
      expect(json['email'], isEmpty);
      expect(json['name'], isEmpty);
      expect(json['roles'], equals(['']));
      expect(json['active_role'], isEmpty);
      expect(json['status'], isEmpty);
    });

    test('toJson with unicode characters', () {
      final user = PortalUser(
        id: 'user-日本語',
        email: 'tëst@ëxämplé.com',
        name: '测试用户 こんにちは',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      final json = user.toJson();
      expect(json['id'], equals('user-日本語'));
      expect(json['name'], contains('测试用户'));
    });

    test('toJson can be serialized to JSON string', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
        sites: [
          {'site_id': 'site-1'},
        ],
      );

      final jsonStr = jsonEncode(user.toJson());
      expect(jsonStr, contains('"id":"user-123"'));
      expect(jsonStr, contains('"sites":['));

      // Verify it can be decoded back
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['email'], equals('test@example.com'));
    });

    test('toJson with multiple roles', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'admin@example.com',
        name: 'Multi-Role User',
        roles: ['Administrator', 'Developer Admin', 'Investigator'],
        activeRole: 'Administrator',
        status: 'active',
      );

      final json = user.toJson();
      expect(json['roles'], hasLength(3));
      expect(json['roles'], contains('Administrator'));
      expect(json['roles'], contains('Developer Admin'));
      expect(json['roles'], contains('Investigator'));
      expect(json['active_role'], equals('Administrator'));
    });
  });

  // ====================================================================
  // CUR-1021: Activated user gets 403 on /portal/me after successful auth
  // ====================================================================
  group('portalMeHandler - CUR-1021 activated user 403', () {
    // Simulates an activated user: firebase_uid linked, status='active',
    // roles in portal_user_roles (modern path, NO legacy role column).
    const testUid = 'firebase-activated-user-uid';
    const testEmail = 'activated@example.com';
    const testUserId = '11110000-0000-0000-0000-000000000001';

    setUp(() {
      verifyIdTokenOverride = (token) async => VerificationResult(
        uid: testUid,
        email: testEmail,
        emailVerified: true,
      );
    });

    tearDown(() {
      verifyIdTokenOverride = null;
      databaseQueryOverride = null;
    });

    test(
      'returns 200 for activated user with roles in portal_user_roles',
      () async {
        // Mock DB: user found by firebase_uid, active, roles in junction table
        databaseQueryOverride = (query, {parameters, required context}) async {
          // 1. Lookup by firebase_uid
          if (query.contains('FROM portal_users') &&
              query.contains('firebase_uid')) {
            return [
              [
                testUserId,
                testUid,
                testEmail,
                'Activated User',
                'active',
                null,
              ],
            ];
          }
          // 2. Roles from portal_user_roles (modern path)
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }
          return [];
        };

        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer mock-token'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(200));
        final json = await getResponseJson(response);
        expect(json['email'], equals(testEmail));
        expect(json['roles'], contains('Administrator'));
      },
    );

    test(
      'returns 200 when email case differs between Firebase token and DB',
      () async {
        // BUG scenario: Firebase normalizes email to lowercase but DB has
        // mixed case from user creation. After activation, firebase_uid IS
        // set so the lookup by UID should work regardless of email case.
        const dbEmail = 'AnsparUser2@proton.me';

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('firebase_uid')) {
            return [
              [testUserId, testUid, dbEmail, 'Anspar User', 'active', null],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }
          return [];
        };

        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer mock-token'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(200));
        final json = await getResponseJson(response);
        expect(json['email'], equals(dbEmail));
      },
    );

    test('returns 403 when activated user has no roles (regression)', () async {
      // This is the suspected root cause of CUR-1021: user exists, is
      // active, firebase_uid linked, but portal_user_roles is empty AND
      // legacy role column is NULL.
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM portal_users') &&
            query.contains('firebase_uid')) {
          return [
            [testUserId, testUid, testEmail, 'No Role User', 'active', null],
          ];
        }
        // portal_user_roles returns empty
        if (query.contains('FROM portal_user_roles')) {
          return [];
        }
        // Legacy role column also NULL
        if (query.contains('FROM portal_users') &&
            query.contains('role') &&
            query.contains('IS NOT NULL')) {
          return [];
        }
        return [];
      };

      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer mock-token'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], contains('no assigned roles'));
    });

    test(
      'FAILING: email-link fallback should use case-insensitive matching',
      () async {
        // CUR-1021 root cause: When firebase_uid lookup fails (e.g., user's
        // Firebase account was recreated, giving a new UID), the handler
        // falls back to email-based linking. But the SQL uses case-sensitive
        // matching (WHERE email = @email), while Firebase normalizes emails
        // to lowercase. If the DB has mixed-case email (as entered by the
        // admin), the match fails and the user gets 403.
        //
        // The activation handler already does case-insensitive comparison
        // (toLowerCase), but portalMeHandler does not.
        //
        // Scenario:
        //   Admin creates user with email "AnsparUser2@proton.me"
        //   User activates with Firebase UID-A → firebase_uid = 'uid-A'
        //   Firebase account is recreated → new UID-B
        //   User signs in → token has uid='uid-B', email='ansparuser2@proton.me'
        //   /me: lookup by uid-B → NOT FOUND
        //   /me: email link WHERE email = 'ansparuser2@proton.me' → NO MATCH
        //       (DB has 'AnsparUser2@proton.me', PostgreSQL = is case-sensitive)
        //   /me: returns 403 "Email already linked to another account"
        //
        // Expected: handler should use LOWER(email) = LOWER(@email) so the
        // user can still be found regardless of email case.

        const dbEmail = 'AnsparUser2@proton.me';
        const firebaseEmail =
            'ansparuser2@proton.me'; // lowercase from Firebase
        const oldUid = 'firebase-old-uid';
        const newUid = 'firebase-new-uid';

        verifyIdTokenOverride = (token) async => VerificationResult(
          uid: newUid,
          email: firebaseEmail,
          emailVerified: true,
        );

        databaseQueryOverride = (query, {parameters, required context}) async {
          final email = parameters?['email'] as String?;
          final firebaseUid = parameters?['firebaseUid'] as String?;

          // 1. Lookup by firebase_uid (new UID) → NOT FOUND
          if (query.contains('FROM portal_users') &&
              query.contains('WHERE firebase_uid') &&
              !query.contains('UPDATE')) {
            if (firebaseUid == newUid) return [];
            return [];
          }

          // 2. Email-link UPDATE: simulates PostgreSQL case-sensitive behavior
          //    DB has 'AnsparUser2@proton.me', query has 'ansparuser2@proton.me'
          if (query.contains('UPDATE portal_users') &&
              query.contains('firebase_uid')) {
            // Case-sensitive: 'ansparuser2@proton.me' != 'AnsparUser2@proton.me'
            if (email != null && email != dbEmail) return [];
            // If email matched case-insensitively, would return the user
            if (email != null && email.toLowerCase() == dbEmail.toLowerCase()) {
              return [
                [testUserId, newUid, dbEmail, 'Anspar User', 'active', null],
              ];
            }
            return [];
          }

          // 3. Check if email exists (also case-sensitive in PostgreSQL)
          if (query.contains('SELECT firebase_uid FROM portal_users') &&
              query.contains('WHERE email')) {
            // Case-sensitive: won't match
            if (email != null && email != dbEmail) return [];
            // But it DOES exist with old UID
            if (email != null && email.toLowerCase() == dbEmail.toLowerCase()) {
              return [
                [oldUid],
              ];
            }
            return [];
          }

          // Roles (in case we get past the email check)
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }

          return [];
        };

        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'Bearer mock-token'},
        );
        final response = await portalMeHandler(request);
        final json = await getResponseJson(response);

        // BUG: Currently returns 403 because case-sensitive email matching
        // fails to find the user. Should return 200 after case-insensitive
        // email lookup finds and re-links the user.
        expect(
          response.statusCode,
          equals(200),
          reason:
              'Activated user should not get 403 due to email case '
              'mismatch between Firebase (lowercase) and DB (mixed case)',
        );
        expect(json['email'], equals(dbEmail));
      },
    );
  });
}
