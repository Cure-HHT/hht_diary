/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

/// Base class for authentication-related exceptions.
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, [this.code]);

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

/// Exception thrown when credentials are invalid.
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException([String? message])
      : super(message ?? 'Invalid username or password', 'INVALID_CREDENTIALS');
}

/// Exception thrown when account is locked.
class AccountLockedException extends AuthException {
  final DateTime lockedUntil;

  AccountLockedException(this.lockedUntil)
      : super('Account is locked until ${lockedUntil.toIso8601String()}',
            'ACCOUNT_LOCKED');
}

/// Exception thrown when linking code is invalid.
class InvalidLinkingCodeException extends AuthException {
  const InvalidLinkingCodeException([String? message])
      : super(message ?? 'Invalid or unrecognized linking code',
            'INVALID_LINKING_CODE');
}

/// Exception thrown when username already exists.
class UsernameExistsException extends AuthException {
  const UsernameExistsException([String? message])
      : super(message ?? 'Username already exists', 'USERNAME_EXISTS');
}

/// Exception thrown when token is expired.
class TokenExpiredException extends AuthException {
  const TokenExpiredException([String? message])
      : super(message ?? 'Authentication token has expired', 'TOKEN_EXPIRED');
}

/// Exception thrown when token is invalid or malformed.
class InvalidTokenException extends AuthException {
  const InvalidTokenException([String? message])
      : super(message ?? 'Invalid authentication token', 'INVALID_TOKEN');
}

/// Exception thrown for network or server errors.
class NetworkAuthException extends AuthException {
  const NetworkAuthException([String? message])
      : super(message ?? 'Network or server error occurred', 'NETWORK_ERROR');
}
