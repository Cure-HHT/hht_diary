// Tests for email service configuration and result classes
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance

import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/email_service.dart';

// Mock classes for Gmail API
class MockGmailApi extends Mock implements gmail.GmailApi {}

class MockUsersResource extends Mock implements gmail.UsersResource {}

class MockMessagesResource extends Mock
    implements gmail.UsersMessagesResource {}

void main() {
  // Register fallback value for Gmail Message type
  setUpAll(() {
    registerFallbackValue(gmail.Message());
  });
  group('EmailConfig', () {
    test('isConfigured returns false when not enabled', () {
      final config = EmailConfig(
        gmailServiceAccountEmail: 'sa@example.iam.gserviceaccount.com',
        senderEmail: 'noreply@example.com',
        enabled: false,
      );

      expect(config.isConfigured, isFalse);
    });

    test(
      'isConfigured returns false when gmailServiceAccountEmail is null',
      () {
        final config = EmailConfig(
          gmailServiceAccountEmail: null,
          senderEmail: 'noreply@example.com',
          enabled: true,
        );

        expect(config.isConfigured, isFalse);
      },
    );

    test(
      'isConfigured returns false when gmailServiceAccountEmail is empty',
      () {
        final config = EmailConfig(
          gmailServiceAccountEmail: '',
          senderEmail: 'noreply@example.com',
          enabled: true,
        );

        expect(config.isConfigured, isFalse);
      },
    );

    test('isConfigured returns true when properly configured', () {
      final config = EmailConfig(
        gmailServiceAccountEmail: 'sa@example.iam.gserviceaccount.com',
        senderEmail: 'noreply@example.com',
        enabled: true,
      );

      expect(config.isConfigured, isTrue);
    });

    test('senderName is constant', () {
      expect(EmailConfig.senderName, equals('Clinical Trial Portal'));
    });

    test('stores all fields correctly', () {
      final config = EmailConfig(
        gmailServiceAccountEmail: 'test-sa@project.iam.gserviceaccount.com',
        senderEmail: 'support@example.com',
        enabled: true,
      );

      expect(
        config.gmailServiceAccountEmail,
        equals('test-sa@project.iam.gserviceaccount.com'),
      );
      expect(config.senderEmail, equals('support@example.com'));
      expect(config.enabled, isTrue);
    });
  });

  group('EmailResult', () {
    test('success creates result with success=true and messageId', () {
      final result = EmailResult.success('msg-12345');

      expect(result.success, isTrue);
      expect(result.messageId, equals('msg-12345'));
      expect(result.error, isNull);
    });

    test('failure creates result with success=false and error', () {
      final result = EmailResult.failure('Connection refused');

      expect(result.success, isFalse);
      expect(result.messageId, isNull);
      expect(result.error, equals('Connection refused'));
    });

    test('success with null messageId', () {
      final result = EmailResult.success(null);

      expect(result.success, isTrue);
      expect(result.messageId, isNull);
      expect(result.error, isNull);
    });

    test('failure with empty error message', () {
      final result = EmailResult.failure('');

      expect(result.success, isFalse);
      expect(result.error, equals(''));
    });

    test('failure with long error message', () {
      final longError = 'Error: ' * 100;
      final result = EmailResult.failure(longError);

      expect(result.success, isFalse);
      expect(result.error, equals(longError));
    });
  });

  group('EmailService singleton', () {
    test('instance returns same object on repeated calls', () {
      final instance1 = EmailService.instance;
      final instance2 = EmailService.instance;

      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('generateOtpCode', () {
    test('generates 6-digit code', () {
      final code = generateOtpCode();
      expect(code.length, equals(6));
      expect(RegExp(r'^\d{6}$').hasMatch(code), isTrue);
    });

    test('generates different codes on repeated calls', () {
      final codes = <String>{};
      for (var i = 0; i < 10; i++) {
        codes.add(generateOtpCode());
      }
      // With 10 generations, we should have some variety
      // (statistically very unlikely to get all same codes)
      expect(codes.length, greaterThan(1));
    });

    test('generates only numeric characters', () {
      for (var i = 0; i < 10; i++) {
        final code = generateOtpCode();
        for (final char in code.split('')) {
          expect(int.tryParse(char), isNotNull);
        }
      }
    });
  });

  group('hashOtpCode', () {
    test('returns 64-character hex string (SHA-256)', () {
      final hash = hashOtpCode('123456');
      expect(hash.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash), isTrue);
    });

    test('produces consistent hash for same input', () {
      final hash1 = hashOtpCode('654321');
      final hash2 = hashOtpCode('654321');
      expect(hash1, equals(hash2));
    });

    test('produces different hash for different input', () {
      final hash1 = hashOtpCode('111111');
      final hash2 = hashOtpCode('222222');
      expect(hash1, isNot(equals(hash2)));
    });

    test('handles empty string', () {
      final hash = hashOtpCode('');
      expect(hash.length, equals(64));
    });

    test('handles special characters', () {
      final hash = hashOtpCode(r'!@#$%^');
      expect(hash.length, equals(64));
    });
  });

  group('EmailService with mock Gmail API', () {
    late MockGmailApi mockGmailApi;
    late MockUsersResource mockUsersResource;
    late MockMessagesResource mockMessagesResource;
    late EmailConfig testConfig;

    setUp(() {
      // Reset singleton before each test
      EmailService.resetForTesting();

      mockGmailApi = MockGmailApi();
      mockUsersResource = MockUsersResource();
      mockMessagesResource = MockMessagesResource();
      testConfig = EmailConfig(
        gmailServiceAccountEmail: 'test-sa@project.iam.gserviceaccount.com',
        senderEmail: 'noreply@test.com',
        enabled: true,
      );

      // Wire up mock hierarchy
      when(() => mockGmailApi.users).thenReturn(mockUsersResource);
      when(() => mockUsersResource.messages).thenReturn(mockMessagesResource);
    });

    tearDown(() {
      EmailService.resetForTesting();
    });

    test('sendOtpCode returns success when Gmail API succeeds', () async {
      // Setup mock to return successful message
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = 'msg-12345');

      // Initialize with mock
      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'user@example.com',
        code: '123456',
        recipientName: 'Test User',
      );

      expect(result.success, isTrue);
      expect(result.messageId, equals('msg-12345'));
      expect(result.error, isNull);

      verify(
        () => mockMessagesResource.send(any(), testConfig.senderEmail),
      ).called(1);
    });

    test('sendOtpCode returns failure when Gmail API throws', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenThrow(Exception('API error: quota exceeded'));

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'user@example.com',
        code: '123456',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('quota exceeded'));
      expect(result.messageId, isNull);
    });

    test(
      'sendActivationCode returns success when Gmail API succeeds',
      () async {
        when(
          () => mockMessagesResource.send(any(), any()),
        ).thenAnswer((_) async => gmail.Message()..id = 'activation-msg-789');

        EmailService.initializeWithMock(mockGmailApi, testConfig);

        final result = await EmailService.instance.sendActivationCode(
          recipientEmail: 'newuser@example.com',
          recipientName: 'New User',
          activationCode: 'ABC12-DEF34',
          activationUrl: 'https://portal.example.com/activate?code=ABC12-DEF34',
        );

        expect(result.success, isTrue);
        expect(result.messageId, equals('activation-msg-789'));
      },
    );

    test('sendActivationCode returns failure when Gmail API throws', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenThrow(Exception('Network timeout'));

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendActivationCode(
        recipientEmail: 'newuser@example.com',
        recipientName: 'New User',
        activationCode: 'ABC12-DEF34',
        activationUrl: 'https://portal.example.com/activate?code=ABC12-DEF34',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Network timeout'));
    });

    test('sendOtpCode handles null message ID in response', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = null);

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'user@example.com',
        code: '654321',
      );

      expect(result.success, isTrue);
      expect(result.messageId, equals('unknown'));
    });

    test('sendOtpCode without recipientName still works', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = 'msg-noname');

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'user@example.com',
        code: '111222',
        // No recipientName
      );

      expect(result.success, isTrue);
    });

    test('isReady returns true when mock is initialized', () {
      EmailService.initializeWithMock(mockGmailApi, testConfig);

      expect(EmailService.instance.isReady, isTrue);
    });

    test('isReady returns false when config is disabled', () {
      final disabledConfig = EmailConfig(
        gmailServiceAccountEmail: 'test-sa@project.iam.gserviceaccount.com',
        senderEmail: 'noreply@test.com',
        enabled: false,
      );

      EmailService.initializeWithMock(mockGmailApi, disabledConfig);

      expect(EmailService.instance.isReady, isFalse);
    });

    test('sendOtpCode returns failure when not ready', () async {
      // Don't initialize - service is not ready
      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'user@example.com',
        code: '123456',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Email service not ready'));
    });

    test('sendActivationCode returns failure when not ready', () async {
      // Don't initialize - service is not ready
      final result = await EmailService.instance.sendActivationCode(
        recipientEmail: 'user@example.com',
        recipientName: 'User',
        activationCode: 'CODE',
        activationUrl: 'https://example.com',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Email service not ready'));
    });

    test('sendActivationCode with sentByUserId works', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = 'msg-with-sender');

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendActivationCode(
        recipientEmail: 'newuser@example.com',
        recipientName: 'New User',
        activationCode: 'ABC12-DEF34',
        activationUrl: 'https://portal.example.com/activate?code=ABC12-DEF34',
        sentByUserId: 'admin-user-uuid-12345',
      );

      expect(result.success, isTrue);
      expect(result.messageId, equals('msg-with-sender'));
    });

    test('sendOtpCode with short email local part (<=2 chars)', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = 'msg-short-email');

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'ab@example.com', // Short local part
        code: '123456',
      );

      expect(result.success, isTrue);
    });

    test('sendOtpCode with single char email local part', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = 'msg-single-char');

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendOtpCode(
        recipientEmail: 'a@example.com', // Single char local part
        code: '654321',
      );

      expect(result.success, isTrue);
    });
  });

  group('EmailService reset and reinitialize', () {
    test('resetForTesting clears singleton state', () {
      final instance1 = EmailService.instance;
      EmailService.resetForTesting();
      final instance2 = EmailService.instance;

      // After reset, we get a new instance
      expect(identical(instance1, instance2), isFalse);
    });

    test('can reinitialize after reset', () async {
      EmailService.resetForTesting();

      // Initialize with disabled config
      final config = EmailConfig(
        gmailServiceAccountEmail: null,
        senderEmail: 'test@test.com',
        enabled: false,
      );

      await EmailService.instance.initialize(config);

      // Service should not be ready (disabled)
      expect(EmailService.instance.isReady, isFalse);
    });
  });

  group('EmailConfig console mode', () {
    test('consoleMode defaults to false', () {
      final config = EmailConfig(
        gmailServiceAccountEmail: 'test@example.iam.gserviceaccount.com',
        senderEmail: 'noreply@example.com',
        enabled: true,
      );

      expect(config.consoleMode, isFalse);
    });

    test('consoleMode can be set to true', () {
      final config = EmailConfig(
        gmailServiceAccountEmail: 'test@example.iam.gserviceaccount.com',
        senderEmail: 'noreply@example.com',
        enabled: true,
        consoleMode: true,
      );

      expect(config.consoleMode, isTrue);
    });

    test('isConfigured returns true in console mode even without SA email', () {
      final config = EmailConfig(
        gmailServiceAccountEmail: null,
        senderEmail: 'noreply@example.com',
        enabled: true,
        consoleMode: true,
      );

      // Console mode counts as configured
      expect(config.isConfigured, isTrue);
    });
  });

  group('EmailService console mode', () {
    setUp(() {
      EmailService.resetForTesting();
    });

    tearDown(() {
      EmailService.resetForTesting();
    });

    test('isConsoleMode returns true when initialized with console mode', () {
      final consoleConfig = EmailConfig(
        gmailServiceAccountEmail: null,
        senderEmail: 'noreply@test.com',
        enabled: true,
        consoleMode: true,
      );

      EmailService.initializeWithMock(MockGmailApi(), consoleConfig);

      expect(EmailService.instance.isConsoleMode, isTrue);
    });

    test('isConsoleMode returns false when not in console mode', () {
      final normalConfig = EmailConfig(
        gmailServiceAccountEmail: 'sa@test.iam.gserviceaccount.com',
        senderEmail: 'noreply@test.com',
        enabled: true,
        consoleMode: false,
      );

      EmailService.initializeWithMock(MockGmailApi(), normalConfig);

      expect(EmailService.instance.isConsoleMode, isFalse);
    });

    test('isConsoleMode returns false when not initialized', () {
      expect(EmailService.instance.isConsoleMode, isFalse);
    });
  });

  group('sendPasswordResetEmail', () {
    late MockGmailApi mockGmailApi;
    late MockUsersResource mockUsersResource;
    late MockMessagesResource mockMessagesResource;
    late EmailConfig testConfig;

    setUp(() {
      EmailService.resetForTesting();

      mockGmailApi = MockGmailApi();
      mockUsersResource = MockUsersResource();
      mockMessagesResource = MockMessagesResource();
      testConfig = EmailConfig(
        gmailServiceAccountEmail: 'test-sa@project.iam.gserviceaccount.com',
        senderEmail: 'noreply@test.com',
        enabled: true,
      );

      when(() => mockGmailApi.users).thenReturn(mockUsersResource);
      when(() => mockUsersResource.messages).thenReturn(mockMessagesResource);
    });

    tearDown(() {
      EmailService.resetForTesting();
    });

    test(
      'sendPasswordResetEmail returns success when Gmail API succeeds',
      () async {
        when(
          () => mockMessagesResource.send(any(), any()),
        ).thenAnswer((_) async => gmail.Message()..id = 'reset-msg-123');

        EmailService.initializeWithMock(mockGmailApi, testConfig);

        final result = await EmailService.instance.sendPasswordResetEmail(
          recipientEmail: 'user@example.com',
          resetLink: 'https://portal.example.com/reset?code=abc123',
          recipientName: 'Test User',
        );

        expect(result.success, isTrue);
        expect(result.messageId, equals('reset-msg-123'));
      },
    );

    test('sendPasswordResetEmail returns failure when not ready', () async {
      final result = await EmailService.instance.sendPasswordResetEmail(
        recipientEmail: 'user@example.com',
        resetLink: 'https://portal.example.com/reset?code=abc123',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Email service not ready'));
    });

    test('sendPasswordResetEmail works without recipientName', () async {
      when(
        () => mockMessagesResource.send(any(), any()),
      ).thenAnswer((_) async => gmail.Message()..id = 'reset-msg-noname');

      EmailService.initializeWithMock(mockGmailApi, testConfig);

      final result = await EmailService.instance.sendPasswordResetEmail(
        recipientEmail: 'user@example.com',
        resetLink: 'https://portal.example.com/reset?code=def456',
        // No recipientName - uses "Hello" greeting
      );

      expect(result.success, isTrue);
      expect(result.messageId, equals('reset-msg-noname'));
    });

    test(
      'sendPasswordResetEmail returns failure when Gmail API throws',
      () async {
        when(
          () => mockMessagesResource.send(any(), any()),
        ).thenThrow(Exception('SMTP connection failed'));

        EmailService.initializeWithMock(mockGmailApi, testConfig);

        final result = await EmailService.instance.sendPasswordResetEmail(
          recipientEmail: 'user@example.com',
          resetLink: 'https://portal.example.com/reset?code=xyz789',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('SMTP connection failed'));
      },
    );
  });
}
