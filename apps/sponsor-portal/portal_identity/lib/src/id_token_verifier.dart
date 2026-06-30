import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:meta/meta.dart';

/// Google's public key URL for ID token verification
const _googleCertsUrl =
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

/// Issuer prefix for Identity Platform tokens
const _issuerPrefix = 'https://securetoken.google.com/';

/// Cache for Google's public keys
Map<String, String>? _cachedKeys;
DateTime? _cacheExpiry;

/// Get the GCP project ID from environment
///
/// Only consulted on the production token-verification path
/// (issuer + audience checks below). When FIREBASE_AUTH_EMULATOR_HOST is
/// set, [verifyIdToken] takes the emulator branch and never reads this.
///
/// Precedence matches identity_admin.dart:53 and portal_password_reset.dart:67
/// — PORTAL_IDENTITY_PROJECT_ID first, then GCP_PROJECT_ID, then
/// GOOGLE_CLOUD_PROJECT, then a local-stack sentinel. A mismatch here
/// (e.g., this file resolving to project A while activation writes to
/// project B) would silently break sign-in: tokens minted by one IdP
/// would fail audience check against the other.
String get _projectId => (Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ??
        Platform.environment['GCP_PROJECT_ID'] ??
        Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
        'demo-local-stack')
    .trim();

/// Check if running against Firebase emulator
bool get _useEmulator =>
    Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] != null;

/// MFA enrollment and verification info extracted from token
///
/// Identity Platform tokens include MFA info in the `firebase` claim when
/// the user signed in with a second factor.
class MfaInfo {
  /// Whether the user has MFA enrolled and used it for this sign-in
  final bool isEnrolled;

  /// The MFA method used (e.g., 'totp' for authenticator app)
  final String? method;

  /// The enrolled factor ID (useful for audit logging)
  final String? enrolledFactorId;

  MfaInfo({required this.isEnrolled, this.method, this.enrolledFactorId});

  /// Create from JWT payload's firebase claim
  factory MfaInfo.fromFirebaseClaim(Map<String, dynamic>? firebaseClaim) {
    if (firebaseClaim == null) {
      return MfaInfo(isEnrolled: false);
    }

    // When MFA is used, the token contains:
    // firebase.sign_in_second_factor: "totp" (or "phone")
    // firebase.second_factor_identifier: factor ID
    final signInSecondFactor =
        firebaseClaim['sign_in_second_factor'] as String?;
    final secondFactorId = firebaseClaim['second_factor_identifier'] as String?;

    return MfaInfo(
      isEnrolled: signInSecondFactor != null,
      method: signInSecondFactor,
      enrolledFactorId: secondFactorId,
    );
  }

  @override
  String toString() =>
      'MfaInfo(isEnrolled: $isEnrolled, method: $method, factorId: $enrolledFactorId)';
}

/// Result of token verification
class VerificationResult {
  final String? uid;
  final String? email;
  final bool emailVerified;
  final String? error;

  /// MFA info extracted from the token (null if parsing failed)
  final MfaInfo? mfaInfo;

  VerificationResult({
    this.uid,
    this.email,
    this.emailVerified = false,
    this.error,
    this.mfaInfo,
  });

  /// A token is valid when it carries a uid and has no parse error.
  ///
  /// CUR-1296: emailVerified was previously required here (CUR-1272) to
  /// protect the email-keyed firebase_uid re-link branch in portal_auth.
  /// That branch has been deleted; the takeover vector closes by structure.
  /// All call sites lookup by `firebase_uid` only, and the binding itself
  /// (set once at activation) is the proof of identity.
  ///
  // Implements: DIARY-DEV-portal-login-identity-verification/B
  bool get isValid => uid != null && error == null;
}

// Implements: DIARY-DEV-portal-login-identity-verification/A
/// Verify an Identity Platform ID token
///
/// Returns [VerificationResult] with uid and email on success,
/// or error message on failure.
Future<VerificationResult> verifyIdToken(
  String idToken, {
  @visibleForTesting bool? useEmulator,
}) async {
  // Default to the ambient env check; tests pass useEmulator explicitly to
  // exercise the emulator branch hermetically (Platform.environment cannot be
  // mutated at runtime). Production call sites omit it and behave as before.
  // @visibleForTesting enforces that: a non-test caller passing useEmulator
  // trips invalid_use_of_visible_for_testing_member (fatal in CI analyze).
  final emulator = useEmulator ?? _useEmulator;
  final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
  print('[AUTH] verifyIdToken called');
  print('[AUTH] FIREBASE_AUTH_EMULATOR_HOST = $emulatorHost');
  print('[AUTH] emulator = $emulator');
  // Log only non-secret metadata — never any portion of the token itself,
  // which would leak authentication material into CI / aggregated logs.
  print('[AUTH] Token length: ${idToken.length}');

  // For Firebase emulator, use simplified verification
  if (emulator) {
    print('[AUTH] Using emulator verification');
    return _verifyEmulatorToken(idToken);
  }

  print('[AUTH] Using production verification');

  try {
    // Parse the JWT header to get the key ID
    final parts = idToken.split('.');
    if (parts.length != 3) {
      return VerificationResult(error: 'Invalid token format');
    }

    final headerJson = _base64UrlDecode(parts[0]);
    final header = jsonDecode(headerJson) as Map<String, dynamic>;
    final keyId = header['kid'] as String?;

    if (keyId == null) {
      return VerificationResult(error: 'Token missing key ID');
    }

    // Parse the full JWT for verification
    final jwt = JsonWebToken.unverified(idToken);

    // Fetch Google's public keys
    final publicKey = await _getPublicKey(keyId);
    if (publicKey == null) {
      return VerificationResult(error: 'Unknown key ID');
    }

    // Create key store with the public key
    final keyStore = JsonWebKeyStore()
      ..addKey(JsonWebKey.fromPem(publicKey, keyId: keyId));

    // Verify the token signature
    final verified = await jwt.verify(keyStore);
    if (!verified) {
      return VerificationResult(error: 'Invalid signature');
    }

    // Validate claims
    final claims = jwt.claims;
    final now = DateTime.now();

    // Check expiration
    final exp = claims.expiry;
    if (exp != null && exp.isBefore(now)) {
      return VerificationResult(error: 'Token expired');
    }

    // Check not before
    final nbf = claims.notBefore;
    if (nbf != null && nbf.isAfter(now)) {
      return VerificationResult(error: 'Token not yet valid');
    }

    // Check issued at (should not be in the future)
    final iat = claims.issuedAt;
    if (iat != null && iat.isAfter(now.add(const Duration(minutes: 5)))) {
      return VerificationResult(error: 'Token issued in the future');
    }

    // Check issuer (normalize: trim and remove trailing slashes)
    final expectedIssuer = '$_issuerPrefix$_projectId'.replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final actualIssuer = (claims.issuer?.toString().trim() ?? '').replaceAll(
      RegExp(r'/+$'),
      '',
    );
    if (actualIssuer != expectedIssuer) {
      // Debug: show character codes and lengths if they look identical but don't match
      print(
        '[AUTH] Expected issuer (${expectedIssuer.length}): "$expectedIssuer"',
      );
      print('[AUTH] Actual issuer (${actualIssuer.length}): "$actualIssuer"');
      print('[AUTH] Expected codes: ${expectedIssuer.codeUnits}');
      print('[AUTH] Actual codes: ${actualIssuer.codeUnits}');
      return VerificationResult(
        error: 'Invalid issuer: $actualIssuer != $expectedIssuer',
      );
    }

    // Check audience
    if (claims.audience?.contains(_projectId) != true) {
      return VerificationResult(error: 'Invalid audience');
    }

    // Extract user info
    final payload = claims.toJson();
    final uid = claims.subject;
    final email = payload['email'] as String?;
    final emailVerified = payload['email_verified'] as bool? ?? false;

    // Extract MFA info from firebase claim
    final firebaseClaim = payload['firebase'] as Map<String, dynamic>?;
    final mfaInfo = MfaInfo.fromFirebaseClaim(firebaseClaim);
    print('[AUTH] MFA info: $mfaInfo');

    if (uid == null || uid.isEmpty) {
      return VerificationResult(error: 'Token missing subject');
    }

    return VerificationResult(
      uid: uid,
      email: email,
      emailVerified: emailVerified,
      mfaInfo: mfaInfo,
    );
  } catch (e) {
    return VerificationResult(error: 'Token verification failed: $e');
  }
}

/// Verify token from Firebase emulator (simplified verification)
Future<VerificationResult> _verifyEmulatorToken(String idToken) async {
  try {
    // In emulator mode, we trust the token structure but still parse it
    final parts = idToken.split('.');
    if (parts.length != 3) {
      print('[AUTH] Emulator: Invalid token format (parts: ${parts.length})');
      return VerificationResult(error: 'Invalid token format');
    }

    final payloadBase64 = _base64UrlDecode(parts[1]);
    final payload = jsonDecode(payloadBase64) as Map<String, dynamic>;
    print('[AUTH] Emulator: Parsed payload keys: ${payload.keys.toList()}');

    // CUR-1280 (issue 7): emulator tokens are not signed, so we still
    // validate the expiry claim to keep the server from accepting stale
    // tokens that the client SDK has already refreshed/expired. Without
    // this check, the portal-server would green-light credentials the
    // client considers dead — one of the "client and server disagree
    // about whether I'm logged in" flakiness symptoms.
    final exp = payload['exp'];
    if (exp is num) {
      final expSec = exp.toInt();
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expSec < nowSec) {
        print('[AUTH] Emulator: token expired (exp=$expSec, now=$nowSec)');
        return VerificationResult(error: 'Token expired');
      }
    }

    // CUR-1280: NO audience check on the emulator path.
    //
    // The auth emulator only ever issues tokens for its own
    // --project flag (demo-local-stack in this stack). It cannot
    // mint tokens for any other project. Meanwhile, the server's
    // _projectId is sourced from GCP_PROJECT_ID, which Doppler injects
    // as the production GCP project (e.g. callisto4-dev) even when
    // the rest of the stack is running against the emulator. Comparing
    // the emulator's aud against _projectId is a structural false-
    // positive that rejects every valid emulator token.
    //
    // Audience binding in emulator mode is implicit: the only way a
    // token can reach this verifier is to come from the emulator at
    // FIREBASE_AUTH_EMULATOR_HOST, and the emulator only signs tokens
    // for its own project. Production verification (the non-emulator
    // path above) does enforce audience.

    final uid = payload['sub'] as String? ?? payload['user_id'] as String?;
    final email = payload['email'] as String?;

    // CUR-1296: with the strict isValid gate gone, the emulator path
    // returns the real email_verified claim from the parsed token.
    // Earlier (CUR-1280) we forced this to true to keep CUR-1272's
    // emailVerified gate from rejecting every freshly-minted emulator
    // token. The gate's gone (REQ-d00167-C); the fake's not needed.
    //
    // Implements: REQ-d00167-C
    final emailVerified = payload['email_verified'] as bool? ?? false;

    // Extract MFA info from firebase claim (emulator may or may not have this)
    final firebaseClaim = payload['firebase'] as Map<String, dynamic>?;
    final mfaInfo = MfaInfo.fromFirebaseClaim(firebaseClaim);

    print('[AUTH] Emulator: uid=$uid, email=$email, mfa=$mfaInfo');

    if (uid == null || uid.isEmpty) {
      print('[AUTH] Emulator: Token missing subject');
      return VerificationResult(error: 'Token missing subject');
    }

    print('[AUTH] Emulator: Verification SUCCESS');
    return VerificationResult(
      uid: uid,
      email: email,
      emailVerified: emailVerified,
      mfaInfo: mfaInfo,
    );
  } catch (e) {
    print('[AUTH] Emulator: Token parsing failed: $e');
    return VerificationResult(error: 'Emulator token parsing failed: $e');
  }
}

/// Fetch Google's public key by key ID
Future<String?> _getPublicKey(String keyId) async {
  await _refreshKeysIfNeeded();
  return _cachedKeys?[keyId];
}

/// Refresh the public key cache if needed
Future<void> _refreshKeysIfNeeded() async {
  final now = DateTime.now();

  // Use cached keys if still valid
  if (_cachedKeys != null &&
      _cacheExpiry != null &&
      now.isBefore(_cacheExpiry!)) {
    return;
  }

  try {
    final response = await http.get(Uri.parse(_googleCertsUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch public keys: ${response.statusCode}');
    }

    // Parse the keys
    _cachedKeys = Map<String, String>.from(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    // Parse cache expiry from headers
    final cacheControl = response.headers['cache-control'];
    var maxAge = 3600; // Default 1 hour

    if (cacheControl != null) {
      final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (match != null) {
        maxAge = int.parse(match.group(1)!);
      }
    }

    _cacheExpiry = now.add(Duration(seconds: maxAge));
  } catch (e) {
    // If we have cached keys, continue using them
    if (_cachedKeys != null) {
      return;
    }
    rethrow;
  }
}

String _base64UrlDecode(String input) {
  var padded = input;
  switch (input.length % 4) {
    case 2:
      padded = '$input==';
    case 3:
      padded = '$input=';
  }
  final bytes = base64Url.decode(padded);
  return utf8.decode(bytes);
}

/// Extract bearer token from Authorization header
String? extractBearerToken(String? authHeader) {
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.substring(7);
}
