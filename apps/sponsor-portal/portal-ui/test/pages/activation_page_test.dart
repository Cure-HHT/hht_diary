// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166: Server-owned portal activation
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/pages/activation_page.dart';

/// Pumps an [ActivationPage] with the given code and mock HTTP client.
///
/// Uses a GoRouter with stub `/login` and `/common-dashboard` routes so
/// post-activation navigation doesn't throw a missing-route error.
Widget makeActivationPage({
  required String code,
  required http.Client httpClient,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            ActivationPage(code: code, httpClient: httpClient),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: Text('login-page-stub')),
      ),
      GoRoute(
        path: '/common-dashboard',
        builder: (context, state) =>
            const Scaffold(body: Text('dashboard-stub')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  // CUR-1312: activation page no longer auto-signs-in. Server-side
  // activation succeeds → success modal → /login. The user signs in via
  // the standard /login flow (which goes through AuthService.signIn() and
  // therefore does NOT trip the auth_service.dart fresh-tab restore branch
  // that was silently signing newly-activated users out).
  group('CUR-1296 server-owned activation', () {
    // Verifies: REQ-d00166-A
    testWidgets('REQ-d00166-A + CUR-1312: happy path — POSTs {code, password}, '
        'shows success modal, routes to /login on dismiss', (tester) async {
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
        if (req.method == 'POST' && req.url.path == '/api/v1/portal/activate') {
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

      await tester.pumpWidget(
        makeActivationPage(code: 'HAPPY-CODE1', httpClient: mockClient),
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
      final activatePosts = apiCalls
          .where(
            (c) =>
                c['path'] == '/api/v1/portal/activate' && c['method'] == 'POST',
          )
          .toList();
      expect(activatePosts, hasLength(1));
      final body = activatePosts.first['body'] as Map<String, dynamic>;
      expect(body['code'], equals('HAPPY-CODE1'));
      expect(body['password'], equals('pw123456'));

      // CUR-1312: success modal visible.
      expect(find.text('Account activated'), findsOneWidget);
      expect(find.text('Please sign in to continue.'), findsOneWidget);

      // Tapping the modal's Sign in button dismisses and routes to /login.
      await tester.tap(find.byKey(const Key('activatedDialogSignInButton')));
      await tester.pumpAndSettle();

      expect(find.text('login-page-stub'), findsOneWidget);
      expect(find.text('dashboard-stub'), findsNothing);
    });

    // Verifies: REQ-d00166-B
    testWidgets(
      'REQ-d00166-B: code_invalid surfaces the right copy, no modal, no nav',
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

        await tester.pumpWidget(
          makeActivationPage(code: 'BADBA-DCODE', httpClient: mockClient),
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

        // No success modal, no navigation to login or dashboard.
        expect(find.text('Account activated'), findsNothing);
        expect(find.text('login-page-stub'), findsNothing);
        expect(find.text('dashboard-stub'), findsNothing);
      },
    );
  });
}
