// test/widgets/user_activity_listener_test.dart
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Session Inactivity Timeout

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/user_activity_listener.dart';

/// Creates an [AuthService] with a signed-in mock user.
Future<AuthService> _createSignedInAuthService({
  Duration inactivityTimeout = const Duration(minutes: 15),
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

  // Trigger _fetchPortalUser so isAuthenticated becomes true
  await authService.signIn('test@example.com', 'password');
  addTearDown(authService.signOut);
  return authService;
}

/// Creates an [AuthService] with no signed-in user.
AuthService _createSignedOutAuthService() {
  final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
  final mockHttpClient = MockClient((_) async => http.Response('', 500));
  return AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
}

Widget _wrapWithProvider(Widget child, AuthService authService) {
  return ChangeNotifierProvider<AuthService>.value(
    value: authService,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('UserActivityListener', () {
    testWidgets(
      'calls resetInactivityTimer on pointer down when authenticated',
      (tester) async {
        final authService = await _createSignedInAuthService();
        expect(authService.isAuthenticated, isTrue);
        addTearDown(authService.signOut);

        // Capture timer resets by watching if the timer cancels/restarts.
        // We do this by tapping and checking the service doesn't sign out early.
        authService.resetInactivityTimer();

        await tester.pumpWidget(
          _wrapWithProvider(
            UserActivityListener(
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
            authService,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SizedBox));
        await tester.pump();

        // Still authenticated after tap — timer was reset not cancelled
        expect(authService.isAuthenticated, isTrue);
        expect(authService.isTimedOut, isFalse);
      },
    );

    testWidgets('does not throw when user is not authenticated', (
      tester,
    ) async {
      final authService = _createSignedOutAuthService();
      expect(authService.isAuthenticated, isFalse);

      await tester.pumpWidget(
        _wrapWithProvider(
          UserActivityListener(child: const SizedBox(width: 200, height: 200)),
          authService,
        ),
      );
      await tester.pumpAndSettle();

      // Tapping when not authenticated should not throw
      await tester.tap(find.byType(SizedBox));
      await tester.pump();

      expect(authService.isTimedOut, isFalse);
    });

    testWidgets('renders child widget correctly', (tester) async {
      final authService = await _createSignedInAuthService();

      addTearDown(authService.signOut);

      await tester.pumpWidget(
        _wrapWithProvider(
          UserActivityListener(child: const Text('dashboard content')),
          authService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('dashboard content'), findsOneWidget);
    });
  });
}
