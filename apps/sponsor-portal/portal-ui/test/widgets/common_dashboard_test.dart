// test/widgets/common_dashboard_test.dart

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/common_dashboard.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

// CUR-1118: Stub that always reports isInitialized=false and no current user,
// so widget tests can assert the spinner guard without racing against the
// async Firebase auth state emission that sets _isInitialized=true.
class _UninitializedAuthService extends AuthService {
  _UninitializedAuthService()
    : super(
        firebaseAuth: MockFirebaseAuth(signedIn: false),
        enableInactivityTimer: false,
      );

  @override
  bool get isInitialized => false;

  @override
  PortalUser? get currentUser => null;
}

/// Creates a signed-in [AuthService] for the given [role].
Future<AuthService> _createAuthServiceForRole(
  String role, {
  Duration inactivityTimeout = const Duration(
    seconds: 30,
  ), // match working test
}) async {
  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = MockClient((request) async {
    if (request.url.path == '/api/v1/portal/me') {
      return http.Response(
        jsonEncode({
          'id': 'user-001',
          'email': 'test@example.com',
          'name': 'Test User',
          'status': 'active',
          'roles': [role],
          'active_role': role,
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
  await authService.signIn('test@example.com', 'password');
  return authService;
}

Widget _wrapWithProvider({
  required AuthService authService,
  UserRole? role,
  GoRouter? router,
}) {
  final child = ChangeNotifierProvider<AuthService>.value(
    value: authService,
    child: CommonDashboard(role: role),
  );

  // Use a real GoRouter so context.replace('/login') doesn't throw
  return MaterialApp.router(
    routerConfig:
        router ??
        GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => child),
            GoRoute(
              path: '/login',
              builder: (_, __) => const Scaffold(body: Text('Login Page')),
            ),
          ],
        ),
  );
}

void main() {
  group('CommonDashboard', () {
    // REQ-d00080-A, REQ-p00024: role-based dashboard wrapped with session activity listener
    testWidgets('renders correct dashboard for each role via role parameter', (
      tester,
    ) async {
      // Test a sample of roles via the explicit role parameter
      final cases = [
        (UserRole.administrator, 'Admin Dashboard'),
        (UserRole.analyst, 'Analyst Dashboard'),
        (UserRole.auditor, 'Auditor Dashboard'),
        (UserRole.sponsor, 'Sponsor Dashboard'),
      ];

      for (final (role, expectedTitle) in cases) {
        final authService = await _createAuthServiceForRole(role.displayName);

        addTearDown(authService.signOut);

        await tester.pumpWidget(
          _wrapWithProvider(authService: authService, role: role),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(expectedTitle),
          findsAtLeastNWidgets(1),
          reason: 'Expected $expectedTitle for role ${role.displayName}',
        );

        // Flush the inactivity timer before next iteration
        await tester.pump(const Duration(seconds: 30));
      }
    });

    testWidgets('falls back to AuthService activeRole when role is null', (
      tester,
    ) async {
      final authService = await _createAuthServiceForRole('Investigator');
      addTearDown(authService.signOut);

      // Pass role: null — should read from AuthService
      await tester.pumpWidget(
        _wrapWithProvider(authService: authService, role: null),
      );
      await tester.pumpAndSettle();

      expect(find.text('Study Coordinator Dashboard'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });

    // CUR-1118: Spinner guard prevents flash-redirect to /login while Firebase
    // is still restoring its session asynchronously from IndexedDB.
    // Without this guard the dashboard would redirect to /login on every F5.
    testWidgets(
      'CUR-1118: shows spinner instead of redirecting while isInitialized=false',
      (tester) async {
        final authService = _UninitializedAuthService();
        addTearDown(authService.dispose);

        await tester.pumpWidget(
          _wrapWithProvider(authService: authService, role: null),
        );
        // One frame — isInitialized is false so the spinner guard must fire.
        await tester.pump();

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason:
              'Spinner must be shown while isInitialized=false to prevent '
              'flash-redirect on page refresh',
        );
        expect(
          find.text('Login Page'),
          findsNothing,
          reason:
              'Must NOT redirect to /login before Firebase has finished '
              'restoring the session — the user is on the page via a refresh',
        );
      },
    );

    // REQ-d00080-A: session management redirects to login when no authenticated user
    testWidgets('redirects to login when role is null and user is null', (
      tester,
    ) async {
      // Signed-out AuthService — currentUser is null
      final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
      final mockHttpClient = MockClient((_) async => http.Response('', 500));
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );

      await tester.pumpWidget(
        _wrapWithProvider(authService: authService, role: null),
      );
      await tester.pumpAndSettle();

      // Should have redirected to the login route
      expect(find.text('Login Page'), findsOneWidget);
    });
  });
}
