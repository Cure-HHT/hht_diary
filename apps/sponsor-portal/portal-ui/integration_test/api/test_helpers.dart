// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: First Admin Provisioning
//   REQ-CAL-p00029: Create User Account
//   REQ-d00031: Identity Platform Integration
//
// Test helpers for portal-ui integration tests.
// Provides database access, Firebase emulator auth, and HTTP client utilities.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';

/// Test configuration from environment
class TestConfig {
  static String get dbHost => Platform.environment['DB_HOST'] ?? 'localhost';
  static int get dbPort => int.parse(Platform.environment['DB_PORT'] ?? '5432');
  static String get dbName =>
      Platform.environment['DB_NAME'] ?? 'sponsor_portal';
  static String get dbUser => Platform.environment['DB_USER'] ?? 'postgres';
  static String get dbPassword =>
      Platform.environment['DB_PASSWORD'] ??
      Platform.environment['LOCAL_DB_ROOT_PASSWORD'] ??
      'postgres';

  static String get portalServerUrl =>
      Platform.environment['PORTAL_SERVER_URL'] ?? 'http://localhost:8080';

  static String get firebaseEmulatorHost =>
      Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? 'localhost:9099';

  /// GCP Identity Platform configuration for --dev mode
  static String? get identityApiKey =>
      Platform.environment['PORTAL_IDENTITY_API_KEY'];

  static String? get identityProjectId =>
      Platform.environment['PORTAL_IDENTITY_PROJECT_ID'];

  /// True when using real GCP Identity Platform instead of Firebase emulator
  /// This is detected by:
  /// - FIREBASE_AUTH_EMULATOR_HOST being unset (not using emulator)
  /// - PORTAL_IDENTITY_API_KEY being set (have real Identity Platform credentials)
  static bool get useDevIdentity =>
      Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] == null &&
      identityApiKey != null;
}

/// Database helper for integration tests
class TestDatabase {
  Connection? _connection;

  Future<void> connect() async {
    _connection = await Connection.open(
      Endpoint(
        host: TestConfig.dbHost,
        port: TestConfig.dbPort,
        database: TestConfig.dbName,
        username: TestConfig.dbUser,
        password: TestConfig.dbPassword,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  Future<Result> execute(String sql, {Map<String, dynamic>? parameters}) async {
    if (_connection == null) {
      throw StateError('Database not connected');
    }
    return await _connection!.execute(Sql.named(sql), parameters: parameters);
  }

  /// Clean up all test data (users with test emails)
  Future<void> cleanupTestData() async {
    // Delete in order respecting foreign keys
    await execute('''
      DELETE FROM portal_user_site_access
      WHERE user_id IN (
        SELECT id FROM portal_users
        WHERE email LIKE '%@integration-test.example.com'
      )
    ''');
    await execute('''
      DELETE FROM portal_user_roles
      WHERE user_id IN (
        SELECT id FROM portal_users
        WHERE email LIKE '%@integration-test.example.com'
      )
    ''');
    await execute('''
      DELETE FROM portal_users
      WHERE email LIKE '%@integration-test.example.com'
    ''');
  }

  /// Create a pending admin user for activation testing
  /// Returns the user ID and activation code
  Future<({String userId, String activationCode})> createPendingAdminUser({
    required String email,
    required String name,
  }) async {
    final activationCode = 'TEST1-ACTV1';
    final expiry = DateTime.now().add(const Duration(days: 14));

    final result = await execute(
      '''
      INSERT INTO portal_users (email, name, status, activation_code, activation_code_expires_at)
      VALUES (@email, @name, 'pending', @code, @expiry)
      RETURNING id
    ''',
      parameters: {
        'email': email,
        'name': name,
        'code': activationCode,
        'expiry': expiry,
      },
    );

    final userId = result.first[0] as String;

    // Add Administrator role
    await execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Administrator')
    ''',
      parameters: {'userId': userId},
    );

    return (userId: userId, activationCode: activationCode);
  }

  /// Get activation code for a user by email
  Future<String?> getActivationCode(String email) async {
    final result = await execute(
      '''
      SELECT activation_code FROM portal_users WHERE email = @email
    ''',
      parameters: {'email': email},
    );

    if (result.isEmpty) return null;
    return result.first[0] as String?;
  }

  /// Get user status by email
  Future<String?> getUserStatus(String email) async {
    final result = await execute(
      '''
      SELECT status FROM portal_users WHERE email = @email
    ''',
      parameters: {'email': email},
    );

    if (result.isEmpty) return null;
    return result.first[0] as String?;
  }

  /// Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final result = await execute(
      '''
      SELECT id, email, name, status, activation_code, firebase_uid
      FROM portal_users WHERE email = @email
    ''',
      parameters: {'email': email},
    );

    if (result.isEmpty) return null;
    final row = result.first;
    return {
      'id': row[0],
      'email': row[1],
      'name': row[2],
      'status': row[3],
      'activation_code': row[4],
      'firebase_uid': row[5],
    };
  }
}

/// Helper for creating Firebase emulator auth tokens
class FirebaseEmulatorAuth {
  final String emulatorUrl;

  FirebaseEmulatorAuth({String? emulatorHost})
    : emulatorUrl = 'http://${emulatorHost ?? TestConfig.firebaseEmulatorHost}';

  /// Create a Firebase user in the emulator
  Future<({String uid, String idToken})?> createUser({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$emulatorUrl/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
      ),
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

    // User might already exist, try signing in
    return await signIn(email: email, password: password);
  }

  /// Sign in to Firebase emulator
  Future<({String uid, String idToken})?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$emulatorUrl/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
      ),
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

    return null;
  }

  /// Delete a Firebase user from emulator
  Future<void> deleteUser(String idToken) async {
    await http.post(
      Uri.parse(
        '$emulatorUrl/identitytoolkit.googleapis.com/v1/accounts:delete?key=fake-api-key',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
  }

  /// Create a mock emulator JWT token for testing
  /// This bypasses actual Firebase auth for faster unit-style tests
  String createMockToken({
    required String uid,
    required String email,
    bool mfaEnrolled = false,
  }) {
    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})),
    );
    final payloadData = {
      'sub': uid,
      'user_id': uid,
      'email': email,
      'email_verified': true,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    };

    if (mfaEnrolled) {
      payloadData['firebase'] = {
        'sign_in_second_factor': 'totp',
        'second_factor_identifier': 'test-mfa-factor-id',
      };
    }

    final payload = base64Url.encode(utf8.encode(jsonEncode(payloadData)));
    return '$header.$payload.';
  }
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
    : apiKey = apiKey ?? TestConfig.identityApiKey ?? '',
      projectId = projectId ?? TestConfig.identityProjectId;

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

  /// Delete a user account using their ID token
  /// Note: This deletes the currently authenticated user
  Future<bool> deleteUser(String idToken) async {
    if (apiKey.isEmpty) {
      throw StateError('PORTAL_IDENTITY_API_KEY not set.');
    }

    final response = await http.post(
      Uri.parse('$_identityToolkitUrl/accounts:delete?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    return response.statusCode == 200;
  }

  /// Refresh an ID token using a refresh token
  /// Returns new idToken and refreshToken
  Future<({String idToken, String refreshToken})?> refreshToken(
    String refreshToken,
  ) async {
    if (apiKey.isEmpty) {
      throw StateError('PORTAL_IDENTITY_API_KEY not set.');
    }

    // Token refresh uses a different endpoint
    final response = await http.post(
      Uri.parse('https://securetoken.googleapis.com/v1/token?key=$apiKey'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=$refreshToken',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        idToken: data['id_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
    }

    return null;
  }
}

/// Portal API client for integration tests
class TestPortalApiClient {
  final http.Client _client;
  final String baseUrl;

  TestPortalApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? TestConfig.portalServerUrl;

  void close() {
    _client.close();
  }

  /// Validate activation code
  Future<Map<String, dynamic>> validateActivationCode(String code) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/portal/activate/$code'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Activate user account
  Future<({int statusCode, Map<String, dynamic> body})> activateUser({
    required String code,
    required String idToken,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/portal/activate'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code}),
    );
    return (
      statusCode: response.statusCode,
      body: jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Get current user info
  Future<({int statusCode, Map<String, dynamic> body})> getMe(
    String idToken,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/portal/me'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    return (
      statusCode: response.statusCode,
      body: jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Get all portal users (admin only)
  Future<({int statusCode, Map<String, dynamic> body})> getUsers(
    String idToken,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/portal/users'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    return (
      statusCode: response.statusCode,
      body: jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Create a new portal user (admin only)
  Future<({int statusCode, Map<String, dynamic> body})> createUser({
    required String idToken,
    required String name,
    required String email,
    required List<String> roles,
    List<String>? siteIds,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/portal/users'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'roles': roles,
        if (siteIds != null) 'site_ids': siteIds,
      }),
    );
    return (
      statusCode: response.statusCode,
      body: jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Get available sites
  Future<({int statusCode, Map<String, dynamic> body})> getSites(
    String idToken,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/portal/sites'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    return (
      statusCode: response.statusCode,
      body: jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
