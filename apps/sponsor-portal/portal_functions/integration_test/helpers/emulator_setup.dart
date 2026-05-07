// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166: Server-owned portal activation
//
// Thin REST helpers for the Firebase Auth Emulator admin endpoints.
// Used by emulator integration tests to inspect and reset emulator state.
//
// All helpers require FIREBASE_AUTH_EMULATOR_HOST to be set and the
// emulator to be running.  They do NOT start or stop the emulator process.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Host for the auth emulator.  Defaults to `127.0.0.1:9099`.
String get emulatorHost =>
    Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? '127.0.0.1:9099';

/// GCP project id used when talking to the emulator.
String get emulatorProjectId =>
    Platform.environment['GCP_PROJECT_ID'] ?? 'demo-test';

/// Base URL for the Identity Toolkit v1 emulator admin endpoints.
String get _adminBase =>
    'http://$emulatorHost/identitytoolkit.googleapis.com/v1';

/// Headers for project-scoped admin endpoints. The emulator requires an
/// Authorization header but accepts any bearer value; `owner` is the
/// conventional placeholder.
const Map<String, String> _adminHeaders = {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer owner',
};

// ---------------------------------------------------------------------------
// Public helpers
// ---------------------------------------------------------------------------

/// Look up a user by email in the emulator.  Returns the user JSON object
/// (e.g. `{'localId': ..., 'email': ..., 'emailVerified': ...}`) or `null`
/// if no user with that email exists.
Future<Map<String, dynamic>?> emulatorLookupByEmail(String email) async {
  final res = await http.post(
    Uri.parse('$_adminBase/projects/$emulatorProjectId/accounts:lookup'),
    headers: _adminHeaders,
    body: jsonEncode({
      'email': [email],
    }),
  );
  if (res.statusCode != 200) {
    throw StateError(
      'emulatorLookupByEmail failed (${res.statusCode}): ${res.body}',
    );
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final users = (body['users'] as List?) ?? const [];
  if (users.isEmpty) return null;
  return users.first as Map<String, dynamic>;
}

/// Create a user in the emulator via `accounts:signUp` (admin path).
/// Returns the created user's `localId` (firebase uid).
Future<String> emulatorCreateUser(
  String email,
  String password, {
  bool emailVerified = false,
}) async {
  final res = await http.post(
    Uri.parse('$_adminBase/projects/$emulatorProjectId/accounts'),
    headers: _adminHeaders,
    body: jsonEncode({
      'email': email,
      'password': password,
      'emailVerified': emailVerified,
    }),
  );
  if (res.statusCode != 200) {
    throw StateError(
      'emulatorCreateUser failed (${res.statusCode}): ${res.body}',
    );
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return body['localId'] as String;
}

/// Sign in via the emulator's `accounts:signInWithPassword` endpoint.
/// Returns `true` if the credentials are accepted, `false` otherwise.
Future<bool> emulatorSignIn(String email, String password) async {
  // The emulator accepts any string as the API key parameter.
  final res = await http.post(
    Uri.parse(
      'http://$emulatorHost/identitytoolkit.googleapis.com/v1/'
      'accounts:signInWithPassword?key=emulator-test-key',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  return res.statusCode == 200;
}

/// Delete ALL users from the emulator project.  Call in `tearDown` to
/// keep tests isolated.
Future<void> deleteAllEmulatorUsers() async {
  final res = await http.delete(
    Uri.parse(
      'http://$emulatorHost/emulator/v1/projects/$emulatorProjectId/accounts',
    ),
  );
  if (res.statusCode != 200) {
    throw StateError(
      'deleteAllEmulatorUsers failed (${res.statusCode}): ${res.body}',
    );
  }
}
