// Implements: DIARY-DEV-portal-identity-provisioning/A+B
//
// Thin wrapper around the Identity Toolkit v1 admin REST endpoints
// (accounts:lookup, accounts:signUp, accounts:update). Static surface so
// tests can swap in a mock client without DI ceremony. Extracted verbatim
// from portal_functions (no Postgres coupling).
import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class LookupOrProvisionResult {
  final String uid;
  final bool created;
  const LookupOrProvisionResult({required this.uid, required this.created});
}

class IdentityAdminException implements Exception {
  final String message;
  final int? statusCode;
  IdentityAdminException(this.message, {this.statusCode});
  @override
  String toString() => 'IdentityAdminException($statusCode): $message';
}

class IdentityAdmin {
  IdentityAdmin._();

  static http.Client? overrideClient;

  static String get _base {
    final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      return 'http://$emulatorHost/identitytoolkit.googleapis.com/v1';
    }
    return 'https://identitytoolkit.googleapis.com/v1';
  }

  static String get _projectId =>
      Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ??
      Platform.environment['GCP_PROJECT_ID'] ??
      Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      'demo-test';

  static Future<http.Client> _client() async {
    if (overrideClient != null) return overrideClient!;
    final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      return http.Client();
    }
    return clientViaApplicationDefaultCredentials(
      scopes: const ['https://www.googleapis.com/auth/cloud-platform'],
    );
  }

  static Map<String, String> _emulatorHeaders() {
    final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      return const {'Authorization': 'Bearer owner'};
    }
    return const {};
  }

  static Future<LookupOrProvisionResult> lookupOrProvisionByEmail({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final client = await _client();
    final headers = {'Content-Type': 'application/json', ..._emulatorHeaders()};
    try {
      final lookupRes = await client.post(
        Uri.parse('$_base/projects/$_projectId/accounts:lookup'),
        headers: headers,
        body: jsonEncode({
          'email': [email]
        }),
      );
      if (lookupRes.statusCode != 200) {
        throw IdentityAdminException('lookup failed: ${lookupRes.body}',
            statusCode: lookupRes.statusCode);
      }
      final lookupBody = jsonDecode(lookupRes.body) as Map<String, dynamic>;
      final users = (lookupBody['users'] as List?) ?? const [];

      if (users.isEmpty) {
        final signUpRes = await client.post(
          Uri.parse('$_base/projects/$_projectId/accounts'),
          headers: headers,
          body: jsonEncode({
            'email': email,
            'password': password,
            'displayName': displayName,
            'emailVerified': true,
          }),
        );
        if (signUpRes.statusCode != 200) {
          throw IdentityAdminException('signUp failed: ${signUpRes.body}',
              statusCode: signUpRes.statusCode);
        }
        final body = jsonDecode(signUpRes.body) as Map<String, dynamic>;
        return LookupOrProvisionResult(
            uid: body['localId'] as String, created: true);
      }

      final existingUid =
          (users[0] as Map<String, dynamic>)['localId'] as String;
      final updateRes = await client.post(
        Uri.parse('$_base/projects/$_projectId/accounts:update'),
        headers: headers,
        body: jsonEncode({
          'localId': existingUid,
          'password': password,
          'displayName': displayName,
          'emailVerified': true,
        }),
      );
      if (updateRes.statusCode != 200) {
        throw IdentityAdminException('update failed: ${updateRes.body}',
            statusCode: updateRes.statusCode);
      }
      return LookupOrProvisionResult(uid: existingUid, created: false);
    } finally {
      if (overrideClient == null) client.close();
    }
  }

  /// Updates the Identity Platform password for an EXISTING account, looked up
  /// by email. Never creates an account (reset must not provision). Throws
  /// IdentityAdminException if the account is absent or the update is rejected
  /// (e.g. weak password -> statusCode 400). Returns the account uid.
  // Implements: DIARY-DEV-portal-reset-password-update/A
  static Future<String> updatePasswordByEmail({
    required String email,
    required String password,
  }) async {
    final client = await _client();
    final headers = {'Content-Type': 'application/json', ..._emulatorHeaders()};
    try {
      final lookupRes = await client.post(
        Uri.parse('$_base/projects/$_projectId/accounts:lookup'),
        headers: headers,
        body: jsonEncode({
          'email': [email]
        }),
      );
      if (lookupRes.statusCode != 200) {
        throw IdentityAdminException('lookup failed: ${lookupRes.body}',
            statusCode: lookupRes.statusCode);
      }
      final users = ((jsonDecode(lookupRes.body)
              as Map<String, dynamic>)['users'] as List?) ??
          const [];
      if (users.isEmpty) {
        throw IdentityAdminException('no account for email', statusCode: 404);
      }
      final uid = (users[0] as Map<String, dynamic>)['localId'] as String;
      final updateRes = await client.post(
        Uri.parse('$_base/projects/$_projectId/accounts:update'),
        headers: headers,
        body: jsonEncode({'localId': uid, 'password': password}),
      );
      if (updateRes.statusCode != 200) {
        throw IdentityAdminException('update failed: ${updateRes.body}',
            statusCode: updateRes.statusCode);
      }
      return uid;
    } finally {
      if (overrideClient == null) client.close();
    }
  }
}
