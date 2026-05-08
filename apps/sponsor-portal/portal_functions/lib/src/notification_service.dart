// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-p00049: Ancillary Platform Services (push notifications)
//   REQ-d00167: FCM Dispatch via cure-hht-admin Project
//
// Server-side FCM orchestrator. Phase 1A.4: the actual transport
// (HTTP POST + ADC client + APNS payload split) moved into the
// `comms` package as `FcmChannel`. This service is now a thin
// orchestrator that:
//   * holds the FcmChannel + console mode
//   * exposes per-notification-type helpers used by the patient_linking
//     and questionnaire handlers
//   * builds an FcmMessage and dispatches via the channel
//   * keeps the FDA audit row + metrics that Phase 1B will move into
//     the OutboxWriter when envelopes land
//
// Public API (sendQuestionnaireNotification, sendPatientStatusNotification,
// etc.) is unchanged — callers get NotificationResult back as before.

import 'dart:convert';
import 'dart:io';

import 'package:comms/comms.dart';
import 'package:otel_common/otel_common.dart';

import 'database.dart';
import 'portal_metrics.dart';

/// FCM notification service configuration from environment
class NotificationConfig {
  const NotificationConfig({
    required this.projectId,
    required this.enabled,
    this.consoleMode = false,
  });

  /// Create config from environment variables
  factory NotificationConfig.fromEnvironment() {
    return NotificationConfig(
      projectId: Platform.environment['FCM_PROJECT_ID'] ?? 'cure-hht-admin',
      enabled: Platform.environment['FCM_ENABLED'] != 'false',
      consoleMode: Platform.environment['FCM_CONSOLE_MODE'] == 'true',
    );
  }

  /// Firebase project ID for FCM API endpoint (e.g., `cure-hht-admin`).
  final String projectId;

  /// Whether push notifications are enabled.
  final bool enabled;

  /// Console mode — logs messages instead of sending. Useful for local
  /// development without GCP credentials.
  final bool consoleMode;

  /// Check if notification service is properly configured.
  bool get isConfigured => enabled && projectId.isNotEmpty;
}

/// Result of a notification send operation. Wraps [DispatchResult] from
/// `comms` so existing callers keep their {success, messageId, error}
/// shape — Phase 1B will migrate them to the envelope-based contract.
class NotificationResult {
  NotificationResult.success(this.messageId) : success = true, error = null;

  NotificationResult.failure(this.error) : success = false, messageId = null;

  final bool success;
  final String? messageId;
  final String? error;
}

/// FCM orchestrator singleton. Sends data-only / alert push messages to
/// patient devices. PHI is rejected by `PayloadGuard` inside the channel
/// before any network egress (REQ-d00168).
class NotificationService {
  NotificationService._();

  static NotificationService? _instance;
  static NotificationConfig? _config;
  static FcmChannel? _fcmChannel;

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// Reset the service for testing purposes.
  /// @visibleForTesting
  static void resetForTesting() {
    _fcmChannel?.dispose();
    _instance = null;
    _config = null;
    _fcmChannel = null;
  }

  /// Initialize the notification service with configuration.
  ///
  /// Uses WIF: Cloud Run SA gets ADC automatically. The SA must have
  /// the `fcmSender` role on the Firebase project (`cure-hht-admin`).
  Future<void> initialize(NotificationConfig config) async {
    if (_fcmChannel != null) return;
    _config = config;

    if (!config.isConfigured) {
      logWithTrace(
        'INFO',
        'FCM notification service disabled or not configured',
      );
      return;
    }

    if (config.consoleMode) {
      logWithTrace('INFO', 'FCM console mode enabled');
      _fcmChannel = FcmChannel(projectId: config.projectId, consoleMode: true);
      return;
    }

    try {
      logWithTrace('INFO', 'FCM using Workload Identity Federation (ADC)');
      _fcmChannel = FcmChannel(projectId: config.projectId);
      logWithTrace('INFO', 'FCM notification service initialized successfully');
    } catch (e) {
      reportAndRecordError(e, stackTrace: StackTrace.current);
      logWithTrace(
        'ERROR',
        'FCM failed to initialize notification service',
        labels: {'error': e.toString()},
      );
      _fcmChannel = null;
    }
  }

  /// Check if service is ready to send notifications.
  bool get isReady => (_config?.enabled ?? false) && _fcmChannel != null;

  /// Check if running in console mode.
  bool get isConsoleMode => _config?.consoleMode ?? false;

  /// Send a questionnaire notification to a patient's device.
  ///
  /// Per REQ-CAL-p00023-D: When a questionnaire is sent, the patient
  /// SHALL receive a push notification on their Mobile App.
  Future<NotificationResult> sendQuestionnaireNotification({
    required String fcmToken,
    required String questionnaireType,
    required String questionnaireInstanceId,
    required String patientId,
  }) async {
    return _sendFcmMessage(
      fcmToken: fcmToken,
      data: {
        'type': 'questionnaire_sent',
        'questionnaire_type': questionnaireType,
        'questionnaire_instance_id': questionnaireInstanceId,
        'action': 'new_task',
      },
      notificationTitle: 'New Questionnaire Available',
      notificationBody: 'You have a new questionnaire to complete.',
      messageType: 'questionnaire_sent',
      patientId: patientId,
    );
  }

  /// Send a questionnaire deletion notification to a patient's device.
  ///
  /// Per REQ-CAL-p00023-H: When a questionnaire is deleted, it SHALL be
  /// removed from the patient's app. Silent push — no title/body.
  Future<NotificationResult> sendQuestionnaireDeletedNotification({
    required String fcmToken,
    required String questionnaireInstanceId,
    required String patientId,
  }) async {
    return _sendFcmMessage(
      fcmToken: fcmToken,
      data: {
        'type': 'questionnaire_deleted',
        'questionnaire_instance_id': questionnaireInstanceId,
        'action': 'remove_task',
      },
      messageType: 'questionnaire_deleted',
      patientId: patientId,
    );
  }

  /// Send a questionnaire unlocked notification to a patient's device.
  Future<NotificationResult> sendQuestionnaireUnlockedNotification({
    required String fcmToken,
    required String questionnaireInstanceId,
    required String patientId,
  }) async {
    return _sendFcmMessage(
      fcmToken: fcmToken,
      data: {
        'type': 'questionnaire_unlocked',
        'questionnaire_instance_id': questionnaireInstanceId,
        'action': 'unlock_task',
      },
      notificationTitle: 'Questionnaire Unlocked',
      notificationBody: 'A questionnaire has been unlocked for editing.',
      messageType: 'questionnaire_unlocked',
      patientId: patientId,
    );
  }

  /// Send a questionnaire-finalized notification to a patient's device.
  Future<NotificationResult> sendQuestionnaireFinalizedNotification({
    required String fcmToken,
    required String questionnaireInstanceId,
    required String patientId,
  }) async {
    return _sendFcmMessage(
      fcmToken: fcmToken,
      data: {
        'type': 'questionnaire_finalized',
        'questionnaire_instance_id': questionnaireInstanceId,
        'action': 'lock_task',
      },
      notificationTitle: 'Questionnaire Finalized',
      notificationBody: 'Your questionnaire has been finalized.',
      messageType: 'questionnaire_finalized',
      patientId: patientId,
    );
  }

  /// Send a patient-status-change notification (disconnect, reconnect,
  /// mark_not_participating, reactivate, start_trial).
  Future<NotificationResult> sendPatientStatusNotification({
    required String fcmToken,
    required String patientId,
    required String action,
    required String title,
    required String body,
    Map<String, String>? extraData,
  }) async {
    final data = <String, String>{
      'type': 'patient_status_update',
      'action': action,
      if (extraData != null) ...extraData,
    };
    return _sendFcmMessage(
      fcmToken: fcmToken,
      data: data,
      notificationTitle: title,
      notificationBody: body,
      messageType: 'patient_status_update',
      patientId: patientId,
    );
  }

  /// Build an [FcmMessage], dispatch through the channel, audit, and
  /// emit metrics. The `userVisible` flag is derived from the title
  /// presence — the same convention each public method already encodes
  /// (alert callers pass a title; silent ones omit it).
  Future<NotificationResult> _sendFcmMessage({
    required String fcmToken,
    required Map<String, String> data,
    required String messageType,
    required String patientId,
    String? notificationTitle,
    String? notificationBody,
  }) async {
    final config = _config;
    if (config == null) {
      return NotificationResult.failure('Notification service not configured');
    }
    final channel = _fcmChannel;
    if (channel == null) {
      return NotificationResult.failure('FCM HTTP client not initialized');
    }

    final fcmMessage = FcmMessage(
      fcmToken: fcmToken,
      data: data,
      userVisible: notificationTitle != null,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
    );

    try {
      final result = await channel.dispatch(fcmMessage);

      if (config.consoleMode) {
        logWithTrace(
          'INFO',
          'FCM console mode: would send $messageType',
          labels: {'patient_id': patientId, 'message_type': messageType},
        );
        await _logNotificationAudit(
          patientId: patientId,
          messageType: messageType,
          status: 'console',
          data: data,
        );
        return NotificationResult.success(result.messageId ?? 'console-mode');
      }

      if (result.success) {
        fcmNotificationSent(messageType: messageType, status: 'sent');
        logWithTrace(
          'INFO',
          'FCM sent $messageType',
          labels: {
            'patient_id': patientId,
            'message_id': result.messageId ?? 'unknown',
          },
        );
        await _logNotificationAudit(
          patientId: patientId,
          messageType: messageType,
          status: 'sent',
          messageId: result.messageId,
          data: data,
        );
        return NotificationResult.success(result.messageId);
      }

      // Failure path — both UNREGISTERED and other errors land here.
      // Phase 1B will start consuming `result.unregistered` for token
      // deactivation via the OutboxWriter.onUnregistered callback;
      // for now we keep the legacy "failed" tagging on metric + audit.
      final errorMessage = result.error ?? 'unknown';
      fcmNotificationSent(messageType: messageType, status: 'failed');
      reportError(Exception('FCM dispatch failed: $errorMessage'));
      logWithTrace(
        'ERROR',
        'FCM failed to send $messageType',
        labels: {'patient_id': patientId, 'error': errorMessage},
      );
      await _logNotificationAudit(
        patientId: patientId,
        messageType: messageType,
        status: 'failed',
        error: errorMessage,
        data: data,
      );
      return NotificationResult.failure(errorMessage);
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      fcmNotificationSent(messageType: messageType, status: 'error');
      reportAndRecordError(e, stackTrace: stackTrace);
      logWithTrace(
        'ERROR',
        'FCM exception sending $messageType',
        labels: {'patient_id': patientId, 'error': errorMessage},
      );
      await _logNotificationAudit(
        patientId: patientId,
        messageType: messageType,
        status: 'failed',
        error: errorMessage,
        data: data,
      );
      return NotificationResult.failure(errorMessage);
    }
  }

  /// Log notification to audit table (FDA compliance).
  Future<void> _logNotificationAudit({
    required String patientId,
    required String messageType,
    required String status,
    String? messageId,
    String? error,
    Map<String, String>? data,
  }) async {
    try {
      final db = Database.instance;

      await db.executeWithContext(
        '''
        INSERT INTO admin_action_log (
          admin_id, action_type, target_resource, action_details,
          justification, requires_review
        )
        VALUES (
          'system', @actionType, @targetResource,
          @actionDetails::jsonb, @justification, false
        )
        ''',
        parameters: {
          'actionType': 'FCM_NOTIFICATION',
          'targetResource': 'patient:$patientId',
          'actionDetails': jsonEncode({
            'message_type': messageType,
            'status': status,
            'message_id': messageId,
            'error': error,
            'data_keys': data?.keys.toList(),
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          'justification': '$messageType notification $status',
        },
        context: UserContext.service,
      );
    } catch (e) {
      logWithTrace(
        'ERROR',
        'FCM failed to log notification audit',
        labels: {'error': e.toString()},
      );
    }
  }
}
