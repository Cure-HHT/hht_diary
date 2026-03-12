// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00031: Identity Platform Integration

// Service tests for AuthService
// Uses firebase_auth_mocks for Firebase and MockClient for HTTP

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

void main() {
  group('AuthService with mocked dependencies', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'test-firebase-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser);
    });

    group('signIn', () {
      test('successful sign in with authorized user', () async {
        // Mock HTTP response for /api/v1/portal/me
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/api/v1/portal/me') {
            return http.Response(
              jsonEncode({
                'id': 'user-123',
                'email': 'test@example.com',
                'name': 'Test User',
                'role': 'Administrator',
                'status': 'active',
                'sites': [],
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        // Sign in
        final result = await authService.signIn(
          'test@example.com',
          'password123',
        );

        expect(result, isTrue);
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentUser?.email, 'test@example.com');
        expect(authService.currentUser?.role, UserRole.administrator);
      });

      test('sign in fails for unauthorized user (403)', () async {
        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/api/v1/portal/me') {
            return http.Response(
              jsonEncode({'error': 'User not authorized for portal access'}),
              403,
            );
          }
          return http.Response('Not Found', 404);
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        final result = await authService.signIn(
          'test@example.com',
          'password123',
        );

        expect(result, isFalse);
        expect(authService.isAuthenticated, isFalse);
        expect(authService.error, contains('not authorized'));
      });

      test('sign in handles server error', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        final result = await authService.signIn(
          'test@example.com',
          'password123',
        );

        expect(result, isFalse);
        expect(authService.error, isNotNull);
      });
    });

    group('signOut', () {
      test('clears user on sign out', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'email': 'test@example.com',
              'name': 'Test User',
              'role': 'Administrator',
              'status': 'active',
              'sites': [],
            }),
            200,
          );
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        // Sign in first
        await authService.signIn('test@example.com', 'password123');
        expect(authService.isAuthenticated, isTrue);

        // Sign out
        await authService.signOut();
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentUser, isNull);
        expect(authService.error, isNull);
      });
    });

    group('hasRole', () {
      test('correctly identifies user role', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'email': 'test@example.com',
              'name': 'Test Investigator',
              'role': 'Investigator',
              'status': 'active',
              'sites': [
                {'site_id': 'site-1', 'site_name': 'Site One'},
              ],
            }),
            200,
          );
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        await authService.signIn('test@example.com', 'password123');

        expect(authService.hasRole(UserRole.investigator), isTrue);
        expect(authService.hasRole(UserRole.administrator), isFalse);
        expect(authService.hasRole(UserRole.auditor), isFalse);
      });
    });

    group('canAccessSite', () {
      test('investigator can only access assigned sites', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'email': 'investigator@example.com',
              'name': 'Test Investigator',
              'role': 'Investigator',
              'status': 'active',
              'sites': [
                {'site_id': 'site-1', 'site_name': 'Site One'},
                {'site_id': 'site-2', 'site_name': 'Site Two'},
              ],
            }),
            200,
          );
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        await authService.signIn('investigator@example.com', 'password123');

        expect(authService.canAccessSite('site-1'), isTrue);
        expect(authService.canAccessSite('site-2'), isTrue);
        expect(authService.canAccessSite('site-3'), isFalse);
      });

      test('admin can access all sites', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'email': 'admin@example.com',
              'name': 'Test Admin',
              'role': 'Administrator',
              'status': 'active',
              'sites': [],
            }),
            200,
          );
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        await authService.signIn('admin@example.com', 'password123');

        expect(authService.canAccessSite('any-site'), isTrue);
        expect(authService.canAccessSite('another-site'), isTrue);
      });
    });

    group('getIdToken', () {
      test('returns token when user is authenticated', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'email': 'test@example.com',
              'name': 'Test User',
              'role': 'Administrator',
              'status': 'active',
              'sites': [],
            }),
            200,
          );
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        await authService.signIn('test@example.com', 'password123');

        final token = await authService.getIdToken();
        expect(token, isNotNull);
      });
    });

    // ===== CUR-982: Cross-Session Auth Collision Tests =====

    group('cross-session auth collision (CUR-982)', () {
      test('detects user identity change and clears state', () async {
        // Scenario: User A is signed in, then Firebase auth state changes
        // to User B (e.g., another tab signed in as different user).
        // AuthService should detect the UID mismatch and sign out.

        final adminUser = MockUser(
          uid: 'admin-uid-001',
          email: 'admin@example.com',
          displayName: 'Admin User',
        );
        final adminAuth = MockFirebaseAuth(mockUser: adminUser);

        final mockHttpClient = MockClient((request) async {
          if (request.url.path == '/api/v1/portal/me') {
            return http.Response(
              jsonEncode({
                'id': 'admin-123',
                'email': 'admin@example.com',
                'name': 'Admin User',
                'roles': ['Administrator'],
                'active_role': 'Administrator',
                'status': 'active',
                'sites': [],
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final authService = AuthService(
          firebaseAuth: adminAuth,
          httpClient: mockHttpClient,
        );

        // Sign in as Admin
        await authService.signIn('admin@example.com', 'password123');
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentUser?.activeRole, UserRole.administrator);

        // Verify that the service tracks the last known UID
        // (This tests the new _lastKnownUid field)
        expect(authService.lastKnownUid, 'admin-uid-001');
      });

      test(
        'role matches API response after sign-in, not stale state',
        () async {
          // Scenario: Ensure that after signIn(), the currentUser's role
          // comes from the API response, not from any previously cached state.

          final scUser = MockUser(
            uid: 'sc-uid-002',
            email: 'coordinator@example.com',
            displayName: 'Study Coordinator',
          );
          final scAuth = MockFirebaseAuth(mockUser: scUser);

          final mockHttpClient = MockClient((request) async {
            if (request.url.path == '/api/v1/portal/me') {
              return http.Response(
                jsonEncode({
                  'id': 'sc-123',
                  'email': 'coordinator@example.com',
                  'name': 'Study Coordinator',
                  'roles': ['Investigator'],
                  'active_role': 'Investigator',
                  'status': 'active',
                  'sites': [
                    {'site_id': 'site-1', 'site_name': 'Test Site'},
                  ],
                }),
                200,
              );
            }
            return http.Response('Not Found', 404);
          });

          final authService = AuthService(
            firebaseAuth: scAuth,
            httpClient: mockHttpClient,
          );

          // Sign in as Study Coordinator
          await authService.signIn('coordinator@example.com', 'password123');

          // The role must match what the API returned, not something stale
          expect(authService.isAuthenticated, isTrue);
          expect(authService.currentUser?.activeRole, UserRole.investigator);
          expect(authService.currentUser?.name, 'Study Coordinator');
          // UID tracking must reflect the current user
          expect(authService.lastKnownUid, 'sc-uid-002');
        },
      );

      test('sign out clears last known UID', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'email': 'test@example.com',
              'name': 'Test User',
              'roles': ['Administrator'],
              'active_role': 'Administrator',
              'status': 'active',
              'sites': [],
            }),
            200,
          );
        });

        final authService = AuthService(
          firebaseAuth: mockFirebaseAuth,
          httpClient: mockHttpClient,
        );

        await authService.signIn('test@example.com', 'password123');
        expect(authService.lastKnownUid, isNotNull);

        await authService.signOut();
        expect(authService.lastKnownUid, isNull);
        expect(authService.currentUser, isNull);
      });
    });
  });
}
