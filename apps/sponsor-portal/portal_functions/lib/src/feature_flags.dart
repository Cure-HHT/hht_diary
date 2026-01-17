// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-o00006: MFA Configuration for Staff Accounts
//
// Feature flags for conditional 2FA behavior
// Allows toggling between TOTP (authenticator app) and Email OTP

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Feature flags loaded from environment variables
///
/// These flags control the 2FA behavior:
/// - TOTP (authenticator app): Developer Admins only (when totpAdminOnly is true)
/// - Email OTP: All other users on every login (when emailOtpEnabled is true)
/// - Email activation: Automatically email activation codes (when emailActivation is true)
class FeatureFlags {
  /// When true, only Developer Admins use TOTP (authenticator app).
  /// All other users skip TOTP setup during activation.
  ///
  /// Environment: FEATURE_TOTP_ADMIN_ONLY (default: true)
  static bool get totpAdminOnly =>
      Platform.environment['FEATURE_TOTP_ADMIN_ONLY'] != 'false';

  /// When true, non-admin users must verify via email OTP on every login.
  ///
  /// Environment: FEATURE_EMAIL_OTP_ENABLED (default: true)
  static bool get emailOtpEnabled =>
      Platform.environment['FEATURE_EMAIL_OTP_ENABLED'] != 'false';

  /// When true, activation codes are automatically emailed to new users.
  /// When false, activation codes must be manually communicated.
  ///
  /// Environment: FEATURE_EMAIL_ACTIVATION (default: true)
  static bool get emailActivation =>
      Platform.environment['FEATURE_EMAIL_ACTIVATION'] != 'false';

  /// Convert feature flags to JSON for API response
  static Map<String, dynamic> toJson() => {
    'totp_admin_only': totpAdminOnly,
    'email_otp_enabled': emailOtpEnabled,
    'email_activation': emailActivation,
  };
}

/// Get feature flags for frontend configuration
/// GET /api/v1/portal/config/features
///
/// Returns current feature flag values so frontend can adjust behavior.
/// This endpoint is public (no auth required) as it only exposes
/// non-sensitive configuration.
///
/// Returns:
///   200: {
///     "totp_admin_only": true,
///     "email_otp_enabled": true,
///     "email_activation": true
///   }
Future<Response> featureFlagsHandler(Request request) async {
  print('[FEATURE_FLAGS] featureFlagsHandler called');

  return Response.ok(
    jsonEncode(FeatureFlags.toJson()),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Determine MFA type based on user role and feature flags
///
/// Returns the MFA type that should be used for the given role:
/// - 'totp': User must use authenticator app (TOTP)
/// - 'email_otp': User must verify via email OTP on each login
/// - 'none': No additional MFA required (fallback, not recommended)
String getMfaTypeForRole(String role) {
  // Developer Admin always uses TOTP (when feature flag allows)
  if (role == 'Developer Admin' && FeatureFlags.totpAdminOnly) {
    return 'totp';
  }

  // All other users use email OTP (when enabled)
  if (FeatureFlags.emailOtpEnabled) {
    return 'email_otp';
  }

  // Fallback: TOTP for all (original behavior)
  return 'totp';
}

/// Check if a role requires TOTP enrollment during activation
///
/// Returns true if the user should go through TOTP setup during activation.
/// Used by portal_activation.dart to determine activation flow.
bool requiresTotpEnrollment(String role) {
  if (!FeatureFlags.totpAdminOnly) {
    // Original behavior: all users get TOTP
    return true;
  }

  // Only Developer Admin needs TOTP enrollment
  return role == 'Developer Admin';
}

/// Check if a role requires email OTP verification on login
///
/// Returns true if the user should verify via email OTP after password auth.
/// Used by frontend to determine login flow.
bool requiresEmailOtp(String role) {
  if (!FeatureFlags.emailOtpEnabled) {
    return false;
  }

  // Developer Admins use TOTP, not email OTP
  if (role == 'Developer Admin' && FeatureFlags.totpAdminOnly) {
    return false;
  }

  return true;
}
