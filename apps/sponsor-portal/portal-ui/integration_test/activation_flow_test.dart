// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: First Admin Provisioning
//   REQ-CAL-p00043: Password Requirements
//   REQ-CAL-p00062: Activation Link Expiration

@Tags(['ui'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sponsor_portal_ui/pages/activation_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/theme/portal_theme.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeFirebaseForTests();
  });

  tearDown(() async {
    await signOutCurrentUser();
  });

  Widget buildActivationTestApp({String? code, http.Client? client}) {
    final testRouter = GoRouter(
      initialLocation: '/activate',
      routes: [
        GoRoute(
          path: '/activate',
          builder: (context, state) {
            return ActivationPage(code: code, httpClient: client);
          },
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Admin Dashboard'))),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Login Page'))),
        ),
      ],
    );

    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp.router(
        title: 'Portal UI Activation Test',
        theme: portalTheme,
        routerConfig: testRouter,

        debugShowCheckedModeBanner: false,
      ),
    );
  }

  group('Activation Page UI', () {
    testWidgets('loads activation page', (tester) async {
      await tester.pumpWidget(buildActivationTestApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Enter Valid code to Activate Your Account'),
        findsOneWidget,
      );
    });

    testWidgets('shows login link', (tester) async {
      await tester.pumpWidget(buildActivationTestApp());
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextButton, 'Already have an account? Sign in'),
        findsOneWidget,
      );
    });

    testWidgets('navigates to login when link clicked', (tester) async {
      await tester.pumpWidget(buildActivationTestApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(TextButton, 'Already have an account? Sign in'),
      );

      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);
    });
  });

  group('Activation Code from URL', () {
    testWidgets('activation flow works with generated code', (tester) async {
      const activationCode = "Test-Code";
      final mockHttpClient = MockClient(
        (_) async =>
            http.Response('{"valid": true,"email":"test@email.com"}', 200),
      );
      await tester.pumpWidget(
        buildActivationTestApp(code: activationCode, client: mockHttpClient),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Password screen should appear
      expect(find.text('Create Your Password'), findsOneWidget);
    });
  });

  group('Password Creation Form', () {
    testWidgets('password form elements exist when validated', (tester) async {
      await tester.pumpWidget(buildActivationTestApp());
      await tester.pumpAndSettle();

      // Simulate validated state by accessing widget state
      final state = tester.state(find.byType(ActivationPage)) as dynamic;

      state.setState(() {
        state.codeValidated = true;
        state.maskedEmail = 't***@example.com';
      });

      await tester.pumpAndSettle();

      expect(find.text('Create Your Password'), findsOneWidget);
      expect(find.text('Set a password for your account'), findsOneWidget);

      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        findsOneWidget,
      );

      expect(
        find.widgetWithText(FilledButton, 'Activate Account'),
        findsOneWidget,
      );

      expect(
        find.widgetWithText(TextButton, 'Use Different Code'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error for mismatched passwords', (
      tester,
    ) async {
      await tester.pumpWidget(buildActivationTestApp());
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(ActivationPage)) as dynamic;

      state.setState(() {
        state.codeValidated = true;
        state.maskedEmail = 't***@example.com';
      });

      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'password999',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Activate Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
