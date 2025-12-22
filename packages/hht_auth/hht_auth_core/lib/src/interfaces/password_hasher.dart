/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00082: Password Hashing interfaces

/// Password hashing parameters based on OWASP recommendations.
class HashingParams {
  /// Memory cost in KB (default: 64 MB = 65536 KB)
  final int memory;

  /// Number of iterations (default: 3)
  final int iterations;

  /// Parallelism factor (default: 4)
  final int parallelism;

  /// Hash output length in bytes (default: 32)
  final int hashLength;

  const HashingParams({
    this.memory = 65536,
    this.iterations = 3,
    this.parallelism = 4,
    this.hashLength = 32,
  });

  /// OWASP-recommended default parameters for Argon2id.
  static const HashingParams owasp = HashingParams();
}

/// Interface for password hashing using Argon2id.
///
/// Provides secure password hashing for client-side and server-side use.
abstract class PasswordHasher {
  /// Hashes a password using Argon2id with the provided salt.
  ///
  /// Returns base64-encoded hash string.
  /// Uses OWASP-recommended parameters by default.
  Future<String> hashPassword(
    String password,
    String salt, {
    HashingParams params = HashingParams.owasp,
  });

  /// Verifies a password against a stored hash.
  ///
  /// Returns true if the password matches the hash.
  Future<bool> verifyPassword(
    String password,
    String salt,
    String storedHash, {
    HashingParams params = HashingParams.owasp,
  });

  /// Generates a cryptographically secure random salt.
  ///
  /// Returns base64-encoded salt string.
  String generateSalt();
}
