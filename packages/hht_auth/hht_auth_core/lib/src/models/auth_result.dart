/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

import 'package:hht_auth_core/src/models/auth_token.dart';

/// Sealed class representing the result of an authentication operation.
sealed class AuthResult {
  const AuthResult();
}

/// Authentication succeeded with a valid token.
class AuthSuccess extends AuthResult {
  final AuthToken token;

  const AuthSuccess(this.token);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSuccess &&
          runtimeType == other.runtimeType &&
          token == other.token;

  @override
  int get hashCode => token.hashCode;
}

/// Authentication failed with an error.
class AuthFailure extends AuthResult {
  final String message;
  final AuthFailureReason reason;

  const AuthFailure({
    required this.message,
    required this.reason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          reason == other.reason;

  @override
  int get hashCode => message.hashCode ^ reason.hashCode;
}

/// Enumeration of authentication failure reasons.
enum AuthFailureReason {
  /// Invalid credentials (wrong username or password)
  invalidCredentials,

  /// Account is locked due to too many failed attempts
  accountLocked,

  /// Linking code is invalid or not recognized
  invalidLinkingCode,

  /// Username already exists (registration only)
  usernameExists,

  /// Network or server error
  networkError,

  /// Token has expired
  tokenExpired,

  /// Unknown or unexpected error
  unknown,
}
