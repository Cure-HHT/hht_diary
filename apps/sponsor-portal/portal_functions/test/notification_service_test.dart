// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// Unit tests for NotificationService, NotificationConfig, and NotificationResult.
// Tests cover configuration, lifecycle, and send paths that don't require
// GCP credentials or a running database.

import 'package:test/test.dart';

import 'package:portal_functions/src/notification_service.dart';

void main() {
  group('NotificationConfig', () {
    test('stores projectId, enabled, and consoleMode', () {
      final config = NotificationConfig(
        projectId: 'test-project',
        enabled: true,
        consoleMode: false,
      );

      expect(config.projectId, 'test-project');
      expect(config.enabled, isTrue);
      expect(config.consoleMode, isFalse);
    });

    test('consoleMode defaults to false', () {
      final config = NotificationConfig(
        projectId: 'test-project',
        enabled: true,
      );

      expect(config.consoleMode, isFalse);
    });

    test('isConfigured returns true when enabled with non-empty projectId', () {
      final config = NotificationConfig(
        projectId: 'cure-hht-admin',
        enabled: true,
      );

      expect(config.isConfigured, isTrue);
    });

    test('isConfigured returns false when disabled', () {
      final config = NotificationConfig(
        projectId: 'cure-hht-admin',
        enabled: false,
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured returns false when projectId is empty', () {
      final config = NotificationConfig(projectId: '', enabled: true);

      expect(config.isConfigured, isFalse);
    });

    test('fromEnvironment creates config from env vars', () {
      // Without env vars set, uses defaults
      final config = NotificationConfig.fromEnvironment();

      // Default project ID is 'cure-hht-admin'
      expect(config.projectId, 'cure-hht-admin');
      // Default enabled is true (FCM_ENABLED != 'false')
      expect(config.enabled, isTrue);
    });
  });

  group('NotificationResult', () {
    test('success stores messageId and has success=true', () {
      final result = NotificationResult.success('msg-123');

      expect(result.success, isTrue);
      expect(result.messageId, 'msg-123');
      expect(result.error, isNull);
    });

    test('success with null messageId', () {
      final result = NotificationResult.success(null);

      expect(result.success, isTrue);
      expect(result.messageId, isNull);
      expect(result.error, isNull);
    });

    test('failure stores error and has success=false', () {
      final result = NotificationResult.failure('Network error');

      expect(result.success, isFalse);
      expect(result.error, 'Network error');
      expect(result.messageId, isNull);
    });
  });

  group('NotificationService', () {
    setUp(() {
      NotificationService.resetForTesting();
    });

    test('instance returns singleton', () {
      final instance1 = NotificationService.instance;
      final instance2 = NotificationService.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    test('resetForTesting clears singleton', () {
      final instance1 = NotificationService.instance;
      NotificationService.resetForTesting();
      final instance2 = NotificationService.instance;

      expect(identical(instance1, instance2), isFalse);
    });

    test('isReady returns false before initialization', () {
      expect(NotificationService.instance.isReady, isFalse);
    });

    test('isConsoleMode returns false before initialization', () {
      expect(NotificationService.instance.isConsoleMode, isFalse);
    });

    test(
      'initialize with disabled config marks service as not ready',
      () async {
        final config = NotificationConfig(projectId: 'test', enabled: false);

        await NotificationService.instance.initialize(config);

        expect(NotificationService.instance.isReady, isFalse);
      },
    );

    test('initialize with console mode marks service as ready', () async {
      final config = NotificationConfig(
        projectId: 'test-project',
        enabled: true,
        consoleMode: true,
      );

      await NotificationService.instance.initialize(config);

      expect(NotificationService.instance.isReady, isTrue);
      expect(NotificationService.instance.isConsoleMode, isTrue);
    });

    test('sendQuestionnaireNotification fails when not configured', () async {
      final result = await NotificationService.instance
          .sendQuestionnaireNotification(
            fcmToken: 'test-token-1234567890',
            questionnaireType: 'nose_hht',
            questionnaireInstanceId: 'inst-001',
            patientId: 'pat-001',
          );

      expect(result.success, isFalse);
      expect(result.error, contains('not configured'));
    });

    test(
      'sendQuestionnaireDeletedNotification fails when not configured',
      () async {
        final result = await NotificationService.instance
            .sendQuestionnaireDeletedNotification(
              fcmToken: 'test-token-1234567890',
              questionnaireInstanceId: 'inst-001',
              patientId: 'pat-001',
            );

        expect(result.success, isFalse);
        expect(result.error, contains('not configured'));
      },
    );

    test(
      'sendQuestionnaireUnlockedNotification fails when not configured',
      () async {
        final result = await NotificationService.instance
            .sendQuestionnaireUnlockedNotification(
              fcmToken: 'test-token-1234567890',
              questionnaireInstanceId: 'inst-001',
              patientId: 'pat-001',
            );

        expect(result.success, isFalse);
        expect(result.error, contains('not configured'));
      },
    );

    test(
      'sendQuestionnaireNotification fails when http client not initialized',
      () async {
        // Initialize with non-console, non-ADC config (will fail to get ADC but
        // config is set). We use disabled config + manually set _config to
        // simulate config-set but no client.
        final config = NotificationConfig(projectId: 'test', enabled: false);
        await NotificationService.instance.initialize(config);

        // The service has _config set but disabled, so isReady=false.
        // When we call send, it hits _config != null but _httpClient == null.
        // However, with enabled=false, _config.isConfigured returns false
        // so initialize sets _config but skips client creation.
        // The send method checks _config == null first. Since _config is set,
        // it proceeds past that check. Then it checks consoleMode (false),
        // then _httpClient == null -> returns failure.
        final result = await NotificationService.instance
            .sendQuestionnaireNotification(
              fcmToken: 'test-token-1234567890',
              questionnaireType: 'qol',
              questionnaireInstanceId: 'inst-002',
              patientId: 'pat-002',
            );

        expect(result.success, isFalse);
        expect(result.error, contains('not initialized'));
      },
    );
  });
}
