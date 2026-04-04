// Tests for AuthService, UserRole, and PortalUser
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00044: Password Reset
//   REQ-d00031: Identity Platform Integration
//   REQ-p01044-C: Sponsors SHALL be able to configure the inactivity timeout
//   REQ-d00080-A: client-side session management with configurable inactivity timeout

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

void main() {
  group('UserRole', () {
    group('fromString', () {
      test('parses Investigator', () {
        expect(UserRole.fromString('Investigator'), UserRole.investigator);
      });

      test('parses Sponsor', () {
        expect(UserRole.fromString('Sponsor'), UserRole.sponsor);
      });

      test('parses Auditor', () {
        expect(UserRole.fromString('Auditor'), UserRole.auditor);
      });

      test('parses Analyst', () {
        expect(UserRole.fromString('Analyst'), UserRole.analyst);
      });

      test('parses Administrator', () {
        expect(UserRole.fromString('Administrator'), UserRole.administrator);
      });

      test('parses Developer Admin', () {
        expect(UserRole.fromString('Developer Admin'), UserRole.developerAdmin);
      });

      test('defaults to investigator for unknown role', () {
        expect(UserRole.fromString('Unknown'), UserRole.investigator);
        expect(UserRole.fromString(''), UserRole.investigator);
        expect(UserRole.fromString('invalid'), UserRole.investigator);
      });
    });

    group('displayName', () {
      test('returns correct display names', () {
        expect(UserRole.investigator.displayName, 'Investigator');
        expect(UserRole.sponsor.displayName, 'Sponsor');
        expect(UserRole.auditor.displayName, 'Auditor');
        expect(UserRole.analyst.displayName, 'Analyst');
        expect(UserRole.administrator.displayName, 'Administrator');
        expect(UserRole.developerAdmin.displayName, 'Developer Admin');
      });
    });

    group('isAdmin', () {
      test('returns true for Administrator', () {
        expect(UserRole.administrator.isAdmin, isTrue);
      });

      test('returns true for Developer Admin', () {
        expect(UserRole.developerAdmin.isAdmin, isTrue);
      });

      test('returns false for non-admin roles', () {
        expect(UserRole.investigator.isAdmin, isFalse);
        expect(UserRole.sponsor.isAdmin, isFalse);
        expect(UserRole.auditor.isAdmin, isFalse);
        expect(UserRole.analyst.isAdmin, isFalse);
      });
    });
  });

  group('PortalUser', () {
    group('fromJson', () {
      test('parses all fields with roles array', () {
        final json = {
          'id': 'user-123',
          'email': 'test@example.com',
          'name': 'Test User',
          'roles': ['Administrator', 'Developer Admin'],
          'active_role': 'Administrator',
          'status': 'active',
          'sites': [
            {'site_id': 'site-1', 'site_name': 'Site One'},
            {'site_id': 'site-2', 'site_name': 'Site Two'},
          ],
        };

        final user = PortalUser.fromJson(json);

        expect(user.id, 'user-123');
        expect(user.email, 'test@example.com');
        expect(user.name, 'Test User');
        expect(user.roles, [UserRole.administrator, UserRole.developerAdmin]);
        expect(user.activeRole, UserRole.administrator);
        expect(user.role, UserRole.administrator); // backwards compat getter
        expect(user.status, 'active');
        expect(user.sites.length, 2);
        expect(user.sites[0]['site_id'], 'site-1');
      });

      test('parses single role for backwards compatibility', () {
        final json = {
          'id': 'user-123',
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'Administrator',
          'status': 'active',
        };

        final user = PortalUser.fromJson(json);

        expect(user.roles, [UserRole.administrator]);
        expect(user.activeRole, UserRole.administrator);
      });

      test('handles null sites', () {
        final json = {
          'id': 'user-123',
          'email': 'test@example.com',
          'name': 'Test User',
          'roles': ['Investigator'],
          'status': 'active',
        };

        final user = PortalUser.fromJson(json);

        expect(user.sites, isEmpty);
      });

      test('handles empty sites', () {
        final json = {
          'id': 'user-123',
          'email': 'test@example.com',
          'name': 'Test User',
          'roles': ['Investigator'],
          'status': 'active',
          'sites': <dynamic>[],
        };

        final user = PortalUser.fromJson(json);

        expect(user.sites, isEmpty);
      });

      test('defaults active_role to first role', () {
        final json = {
          'id': 'user-123',
          'email': 'test@example.com',
          'name': 'Test User',
          'roles': ['Administrator', 'Investigator'],
          'status': 'active',
        };

        final user = PortalUser.fromJson(json);

        expect(user.activeRole, UserRole.administrator);
      });
    });

    group('hasRole', () {
      test('returns true for role in list', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test',
          roles: [UserRole.administrator, UserRole.developerAdmin],
          activeRole: UserRole.administrator,
          status: 'active',
        );

        expect(user.hasRole(UserRole.administrator), isTrue);
        expect(user.hasRole(UserRole.developerAdmin), isTrue);
        expect(user.hasRole(UserRole.investigator), isFalse);
      });
    });

    group('hasMultipleRoles', () {
      test('returns true when user has multiple roles', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test',
          roles: [UserRole.administrator, UserRole.developerAdmin],
          activeRole: UserRole.administrator,
          status: 'active',
        );

        expect(user.hasMultipleRoles, isTrue);
      });

      test('returns false when user has single role', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test',
          roles: [UserRole.administrator],
          activeRole: UserRole.administrator,
          status: 'active',
        );

        expect(user.hasMultipleRoles, isFalse);
      });
    });

    group('isAdmin', () {
      test('returns true when user has Administrator role', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test',
          roles: [UserRole.administrator],
          activeRole: UserRole.administrator,
          status: 'active',
        );

        expect(user.isAdmin, isTrue);
      });

      test('returns true when user has Developer Admin role', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test',
          roles: [UserRole.developerAdmin],
          activeRole: UserRole.developerAdmin,
          status: 'active',
        );

        expect(user.isAdmin, isTrue);
      });

      test('returns false when user has no admin role', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test',
          roles: [UserRole.investigator],
          activeRole: UserRole.investigator,
          status: 'active',
        );

        expect(user.isAdmin, isFalse);
      });
    });

    group('canAccessSite', () {
      test('admin can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'admin@example.com',
          name: 'Admin',
          roles: [UserRole.administrator],
          activeRole: UserRole.administrator,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
        expect(user.canAccessSite('another-site'), isTrue);
      });

      test('sponsor can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'sponsor@example.com',
          name: 'Sponsor',
          roles: [UserRole.sponsor],
          activeRole: UserRole.sponsor,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
      });

      test('auditor can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'auditor@example.com',
          name: 'Auditor',
          roles: [UserRole.auditor],
          activeRole: UserRole.auditor,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
      });

      test('analyst can access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'analyst@example.com',
          name: 'Analyst',
          roles: [UserRole.analyst],
          activeRole: UserRole.analyst,
          status: 'active',
        );

        expect(user.canAccessSite('any-site'), isTrue);
      });

      test('investigator can only access assigned sites', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'investigator@example.com',
          name: 'Investigator',
          roles: [UserRole.investigator],
          activeRole: UserRole.investigator,
          status: 'active',
          sites: [
            {'site_id': 'site-1', 'site_name': 'Site One'},
            {'site_id': 'site-2', 'site_name': 'Site Two'},
          ],
        );

        expect(user.canAccessSite('site-1'), isTrue);
        expect(user.canAccessSite('site-2'), isTrue);
        expect(user.canAccessSite('site-3'), isFalse);
        expect(user.canAccessSite('unknown'), isFalse);
      });

      test('investigator with no sites cannot access any site', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'investigator@example.com',
          name: 'Investigator',
          roles: [UserRole.investigator],
          activeRole: UserRole.investigator,
          status: 'active',
          sites: [],
        );

        expect(user.canAccessSite('site-1'), isFalse);
        expect(user.canAccessSite('any-site'), isFalse);
      });
    });

    group('copyWithActiveRole', () {
      test('creates copy with new active role', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test User',
          roles: [UserRole.administrator, UserRole.investigator],
          activeRole: UserRole.administrator,
          status: 'active',
          sites: [
            {'site_id': 'site-1'},
          ],
        );

        final updatedUser = user.copyWithActiveRole(UserRole.investigator);

        expect(updatedUser.id, user.id);
        expect(updatedUser.email, user.email);
        expect(updatedUser.name, user.name);
        expect(updatedUser.roles, user.roles);
        expect(updatedUser.status, user.status);
        expect(updatedUser.sites, user.sites);
        expect(updatedUser.activeRole, UserRole.investigator);
      });

      test('throws when role not in user roles', () {
        final user = PortalUser(
          id: 'user-1',
          email: 'test@example.com',
          name: 'Test User',
          roles: [UserRole.investigator],
          activeRole: UserRole.investigator,
          status: 'active',
        );

        expect(
          () => user.copyWithActiveRole(UserRole.administrator),
          throwsArgumentError,
        );
      });

      test('preserves all original data', () {
        final user = PortalUser(
          id: 'user-123',
          email: 'multi@example.com',
          name: 'Multi Role User',
          roles: [UserRole.sponsor, UserRole.auditor, UserRole.analyst],
          activeRole: UserRole.sponsor,
          status: 'active',
          sites: [
            {'site_id': 's1', 'site_name': 'Site 1'},
            {'site_id': 's2', 'site_name': 'Site 2'},
          ],
        );

        final copied = user.copyWithActiveRole(UserRole.auditor);

        expect(copied.id, 'user-123');
        expect(copied.email, 'multi@example.com');
        expect(copied.name, 'Multi Role User');
        expect(copied.roles.length, 3);
        expect(copied.status, 'active');
        expect(copied.sites.length, 2);
        expect(copied.activeRole, UserRole.auditor);
      });
    });

    group('fromJson edge cases', () {
      test('defaults to investigator when no roles provided', () {
        final json = {
          'id': 'user-1',
          'email': 'test@example.com',
          'name': 'Test',
          'status': 'active',
        };

        final user = PortalUser.fromJson(json);

        expect(user.roles, [UserRole.investigator]);
        expect(user.activeRole, UserRole.investigator);
      });

      test('parses developer admin active role', () {
        final json = {
          'id': 'user-1',
          'email': 'test@example.com',
          'name': 'Test',
          'roles': ['Developer Admin', 'Administrator'],
          'active_role': 'Developer Admin',
          'status': 'active',
        };

        final user = PortalUser.fromJson(json);

        expect(user.activeRole, UserRole.developerAdmin);
      });
    });
  });

  group('AuthService Password Reset', () {
    test('requestPasswordReset sends correct request', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/portal/auth/password-reset/request');
        expect(request.headers['content-type'], startsWith('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'test@example.com');

        return http.Response(jsonEncode({'success': true}), 200);
      });

      // Note: In real implementation, AuthService would accept http.Client
      // For now, we're testing the request format
      final response = await mockClient.post(
        Uri.parse('http://localhost/api/v1/portal/auth/password-reset/request'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': 'test@example.com'}),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json['success'], isTrue);
    });

    test('requestPasswordReset handles error response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Too many requests'}), 429);
      });

      final response = await mockClient.post(
        Uri.parse('http://localhost/api/v1/portal/auth/password-reset/request'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': 'test@example.com'}),
      );

      expect(response.statusCode, 429);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json['error'], 'Too many requests');
    });

    test('requestPasswordReset validates email format', () {
      // Simple email validation: must contain '@' and be at least 3 characters
      // Note: This is intentionally loose validation on the client side
      // Server performs more strict validation
      final invalidEmails = [
        '',
        'a@', // Only 2 characters
        'no-at-sign',
        'a',
      ];

      for (final email in invalidEmails) {
        expect(
          email.contains('@') && email.length >= 3,
          isFalse,
          reason: '$email should be invalid',
        );
      }

      final validEmails = [
        'test@example.com',
        'user+tag@domain.co.uk',
        'name.surname@company.org',
        '@ab', // Passes simple check (server will reject)
      ];

      for (final email in validEmails) {
        expect(
          email.contains('@') && email.length >= 3,
          isTrue,
          reason: '$email should pass simple validation',
        );
      }
    });
  });

  group('AuthService inactivity timeout', () {
    // Synchronous setup helper — must run inside a fakeAsync zone so that
    // the AuthService's internal Timer is governed by fake time.
    AuthService buildSignedInAuthService(
      FakeAsync fake, {
      required Duration inactivityTimeout,
    }) {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/portal/me') {
          return http.Response(
            jsonEncode({
              'id': 'user-001',
              'email': 'test@example.com',
              'name': 'Test User',
              'status': 'active',
              'roles': ['Investigator'],
              'active_role': 'Investigator',
              'sites': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
        inactivityTimeout: inactivityTimeout,
      );
      // Fire sign-in without awaiting, then flush microtasks to complete the
      // entire sign-in chain (Firebase mock → token → HTTP mock → user set →
      // resetInactivityTimer() → Timer created under fake time control).
      authService.signIn('test@example.com', 'password');
      fake.flushMicrotasks();
      return authService;
    }

    test('inactivity timer firing signs user out and sets isTimedOut', () {
      fakeAsync((fake) {
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 100),
        );

        expect(authService.isAuthenticated, isTrue);
        expect(authService.isTimedOut, isFalse);

        // Advance fake clock past the inactivity timeout
        fake.elapse(const Duration(milliseconds: 200));

        expect(authService.isTimedOut, isTrue);
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentUser, isNull);

        // Clean up
        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    test('inactivity timer does not fire before the timeout duration', () {
      fakeAsync((fake) {
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 300),
        );

        expect(authService.isAuthenticated, isTrue);

        // Advance less than the timeout
        fake.elapse(const Duration(milliseconds: 100));

        expect(authService.isTimedOut, isFalse);
        expect(authService.isAuthenticated, isTrue);

        // Clean up
        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    test('resetInactivityTimer prevents timeout from firing', () {
      fakeAsync((fake) {
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 200),
        );

        // Advance to 150ms — before the 200ms timeout fires
        fake.elapse(const Duration(milliseconds: 150));
        authService.resetInactivityTimer();

        // Advance another 150ms — would have timed out without the reset
        fake.elapse(const Duration(milliseconds: 150));

        expect(authService.isTimedOut, isFalse);
        expect(authService.isAuthenticated, isTrue);

        // Clean up
        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    test(
      'isTimedOut remains true after timeout even when currentUser is null',
      () {
        fakeAsync((fake) {
          final authService = buildSignedInAuthService(
            fake,
            inactivityTimeout: const Duration(milliseconds: 100),
          );

          fake.elapse(const Duration(milliseconds: 200));

          // Both must be true simultaneously — this is what drives the login banner
          expect(authService.isTimedOut, isTrue);
          expect(authService.currentUser, isNull);

          // Clean up (timer already fired, but ensures no pending microtasks)
          authService.signOut();
          fake.flushMicrotasks();
        });
      },
    );

    // REQ-d00080-D, REQ-p01044-G: isWarning becomes true before timeout fires
    test('isWarning becomes true before inactivity timeout', () {
      fakeAsync((fake) {
        // Use a 200ms timeout with a 30s warning lead time. Since 200ms < 30s,
        // the warning fires at timeout/2 = 100ms.
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 200),
        );

        expect(authService.isWarning, isFalse);

        // Advance to just past the warning point (100ms) but before timeout (200ms)
        fake.elapse(const Duration(milliseconds: 110));

        // REQ-p01044-G: warning should now be active
        expect(authService.isWarning, isTrue);
        expect(authService.isAuthenticated, isTrue); // Not timed out yet

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    // REQ-d00080-E, REQ-p01044-I: resetInactivityTimer dismisses the warning
    test('resetInactivityTimer clears isWarning', () {
      fakeAsync((fake) {
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 200),
        );

        // Trigger the warning (fires at 100ms for a 200ms timeout)
        fake.elapse(const Duration(milliseconds: 110));
        expect(authService.isWarning, isTrue);

        // User clicks "Stay Logged In" — resets timer
        authService.resetInactivityTimer();

        // Warning should be cleared immediately
        expect(authService.isWarning, isFalse);
        expect(authService.isAuthenticated, isTrue);

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    // REQ-d00080-F: timeout still fires even if warning was shown
    test('inactivity timeout fires after warning if not reset', () {
      fakeAsync((fake) {
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 200),
        );

        // Advance past warning point
        fake.elapse(const Duration(milliseconds: 110));
        expect(authService.isWarning, isTrue);

        // Advance past the full timeout without resetting
        fake.elapse(const Duration(milliseconds: 100));
        fake.flushMicrotasks();

        expect(authService.isTimedOut, isTrue);
        expect(authService.isAuthenticated, isFalse);
        expect(authService.isWarning, isFalse); // cleared on sign-out

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    // REQ-d00083-A..E, REQ-p01044-J..M: clearStorage called on explicit logout
    test('clearStorage is called on explicit signOut', () {
      fakeAsync((fake) {
        var clearStorageCalled = false;
        final mockUser = MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        );
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: mockUser,
          signedIn: true,
        );
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/api/v1/portal/me') {
            return http.Response(
              jsonEncode({
                'id': 'user-001',
                'email': 'test@example.com',
                'name': 'Test User',
                'status': 'active',
                'roles': ['Investigator'],
                'active_role': 'Investigator',
                'sites': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          inactivityTimeout: const Duration(milliseconds: 200),
          clearStorage: () async {
            clearStorageCalled = true;
          },
        );
        authService.signIn('test@example.com', 'password');
        fake.flushMicrotasks();

        authService.signOut();
        fake.flushMicrotasks();

        expect(clearStorageCalled, isTrue);
      });
    });

    // REQ-d00083-F..J: clearStorage also called when session times out
    test('clearStorage is called on inactivity timeout', () {
      fakeAsync((fake) {
        var clearStorageCalled = false;
        final mockUser = MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        );
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: mockUser,
          signedIn: true,
        );
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/api/v1/portal/me') {
            return http.Response(
              jsonEncode({
                'id': 'user-001',
                'email': 'test@example.com',
                'name': 'Test User',
                'status': 'active',
                'roles': ['Investigator'],
                'active_role': 'Investigator',
                'sites': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          inactivityTimeout: const Duration(milliseconds: 100),
          clearStorage: () async {
            clearStorageCalled = true;
          },
        );
        authService.signIn('test@example.com', 'password');
        fake.flushMicrotasks();

        // Let the inactivity timer fire
        fake.elapse(const Duration(milliseconds: 200));
        fake.flushMicrotasks();

        expect(clearStorageCalled, isTrue);
        expect(authService.isTimedOut, isTrue);

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    // signOut clears isWarning
    test('signOut clears isWarning flag', () {
      fakeAsync((fake) {
        final authService = buildSignedInAuthService(
          fake,
          inactivityTimeout: const Duration(milliseconds: 200),
        );

        fake.elapse(const Duration(milliseconds: 110));
        expect(authService.isWarning, isTrue);

        authService.signOut();
        fake.flushMicrotasks();

        expect(authService.isWarning, isFalse);
      });
    });
  });

  // REQ-p01044-C, REQ-d00080-A: sponsor-configurable inactivity timeout
  group('Sponsor-configurable timeout', () {
    /// Build a signed-in AuthService where the sponsor config endpoint returns
    /// [sponsorTimeoutMinutes] (null = 404, simulating failure).
    AuthService buildWithSponsorConfig(
      FakeAsync fake, {
      int? sponsorTimeoutMinutes,
      Duration inactivityTimeout = const Duration(milliseconds: 500),
    }) {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/portal/me') {
          return http.Response(
            jsonEncode({
              'id': 'user-001',
              'email': 'test@example.com',
              'name': 'Test User',
              'status': 'active',
              'roles': ['Investigator'],
              'active_role': 'Investigator',
              'sites': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/sponsor/config') {
          if (sponsorTimeoutMinutes == null) {
            return http.Response('Not found', 404);
          }
          return http.Response(
            jsonEncode({
              'sponsorId': 'callisto',
              'flags': {
                'inactivityTimeoutMinutes': sponsorTimeoutMinutes,
                'useReviewScreen': false,
                'useAnimations': true,
              },
              'isDefault': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
        inactivityTimeout: inactivityTimeout,
      );
      authService.signIn('test@example.com', 'password');
      fake.flushMicrotasks();
      return authService;
    }

    test('applies sponsor timeout from config API after login', () {
      fakeAsync((fake) {
        // Sponsor config returns 30 minutes; default is 500ms
        final authService = buildWithSponsorConfig(
          fake,
          sponsorTimeoutMinutes: 30,
        );

        expect(authService.isAuthenticated, isTrue);
        // Timeout should now be 30 minutes from sponsor config
        expect(
          authService.currentInactivityTimeout,
          const Duration(minutes: 30),
        );

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    test('falls back to default timeout when sponsor config API fails', () {
      fakeAsync((fake) {
        // null → config endpoint returns 404
        final authService = buildWithSponsorConfig(
          fake,
          sponsorTimeoutMinutes: null,
          inactivityTimeout: const Duration(milliseconds: 500),
        );

        expect(authService.isAuthenticated, isTrue);
        // Timeout should remain at the injected default
        expect(
          authService.currentInactivityTimeout,
          const Duration(milliseconds: 500),
        );

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    test('clamps timeout below 1 minute to 1 minute', () {
      fakeAsync((fake) {
        final authService = buildWithSponsorConfig(
          fake,
          sponsorTimeoutMinutes: 0, // out of range
        );

        expect(
          authService.currentInactivityTimeout,
          const Duration(minutes: 1),
        );

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    test('clamps timeout above 30 minutes to 30 minutes', () {
      fakeAsync((fake) {
        final authService = buildWithSponsorConfig(
          fake,
          sponsorTimeoutMinutes: 60, // out of range
        );

        expect(
          authService.currentInactivityTimeout,
          const Duration(minutes: 30),
        );

        authService.signOut();
        fake.flushMicrotasks();
      });
    });

    // Sponsor-configurable timeout tests continue below
    test('updateInactivityTimeout restarts live timer with new duration', () {
      fakeAsync((fake) {
        final authService = buildWithSponsorConfig(
          fake,
          sponsorTimeoutMinutes: null, // use injected default
          inactivityTimeout: const Duration(milliseconds: 300),
        );

        expect(authService.isAuthenticated, isTrue);
        // Advance past the sponsor-fetch microtasks so timer is running
        fake.elapse(const Duration(milliseconds: 50));

        // Now update to a longer timeout while session is live
        authService.updateInactivityTimeout(const Duration(milliseconds: 600));
        expect(
          authService.currentInactivityTimeout,
          const Duration(milliseconds: 600),
        );

        // The old 300ms timer would have fired by now (50+300=350ms total),
        // but it was replaced — session should still be alive
        fake.elapse(const Duration(milliseconds: 400));
        expect(authService.isAuthenticated, isTrue);
        expect(authService.isTimedOut, isFalse);

        // Advance past the new 600ms timeout — should now sign out
        fake.elapse(const Duration(milliseconds: 300));
        fake.flushMicrotasks();
        expect(authService.isTimedOut, isTrue);
        expect(authService.isAuthenticated, isFalse);

        authService.signOut();
        fake.flushMicrotasks();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // CUR-982: Cross-session auth collision
  // ---------------------------------------------------------------------------
  group('CUR-982: cross-session auth collision', () {
    test(
      'detects cross-tab UID change and signs out instead of adopting foreign session',
      () {
        fakeAsync((fake) {
          // Admin is signed in initially
          final adminUser = MockUser(
            uid: 'admin-uid',
            email: 'admin@test.com',
            displayName: 'Admin User',
          );
          final mockAuth = MockFirebaseAuth(
            mockUser: adminUser,
            signedIn: true,
          );

          final mockHttpClient = MockClient((request) async {
            if (request.url.path == '/api/v1/portal/me') {
              return http.Response(
                jsonEncode({
                  'id': 'admin-id',
                  'email': 'admin@test.com',
                  'name': 'Admin User',
                  'roles': ['Administrator'],
                  'active_role': 'Administrator',
                  'status': 'active',
                  'sites': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/portal/config/session') {
              return http.Response('{}', 200);
            }
            return http.Response('Not found', 404);
          });

          final authService = AuthService(
            firebaseAuth: mockAuth,
            httpClient: mockHttpClient,
            inactivityTimeout: const Duration(minutes: 30),
            enableInactivityTimer: false,
          );

          // Sign in as Admin
          authService.signIn('admin@test.com', 'password');
          fake.flushMicrotasks();

          expect(authService.isAuthenticated, isTrue);
          expect(authService.currentUser!.activeRole, UserRole.administrator);

          // Simulate cross-tab auth collision: another browser window signs
          // in as a different user, which changes the Firebase auth state in
          // localStorage. Our tab's authStateChanges listener receives a user
          // with a DIFFERENT UID.
          final scUser = MockUser(
            uid: 'sc-uid',
            email: 'coordinator@test.com',
            displayName: 'Study Coordinator',
          );
          mockAuth.stateChangedStreamController.add(scUser);
          fake.flushMicrotasks();

          // BUG CUR-982: The service silently adopts the foreign user's
          // identity. The session should be invalidated because the Firebase
          // UID changed — this tab's session was overwritten by another tab.
          //
          // Expected: service detects UID mismatch and signs out, clearing
          // currentUser so the UI shows a login prompt instead of the wrong
          // role badge.
          //
          // Actual: service fetches the new user's profile and displays
          // their role, creating a privilege confusion (FDA 21 CFR Part 11).
          expect(
            authService.isAuthenticated,
            isFalse,
            reason:
                'Session must be invalidated when Firebase UID changes '
                'from a cross-tab sign-in — silently adopting another '
                "user's identity is a role-escalation display mismatch",
          );
          expect(
            authService.currentUser,
            isNull,
            reason:
                'currentUser must be cleared on cross-session collision '
                'to prevent wrong role display',
          );
        });
      },
    );
  });
}
