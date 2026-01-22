// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-p00002: Multi-Factor Authentication for Staff
//
// Identity Platform (Firebase Auth) token verification
// Verifies JWT tokens issued by Google Identity Platform

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

/// Google's public key URL for ID token verification
const _googleCertsUrl =
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

/// Issuer prefix for Identity Platform tokens
const _issuerPrefix = 'https://securetoken.google.com/';

/// Cache for Google's public keys
Map<String, String>? _cachedKeys;
DateTime? _cacheExpiry;

/// Get the GCP project ID from environment
String get _projectId =>
    (Platform.environment['GCP_PROJECT_ID'] ??
            Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
            'demo-sponsor-portal')
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

  bool get isValid => uid != null && error == null;
}

/// Verify an Identity Platform ID token
///
/// Returns [VerificationResult] with uid and email on success,
/// or error message on failure.
Future<VerificationResult> verifyIdToken(String idToken) async {
  final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
  print('[AUTH] verifyIdToken called');
  print('[AUTH] FIREBASE_AUTH_EMULATOR_HOST = $emulatorHost');
  print('[AUTH] _useEmulator = $_useEmulator');
  print(
    '[AUTH] Token prefix: ${idToken.substring(0, idToken.length > 50 ? 50 : idToken.length)}...',
  );

  // For Firebase emulator, use simplified verification
  if (_useEmulator) {
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

    final uid = payload['sub'] as String? ?? payload['user_id'] as String?;
    final email = payload['email'] as String?;
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
