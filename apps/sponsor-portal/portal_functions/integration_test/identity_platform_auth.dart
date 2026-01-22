// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//
// Helper for real GCP Identity Platform authentication (--dev mode)
// Uses the Identity Toolkit REST API for signInWithPassword

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Configuration for test authentication
class TestAuthConfig {
  /// Get the Identity Platform API key from environment
  static String? get apiKey => Platform.environment['PORTAL_IDENTITY_API_KEY'];

  /// Get the GCP project ID from environment
  static String? get projectId =>
      Platform.environment['GCP_PROJECT_ID'] ??
      Platform.environment['PORTAL_IDENTITY_PROJECT_ID'];

  /// Check if we're in --dev mode (using real GCP Identity Platform)
  static bool get useDevMode =>
      Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] == null &&
      apiKey != null &&
      apiKey!.isNotEmpty;
}

/// Helper for real GCP Identity Platform authentication (--dev mode)
/// Uses the Identity Toolkit REST API for signInWithPassword
class IdentityPlatformAuth {
  final String apiKey;
  final String? projectId;

  /// Identity Toolkit REST API base URL
  static const _identityToolkitUrl =
      'https://identitytoolkit.googleapis.com/v1';

  IdentityPlatformAuth({String? apiKey, String? projectId})
    : apiKey = apiKey ?? TestAuthConfig.apiKey ?? '',
      projectId = projectId ?? TestAuthConfig.projectId;

  /// Sign in with real GCP Identity Platform
  /// Returns uid and idToken on success, null on failure
  Future<({String uid, String idToken})?> signIn({
    required String email,
    required String password,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'PORTAL_IDENTITY_API_KEY not set. '
        'Run with --dev mode or set environment variable.',
      );
    }

    final response = await http.post(
      Uri.parse('$_identityToolkitUrl/accounts:signInWithPassword?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        uid: data['localId'] as String,
        idToken: data['idToken'] as String,
      );
    }

    // Parse error response for debugging
    if (response.statusCode == 400) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      final errorInfo = error['error'] as Map<String, dynamic>?;
      final message = errorInfo?['message'] as String? ?? 'Unknown error';

      // Common error codes:
      // - EMAIL_NOT_FOUND: No user with this email
      // - INVALID_PASSWORD: Wrong password
      // - USER_DISABLED: Account disabled
      stderr.writeln(
        'Identity Platform sign-in failed: $message (email: $email)',
      );
    }

    return null;
  }

  /// Create a new user in GCP Identity Platform
  /// Note: This uses signUp endpoint which requires email/password sign-up to be enabled
  Future<({String uid, String idToken})?> createUser({
    required String email,
    required String password,
  }) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'PORTAL_IDENTITY_API_KEY not set. '
        'Run with --dev mode or set environment variable.',
      );
    }

    final response = await http.post(
      Uri.parse('$_identityToolkitUrl/accounts:signUp?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        uid: data['localId'] as String,
        idToken: data['idToken'] as String,
      );
    }

    // If user exists, try sign-in instead
    if (response.statusCode == 400) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      final errorInfo = error['error'] as Map<String, dynamic>?;
      final message = errorInfo?['message'] as String? ?? '';

      if (message == 'EMAIL_EXISTS') {
        return await signIn(email: email, password: password);
      }

      stderr.writeln('Identity Platform createUser failed: $message');
    }

    return null;
  }
}
