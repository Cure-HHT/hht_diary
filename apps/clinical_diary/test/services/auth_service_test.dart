// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management

import 'package:clinical_diary/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
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

    group('hashPassword', () {
      test('returns SHA-256 hash of password', () {
        // SHA-256 hash of "password123" (well-known test value)
        final hash = authService.hashPassword('password123');

        expect(hash, isNotEmpty);
        expect(hash.length, 64); // SHA-256 produces 64 hex characters
      });

      test('produces consistent hash for same input', () {
        final hash1 = authService.hashPassword('testPassword');
        final hash2 = authService.hashPassword('testPassword');

        expect(hash1, hash2);
      });

      test('produces different hash for different input', () {
        final hash1 = authService.hashPassword('password1');
        final hash2 = authService.hashPassword('password2');

        expect(hash1, isNot(hash2));
      });
    });

    group('getAppUuid', () {
      test('generates and stores UUID on first call', () async {
        final uuid = await authService.getAppUuid();

        expect(uuid, isNotEmpty);
        expect(mockStorage.data['app_uuid'], uuid);
      });

      test('returns same UUID on subsequent calls', () async {
        final uuid1 = await authService.getAppUuid();
        final uuid2 = await authService.getAppUuid();

        expect(uuid1, uuid2);
      });

      test('returns existing UUID from storage', () async {
        mockStorage.data['app_uuid'] = 'existing-uuid-12345';

        final uuid = await authService.getAppUuid();

        expect(uuid, 'existing-uuid-12345');
      });
    });

    group('validateUsername', () {
      test('returns null for valid username', () {
        expect(authService.validateUsername('validuser'), isNull);
        expect(authService.validateUsername('valid_user'), isNull);
        expect(authService.validateUsername('User123'), isNull);
        expect(authService.validateUsername('user_123_name'), isNull);
      });

      test('returns error for empty username', () {
        final result = authService.validateUsername('');

        expect(result, isNotNull);
        expect(result, contains('required'));
      });

      test('returns error for username shorter than 6 characters', () {
        final result = authService.validateUsername('short');

        expect(result, isNotNull);
        expect(result, contains('6'));
      });

      test('returns error for username containing @ symbol', () {
        final result = authService.validateUsername('user@domain');

        expect(result, isNotNull);
        expect(result, contains('@'));
      });

      test('returns error for username with special characters', () {
        expect(authService.validateUsername('user!name'), isNotNull);
        expect(authService.validateUsername('user#name'), isNotNull);
        expect(authService.validateUsername('user.name'), isNotNull);
        expect(authService.validateUsername('user-name'), isNotNull);
      });

      test('accepts underscores in username', () {
        expect(authService.validateUsername('user_name'), isNull);
      });
    });

    group('validatePassword', () {
      test('returns null for valid password', () {
        expect(authService.validatePassword('password123'), isNull);
        expect(authService.validatePassword('12345678'), isNull);
        expect(authService.validatePassword('verylongpassword'), isNull);
      });

      test('returns error for empty password', () {
        final result = authService.validatePassword('');

        expect(result, isNotNull);
        expect(result, contains('required'));
      });

      test('returns error for password shorter than 8 characters', () {
        final result = authService.validatePassword('short12');

        expect(result, isNotNull);
        expect(result, contains('8'));
      });
    });

    group('isUsernameTaken', () {
      test('returns false when username does not exist', () async {
        final result = await authService.isUsernameTaken('newuser123');

        expect(result, false);
      });

      test('returns true when username exists', () async {
        // Create existing user in Firestore
        await fakeFirestore.collection('users').doc('existinguser').set({
          'username': 'existinguser',
          'passwordHash': 'somehash',
        });

        final result = await authService.isUsernameTaken('existinguser');

        expect(result, true);
      });

      test('is case-insensitive', () async {
        await fakeFirestore.collection('users').doc('testuser').set({
          'username': 'testuser',
          'passwordHash': 'somehash',
        });

        final result = await authService.isUsernameTaken('TESTUSER');

        expect(result, true);
      });
    });

    group('register', () {
      test('successfully registers with valid credentials', () async {
        final result = await authService.register(
          username: 'newuser123',
          password: 'password123',
        );

        expect(result.success, true);
        expect(result.user, isNotNull);
        expect(result.user!.username, 'newuser123');
        expect(result.user!.isLoggedIn, true);
      });

      test('stores credentials locally on success', () async {
        await authService.register(
          username: 'newuser123',
          password: 'password123',
        );

        expect(mockStorage.data['auth_username'], 'newuser123');
        expect(mockStorage.data['auth_password'], 'password123');
        expect(mockStorage.data['auth_is_logged_in'], 'true');
      });

      test('creates user document in Firestore', () async {
        await authService.register(
          username: 'firestoreuser',
          password: 'password123',
        );

        final doc = await fakeFirestore
            .collection('users')
            .doc('firestoreuser')
            .get();

        expect(doc.exists, true);
        expect(doc.data()!['username'], 'firestoreuser');
        expect(doc.data()!['passwordHash'], isNotEmpty);
        expect(doc.data()!['appUuid'], isNotEmpty);
      });

      test('fails for invalid username', () async {
        final result = await authService.register(
          username: 'bad@user',
          password: 'password123',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('@'));
      });

      test('fails for invalid password', () async {
        final result = await authService.register(
          username: 'validuser',
          password: 'short',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('8'));
      });

      test('fails when username is already taken', () async {
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

      test('stores password hash (not plaintext) in Firestore', () async {
        await authService.register(
          username: 'hashtest',
          password: 'mySecretPassword',
        );

        final doc = await fakeFirestore
            .collection('users')
            .doc('hashtest')
            .get();

        expect(doc.data()!['passwordHash'], isNot('mySecretPassword'));
        expect(
          doc.data()!['passwordHash'],
          authService.hashPassword('mySecretPassword'),
        );
      });
    });

    group('login', () {
      setUp(() async {
        // Create a test user
        await fakeFirestore.collection('users').doc('testlogin').set({
          'username': 'testlogin',
          'passwordHash': authService.hashPassword('correctpassword'),
          'appUuid': 'test-uuid',
        });
      });

      test('successfully logs in with correct credentials', () async {
        final result = await authService.login(
          username: 'testlogin',
          password: 'correctpassword',
        );

        expect(result.success, true);
        expect(result.user, isNotNull);
        expect(result.user!.username, 'testlogin');
        expect(result.user!.isLoggedIn, true);
      });

      test('stores credentials locally on success', () async {
        await authService.login(
          username: 'testlogin',
          password: 'correctpassword',
        );

        expect(mockStorage.data['auth_username'], 'testlogin');
        expect(mockStorage.data['auth_password'], 'correctpassword');
        expect(mockStorage.data['auth_is_logged_in'], 'true');
      });

      test('fails with incorrect password', () async {
        final result = await authService.login(
          username: 'testlogin',
          password: 'wrongpassword',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('Invalid'));
      });

      test('fails with non-existent username', () async {
        final result = await authService.login(
          username: 'nonexistent',
          password: 'password123',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('Invalid'));
      });

      test('fails with empty username', () async {
        final result = await authService.login(
          username: '',
          password: 'password123',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('required'));
      });

      test('fails with empty password', () async {
        final result = await authService.login(
          username: 'testlogin',
          password: '',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('required'));
      });

      test('is case-insensitive for username', () async {
        final result = await authService.login(
          username: 'TESTLOGIN',
          password: 'correctpassword',
        );

        expect(result.success, true);
      });
    });

    group('logout', () {
      test('sets logged in status to false', () async {
        mockStorage.data['auth_is_logged_in'] = 'true';

        await authService.logout();

        expect(mockStorage.data['auth_is_logged_in'], 'false');
      });
    });

    group('isLoggedIn', () {
      test('returns false when not logged in', () async {
        final result = await authService.isLoggedIn();

        expect(result, false);
      });

      test('returns true when logged in', () async {
        mockStorage.data['auth_is_logged_in'] = 'true';

        final result = await authService.isLoggedIn();

        expect(result, true);
      });

      test('returns false after logout', () async {
        mockStorage.data['auth_is_logged_in'] = 'true';

        await authService.logout();
        final result = await authService.isLoggedIn();

        expect(result, false);
      });
    });

    group('getCurrentUser', () {
      test('returns null when not logged in', () async {
        final result = await authService.getCurrentUser();

        expect(result, isNull);
      });

      test('returns user when logged in', () async {
        mockStorage.data['auth_username'] = 'currentuser';
        mockStorage.data['auth_is_logged_in'] = 'true';

        final result = await authService.getCurrentUser();

        expect(result, isNotNull);
        expect(result!.username, 'currentuser');
        expect(result.isLoggedIn, true);
      });

      test('returns null when logged in but no username stored', () async {
        mockStorage.data['auth_is_logged_in'] = 'true';
        // No username stored

        final result = await authService.getCurrentUser();

        expect(result, isNull);
      });
    });

    group('getStoredUsername', () {
      test('returns null when no username stored', () async {
        final result = await authService.getStoredUsername();

        expect(result, isNull);
      });

      test('returns username when stored', () async {
        mockStorage.data['auth_username'] = 'storeduser';

        final result = await authService.getStoredUsername();

        expect(result, 'storeduser');
      });
    });

    group('getStoredPassword', () {
      test('returns null when no password stored', () async {
        final result = await authService.getStoredPassword();

        expect(result, isNull);
      });

      test('returns password when stored', () async {
        mockStorage.data['auth_password'] = 'storedpassword';

        final result = await authService.getStoredPassword();

        expect(result, 'storedpassword');
      });
    });

    group('changePassword', () {
      setUp(() async {
        // Create user and login state
        mockStorage.data['auth_username'] = 'changeuser';
        mockStorage.data['auth_password'] = 'oldpassword';
        mockStorage.data['auth_is_logged_in'] = 'true';

        await fakeFirestore.collection('users').doc('changeuser').set({
          'username': 'changeuser',
          'passwordHash': authService.hashPassword('oldpassword'),
          'appUuid': 'test-uuid',
        });
      });

      test(
        'successfully changes password with correct current password',
        () async {
          final result = await authService.changePassword(
            currentPassword: 'oldpassword',
            newPassword: 'newpassword123',
          );

          expect(result.success, true);
        },
      );

      test('updates password hash in Firestore', () async {
        await authService.changePassword(
          currentPassword: 'oldpassword',
          newPassword: 'newpassword123',
        );

        final doc = await fakeFirestore
            .collection('users')
            .doc('changeuser')
            .get();

        expect(
          doc.data()!['passwordHash'],
          authService.hashPassword('newpassword123'),
        );
      });

      test('updates locally stored password', () async {
        await authService.changePassword(
          currentPassword: 'oldpassword',
          newPassword: 'newpassword123',
        );

        expect(mockStorage.data['auth_password'], 'newpassword123');
      });

      test('fails with incorrect current password', () async {
        final result = await authService.changePassword(
          currentPassword: 'wrongpassword',
          newPassword: 'newpassword123',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('incorrect'));
      });

      test('fails with invalid new password', () async {
        final result = await authService.changePassword(
          currentPassword: 'oldpassword',
          newPassword: 'short',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('8'));
      });

      test('fails when no account exists', () async {
        mockStorage.data.remove('auth_username');

        final result = await authService.changePassword(
          currentPassword: 'oldpassword',
          newPassword: 'newpassword123',
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('No account'));
      });
    });

    group('hasStoredCredentials', () {
      test('returns false when no credentials stored', () async {
        final result = await authService.hasStoredCredentials();

        expect(result, false);
      });

      test('returns true when credentials stored', () async {
        mockStorage.data['auth_username'] = 'someuser';

        final result = await authService.hasStoredCredentials();

        expect(result, true);
      });
    });
  });

  group('UserAccount', () {
    test('creates with required fields', () {
      const account = UserAccount(username: 'testuser', appUuid: 'test-uuid');

      expect(account.username, 'testuser');
      expect(account.appUuid, 'test-uuid');
      expect(account.isLoggedIn, false); // Default value
    });

    test('creates with all fields', () {
      const account = UserAccount(
        username: 'testuser',
        appUuid: 'test-uuid',
        isLoggedIn: true,
      );

      expect(account.isLoggedIn, true);
    });
  });

  group('AuthResult', () {
    test('success factory creates successful result', () {
      const user = UserAccount(username: 'test', appUuid: 'uuid');
      final result = AuthResult.success(user);

      expect(result.success, true);
      expect(result.user, user);
      expect(result.errorMessage, isNull);
    });

    test('failure factory creates failed result', () {
      final result = AuthResult.failure('Error message');

      expect(result.success, false);
      expect(result.errorMessage, 'Error message');
      expect(result.user, isNull);
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
