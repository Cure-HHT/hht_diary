// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166: Server-owned portal activation
//
// Implements: REQ-d00166-C+F — single Identity Platform call per
// activation, IdP-first-DB-second mutation order with idempotent retry.
//
// Thin wrapper around the Identity Toolkit v1 admin REST endpoints
// (`accounts:lookup`, `accounts:signUp`, `accounts:update`). Exposed as a
// static surface so handler tests can swap in a mock without DI ceremony.

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
  /// per call. Tests inject a mock by setting [overrideClient].
  static http.Client? overrideClient;

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
    throw UnimplementedError('Implementation lands in Task 4');
  }
}
