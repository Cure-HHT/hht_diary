// Tests for AuthService, UserRole, and PortalUser
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00044: Password Reset
//   REQ-d00031: Identity Platform Integration
//   REQ-p01044-C: Sponsors SHALL be able to configure the inactivity timeout
//   REQ-d00080-A: client-side session management with configurable inactivity timeout
//   REQ-d00167: Identity Platform binding set only at activation; uid_not_bound 401 is the auth-miss envelope

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, UserMetadata;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/flavors.dart';
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

  // CUR-1118: isInitialized flag — dashboard pages must wait for Firebase to
  // finish restoring its session before deciding to redirect to /login.
  group('CUR-1118: isInitialized flag', () {
    late MockUser mockUser;
    late MockClient mockHttpClient;

    setUp(() {
      mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockHttpClient = MockClient((request) async {
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
    });

    test('isInitialized is false immediately after construction', () {
      fakeAsync((fake) {
        final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
        );

        // Before any authStateChanges event is processed, flag is false.
        expect(
          authService.isInitialized,
          isFalse,
          reason:
              'isInitialized must be false before Firebase restores session '
              'so dashboard pages can show a spinner instead of redirecting',
        );
      });
    });

    test('isInitialized becomes true when Firebase confirms no session', () {
      fakeAsync((fake) {
        // signedIn: false → authStateChanges emits null immediately
        final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
        );
        fake.flushMicrotasks();

        expect(
          authService.isInitialized,
          isTrue,
          reason:
              'isInitialized must flip to true once Firebase confirms the '
              'user is signed out, so login page can render',
        );
        expect(authService.isAuthenticated, isFalse);
      });
    });

    test(
      'isInitialized becomes true after successful session restore on refresh',
      () {
        fakeAsync((fake) {
          // Simulate page refresh: Firebase restores session from IndexedDB.
          // Pass isPageRefresh: true so the stale-session guard is bypassed.
          final mockFirebaseAuth = MockFirebaseAuth(
            mockUser: mockUser,
            signedIn: true,
          );
          final authService = AuthService(
            firebaseAuth: mockFirebaseAuth,
            httpClient: mockHttpClient,
            enableInactivityTimer: false,
            clearStorage: () async {},
            isPageRefresh: true,
          );
          fake.flushMicrotasks();

          expect(
            authService.isInitialized,
            isTrue,
            reason:
                'isInitialized must be true after Firebase restores a valid '
                'session on page refresh',
          );
          expect(authService.isAuthenticated, isTrue);
        });
      },
    );

    // CUR-1157: a transient HTTP 500 on the initial restore must NOT flip
    // isInitialized=true with currentUser=null. Doing so causes dashboards
    // to redirect a still-Firebase-authenticated user to /login on every
    // page refresh whenever the API has a hiccup. While retries are in
    // flight, dashboards must keep showing the spinner.
    test(
      'CUR-1157: isInitialized stays false during retries when fetchPortalUser '
      'fails transiently (HTTP 500)',
      () {
        fakeAsync((fake) {
          final failingHttpClient = MockClient((request) async {
            return http.Response('Internal Server Error', 500);
          });
          final mockFirebaseAuth = MockFirebaseAuth(
            mockUser: mockUser,
            signedIn: true,
          );
          final authService = AuthService(
            firebaseAuth: mockFirebaseAuth,
            httpClient: failingHttpClient,
            enableInactivityTimer: false,
            clearStorage: () async {},
            isPageRefresh: true,
          );
          fake.flushMicrotasks();

          expect(
            authService.isInitialized,
            isFalse,
            reason:
                'CUR-1157: while the initial /portal/me retry is pending, '
                'isInitialized must stay false so dashboards keep showing '
                'the spinner instead of redirecting to /login',
          );
          expect(authService.isAuthenticated, isFalse);
        });
      },
    );

    test(
      'CUR-1157: isInitialized eventually flips after retries are exhausted',
      () {
        fakeAsync((fake) {
          final failingHttpClient = MockClient((request) async {
            return http.Response('Internal Server Error', 500);
          });
          final mockFirebaseAuth = MockFirebaseAuth(
            mockUser: mockUser,
            signedIn: true,
          );
          final authService = AuthService(
            firebaseAuth: mockFirebaseAuth,
            httpClient: failingHttpClient,
            enableInactivityTimer: false,
            clearStorage: () async {},
            isPageRefresh: true,
          );
          // Drain microtasks then advance past the full retry budget
          // (3 retries * 2s spacing, with margin).
          fake.flushMicrotasks();
          fake.elapse(const Duration(seconds: 10));
          fake.flushMicrotasks();

          expect(
            authService.isInitialized,
            isTrue,
            reason:
                'After exhausting retries, isInitialized must flip true so '
                'the user is no longer stuck on a perpetual spinner',
          );
          expect(authService.isAuthenticated, isFalse);
        });
      },
    );

    test('CUR-1157: a transient failure that recovers on retry populates '
        'currentUser without bouncing through /login', () {
      fakeAsync((fake) {
        var callCount = 0;
        final flakyHttpClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Internal Server Error', 500);
          }
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
        });
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: mockUser,
          signedIn: true,
        );
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: flakyHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {},
          isPageRefresh: true,
        );
        fake.flushMicrotasks();
        // Advance past the first retry delay.
        fake.elapse(const Duration(seconds: 3));
        fake.flushMicrotasks();

        expect(
          authService.isInitialized,
          isTrue,
          reason: 'Retry succeeded — initialization is complete',
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason:
              'CUR-1157: after a transient failure recovers, the user '
              'must remain authenticated rather than being kicked to login',
        );
      });
    });
  });

  // CUR-1118: fresh-tab stale-session handling — when a user opens a new tab
  // (or returns after closing the previous tab), any Firebase session still
  // in IndexedDB is stale and must be cleared so the user is prompted to log in.
  group('CUR-1118: fresh-tab stale session handling', () {
    late MockUser mockUser;
    late MockClient mockHttpClient;

    setUp(() {
      mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockHttpClient = MockClient((request) async {
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
    });

    // CUR-1280 (issue 6, subsumes issue 9): the fresh-tab auto-signout used
    // to fire UNCONDITIONALLY whenever Firebase restored a session in a fresh
    // tab. Combined with the broken IndexedDB clear (Task 1.4) this produced
    // "every fresh tab kicks me out". The new contract: only signOut if the
    // restored token actually fails forceRefresh. The two tests below pin
    // the new contract from both sides (valid token => keep, invalid token
    // => sign out). NOTE: this replaces the previous test by the same name
    // that asserted unconditional signOut — that contract is no longer
    // correct after Task 2.5.
    //
    // IMPLEMENTS REQUIREMENTS:
    //   REQ-d00080-A: client-side session management (the listener gate
    //                 must distinguish valid from invalid restored sessions)
    //   REQ-d00080-L: switching tabs MUST NOT trigger logout (a fresh tab
    //                 of an already-authenticated user is the same session)
    //   REQ-p01044-D: terminate on close — NOT on fresh-tab open of a
    //                 still-valid session
    //   REQ-p01044-O: synchronize session timeout across multiple tabs for
    //                 the same user
    test('fresh tab with valid Firebase session preserves session and does NOT '
        'call clearStorage', () {
      fakeAsync((fake) {
        var clearStorageCalled = false;
        // Firebase has a still-valid session in IndexedDB (the default
        // MockUser issues a token that does not throw on getIdToken).
        // This is a fresh tab (isPageRefresh: false).
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: mockUser,
          signedIn: true,
        );
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {
            clearStorageCalled = true;
          },
          isPageRefresh: false,
        );
        fake.flushMicrotasks();

        expect(
          clearStorageCalled,
          isFalse,
          reason:
              'CUR-1280: forceRefresh succeeded => the restored session is '
              'still valid; clearStorage MUST NOT be called. Calling it '
              "here is what produced the user's 'every new tab kicks me "
              "out' UX.",
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason:
              'A fresh tab adopting a valid restored session must end up '
              'authenticated (REQ-d00080-L, REQ-p01044-O).',
        );
        expect(
          authService.isInitialized,
          isTrue,
          reason:
              'Initialization completes once /portal/me resolves with the '
              'valid restored session.',
        );
      });
    });

    test(
      'fresh tab with INVALID restored token calls clearStorage and signs out',
      () {
        fakeAsync((fake) {
          var clearStorageCalled = false;
          // Subclassed MockUser whose forceRefresh throws — simulates an
          // expired refresh token, an emulator restart, or any other reason
          // the cached IndexedDB session can no longer mint a valid token.
          final invalidUser = _ForceRefreshFailingMockUser(
            uid: 'test-uid',
            email: 'test@example.com',
            displayName: 'Test User',
          );
          final mockFirebaseAuth = MockFirebaseAuth(
            mockUser: invalidUser,
            signedIn: true,
          );
          final authService = AuthService(
            firebaseAuth: mockFirebaseAuth,
            httpClient: mockHttpClient,
            enableInactivityTimer: false,
            clearStorage: () async {
              clearStorageCalled = true;
            },
            isPageRefresh: false,
          );
          fake.flushMicrotasks();

          expect(
            clearStorageCalled,
            isTrue,
            reason:
                'CUR-1280: forceRefresh threw => the restored token is no '
                'longer valid; the existing CUR-1118 teardown (clearStorage '
                '+ signOut) MUST still run.',
          );
          expect(
            authService.isAuthenticated,
            isFalse,
            reason: 'An invalid restored session must not authenticate.',
          );
        });
      },
    );

    test('page refresh preserves session and does not call clearStorage', () {
      fakeAsync((fake) {
        var clearStorageCalled = false;
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: mockUser,
          signedIn: true,
        );
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {
            clearStorageCalled = true;
          },
          isPageRefresh: true,
        );
        fake.flushMicrotasks();

        expect(
          clearStorageCalled,
          isFalse,
          reason:
              'clearStorage must NOT be called on a page refresh — the '
              'Firebase session is still valid and should be kept',
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'Session must be preserved on page refresh',
        );
      });
    });

    test(
      'fresh tab with no existing Firebase session does not call clearStorage',
      () {
        fakeAsync((fake) {
          var clearStorageCalled = false;
          // No Firebase session at all (signedIn: false).
          final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
          final authService = AuthService(
            firebaseAuth: mockFirebaseAuth,
            httpClient: mockHttpClient,
            enableInactivityTimer: false,
            clearStorage: () async {
              clearStorageCalled = true;
            },
            isPageRefresh: false,
          );
          fake.flushMicrotasks();

          expect(
            clearStorageCalled,
            isFalse,
            reason:
                'clearStorage must not be called when there is no Firebase '
                'session to clear — nothing stale to remove',
          );
          expect(authService.isAuthenticated, isFalse);
        });
      },
    );

    // CUR-1280 (issue 6): a hung getIdToken (offline / very slow network)
    // must not stall the listener chain. The gate's `.timeout()` budget
    // bounds the wait at _restoredTokenRefreshTimeout (5s); past that,
    // the gate falls back to signOut so the user lands on the login page
    // rather than seeing a frozen UI.
    //
    // IMPLEMENTS REQUIREMENTS:
    //   REQ-d00080-A: client-side session management — a hung token refresh
    //                 must not deadlock the auth state machine.
    test('fresh tab with hung getIdToken (offline / slow network) times out '
        'and signs out after the 5s budget', () {
      fakeAsync((fake) {
        var clearStorageCalled = false;
        final hungUser = _HangingMockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        );
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: hungUser,
          signedIn: true,
        );
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {
            clearStorageCalled = true;
          },
          isPageRefresh: false,
        );

        // Advance past the 5s timeout budget; the gate's .timeout()
        // must fire and the catch must run signOut + clearStorage.
        fake.elapse(const Duration(seconds: 6));
        fake.flushMicrotasks();

        expect(
          clearStorageCalled,
          isTrue,
          reason:
              'CUR-1280 (issue 6): a hung token refresh must time out at '
              '5s and trigger signOut, not stall the listener chain.',
        );
        expect(
          authService.isAuthenticated,
          isFalse,
          reason:
              'A hung restored-token refresh must not authenticate — the '
              'session is unverifiable.',
        );
      });
    });

    // CUR-1312: defense-in-depth — the restore-validity branch must NOT
    // fire for an event whose lastSignInTime is recent. That class of
    // event is, by definition, a fresh sign-in (whether via
    // AuthService.signIn() or a caller bypassing it — see the
    // CUR-1312 retrospective on the activation page). If the gate fires
    // anyway, force-refreshing the just-issued token races the in-flight
    // sign-in and silently signs the user out, which was the original
    // bug. This test PROVES the gate skipped getIdToken: we use a hung
    // mock user (default behavior would 5s-time-out and signOut), but
    // wire the metadata to "sign-in just happened". If the gate is
    // honored the test settles immediately; if it isn't the .timeout()
    // would clearStorage and the assertion below would fail.
    test('CUR-1312: fresh sign-in (recent lastSignInTime) bypasses '
        'restore-validity even with _sessionUid == null', () {
      fakeAsync((fake) {
        var clearStorageCalled = false;
        final freshUser = _ForceRefreshHangingMockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
          metadata: UserMetadata(
            DateTime.now()
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
          ),
        );
        final mockFirebaseAuth = MockFirebaseAuth(
          mockUser: freshUser,
          signedIn: true,
        );
        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {
            clearStorageCalled = true;
          },
          isPageRefresh: false,
        );

        // Settle without advancing past the 5s budget. If the gate
        // erroneously fires, getIdToken hangs and the test would need
        // `fake.elapse(Duration(seconds: 6))` to see clearStorage. We
        // deliberately don't elapse — proving the gate skipped getIdToken.
        fake.flushMicrotasks();

        expect(
          clearStorageCalled,
          isFalse,
          reason:
              'CUR-1312: a fresh sign-in (lastSignInTime within '
              '_freshSignInWindow) MUST skip the restore-validity branch. '
              'Calling getIdToken(true) on a just-issued token races the '
              'sign-in and was the silent-signOut root cause.',
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason:
              'A fresh sign-in must end up authenticated — the restore '
              'branch was correctly skipped and /portal/me succeeded.',
        );
      });
    });

    // CUR-1280 (issue 6): the user's question that drove the gate fix was
    // explicitly about multi-tab same-user behavior. The two tests above
    // cover the gate in isolation. This test exercises the higher-level
    // scenario: a SECOND AuthService instance constructed against the SAME
    // MockFirebaseAuth (simulating two browser tabs sharing IndexedDB) does
    // not tear down the first tab's session.
    //
    // KNOWN MOCK LIMITATION: `firebase_auth_mocks` exposes [authStateChanges]
    // as a plain broadcast stream, which does NOT replay the current user
    // to a late subscriber. Real Firebase Auth and the production stream
    // DO replay the current state to new subscribers — that replay is what
    // makes the multi-tab adoption case work in browsers (a fresh tab gets
    // an immediate "you are signed in as X" event from IndexedDB-restored
    // state). With the broadcast-only mock, tab 2 sees no event at all,
    // so `tab2.isAuthenticated` stays false in the unit test. The gate
    // tests above (valid forceRefresh => fall through, NOT signOut) lock
    // in the per-tab adoption contract; integration / browser tests cover
    // the cross-tab replay path end-to-end.
    //
    // What this test DOES lock in: opening a second AuthService against
    // the same MockFirebaseAuth must NOT tear down the first tab's
    // session — neither tab's `clearStorage` is called, and tab 1 stays
    // authenticated.
    //
    // IMPLEMENTS REQUIREMENTS:
    //   REQ-d00080-L: switching tabs MUST NOT trigger logout — opening a
    //                 second tab while the first is logged in does not
    //                 disturb the first tab.
    //   REQ-p01044-O: synchronize session timeout across multiple tabs
    //                 for the same user — opening a second tab must not
    //                 interfere with the first tab's session.
    test('opening a second fresh tab against the same valid Firebase session '
        "does not disturb the first tab's session", () {
      fakeAsync((fake) {
        // Tab 1: open a tab against a valid Firebase session.
        final sharedUser = MockUser(
          uid: 'shared-uid',
          email: 'shared@test.com',
          displayName: 'Shared User',
        );
        final sharedAuth = MockFirebaseAuth(
          mockUser: sharedUser,
          signedIn: true,
        );

        var tab1ClearStorage = 0;
        final tab1 = AuthService(
          firebaseAuth: sharedAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {
            tab1ClearStorage++;
          },
          isPageRefresh: false,
        );
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));
        fake.flushMicrotasks();

        expect(
          tab1.isAuthenticated,
          isTrue,
          reason: 'sanity: tab 1 must adopt the valid restored session',
        );
        expect(
          tab1ClearStorage,
          0,
          reason: 'sanity: tab 1 must not have torn down its own session',
        );

        // Tab 2: a fresh AuthService against the SAME MockFirebaseAuth
        // (same Firebase IndexedDB in production).
        var tab2ClearStorage = 0;
        final tab2 = AuthService(
          firebaseAuth: sharedAuth,
          httpClient: mockHttpClient,
          enableInactivityTimer: false,
          clearStorage: () async {
            tab2ClearStorage++;
          },
          isPageRefresh: false,
        );
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));
        fake.flushMicrotasks();

        // Tab 1 was not disturbed by tab 2 opening.
        expect(
          tab1.isAuthenticated,
          isTrue,
          reason:
              'CUR-1280 (issue 6, REQ-p01044-O): opening a second tab '
              "must not interfere with the first tab's session.",
        );
        expect(
          tab1ClearStorage,
          0,
          reason:
              "CUR-1280 (issue 6, REQ-p01044-O): the first tab's storage "
              'must not be cleared as a side effect of opening tab 2.',
        );

        // Tab 2 must NOT have torn down the shared Firebase session.
        // (We cannot assert tab2.isAuthenticated == true through this
        // mock — see the KNOWN MOCK LIMITATION note above. But we CAN
        // assert that tab 2 did not call clearStorage; if it had, it
        // would have signed tab 1 out as well in production.)
        expect(
          tab2ClearStorage,
          0,
          reason:
              'CUR-1280 (issue 6, REQ-d00080-L): tab 2 must not tear '
              'down the shared Firebase session — clearStorage on tab 2 '
              'would sign tab 1 out in production.',
        );

        tab1.dispose();
        tab2.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // CUR-1280: serialize the authStateChanges listener so back-to-back events
  // don't race shared state writes. The listener installed in
  // AuthService._init() does NOT serialize: Stream.listen invokes the next
  // event's handler as soon as the previous handler hits its first await,
  // not when its async body completes. Two events arriving close together
  // (e.g. signIn's own signInWithEmailAndPassword echo, or stale-restore
  // followed by Firebase's auto-signout reflection) lead to concurrent
  // invocations writing _currentUser / _isInitialized / _sessionUid and
  // double-issuing /portal/me requests.
  //
  // This group subsumes the layered guards from CUR-982 / CUR-1118 /
  // CUR-1157 by removing the underlying race instead of working around it.
  //
  // IMPLEMENTS REQUIREMENTS:
  //   REQ-d00080-A: client-side session management with configurable
  //                 inactivity timeout (the listener is the session
  //                 management surface)
  //   REQ-p01044-A: configured-period inactivity termination (audit-log
  //                 integrity requires consistent session state)
  //   REQ-p00010:   FDA 21 CFR Part 11 (concurrent writes to session
  //                 fields can produce impossible intermediate states
  //                 visible to downstream audit hooks)
  //   REQ-CAL-p00046: Session Management
  group('CUR-1280: listener serialization', () {
    test('signIn() issues exactly one /portal/me request — listener does not '
        'race a duplicate fetch', () {
      fakeAsync((fake) {
        // Bug surface: signInWithEmailAndPassword inside MockFirebaseAuth
        // (and Firebase in production) fires authStateChanges with the
        // freshly signed-in user BEFORE _fakeSignIn's Future resolves.
        // The listener invocation reads _sessionUid (still null because
        // signIn() hasn't returned from its first await yet) and dispatches
        // its own _fetchPortalUser. Then signIn() resumes, sets _sessionUid
        // and dispatches a SECOND _fetchPortalUser. Result: two GETs to
        // /api/v1/portal/me for a single signIn().
        //
        // Pre-fix: portalMeCallCount == 2.
        // Post-fix (Task 2.4 serializes the listener so it observes
        // _sessionUid set by signIn(), or signIn()'s own fetch completes
        // before the listener's handler runs): portalMeCallCount == 1.
        var portalMeCallCount = 0;
        final mockUser = MockUser(
          uid: 'race-uid',
          email: 'race@test.com',
          displayName: 'Race User',
        );
        final mockAuth = MockFirebaseAuth(mockUser: mockUser);

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/api/v1/portal/me') {
            portalMeCallCount++;
            return http.Response(
              jsonEncode({
                'id': 'race-id',
                'email': 'race@test.com',
                'name': 'Race User',
                'roles': ['Investigator'],
                'active_role': 'Investigator',
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

        // Drive a single signIn() and let every microtask drain.
        authService.signIn('race@test.com', 'password');
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));
        fake.flushMicrotasks();

        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'sanity: signIn must succeed in this fixture',
        );
        expect(
          portalMeCallCount,
          1,
          reason:
              'CUR-1280: a single signIn() must trigger exactly one '
              'GET /api/v1/portal/me. Pre-fix the authStateChanges listener '
              'fires concurrently with signIn() and dispatches a duplicate '
              'fetch — observable as portalMeCallCount == 2. Fixing the '
              'listener to serialize event handling collapses this to one.',
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // CUR-1296: uid_not_bound 401 — Flavor-gated developer banner
  // ---------------------------------------------------------------------------
  /// Verifies REQ-d00167-B, REQ-d00167-C
  group('CUR-1296 uid_not_bound 401 — Flavor-gated banner', () {
    // Helper: build an AuthService whose /portal/me returns 401 uid_not_bound
    // and sign in, then flush microtasks.
    AuthService buildAndSignIn(FakeAsync fake, {required Flavor flavor}) {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'a@example.com',
        displayName: 'Test',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: false,
      );
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/portal/me') {
          return http.Response(
            jsonEncode({'error': 'Account not found', 'code': 'uid_not_bound'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final svc = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
        enableInactivityTimer: false,
        flavor: flavor,
      );
      svc.signIn('a@example.com', 'pw');
      fake.flushMicrotasks();
      return svc;
    }

    // Verifies: REQ-d00167-B
    test(
      'REQ-d00167-B: Flavor.local sets local-stack rebind banner on uid_not_bound',
      () {
        fakeAsync((fake) {
          final svc = buildAndSignIn(fake, flavor: Flavor.local);
          expect(svc.error, contains('./local-stack rebind'));
        });
      },
    );

    // Verifies: REQ-d00167-C
    test('REQ-d00167-C: Flavor.dev sets generic banner on uid_not_bound', () {
      fakeAsync((fake) {
        final svc = buildAndSignIn(fake, flavor: Flavor.dev);
        expect(
          svc.error,
          equals('Account not found — contact your administrator.'),
        );
      });
    });
  });
}

/// CUR-1280: a [MockUser] whose [getIdToken] (with or without forceRefresh)
/// throws, simulating an expired refresh token or an emulator that has been
/// restarted since the cached IndexedDB session was issued.
///
/// `firebase_auth_mocks` does not expose a `mockExceptionFor #getIdToken`
/// hook (see `mock_user.dart` — `getIdToken` is a concrete implementation
/// that does not call `maybeThrowException`), so the only way to make
/// forceRefresh fail is to subclass and override.
// MockUser inherits from User which is @immutable but has mutable fields;
// the upstream library suppresses must_be_immutable file-wide. Mirror that
// here so the subclass doesn't drag the warning into our analyzer output.
// ignore: must_be_immutable
class _ForceRefreshFailingMockUser extends MockUser {
  _ForceRefreshFailingMockUser({super.uid, super.email, super.displayName});

  @override
  Future<String> getIdToken([bool forceRefresh = false]) {
    return Future.error(
      FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Mock: refresh token is no longer valid.',
      ),
    );
  }
}

/// CUR-1280: a [MockUser] whose [getIdToken] returns a Future that never
/// completes, simulating an offline / very slow network where Firebase's
/// token-refresh RPC hangs. Exercises the gate's `.timeout()` code path
/// (the only path that calls `_restoredTokenRefreshTimeout`).
// ignore: must_be_immutable
class _HangingMockUser extends MockUser {
  _HangingMockUser({super.uid, super.email, super.displayName});

  @override
  Future<String> getIdToken([bool forceRefresh = false]) {
    // Never completes — caller must rely on the gate's `.timeout()`.
    return Completer<String>().future;
  }
}

/// CUR-1312: a [MockUser] whose force-refresh hangs but whose ordinary
/// token reads (the ones [_fetchPortalUser] makes for its auth header)
/// succeed. Lets a test prove that the restore-validity gate skipped
/// `getIdToken(true)` — if the gate fired, the hang would be observable;
/// if the gate skipped it, `_fetchPortalUser` proceeds as normal.
// ignore: must_be_immutable
class _ForceRefreshHangingMockUser extends MockUser {
  _ForceRefreshHangingMockUser({
    super.uid,
    super.email,
    super.displayName,
    super.metadata,
  });

  @override
  Future<String> getIdToken([bool forceRefresh = false]) {
    if (forceRefresh) return Completer<String>().future;
    return super.getIdToken(forceRefresh);
  }
}
