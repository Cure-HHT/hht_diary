// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166: Server-owned portal activation
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/pages/activation_page.dart';

/// A [MockFirebaseAuth] subclass that records which auth methods were called.
///
/// Used in place of Mockito verify() — the project does not depend on mockito.
class TrackingFirebaseAuth extends MockFirebaseAuth {
  final List<Map<String, String>> signInCalls = [];
  final List<Map<String, String>> createUserCalls = [];

  TrackingFirebaseAuth({super.mockUser});

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    signInCalls.add({'email': email, 'password': password});
    return super.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    createUserCalls.add({'email': email, 'password': password});
    return super.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}

/// Pumps an [ActivationPage] with the given code and mock dependencies.
///
/// Uses a GoRouter with a minimal route so the dashboard redirect doesn't
/// throw a missing-route error.
Widget makeActivationPage({
  required String code,
  required http.Client httpClient,
  required TrackingFirebaseAuth firebaseAuth,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ActivationPage(
          code: code,
          httpClient: httpClient,
          firebaseAuth: firebaseAuth,
        ),
      ),
      GoRoute(
        path: '/common-dashboard',
        builder: (context, state) => const Scaffold(body: Text('dashboard')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  // Verifies REQ-d00166-A, REQ-d00166-B
  group('CUR-1296 server-owned activation', () {
    // Verifies: REQ-d00166-A
    testWidgets(
      'REQ-d00166-A: happy path — POSTs {code, password} to server, signs in, routes to dashboard',
      (tester) async {
        final apiCalls = <Map<String, Object?>>[];
        final mockClient = MockClient((req) async {
          apiCalls.add({
            'method': req.method,
            'path': req.url.path,
            'body': req.body.isEmpty ? null : jsonDecode(req.body),
          });
          // GET /api/v1/portal/activate/HAPPY-CODE1 — code validation
          if (req.method == 'GET' &&
              req.url.path.endsWith('/api/v1/portal/activate/HAPPY-CODE1')) {
            return http.Response(
              jsonEncode({'email': 'happy@example.com'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          // POST /api/v1/portal/activate — server-side activation
          if (req.method == 'POST' &&
              req.url.path == '/api/v1/portal/activate') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'roles': ['Administrator'],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected ${req.url.path}', 500);
        });

        final mockAuth = TrackingFirebaseAuth(
          mockUser: MockUser(uid: 'test-uid', email: 'happy@example.com'),
        );

        await tester.pumpWidget(
          makeActivationPage(
            code: 'HAPPY-CODE1',
            httpClient: mockClient,
            firebaseAuth: mockAuth,
          ),
        );

        // Let the auto-validate complete (post-frame callback + http response)
        await tester.pumpAndSettle();

        // Password form should now be visible after successful code validation
        await tester.enterText(
          find.byKey(const Key('passwordField')),
          'pw123456',
        );
        await tester.enterText(
          find.byKey(const Key('confirmPasswordField')),
          'pw123456',
        );
        await tester.ensureVisible(find.byKey(const Key('activateButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('activateButton')));
        await tester.pumpAndSettle();

        // Server-side activate POST happened with the right body shape.
        // (The GET also runs twice — once for _validateCode and once for
        // _getEmailFromCode — both are expected.)
        final activatePosts = apiCalls
            .where(
              (c) =>
                  c['path'] == '/api/v1/portal/activate' &&
                  c['method'] == 'POST',
            )
            .toList();
        expect(activatePosts, hasLength(1));
        final body = activatePosts.first['body'] as Map<String, dynamic>;
        expect(body['code'], equals('HAPPY-CODE1'));
        expect(body['password'], equals('pw123456'));

        // Client signed in with the same password.
        expect(mockAuth.signInCalls, hasLength(1));
        expect(
          mockAuth.signInCalls.first['email'],
          equals('happy@example.com'),
        );
        expect(mockAuth.signInCalls.first['password'], equals('pw123456'));

        // Client did NOT try to create the IdP user — the server does that now.
        expect(
          mockAuth.createUserCalls,
          isEmpty,
          reason:
              'createUserWithEmailAndPassword must NOT be called (CUR-1296)',
        );
      },
    );

    // Verifies: REQ-d00166-B
    testWidgets(
      'REQ-d00166-B: code_invalid surfaces the right copy, no Firebase calls',
      (tester) async {
        final mockClient = MockClient((req) async {
          if (req.method == 'GET' &&
              req.url.path.endsWith('/api/v1/portal/activate/BADBA-DCODE')) {
            // Validation succeeds so the form is shown
            return http.Response(
              jsonEncode({'email': 'x@example.com'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.method == 'POST' &&
              req.url.path == '/api/v1/portal/activate') {
            return http.Response(
              jsonEncode({
                'error': 'Invalid activation code',
                'code': 'code_invalid',
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected', 500);
        });

        final mockAuth = TrackingFirebaseAuth(
          mockUser: MockUser(uid: 'uid', email: 'x@example.com'),
        );

        await tester.pumpWidget(
          makeActivationPage(
            code: 'BADBA-DCODE',
            httpClient: mockClient,
            firebaseAuth: mockAuth,
          ),
        );
        await tester.pumpAndSettle();

        // Enter passwords and attempt activation
        await tester.enterText(
          find.byKey(const Key('passwordField')),
          'pw123456',
        );
        await tester.enterText(
          find.byKey(const Key('confirmPasswordField')),
          'pw123456',
        );
        await tester.ensureVisible(find.byKey(const Key('activateButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('activateButton')));
        await tester.pumpAndSettle();

        // Should show the code_invalid user-facing message
        expect(
          find.textContaining('invalid', skipOffstage: false),
          findsWidgets,
        );

        // No Firebase calls should have been made
        expect(
          mockAuth.signInCalls,
          isEmpty,
          reason: 'signInWithEmailAndPassword must NOT be called on error',
        );
        expect(
          mockAuth.createUserCalls,
          isEmpty,
          reason:
              'createUserWithEmailAndPassword must NOT be called (CUR-1296)',
        );
      },
    );
  });
}
