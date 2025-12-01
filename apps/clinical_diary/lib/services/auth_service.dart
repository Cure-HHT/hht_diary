// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
/// - Username/password registration and login
/// - Password hashing (SHA-256) before network transmission
/// - Secure local storage of credentials
/// - Firestore user document management
/// - App UUID generation and persistence
class AuthService {
  AuthService({
    FlutterSecureStorage? secureStorage,
    FirebaseFirestore? firestore,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FlutterSecureStorage _secureStorage;
  final FirebaseFirestore _firestore;

  // Secure storage keys
  static const _keyAppUuid = 'app_uuid';
  static const _keyUsername = 'auth_username';
  static const _keyPassword = 'auth_password';
  static const _keyIsLoggedIn = 'auth_is_logged_in';

  // Firestore collection
  static const _usersCollection = 'users';

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

  /// Check if a username is already taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      final lowercaseUsername = username.toLowerCase();
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(lowercaseUsername)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking username: $e');
      // Assume taken on error to be safe
      return true;
    }
  }

  /// Register a new user
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

    // Check if username is taken
    if (await isUsernameTaken(username)) {
      return AuthResult.failure('Username is already taken');
    }

    try {
      final appUuid = await getAppUuid();
      final passwordHash = hashPassword(password);
      final lowercaseUsername = username.toLowerCase();

      // Create user document in Firestore
      await _firestore.collection(_usersCollection).doc(lowercaseUsername).set({
        'username': lowercaseUsername,
        'passwordHash': passwordHash,
        'appUuid': appUuid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Store credentials locally
      await _secureStorage.write(key: _keyUsername, value: lowercaseUsername);
      await _secureStorage.write(key: _keyPassword, value: password);
      await _secureStorage.write(key: _keyIsLoggedIn, value: 'true');

      return AuthResult.success(
        UserAccount(
          username: lowercaseUsername,
          appUuid: appUuid,
          isLoggedIn: true,
        ),
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      return AuthResult.failure('Failed to create account. Please try again.');
    }
  }

  /// Login with existing credentials
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

      // Fetch user document from Firestore
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(lowercaseUsername)
          .get();

      if (!doc.exists) {
        return AuthResult.failure('Invalid username or password');
      }

      final data = doc.data()!;
      final storedHash = data['passwordHash'] as String?;

      if (storedHash != passwordHash) {
        return AuthResult.failure('Invalid username or password');
      }

      final appUuid = await getAppUuid();

      // Store credentials locally
      await _secureStorage.write(key: _keyUsername, value: lowercaseUsername);
      await _secureStorage.write(key: _keyPassword, value: password);
      await _secureStorage.write(key: _keyIsLoggedIn, value: 'true');

      return AuthResult.success(
        UserAccount(
          username: lowercaseUsername,
          appUuid: appUuid,
          isLoggedIn: true,
        ),
      );
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

  /// Change the user's password
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

    try {
      final newPasswordHash = hashPassword(newPassword);

      // Update password hash in Firestore
      await _firestore.collection(_usersCollection).doc(username).update({
        'passwordHash': newPasswordHash,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update locally stored password
      await _secureStorage.write(key: _keyPassword, value: newPassword);

      final appUuid = await getAppUuid();

      return AuthResult.success(
        UserAccount(username: username, appUuid: appUuid, isLoggedIn: true),
      );
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
