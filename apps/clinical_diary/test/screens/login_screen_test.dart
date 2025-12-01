// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management

import 'package:clinical_diary/screens/login_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen', () {
    late MockSecureStorage mockStorage;
    late FakeFirebaseFirestore fakeFirestore;
    late AuthService authService;

    setUp(() {
      mockStorage = MockSecureStorage();
      fakeFirestore = FakeFirebaseFirestore();
      authService = AuthService(
        secureStorage: mockStorage,
        firestore: fakeFirestore,
      );
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: LoginScreen(authService: authService, onLoginSuccess: () {}),
      );
    }

    // Helper to scroll to and tap a widget
    Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    // Helper to scroll to and enter text
    Future<void> scrollAndEnterText(
      WidgetTester tester,
      Finder finder,
      String text,
    ) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
    }

    group('UI Elements', () {
      testWidgets('displays login title in app bar', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Login'), findsWidgets);
      });

      testWidgets('displays privacy notice', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Privacy Notice'), findsOneWidget);
      });

      testWidgets('displays important security notice', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Important'), findsOneWidget);
      });

      testWidgets('displays username field', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Username'), findsWidgets);
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Password'), findsWidgets);
      });

      testWidgets('displays create account toggle text', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final finder = find.textContaining("Don't have an account?");
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();

        expect(finder, findsOneWidget);
      });
    });

    group('Password Visibility Toggle', () {
      testWidgets('password field has visibility toggle', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Find visibility_off icon (password hidden by default)
        expect(find.byIcon(Icons.visibility_off), findsWidgets);
      });

      testWidgets('toggles password visibility when icon tapped', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Find the password field's visibility toggle
        final visibilityOff = find.byIcon(Icons.visibility_off);
        expect(visibilityOff, findsOneWidget);

        // Tap the visibility toggle
        await scrollAndTap(tester, visibilityOff);

        // Now password is visible (visibility icon shown)
        expect(find.byIcon(Icons.visibility), findsOneWidget);

        // Tap again to hide
        await scrollAndTap(tester, find.byIcon(Icons.visibility));

        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      });
    });

    group('Mode Toggle', () {
      testWidgets('toggles to register mode when create account tapped', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Initially in login mode
        expect(find.text('Login'), findsWidgets);

        // Scroll to and tap the toggle button
        final toggleButton = find.textContaining("Don't have an account?");
        await scrollAndTap(tester, toggleButton);

        // Now in register mode - app bar title should change
        expect(find.text('Create Account'), findsWidgets);
      });

      testWidgets('shows confirm password field in register mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Initially no confirm password field
        expect(find.text('Confirm Password'), findsNothing);

        // Switch to register mode
        await scrollAndTap(
          tester,
          find.textContaining("Don't have an account?"),
        );

        // Now confirm password field is visible
        final confirmField = find.text('Confirm Password');
        await tester.ensureVisible(confirmField);
        expect(confirmField, findsOneWidget);
      });

      testWidgets('toggles back to login mode', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Switch to register mode
        await scrollAndTap(
          tester,
          find.textContaining("Don't have an account?"),
        );

        expect(find.text('Create Account'), findsWidgets);

        // Switch back to login mode
        await scrollAndTap(
          tester,
          find.textContaining('Already have an account?'),
        );

        expect(find.text('Login'), findsWidgets);
        expect(find.text('Confirm Password'), findsNothing);
      });
    });

    group('Form Validation', () {
      testWidgets('shows error when username is empty', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Enter only password
        final usernameField = find.widgetWithText(TextFormField, 'Username');
        await scrollAndEnterText(tester, usernameField, '');

        final passwordField = find.widgetWithText(TextFormField, 'Password');
        await scrollAndEnterText(tester, passwordField, 'password123');

        // Tap login button
        final loginButton = find.widgetWithText(FilledButton, 'Login');
        await scrollAndTap(tester, loginButton);

        expect(find.text('Username is required'), findsOneWidget);
      });

      testWidgets('shows error when username is too short', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'abc',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );

        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.textContaining('at least'), findsOneWidget);
      });

      testWidgets('shows error when username contains @', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'user@test',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );

        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.text('Username cannot contain @ symbol'), findsOneWidget);
      });

      testWidgets('shows error when username has invalid characters', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'user name',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );

        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.textContaining('letters, numbers'), findsOneWidget);
      });

      testWidgets('shows error when password is empty', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'validuser',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          '',
        );

        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.text('Password is required'), findsOneWidget);
      });

      testWidgets('shows error when password is too short', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'validuser',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'short',
        );

        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.textContaining('at least'), findsWidgets);
      });

      testWidgets('shows error when passwords do not match in register mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Switch to register mode
        await scrollAndTap(
          tester,
          find.textContaining("Don't have an account?"),
        );

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'newuser123',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'different12',
        );

        await scrollAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Create Account'),
        );

        expect(find.text('Passwords do not match'), findsOneWidget);
      });
    });

    group('Form Submission', () {
      testWidgets('shows error message on login failure', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'nonexistent',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );

        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        // Should show error message
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Invalid'), findsOneWidget);
      });

      testWidgets('clears error message when username text changes', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Trigger login failure
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'nonexistent',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );
        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Type in username field - error should clear
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'newtext123',
        );

        // Error should be cleared
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });

      testWidgets('clears error message when password text changes', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Trigger login failure
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'nonexistent',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );
        await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Login'));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Type in password field - error should clear
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'newpassword',
        );

        // Error should be cleared
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });

      testWidgets('shows error for taken username in register mode', (
        tester,
      ) async {
        // Create existing user
        await fakeFirestore.collection('users').doc('existinguser').set({
          'username': 'existinguser',
          'passwordHash': 'somehash',
        });

        await tester.pumpWidget(buildTestWidget());

        // Switch to register mode
        await scrollAndTap(
          tester,
          find.textContaining("Don't have an account?"),
        );

        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Username'),
          'existinguser',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );
        await scrollAndEnterText(
          tester,
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'password123',
        );

        await scrollAndTap(
          tester,
          find.widgetWithText(FilledButton, 'Create Account'),
        );

        expect(find.textContaining('already taken'), findsOneWidget);
      });
    });

    group('Confirm Password Visibility', () {
      testWidgets('toggles confirm password visibility', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Switch to register mode
        await scrollAndTap(
          tester,
          find.textContaining("Don't have an account?"),
        );

        // Find all visibility_off icons (password has one, confirm has one)
        expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));

        // Tap the second visibility_off icon (confirm password)
        final icons = find.byIcon(Icons.visibility_off);
        await tester.ensureVisible(icons.last);
        await tester.pumpAndSettle();
        await tester.tap(icons.last);
        await tester.pumpAndSettle();

        // Now there should be one visibility_off (password) and one visibility (confirm)
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });
    });

    group('AuthService Integration', () {
      test('validates username format', () {
        expect(authService.validateUsername(''), isNotNull);
        expect(authService.validateUsername('short'), isNotNull);
        expect(authService.validateUsername('user@domain'), isNotNull);
        expect(authService.validateUsername('validuser'), isNull);
      });

      test('validates password format', () {
        expect(authService.validatePassword(''), isNotNull);
        expect(authService.validatePassword('short'), isNotNull);
        expect(authService.validatePassword('password123'), isNull);
      });

      test('login fails with non-existent user', () async {
        final result = await authService.login(
          username: 'nonexistent',
          password: 'password123',
        );
        expect(result.success, false);
        expect(result.errorMessage, contains('Invalid'));
      });

      test('login succeeds with valid credentials', () async {
        // Create test user
        await fakeFirestore.collection('users').doc('testuser').set({
          'username': 'testuser',
          'passwordHash': authService.hashPassword('password123'),
          'appUuid': 'test-uuid',
        });

        final result = await authService.login(
          username: 'testuser',
          password: 'password123',
        );
        expect(result.success, true);
        expect(result.user?.username, 'testuser');
      });

      test('registration creates user in Firestore', () async {
        final result = await authService.register(
          username: 'newuser123',
          password: 'password123',
        );

        expect(result.success, true);

        final doc = await fakeFirestore
            .collection('users')
            .doc('newuser123')
            .get();
        expect(doc.exists, true);
        expect(doc.data()!['username'], 'newuser123');
      });

      test('registration fails for taken username', () async {
        await fakeFirestore.collection('users').doc('existinguser').set({
          'username': 'existinguser',
          'passwordHash': 'somehash',
        });

        final result = await authService.register(
          username: 'existinguser',
          password: 'password123',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('already taken'));
      });
    });
  });
}

/// Mock implementation of FlutterSecureStorage for testing
class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(data);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.clear();
  }

  @override
  IOSOptions get iOptions => IOSOptions.defaultOptions;

  @override
  AndroidOptions get aOptions => AndroidOptions.defaultOptions;

  @override
  LinuxOptions get lOptions => LinuxOptions.defaultOptions;

  @override
  WebOptions get webOptions => WebOptions.defaultOptions;

  @override
  MacOsOptions get mOptions => MacOsOptions.defaultOptions;

  @override
  WindowsOptions get wOptions => WindowsOptions.defaultOptions;

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool> get onCupertinoProtectedDataAvailabilityChanged =>
      Stream.value(true);

  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterAllListeners() {}

  @override
  void unregisterAllListenersForKey({required String key}) {}
}
