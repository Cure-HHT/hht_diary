// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// Unit tests for NotificationService, NotificationConfig, and NotificationResult.
// Tests cover configuration, lifecycle, and send paths that don't require
// GCP credentials or a running database.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/notification_service.dart';

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-functions-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );
  });
  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

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

  // --------------------------------------------------------------------
  // FCM Flow QA Test Plan coverage (backend, mocked FCM).
  //
  // The console-mode FcmChannel returns DispatchResult.success without
  // hitting the network — this is the project's built-in "mocked FCM"
  // path, so these tests run end-to-end through NotificationService
  // without ADC or a Firebase project.
  //
  // TCs 04, 09, 15 covered here. TCs 02, 03, 11 are wire-layer tests
  // in diary_functions/test/fcm_token_test.dart. TC-10 (UNREGISTERED)
  // and TC-13 (logout deactivation) are covered by the OutboxWriter
  // suite in apps/common-dart/comms.
  // --------------------------------------------------------------------

  group('TC-04: questionnaire assignment dispatches via FCM', () {
    setUp(() {
      NotificationService.resetForTesting();
    });

    Future<void> withConsoleMode(
      Future<void> Function(NotificationService svc) body,
    ) async {
      final config = NotificationConfig(
        projectId: 'cure-hht-admin-test',
        enabled: true,
        consoleMode: true,
      );
      await NotificationService.instance.initialize(config);
      await body(NotificationService.instance);
    }

    test('sendQuestionnaireNotification returns success in console mode',
        () async {
      await withConsoleMode((svc) async {
        final result = await svc.sendQuestionnaireNotification(
          fcmToken: 'test-token-aaaaaaaaaaaaaaaaaaaa',
          questionnaireType: 'nose_hht',
          questionnaireInstanceId: 'inst-tc04-001',
          patientId: 'pat-tc04-001',
        );

        expect(result.success, isTrue);
        // Console-mode messageId is either 'console-mode' (legacy) or
        // 'projects/.../messages/...' — the contract is non-null and
        // distinct from a real FCM v1 send.
        expect(result.messageId, isNotNull);
        expect(result.error, isNull);
      });
    });

    test('sendQuestionnaireDeletedNotification succeeds silently in console mode',
        () async {
      await withConsoleMode((svc) async {
        final result = await svc.sendQuestionnaireDeletedNotification(
          fcmToken: 'test-token-bbbbbbbbbbbbbbbbbbbb',
          questionnaireInstanceId: 'inst-tc04-002',
          patientId: 'pat-tc04-002',
        );

        expect(result.success, isTrue);
        expect(result.error, isNull);
      });
    });

    test('sendQuestionnaireUnlockedNotification succeeds in console mode',
        () async {
      await withConsoleMode((svc) async {
        final result = await svc.sendQuestionnaireUnlockedNotification(
          fcmToken: 'test-token-cccccccccccccccccccc',
          questionnaireInstanceId: 'inst-tc04-003',
          patientId: 'pat-tc04-003',
        );

        expect(result.success, isTrue);
      });
    });

    test('sendQuestionnaireFinalizedNotification succeeds in console mode',
        () async {
      await withConsoleMode((svc) async {
        final result = await svc.sendQuestionnaireFinalizedNotification(
          fcmToken: 'test-token-dddddddddddddddddddd',
          questionnaireInstanceId: 'inst-tc04-004',
          patientId: 'pat-tc04-004',
        );

        expect(result.success, isTrue);
      });
    });

    test('sendPatientStatusNotification succeeds with extra data', () async {
      await withConsoleMode((svc) async {
        final result = await svc.sendPatientStatusNotification(
          fcmToken: 'test-token-eeeeeeeeeeeeeeeeeeee',
          patientId: 'pat-tc04-005',
          action: 'reactivate',
          title: 'Account Reactivated',
          body: 'Your account has been reactivated.',
          extraData: {'study_id': 'study-1'},
        );

        expect(result.success, isTrue);
      });
    });
  });

  group('TC-09: duplicate sends are tolerated (no exception, idempotent shape)',
      () {
    setUp(() {
      NotificationService.resetForTesting();
    });

    test(
      'identical questionnaire send invoked twice returns success twice',
      () async {
        final config = NotificationConfig(
          projectId: 'cure-hht-admin-test',
          enabled: true,
          consoleMode: true,
        );
        await NotificationService.instance.initialize(config);

        Future<NotificationResult> send() =>
            NotificationService.instance.sendQuestionnaireNotification(
              fcmToken: 'tok-dup-1111111111111111',
              questionnaireType: 'nose_hht',
              questionnaireInstanceId: 'inst-tc09-001',
              patientId: 'pat-tc09-001',
            );

        final first = await send();
        final second = await send();

        // Idempotency at THIS layer means: no thrown exception, no
        // mutated state on the in-process service. Database-level
        // questionnaire-record idempotency is the questionnaire
        // handler's responsibility — covered in
        // questionnaire_unlock_finalize_test.dart. End-to-end
        // de-dup at the envelope layer is covered in the comms
        // OutboxWriter test suite.
        expect(first.success, isTrue);
        expect(second.success, isTrue);
      },
    );
  });

  group('TC-15: FCM send failure does not block business state', () {
    setUp(() {
      NotificationService.resetForTesting();
    });

    test('disabled config: send returns failure (does not throw)', () async {
      await NotificationService.instance.initialize(
        NotificationConfig(projectId: 'test', enabled: false),
      );

      final result = await NotificationService.instance
          .sendQuestionnaireNotification(
        fcmToken: 'tok-tc15-aaaaaaaaaaaaaaaa',
        questionnaireType: 'nose_hht',
        questionnaireInstanceId: 'inst-tc15-001',
        patientId: 'pat-tc15-001',
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      // Critical: a caller that wraps this in a transaction must not
      // see an exception bubble up — the failure is captured on the
      // result object so the business event can still commit.
    });

    test('uninitialised service: send returns failure (does not throw)',
        () async {
      // No initialize() call.
      final result = await NotificationService.instance
          .sendQuestionnaireDeletedNotification(
        fcmToken: 'tok-tc15-bbbbbbbbbbbbbbbb',
        questionnaireInstanceId: 'inst-tc15-002',
        patientId: 'pat-tc15-002',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('not configured'));
    });

    test(
      'every public send method returns NotificationResult on failure '
      '(none throw)',
      () async {
        await NotificationService.instance.initialize(
          NotificationConfig(projectId: 'test', enabled: false),
        );
        final svc = NotificationService.instance;

        Future<NotificationResult> assertReturnsResult(
          Future<NotificationResult> Function() call,
        ) async {
          // The assertion is that this completes without throwing — the
          // returned NotificationResult is captured and validated below.
          final r = await call();
          expect(r, isA<NotificationResult>());
          return r;
        }

        final results = <NotificationResult>[
          await assertReturnsResult(
            () => svc.sendQuestionnaireNotification(
              fcmToken: 'tok-tc15-c1-cccccccccccc',
              questionnaireType: 'nose_hht',
              questionnaireInstanceId: 'inst-c1',
              patientId: 'pat-c1',
            ),
          ),
          await assertReturnsResult(
            () => svc.sendQuestionnaireDeletedNotification(
              fcmToken: 'tok-tc15-c2-cccccccccccc',
              questionnaireInstanceId: 'inst-c2',
              patientId: 'pat-c2',
            ),
          ),
          await assertReturnsResult(
            () => svc.sendQuestionnaireUnlockedNotification(
              fcmToken: 'tok-tc15-c3-cccccccccccc',
              questionnaireInstanceId: 'inst-c3',
              patientId: 'pat-c3',
            ),
          ),
          await assertReturnsResult(
            () => svc.sendQuestionnaireFinalizedNotification(
              fcmToken: 'tok-tc15-c4-cccccccccccc',
              questionnaireInstanceId: 'inst-c4',
              patientId: 'pat-c4',
            ),
          ),
          await assertReturnsResult(
            () => svc.sendPatientStatusNotification(
              fcmToken: 'tok-tc15-c5-cccccccccccc',
              patientId: 'pat-c5',
              action: 'disconnect',
              title: 'Disconnected',
              body: 'You were disconnected.',
            ),
          ),
        ];

        // Every helper surfaced a non-throwing failure result.
        expect(results.every((r) => !r.success), isTrue);
        expect(results.every((r) => r.error != null), isTrue);
      },
    );
  });
}
