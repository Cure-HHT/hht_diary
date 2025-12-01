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

    Widget buildTestWidget({Size? surfaceSize}) {
      return MaterialApp(
        home: Material(
          child: LoginScreen(authService: authService, onLoginSuccess: () {}),
        ),
      );
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

        expect(find.textContaining("Don't have an account?"), findsOneWidget);
      });
    });

    group('Password Visibility Toggle', () {
      testWidgets('password field has visibility toggle', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Find visibility_off icon (password hidden by default)
        expect(find.byIcon(Icons.visibility_off), findsWidgets);
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
