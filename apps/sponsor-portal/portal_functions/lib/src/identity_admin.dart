// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166: Server-owned portal activation
//
// Implements: REQ-d00166-C+F — single Identity Platform call per
// activation, IdP-first-DB-second mutation order with idempotent retry.
//
// Thin wrapper around the Identity Toolkit v1 admin REST endpoints
// (`accounts:lookup`, `accounts:signUp`, `accounts:update`). Exposed as a
// static surface so handler tests can swap in a mock without DI ceremony.

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

  /// Test seam: replaceable HTTP client. Defaults to a fresh `http.Client()`
  /// (via ADC) per call. Tests inject a mock by setting [overrideClient].
  static http.Client? overrideClient;

  /// Identity Toolkit v1 base URL (project-scoped admin endpoints).
  /// When FIREBASE_AUTH_EMULATOR_HOST is set the emulator intercepts requests
  /// at http://{host}/identitytoolkit.googleapis.com/v1.
  static String get _base {
    final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      return 'http://$emulatorHost/identitytoolkit.googleapis.com/v1';
    }
    return 'https://identitytoolkit.googleapis.com/v1';
  }

  /// Project id from env. Precedence matches identity_platform.dart:35,
  /// portal_password_reset.dart:67, and identity_config.dart:36 —
  /// PORTAL_IDENTITY_PROJECT_ID first, then GCP_PROJECT_ID, then
  /// GOOGLE_CLOUD_PROJECT, then a test-only sentinel. Production must
  /// set at least one of the first three; a mismatch in the fallback
  /// chain (e.g., this file resolving to project A while token
  /// verification audience-checks project B) would silently break
  /// sign-in.
  static String get _projectId =>
      Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ??
      Platform.environment['GCP_PROJECT_ID'] ??
      Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      'demo-test';

  /// Returns an HTTP client. When FIREBASE_AUTH_EMULATOR_HOST is set a plain
  /// client is used and the per-request `Authorization: Bearer owner` header
  /// is supplied via [_emulatorHeaders]. Otherwise an ADC-authenticated
  /// client is returned, which adds OAuth bearer tokens automatically.
  /// In tests, [overrideClient] short-circuits both paths.
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

  /// Headers to add when talking to the emulator. The emulator's project-
  /// scoped admin endpoints (`/projects/{project}/accounts*`) require an
  /// Authorization header but accept any bearer value; `owner` is the
  /// conventional placeholder. Returns an empty map in production, where
  /// the ADC-authenticated client supplies the real OAuth token itself.
  static Map<String, String> _emulatorHeaders() {
    final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
    if (emulatorHost != null && emulatorHost.isNotEmpty) {
      return const {'Authorization': 'Bearer owner'};
    }
    return const {};
  }

  /// Look up an Identity Platform user by email. If absent, create one with
  /// the given password and `emailVerified=true`. If present, update the
  /// existing user's password and ensure `emailVerified=true`.
  ///
  /// Returns the user's uid plus a flag indicating whether the user was
  /// created on this call (for log discrimination).
  ///
  /// Throws [IdentityAdminException] on any non-2xx underlying response.
  static Future<LookupOrProvisionResult> lookupOrProvisionByEmail({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final hook = IdentityAdminTestOverride.lookupOrProvision;
    if (hook != null) {
      return hook(email: email, displayName: displayName, password: password);
    }
    final client = await _client();
    final headers = {'Content-Type': 'application/json', ..._emulatorHeaders()};
    try {
      // Step 1: lookup by email.
      final lookupRes = await client.post(
        Uri.parse('$_base/projects/$_projectId/accounts:lookup'),
        headers: headers,
        body: jsonEncode({
          'email': [email],
        }),
      );
      if (lookupRes.statusCode != 200) {
        throw IdentityAdminException(
          'lookup failed: ${lookupRes.body}',
          statusCode: lookupRes.statusCode,
        );
      }
      final lookupBody = jsonDecode(lookupRes.body) as Map<String, dynamic>;
      final users = (lookupBody['users'] as List?) ?? const [];

      if (users.isEmpty) {
        // Step 2a: signUp creates a new IdP user with emailVerified=true.
        // The activation code that brought the user here (delivered via
        // email) is the proof of email ownership — no further verification
        // needed. See REQ-d00166-A,B,C.
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
          throw IdentityAdminException(
            'signUp failed: ${signUpRes.body}',
            statusCode: signUpRes.statusCode,
          );
        }
        final body = jsonDecode(signUpRes.body) as Map<String, dynamic>;
        final uid = body['localId'] as String;
        return LookupOrProvisionResult(uid: uid, created: true);
      }

      // Step 2b: update existing user (set password, ensure emailVerified).
      // This is the path for the IdP-collision case where an admin email
      // already has a stale Identity Platform record from prior testing
      // or backup-restore drift.
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
        throw IdentityAdminException(
          'update failed: ${updateRes.body}',
          statusCode: updateRes.statusCode,
        );
      }
      return LookupOrProvisionResult(uid: existingUid, created: false);
    } finally {
      if (overrideClient == null) client.close();
    }
  }
}

/// Test-only static seam. When [lookupOrProvision] is set,
/// `IdentityAdmin.lookupOrProvisionByEmail` delegates to the function
/// instead of making real HTTP calls. Production code never reads this;
/// production callers always go through `IdentityAdmin`.
class IdentityAdminTestOverride {
  static Future<LookupOrProvisionResult> Function({
    required String email,
    required String displayName,
    required String password,
  })?
  lookupOrProvision;
}
