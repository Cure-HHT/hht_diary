/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - JWT generation and verification
///
/// JWT service for generating and verifying RS256-signed JSON Web Tokens.
///
/// Tokens are short-lived (15 minutes) and contain user identification,
/// sponsor information, and session data. The service uses RSA key pairs
/// for secure signing and verification.

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:hht_auth_core/hht_auth_core.dart';

/// Service for JWT token operations using RS256 algorithm.
class JwtService {
  final String _privateKey;
  final String _publicKey;
  final String _issuer;

  /// Creates a JWT service with RSA key pair.
  ///
  /// [privateKey] PEM-encoded RSA private key for signing tokens
  /// [publicKey] PEM-encoded RSA public key for verifying tokens
  /// [issuer] Token issuer identifier (e.g., 'hht-auth-service')
  JwtService({
    required String privateKey,
    required String publicKey,
    required String issuer,
  })  : _privateKey = privateKey,
        _publicKey = publicKey,
        _issuer = issuer;

  /// Generates a JWT string from an AuthToken model.
  ///
  /// Returns a signed JWT string with RS256 algorithm.
  String generateToken(AuthToken authToken) {
    final jwt = JWT(
      {
        'sub': authToken.sub,
        'username': authToken.username,
        'sponsorId': authToken.sponsorId,
        'sponsorUrl': authToken.sponsorUrl,
        'appUuid': authToken.appUuid,
        'iat': authToken.iat.millisecondsSinceEpoch ~/ 1000,
        'exp': authToken.exp.millisecondsSinceEpoch ~/ 1000,
      },
      issuer: _issuer,
    );

    return jwt.sign(
      RSAPrivateKey(_privateKey),
      algorithm: JWTAlgorithm.RS256,
    );
  }

  /// Verifies a JWT string and returns the decoded AuthToken.
  ///
  /// Returns null if the token is invalid, expired, or malformed.
  AuthToken? verifyToken(String token) {
    try {
      final jwt = JWT.verify(
        token,
        RSAPublicKey(_publicKey),
        issuer: _issuer,
      );

      final payload = jwt.payload as Map<String, dynamic>;

      // Validate required claims
      if (!payload.containsKey('sub') ||
          !payload.containsKey('username') ||
          !payload.containsKey('sponsorId') ||
          !payload.containsKey('sponsorUrl') ||
          !payload.containsKey('appUuid') ||
          !payload.containsKey('iat') ||
          !payload.containsKey('exp')) {
        return null;
      }

      return AuthToken(
        sub: payload['sub'] as String,
        username: payload['username'] as String,
        sponsorId: payload['sponsorId'] as String,
        sponsorUrl: payload['sponsorUrl'] as String,
        appUuid: payload['appUuid'] as String,
        iat: DateTime.fromMillisecondsSinceEpoch(
          (payload['iat'] as int) * 1000,
        ),
        exp: DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as int) * 1000,
        ),
      );
    } on JWTExpiredException {
      return null;
    } on JWTException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Refreshes an existing token with a new expiry time.
  ///
  /// Returns a new JWT string with the same claims but updated iat and exp.
  /// Returns null if the original token is invalid or expired.
  String? refreshToken(String token) {
    final decoded = verifyToken(token);
    if (decoded == null) return null;

    final now = DateTime.now();
    final newToken = decoded.copyWith(
      iat: now,
      exp: now.add(Duration(minutes: 15)),
    );

    return generateToken(newToken);
  }

  /// Extracts JWT token from an Authorization header.
  ///
  /// Expected format: "Bearer <token>"
  /// Returns the token string or null if the header is malformed.
  String? extractTokenFromHeader(String? header) {
    if (header == null || header.isEmpty) return null;

    final parts = header.split(' ');
    if (parts.length != 2 || parts[0] != 'Bearer') return null;

    final token = parts[1].trim();
    return token.isEmpty ? null : token;
  }
}
