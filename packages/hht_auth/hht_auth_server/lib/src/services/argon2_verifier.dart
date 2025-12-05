/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00082: Password Hashing Implementation - Server-side Argon2id verification
///
/// Argon2 password hash verification service.
///
/// Uses Argon2id variant with OWASP-recommended parameters for secure
/// password hashing and verification. Passwords are hashed client-side
/// before transmission, and the server verifies by re-hashing with the
/// stored salt.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Service for Argon2id password hashing and verification.
class Argon2Verifier {
  // OWASP recommended parameters for Argon2id
  static const int memory = 65536; // 64 MB
  static const int iterations = 3;
  static const int parallelism = 4;
  static const int hashLength = 32; // 256 bits

  /// Verifies a password against a stored hash.
  ///
  /// Returns true if the password matches the hash when using the provided salt.
  bool verify(String password, String storedHash, String salt) {
    final computedHash = hashPassword(password, salt);
    return computedHash == storedHash;
  }

  /// Hashes a password using Argon2id.
  ///
  /// Returns a base64-encoded hash string.
  String hashPassword(String password, String salt) {
    final argon2 = Argon2BytesGenerator();

    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      utf8.encode(salt),
      desiredKeyLength: hashLength,
      iterations: iterations,
      memory: memory,
      lanes: parallelism,
    );

    argon2.init(params);

    final passwordBytes = utf8.encode(password);
    final result = argon2.process(passwordBytes);

    return base64.encode(result);
  }
}
