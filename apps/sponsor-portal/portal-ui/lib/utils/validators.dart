import 'package:flutter/widgets.dart';

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

  /// Validates a new password for the reset / activation flow. Must be 8–64
  /// printable characters.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (value.length > 64) {
      return 'Password must be less than 64 characters';
    }
    return null;
  }

  /// Returns a validator that requires the field to be non-empty and match
  /// the value [original] returns at validate time. Pass a getter (e.g.
  /// `() => passwordController.text`) so the comparison reads the live
  /// password value, not whatever it held when the form was built.
  static FormFieldValidator<String> confirmPassword(
    ValueGetter<String> original,
  ) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != original()) {
        return 'Passwords do not match';
      }
      return null;
    };
  }
}
