/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00082: Password Hashing Implementation
///
/// Client-side password hashing using Argon2id.
///
/// Implements OWASP-recommended password hashing parameters using the
/// Argon2id variant for resistance against GPU and side-channel attacks.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:pointycastle/export.dart';

/// Client-side Argon2id password hasher implementation.
///
/// Uses PointyCastle library to implement Argon2id hashing with
/// OWASP-recommended parameters (64MB memory, 3 iterations, 4 parallelism).
class Argon2PasswordHasher implements PasswordHasher {
  final Random _random = Random.secure();

  @override
  String generateSalt() {
    // Generate 16 bytes (128 bits) of cryptographically secure random data
    final saltBytes = Uint8List(16);
    for (var i = 0; i < saltBytes.length; i++) {
      saltBytes[i] = _random.nextInt(256);
    }
    return base64Encode(saltBytes);
  }

  @override
  Future<String> hashPassword(
    String password,
    String salt, {
    HashingParams params = HashingParams.owasp,
  }) async {
    final saltBytes = base64Decode(salt);
    final passwordBytes = utf8.encode(password);

    // Create Argon2 parameters
    final argon2 = Argon2BytesGenerator();
    
    // PointyCastle Argon2Parameters constructor:
    // - type (0=Argon2d, 1=Argon2i, 2=Argon2id)
    // - salt bytes
    // - desiredKeyLength
    // - iterations
    // - memory (in KB)
    // - lanes (parallelism)
    final argon2Params = Argon2Parameters(
      Argon2Parameters.ARGON2_id, // Type 2 = Argon2id
      saltBytes,
      desiredKeyLength: params.hashLength,
      iterations: params.iterations,
      memory: params.memory,
      lanes: params.parallelism,
    );

    argon2.init(argon2Params);

    // Generate hash
    final hashBytes = Uint8List(params.hashLength);
    argon2.generateBytes(passwordBytes, hashBytes, 0, params.hashLength);

    return base64Encode(hashBytes);
  }

  @override
  Future<bool> verifyPassword(
    String password,
    String salt,
    String storedHash, {
    HashingParams params = HashingParams.owasp,
  }) async {
    // Hash the provided password with the same salt
    final computedHash = await hashPassword(password, salt, params: params);
    
    // Constant-time comparison to prevent timing attacks
    return _constantTimeEquals(computedHash, storedHash);
  }

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }
}
