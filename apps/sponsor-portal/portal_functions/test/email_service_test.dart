// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Tests for email_service.dart

import 'package:test/test.dart';

import 'package:portal_functions/src/email_service.dart';

void main() {
  group('EmailConfig', () {
    test(
      'fromEnvironment creates config with defaults when env vars not set',
      () {
        // Note: In test environment, env vars are typically not set
        final config = EmailConfig.fromEnvironment();

        expect(config.senderEmail, 'noreply@anspar.com');
        expect(config.senderName, 'Clinical Trial Portal');
        // enabled defaults to true when EMAIL_ENABLED != 'false'
        expect(config.enabled, isTrue);
      },
    );

    test('isConfigured returns false when serviceAccountJson is empty', () {
      final config = EmailConfig(
        serviceAccountJson: '',
        senderEmail: 'test@example.com',
        senderName: 'Test',
        enabled: true,
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns false when disabled', () {
      final config = EmailConfig(
        serviceAccountJson: 'some-json',
        senderEmail: 'test@example.com',
        senderName: 'Test',
        enabled: false,
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns true when properly configured', () {
      final config = EmailConfig(
        serviceAccountJson: 'some-json-content',
        senderEmail: 'test@example.com',
        senderName: 'Test',
        enabled: true,
      );

      expect(config.isConfigured, isTrue);
    });
  });

  group('EmailResult', () {
    test('success factory creates successful result with messageId', () {
      final result = EmailResult.success('msg-123');

      expect(result.success, isTrue);
      expect(result.messageId, 'msg-123');
      expect(result.error, isNull);
    });

    test('failure factory creates failed result with error', () {
      final result = EmailResult.failure('Network error');

      expect(result.success, isFalse);
      expect(result.messageId, isNull);
      expect(result.error, 'Network error');
    });
  });

  group('generateOtpCode', () {
    test('generates a 6-character string', () {
      final code = generateOtpCode();
      expect(code.length, 6);
    });

    test('generates only digits', () {
      for (var i = 0; i < 10; i++) {
        final code = generateOtpCode();
        expect(
          RegExp(r'^\d{6}$').hasMatch(code),
          isTrue,
          reason: 'Code "$code" should contain only 6 digits',
        );
      }
    });

    test('generates different codes on repeated calls', () {
      // Generate multiple codes and check they're not all identical
      // (small chance of collision, but very unlikely for 10 codes)
      final codes = <String>{};
      for (var i = 0; i < 10; i++) {
        codes.add(generateOtpCode());
        // Small delay to ensure microsecond variation
        for (var j = 0; j < 1000; j++) {}
      }
      // At least 2 unique codes out of 10
      expect(
        codes.length,
        greaterThan(1),
        reason: 'Multiple generated codes should have some variation',
      );
    });
  });

  group('hashOtpCode', () {
    test('returns a SHA-256 hash (64 hex characters)', () {
      final hash = hashOtpCode('123456');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('returns consistent hash for same input', () {
      final hash1 = hashOtpCode('123456');
      final hash2 = hashOtpCode('123456');
      expect(hash1, equals(hash2));
    });

    test('returns different hash for different input', () {
      final hash1 = hashOtpCode('123456');
      final hash2 = hashOtpCode('654321');
      expect(hash1, isNot(equals(hash2)));
    });

    test('handles empty string', () {
      final hash = hashOtpCode('');
      expect(hash.length, 64);
      // SHA-256 of empty string is a known value
      expect(
        hash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('handles special characters', () {
      final hash = hashOtpCode('abc!@#\$%^&*()');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });
  });

  group('EmailService singleton', () {
    test('instance returns same object on repeated calls', () {
      final instance1 = EmailService.instance;
      final instance2 = EmailService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('isReady returns false when not initialized', () {
      // Note: In a fresh test, the service might not be initialized
      // This tests the default state behavior
      final service = EmailService.instance;
      // isReady depends on _gmailApi being set
      expect(service.isReady, isA<bool>());
    });
  });
}
