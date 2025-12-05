/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service
///   REQ-d00079: Linking Code Pattern Matching
///   REQ-d00081: User Document Schema
///   REQ-d00082: Password Hashing (server-side verification)
///
/// Server-side authentication service for HHT Diary (Cloud Run).
///
/// This package provides:
/// - JWT token generation and verification (RS256)
/// - Password hash verification (Argon2id)
/// - Rate limiting for brute force protection
/// - User and sponsor pattern repositories
/// - HTTP route handlers for authentication endpoints
///
/// ## Usage
///
/// ```dart
/// import 'package:hht_auth_server/hht_auth_server.dart';
///
/// void main() async {
///   final config = ServerConfig.fromEnv();
///
///   // Initialize services
///   final jwtService = JwtService(
///     privateKey: config.jwtPrivateKey,
///     publicKey: config.jwtPublicKey,
///     issuer: config.jwtIssuer,
///   );
///
///   final rateLimiter = RateLimiter(
///     maxAttempts: config.rateLimitMaxAttempts,
///     windowDuration: config.rateLimitWindow,
///   );
///
///   // Start server
///   final handler = createHandler(/* ... */);
///   await serve(handler, config.host, config.port);
/// }
/// ```
library hht_auth_server;

// Services
export 'src/services/jwt_service.dart';
export 'src/services/rate_limiter.dart';
export 'src/services/argon2_verifier.dart';

// Repositories
export 'src/repositories/user_repository.dart';
export 'src/repositories/sponsor_pattern_repository.dart';

// Configuration
export 'src/config/server_config.dart';
