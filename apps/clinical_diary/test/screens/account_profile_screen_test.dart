// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management

import 'dart:convert';

import 'package:clinical_diary/screens/account_profile_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountProfileScreen', () {
    late MockSecureStorage mockStorage;
    late AuthService authService;

    /// Creates a mock HTTP client with configurable responses
    MockClient createMockClient({
      int changePasswordStatus = 200,
      Map<String, dynamic>? changePasswordResponse,
    }) {
      return MockClient((request) async {
        final uri = request.url.toString();

        if (uri.contains('/changePassword')) {
          return http.Response(
            jsonEncode(changePasswordResponse ?? {'success': true}),
            changePasswordStatus,
          );
        }

        return http.Response('Not found', 404);
      });
    }

    setUp(() {
      mockStorage = MockSecureStorage();
      authService = AuthService(
        secureStorage: mockStorage,
        httpClient: createMockClient(),
      );
    });

    Widget buildTestWidget() {
      return MaterialApp(home: AccountProfileScreen(authService: authService));
    }

    group('UI Elements', () {
      testWidgets('displays Account title in app bar', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Account'), findsOneWidget);
      });

      testWidgets('displays user icon', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('displays credentials card title', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Your Credentials'), findsOneWidget);
      });

      testWidgets('displays security reminder card', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Security Reminder'), findsOneWidget);
        expect(find.textContaining('Write down your username'), findsOneWidget);
      });

      testWidgets('displays change password button', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Change Password'), findsOneWidget);
      });
    });

    group('Username Display', () {
      testWidgets('displays stored username', (tester) async {
        mockStorage.data['auth_username'] = 'myusername';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('myusername'), findsOneWidget);
      });

      testWidgets('displays Unknown when no username stored', (tester) async {
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Unknown'), findsOneWidget);
      });
    });

    group('Password Display', () {
      testWidgets('displays masked password by default', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'mypassword';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Password should be masked (10 asterisks for 'mypassword')
        expect(find.text('**********'), findsOneWidget);
        expect(find.text('mypassword'), findsNothing);
      });

      testWidgets('shows visibility toggle icon', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'password123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });

      testWidgets('reveals password when visibility toggled', (tester) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'secretpass';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Initially masked
        expect(find.text('**********'), findsOneWidget);
        expect(find.text('secretpass'), findsNothing);

        // Toggle visibility
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pumpAndSettle();

        // Password should be visible
        expect(find.text('secretpass'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      });

      testWidgets('hides password when visibility toggled again', (
        tester,
      ) async {
        mockStorage.data['auth_username'] = 'testuser';
        mockStorage.data['auth_password'] = 'mypass123';

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Toggle to show
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pumpAndSettle();

        expect(find.text('mypass123'), findsOneWidget);

        // Toggle to hide
        await tester.tap(find.byIcon(Icons.visibility_off));
        await tester.pumpAndSettle();

        expect(find.text('mypass123'), findsNothing);
        expect(find.text('*********'), findsOneWidget);
      });
    });

    group('Change Password', () {
      setUp(() {
        mockStorage.data['auth_username'] = 'changeuser';
        mockStorage.data['auth_password'] = 'oldpassword';
        mockStorage.data['auth_is_logged_in'] = 'true';
        mockStorage.data['auth_jwt'] = 'valid-jwt-token';
      });

      testWidgets('opens change password dialog', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        // Dialog is open - verify by checking dialog-specific fields
        // (Don't count 'Change Password' text - appears in button, title, and action)
        expect(find.text('Current Password'), findsOneWidget);
        expect(find.text('New Password'), findsOneWidget);
        expect(find.text('Confirm New Password'), findsOneWidget);
      });

      testWidgets('dialog has cancel and change buttons', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Change Password'),
          findsOneWidget,
        );
      });

      testWidgets('cancel closes dialog', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be closed - only button should remain
        expect(find.text('Current Password'), findsNothing);
      });

      testWidgets('shows error for incorrect current password', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Current Password'),
          'wrongpassword',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'newpassword123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          'newpassword123',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
        await tester.pumpAndSettle();

        expect(find.textContaining('incorrect'), findsOneWidget);
      });

      testWidgets('shows error for short new password', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Current Password'),
          'oldpassword',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'short',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          'short',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
        await tester.pumpAndSettle();

        expect(find.textContaining('8'), findsWidgets);
      });

      testWidgets('shows error for mismatched new passwords', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Current Password'),
          'oldpassword',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'newpassword123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          'different123',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
        await tester.pumpAndSettle();

        expect(find.textContaining('do not match'), findsOneWidget);
      });

      testWidgets('successfully changes password', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Current Password'),
          'oldpassword',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'newpassword123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          'newpassword123',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
        await tester.pumpAndSettle();

        // Dialog should close and show success message
        expect(find.text('Current Password'), findsNothing);
        expect(find.text('Password changed successfully'), findsOneWidget);

        // Verify password was updated
        expect(mockStorage.data['auth_password'], 'newpassword123');
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator while loading credentials', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        // Before pumpAndSettle, should show loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        // After loading, should not show loading indicator
        expect(find.byType(CircularProgressIndicator), findsNothing);
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
