/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

/// Base class for validation-related exceptions.
class ValidationException implements Exception {
  final String message;
  final String field;

  const ValidationException(this.field, this.message);

  @override
  String toString() => '$field: $message';
}

/// Exception thrown when username validation fails.
class UsernameValidationException extends ValidationException {
  const UsernameValidationException(String message)
      : super('username', message);
}

/// Exception thrown when password validation fails.
class PasswordValidationException extends ValidationException {
  const PasswordValidationException(String message)
      : super('password', message);
}

/// Exception thrown when linking code validation fails.
class LinkingCodeValidationException extends ValidationException {
  const LinkingCodeValidationException(String message)
      : super('linkingCode', message);
}
