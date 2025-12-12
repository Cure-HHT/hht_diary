/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

/// Validation rules for authentication inputs.
class ValidationRules {
  ValidationRules._();

  /// Minimum username length
  static const int usernameMinLength = 6;

  /// Maximum username length
  static const int usernameMaxLength = 50;

  /// Minimum password length
  static const int passwordMinLength = 8;

  /// Maximum password length
  static const int passwordMaxLength = 128;

  /// Username must not contain @ symbol (to distinguish from email)
  static const String usernamePattern = r'^[^@]+$';

  /// Linking code minimum length
  static const int linkingCodeMinLength = 3;

  /// Validates a username.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username is required';
    }
    if (username.length < usernameMinLength) {
      return 'Username must be at least $usernameMinLength characters';
    }
    if (username.length > usernameMaxLength) {
      return 'Username must be at most $usernameMaxLength characters';
    }
    if (username.contains('@')) {
      return 'Username cannot contain @ symbol';
    }
    return null;
  }

  /// Validates a password.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters';
    }
    if (password.length > passwordMaxLength) {
      return 'Password must be at most $passwordMaxLength characters';
    }
    return null;
  }

  /// Validates a linking code.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateLinkingCode(String linkingCode) {
    if (linkingCode.isEmpty) {
      return 'Linking code is required';
    }
    if (linkingCode.length < linkingCodeMinLength) {
      return 'Linking code must be at least $linkingCodeMinLength characters';
    }
    return null;
  }
}
