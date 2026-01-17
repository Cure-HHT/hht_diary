// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-o00006: MFA Configuration for Staff Accounts
//
// Tests for feature_flags.dart

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    // Note: These tests run with no environment variables set,
    // so all flags default to true (since != 'false' is true for null)

    test('totpAdminOnly defaults to true when env var not set', () {
      // When FEATURE_TOTP_ADMIN_ONLY is not 'false', it returns true
      expect(FeatureFlags.totpAdminOnly, isTrue);
    });

    test('emailOtpEnabled defaults to true when env var not set', () {
      // When FEATURE_EMAIL_OTP_ENABLED is not 'false', it returns true
      expect(FeatureFlags.emailOtpEnabled, isTrue);
    });

    test('emailActivation defaults to true when env var not set', () {
      // When FEATURE_EMAIL_ACTIVATION is not 'false', it returns true
      expect(FeatureFlags.emailActivation, isTrue);
    });

    test('toJson returns all feature flags', () {
      final json = FeatureFlags.toJson();

      expect(json, containsPair('totp_admin_only', isA<bool>()));
      expect(json, containsPair('email_otp_enabled', isA<bool>()));
      expect(json, containsPair('email_activation', isA<bool>()));
      expect(json.length, 3);
    });
  });

  group('featureFlagsHandler', () {
    test('returns 200 OK', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await featureFlagsHandler(request);

      expect(response.statusCode, 200);
    });

    test('returns JSON content type', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await featureFlagsHandler(request);

      expect(response.headers['content-type'], 'application/json');
    });

    test('returns feature flags in body', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await featureFlagsHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(body, containsPair('totp_admin_only', isA<bool>()));
      expect(body, containsPair('email_otp_enabled', isA<bool>()));
      expect(body, containsPair('email_activation', isA<bool>()));
    });
  });

  group('getMfaTypeForRole', () {
    // With default flags: totpAdminOnly=true, emailOtpEnabled=true

    test('returns totp for Developer Admin when totpAdminOnly is true', () {
      final mfaType = getMfaTypeForRole('Developer Admin');
      expect(mfaType, 'totp');
    });

    test('returns email_otp for Investigator when emailOtpEnabled is true', () {
      final mfaType = getMfaTypeForRole('Investigator');
      expect(mfaType, 'email_otp');
    });

    test('returns email_otp for First Admin when emailOtpEnabled is true', () {
      final mfaType = getMfaTypeForRole('First Admin');
      expect(mfaType, 'email_otp');
    });

    test('returns email_otp for Site Admin when emailOtpEnabled is true', () {
      final mfaType = getMfaTypeForRole('Site Admin');
      expect(mfaType, 'email_otp');
    });

    test('returns email_otp for CRA when emailOtpEnabled is true', () {
      final mfaType = getMfaTypeForRole('CRA');
      expect(mfaType, 'email_otp');
    });

    test('returns email_otp for unknown role when emailOtpEnabled is true', () {
      final mfaType = getMfaTypeForRole('Unknown Role');
      expect(mfaType, 'email_otp');
    });

    test('returns email_otp for empty role when emailOtpEnabled is true', () {
      final mfaType = getMfaTypeForRole('');
      expect(mfaType, 'email_otp');
    });
  });

  group('requiresTotpEnrollment', () {
    // With default flags: totpAdminOnly=true

    test('returns true for Developer Admin', () {
      expect(requiresTotpEnrollment('Developer Admin'), isTrue);
    });

    test('returns false for Investigator', () {
      expect(requiresTotpEnrollment('Investigator'), isFalse);
    });

    test('returns false for First Admin', () {
      expect(requiresTotpEnrollment('First Admin'), isFalse);
    });

    test('returns false for Site Admin', () {
      expect(requiresTotpEnrollment('Site Admin'), isFalse);
    });

    test('returns false for CRA', () {
      expect(requiresTotpEnrollment('CRA'), isFalse);
    });

    test('returns false for unknown role', () {
      expect(requiresTotpEnrollment('Unknown'), isFalse);
    });

    test('returns false for empty role', () {
      expect(requiresTotpEnrollment(''), isFalse);
    });
  });

  group('requiresEmailOtp', () {
    // With default flags: totpAdminOnly=true, emailOtpEnabled=true

    test('returns false for Developer Admin (uses TOTP instead)', () {
      expect(requiresEmailOtp('Developer Admin'), isFalse);
    });

    test('returns true for Investigator', () {
      expect(requiresEmailOtp('Investigator'), isTrue);
    });

    test('returns true for First Admin', () {
      expect(requiresEmailOtp('First Admin'), isTrue);
    });

    test('returns true for Site Admin', () {
      expect(requiresEmailOtp('Site Admin'), isTrue);
    });

    test('returns true for CRA', () {
      expect(requiresEmailOtp('CRA'), isTrue);
    });

    test('returns true for unknown role', () {
      expect(requiresEmailOtp('Unknown'), isTrue);
    });

    test('returns true for empty role', () {
      expect(requiresEmailOtp(''), isTrue);
    });
  });

  group('Role-based MFA flow integration', () {
    test('Developer Admin gets TOTP enrollment and no email OTP', () {
      const role = 'Developer Admin';

      expect(getMfaTypeForRole(role), 'totp');
      expect(requiresTotpEnrollment(role), isTrue);
      expect(requiresEmailOtp(role), isFalse);
    });

    test('Investigator gets no TOTP enrollment but requires email OTP', () {
      const role = 'Investigator';

      expect(getMfaTypeForRole(role), 'email_otp');
      expect(requiresTotpEnrollment(role), isFalse);
      expect(requiresEmailOtp(role), isTrue);
    });

    test('First Admin gets no TOTP enrollment but requires email OTP', () {
      const role = 'First Admin';

      expect(getMfaTypeForRole(role), 'email_otp');
      expect(requiresTotpEnrollment(role), isFalse);
      expect(requiresEmailOtp(role), isTrue);
    });
  });
}
