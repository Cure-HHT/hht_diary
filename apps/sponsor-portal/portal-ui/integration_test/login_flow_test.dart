// IMPLEMENTS REQUIREMENTS:
//   REQ-d00034: Login Page Implementation
//   REQ-d00031: Identity Platform Integration
//   REQ-p00024: Portal User Roles and Permissions
//
// Flutter UI integration test for login flow.
// Tests the complete login journey through the UI:
// 1. Launch app on login page
// 2. Enter credentials (email/password)
// 3. Submit form
// 4. Navigate to dashboard on success
//
// Prerequisites:
// - Portal server running on localhost:8080
// - Auth: Firebase emulator (default) or GCP Identity Platform (--dev mode)
// - Database seeded with dev admin users

@Tags(['ui'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeFirebaseForTests();
  });

  tearDown(() async {
    // Sign out after each test to ensure clean state
    await signOutCurrentUser();
  });

  group('Login Page UI', () {
    testWidgets('displays login form elements', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify login page elements are present
      expect(find.text('Clinical Trial Portal'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap sign in without entering anything
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter invalid email
      final emailField = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emailField, 'notanemail');

      // Enter password to avoid that validation error
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      await tester.enterText(passwordField, 'somepassword');

      // Tap sign in
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should show validation error for invalid email
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows validation error for empty password', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter valid email but no password
      final emailField = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emailField, 'test@example.com');

      // Tap sign in
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Should show validation error for password
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Find password field and enter text
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      await tester.enterText(passwordField, 'testpassword');
      await tester.pumpAndSettle();

      // Initially password should be obscured (visibility_outlined icon shown)
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Now should show visibility_off_outlined (password visible)
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('Login Flow with Real Services', () {
    testWidgets('shows error for invalid credentials', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter invalid credentials
      final emailField = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emailField, 'nonexistent@example.com');

      final passwordField = find.widgetWithText(TextFormField, 'Password');
      await tester.enterText(passwordField, 'wrongpassword');

      // Tap sign in
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));

      // Wait for the async sign-in attempt
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should show error message (user not found or invalid credentials)
      final errorFinder = find.textContaining(
        RegExp(r'(Invalid email or password|No account found)'),
      );
      expect(errorFinder, findsOneWidget);
    });

    testWidgets(
      'dev admin can sign in and navigate to dashboard',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Enter dev admin credentials
        final emailField = find.widgetWithText(TextFormField, 'Email');
        await tester.enterText(emailField, IntegrationTestConfig.devAdminEmail);

        final passwordField = find.widgetWithText(TextFormField, 'Password');
        await tester.enterText(
          passwordField,
          IntegrationTestConfig.devAdminPassword,
        );

        // Tap sign in
        await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));

        // Wait for authentication and navigation
        // This may take a few seconds as it involves real network calls
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Should have navigated away from login page
        // Dev admin goes to /dev-admin dashboard
        expect(find.text('Sign in to continue'), findsNothing);

        // Should see dev admin dashboard or role picker
        // (depends on whether user has multiple roles)
        final dashboardOrRolePicker = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.contains('Dashboard') == true ||
                  widget.data?.contains('Select Role') == true),
        );
        expect(dashboardOrRolePicker, findsWidgets);
      },
      skip: !IntegrationTestConfig.useDevIdentity,
      // Skip if using Firebase emulator without seeded users
    );
  });
}
