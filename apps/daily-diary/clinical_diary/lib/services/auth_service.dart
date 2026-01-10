// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management

import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// User account data model
class UserAccount {
  const UserAccount({
    required this.username,
    required this.appUuid,
    this.isLoggedIn = false,
  });

  final String username;
  final String appUuid;
  final bool isLoggedIn;
}

/// Result of authentication operations
class AuthResult {
  const AuthResult._({required this.success, this.errorMessage, this.user});

  factory AuthResult.success(UserAccount user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(success: false, errorMessage: message);

  final bool success;
  final String? errorMessage;
  final UserAccount? user;
}

/// Service for managing user authentication
///
/// Handles:
/// - Username/password registration and login via Cloud Functions
/// - Password hashing (SHA-256) before network transmission
/// - Secure local storage of credentials
/// - App UUID generation and persistence
class AuthService {
  AuthService({FlutterSecureStorage? secureStorage, http.Client? httpClient})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _httpClient = httpClient ?? http.Client();

  final FlutterSecureStorage _secureStorage;
  final http.Client _httpClient;

  // Secure storage keys
  static const _keyAppUuid = 'app_uuid';
  static const _keyUsername = 'auth_username';
  static const _keyPassword = 'auth_password';
  static const _keyIsLoggedIn = 'auth_is_logged_in';
  static const _keyJwt = 'auth_jwt';

  // Validation constants
  static const minUsernameLength = 6;
  static const minPasswordLength = 8;

  /// Hash a password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get or create the app's unique identifier
  Future<String> getAppUuid() async {
    var uuid = await _secureStorage.read(key: _keyAppUuid);
    if (uuid == null) {
      uuid = const Uuid().v4();
      await _secureStorage.write(key: _keyAppUuid, value: uuid);
    }
    return uuid;
  }

  /// Validate username format
  /// Returns null if valid, error message if invalid
  String? validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username is required';
    }
    if (username.length < minUsernameLength) {
      return 'Username must be at least $minUsernameLength characters';
    }
    if (username.contains('@')) {
      return 'Username cannot contain @ symbol';
    }
    // Only allow alphanumeric and underscore
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  /// Validate password format
  /// Returns null if valid, error message if invalid
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  /// Register a new user via Cloud Function
  Future<AuthResult> register({
    required String username,
    required String password,
  }) async {
    // Validate username
    final usernameError = validateUsername(username);
    if (usernameError != null) {
      return AuthResult.failure(usernameError);
    }

    // Validate password
    final passwordError = validatePassword(password);
    if (passwordError != null) {
      return AuthResult.failure(passwordError);
    }

    try {
      final appUuid = await getAppUuid();
      final passwordHash = hashPassword(password);
      final lowercaseUsername = username.toLowerCase();

      final response = await _httpClient.post(
        Uri.parse(AppConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': lowercaseUsername,
          'passwordHash': passwordHash,
          'appUuid': appUuid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final jwt = data['jwt'] as String;

        // Store credentials locally
        await _secureStorage.write(key: _keyUsername, value: lowercaseUsername);
        await _secureStorage.write(key: _keyPassword, value: password);
        await _secureStorage.write(key: _keyIsLoggedIn, value: 'true');
        await _secureStorage.write(key: _keyJwt, value: jwt);

        return AuthResult.success(
          UserAccount(
            username: lowercaseUsername,
            appUuid: appUuid,
            isLoggedIn: true,
          ),
        );
      } else if (response.statusCode == 409) {
        return AuthResult.failure('Username is already taken');
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final error = data['error'] as String? ?? 'Registration failed';
        return AuthResult.failure(error);
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      return AuthResult.failure('Failed to create account. Please try again.');
    }
  }

  /// Login with existing credentials via Cloud Function
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    // Validate inputs
    if (username.isEmpty) {
      return AuthResult.failure('Username is required');
    }
    if (password.isEmpty) {
      return AuthResult.failure('Password is required');
    }

    try {
      final lowercaseUsername = username.toLowerCase();
      final passwordHash = hashPassword(password);

      final response = await _httpClient.post(
        Uri.parse(AppConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': lowercaseUsername,
          'passwordHash': passwordHash,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final jwt = data['jwt'] as String;

        final appUuid = await getAppUuid();

        // Store credentials locally
        await _secureStorage.write(key: _keyUsername, value: lowercaseUsername);
        await _secureStorage.write(key: _keyPassword, value: password);
        await _secureStorage.write(key: _keyIsLoggedIn, value: 'true');
        await _secureStorage.write(key: _keyJwt, value: jwt);

        return AuthResult.success(
          UserAccount(
            username: lowercaseUsername,
            appUuid: appUuid,
            isLoggedIn: true,
          ),
        );
      } else if (response.statusCode == 401) {
        return AuthResult.failure('Invalid username or password');
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final error = data['error'] as String? ?? 'Login failed';
        return AuthResult.failure(error);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return AuthResult.failure('Login failed. Please try again.');
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    await _secureStorage.write(key: _keyIsLoggedIn, value: 'false');
  }

  /// Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    final value = await _secureStorage.read(key: _keyIsLoggedIn);
    return value == 'true';
  }

  /// Get the current user account (if logged in)
  Future<UserAccount?> getCurrentUser() async {
    final isLoggedIn = await this.isLoggedIn();
    if (!isLoggedIn) return null;

    final username = await _secureStorage.read(key: _keyUsername);
    if (username == null) return null;

    final appUuid = await getAppUuid();

    return UserAccount(username: username, appUuid: appUuid, isLoggedIn: true);
  }

  /// Get stored username (even if logged out)
  Future<String?> getStoredUsername() async {
    return _secureStorage.read(key: _keyUsername);
  }

  /// Get stored password (for display in profile)
  Future<String?> getStoredPassword() async {
    return _secureStorage.read(key: _keyPassword);
  }

  /// Get stored JWT token
  Future<String?> getStoredJwt() async {
    return _secureStorage.read(key: _keyJwt);
  }

  /// Change the user's password via Cloud Function
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Validate new password
    final passwordError = validatePassword(newPassword);
    if (passwordError != null) {
      return AuthResult.failure(passwordError);
    }

    final username = await _secureStorage.read(key: _keyUsername);
    if (username == null) {
      return AuthResult.failure('No account found');
    }

    final storedPassword = await _secureStorage.read(key: _keyPassword);
    if (storedPassword != currentPassword) {
      return AuthResult.failure('Current password is incorrect');
    }

    final jwt = await _secureStorage.read(key: _keyJwt);
    if (jwt == null) {
      return AuthResult.failure('Not authenticated');
    }

    try {
      final currentPasswordHash = hashPassword(currentPassword);
      final newPasswordHash = hashPassword(newPassword);

      final response = await _httpClient.post(
        Uri.parse(AppConfig.changePasswordUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'currentPasswordHash': currentPasswordHash,
          'newPasswordHash': newPasswordHash,
        }),
      );

      if (response.statusCode == 200) {
        // Update locally stored password
        await _secureStorage.write(key: _keyPassword, value: newPassword);

        final appUuid = await getAppUuid();

        return AuthResult.success(
          UserAccount(username: username, appUuid: appUuid, isLoggedIn: true),
        );
      } else if (response.statusCode == 401) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final error = data['error'] as String? ?? 'Authentication failed';
        return AuthResult.failure(error);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final error = data['error'] as String? ?? 'Failed to change password';
        return AuthResult.failure(error);
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      return AuthResult.failure('Failed to change password. Please try again.');
    }
  }

  /// Check if user has ever registered (has stored credentials)
  Future<bool> hasStoredCredentials() async {
    final username = await _secureStorage.read(key: _keyUsername);
    return username != null;
  }
}
