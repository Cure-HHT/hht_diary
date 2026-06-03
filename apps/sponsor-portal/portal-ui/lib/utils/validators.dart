/// Shared form-field validators for portal auth screens.
///
/// Each method matches the [FormFieldValidator] signature: returns `null`
/// when valid, or an error message string when invalid.
class Validators {
  const Validators._();

  /// Validates that [value] is a non-empty string containing an `@`.
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validates that [value] is a non-empty password.
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }
}
