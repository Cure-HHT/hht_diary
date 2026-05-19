// Widget tests for AdminDashboardPage
//
// Pins the sidebar contents to the post-CUR-1122 state: only Users and
// Audit Logs should be visible. Regression-tests against accidental
// re-introduction of Overview / Sites / Participants destinations.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/admin/admin_dashboard_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

/// Mock HTTP client returning enough endpoints for the dashboard to boot
/// (auth/me) and for the embedded UserManagementTab to load without errors.
MockClient _createMockHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path == '/api/v1/portal/me') {
      return http.Response(
        jsonEncode({
          'id': 'admin-001',
          'email': 'admin@example.com',
          'name': 'Test Admin',
          'roles': ['Administrator'],
          'active_role': 'Administrator',
          'status': 'active',
          'sites': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/v1/portal/users') {
      return http.Response(
        jsonEncode({'users': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/v1/portal/sites') {
      return http.Response(
        jsonEncode({'sites': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.startsWith('/api/v1/sponsor/roles')) {
      return http.Response(
        jsonEncode({'mappings': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('Not found', 404);
  });
}

Future<void> _pumpAdminDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'admin@example.com',
    displayName: 'Test Admin',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient();

  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
    enableInactivityTimer: false,
  );
  await authService.signIn('admin@example.com', 'password');

  // GoRouter is required because the page calls context.go('/login') on the
  // unauthenticated path; even though auth is set up here, the redirect call
  // would still need a router context if anything goes sideways.
  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardPage()),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Login'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: authService,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('AdminDashboardPage sidebar (CUR-1122)', () {
    testWidgets('shows exactly two NavigationRail destinations', (
      tester,
    ) async {
      await _pumpAdminDashboard(tester);

      // Flutter's NavigationRail consumes destinations as model objects, so
      // find.byType(NavigationRailDestination) returns 0 in the render
      // tree. Read the NavigationRail widget itself and count its
      // configured destinations.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, equals(2));
    });

    testWidgets('shows Users and Audit Logs labels', (tester) async {
      await _pumpAdminDashboard(tester);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);
    });

    testWidgets('does not show removed Overview / Sites / Participants', (
      tester,
    ) async {
      await _pumpAdminDashboard(tester);
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Sites'), findsNothing);
      expect(find.text('Participants'), findsNothing);
      expect(find.text('Patients'), findsNothing);
    });

    testWidgets('Audit Logs tab renders the placeholder', (tester) async {
      await _pumpAdminDashboard(tester);

      // Tap the Audit Logs destination
      await tester.tap(find.text('Audit Logs'));
      await tester.pumpAndSettle();

      // Placeholder text mirrors the Investigator dashboard pattern.
      expect(
        find.text('Audit log viewing will be available in a future update.'),
        findsOneWidget,
      );
    });

    testWidgets('initial selected tab is Users (index 0)', (tester) async {
      await _pumpAdminDashboard(tester);

      // Reading the NavigationRail's selectedIndex is more robust than
      // depending on the embedded UserManagementTab's rendered content
      // (which makes API calls and may not reach a stable state in tests).
      // The negative assertion on the Audit Logs placeholder additionally
      // pins that index 0 is NOT the Audit Logs tab.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, equals(0));
      expect(
        find.text('Audit log viewing will be available in a future update.'),
        findsNothing,
      );
    });
  });
}
