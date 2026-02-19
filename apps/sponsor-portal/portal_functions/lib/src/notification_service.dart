// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// FCM HTTP v1 API integration for sending push notifications to patients.
// Uses Workload Identity Federation (ADC) - no key files needed.
//
// Authentication: WIF (Workload Identity Federation)
//   - Cloud Run SA gets ADC automatically
//   - Local dev: gcloud auth application-default login
//   - Cloud Run SA needs fcmSender role on cure-hht-admin project

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'database.dart';

/// FCM notification service configuration from environment
class NotificationConfig {
  /// Firebase project ID for FCM API endpoint
  /// (e.g., 'cure-hht-admin')
  final String projectId;

  /// Whether push notifications are enabled
  final bool enabled;

  /// Console mode - logs messages to console instead of sending
  /// Useful for local development without GCP credentials
  final bool consoleMode;

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

  /// Check if notification service is properly configured
  bool get isConfigured => enabled && projectId.isNotEmpty;
}

/// Result of a notification send operation
class NotificationResult {
  final bool success;
  final String? messageId;
  final String? error;

  NotificationResult.success(this.messageId) : success = true, error = null;

  NotificationResult.failure(this.error) : success = false, messageId = null;
}

/// FCM notification service singleton using HTTP v1 API.
///
/// Sends data-only push notifications to patient devices.
/// No PHI is included in notification payloads per GDPR/HIPAA compliance.
class NotificationService {
  static NotificationService? _instance;
  static NotificationConfig? _config;
  static http.Client? _httpClient;
  static DateTime? _tokenCreatedAt;

  /// Token refresh buffer - refresh 5 minutes before expiry
  static const _tokenRefreshBuffer = Duration(minutes: 5);

  /// Token lifetime - tokens are valid for 1 hour
  static const _tokenLifetime = Duration(hours: 1);

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// Reset the service for testing purposes
  /// @visibleForTesting
  static void resetForTesting() {
    _instance = null;
    _config = null;
    _httpClient = null;
    _tokenCreatedAt = null;
  }

  /// Check if token needs refresh
  bool _needsTokenRefresh() {
    if (_tokenCreatedAt == null) return false;
    final tokenAge = DateTime.now().difference(_tokenCreatedAt!);
    final needsRefresh = tokenAge >= (_tokenLifetime - _tokenRefreshBuffer);
    if (needsRefresh) {
      print('[FCM] Token age: ${tokenAge.inMinutes} minutes - needs refresh');
    }
    return needsRefresh;
  }

  /// Refresh the HTTP client if token is expired
  Future<void> _refreshIfNeeded() async {
    if (_config == null || _config!.consoleMode) return;
    if (!_needsTokenRefresh()) return;

    print('[FCM] Refreshing ADC token...');
    try {
      _httpClient = await _createAdcClient();
      _tokenCreatedAt = DateTime.now();
      print('[FCM] Token refreshed successfully');
    } catch (e) {
      print('[FCM] Failed to refresh token: $e');
    }
  }

  /// Initialize the notification service with configuration.
  ///
  /// Uses WIF: Cloud Run SA gets ADC automatically. The SA must have
  /// the fcmSender role on the Firebase project (cure-hht-admin).
  Future<void> initialize(NotificationConfig config) async {
    if (_httpClient != null) return;
    _config = config;

    if (!config.isConfigured) {
      print('[FCM] Notification service disabled or not configured');
      return;
    }

    if (config.consoleMode) {
      print(
        '[FCM] Console mode enabled - notifications will be logged to console',
      );
      return;
    }

    try {
      print('[FCM] Using Workload Identity Federation (ADC)');
      _httpClient = await _createAdcClient();
      _tokenCreatedAt = DateTime.now();
      print('[FCM] Notification service initialized successfully');
    } catch (e) {
      print('[FCM] Failed to initialize notification service: $e');
      _httpClient = null;
      _tokenCreatedAt = null;
    }
  }

  /// Create HTTP client using Application Default Credentials.
  ///
  /// Unlike email_service.dart, FCM does NOT need domain-wide delegation
  /// or signJwt. The Cloud Run SA already has fcmSender role on
  /// cure-hht-admin, so a simple ADC token with cloud-platform scope works.
  Future<http.Client> _createAdcClient() async {
    print('[FCM] Getting Application Default Credentials...');
    final client = await clientViaApplicationDefaultCredentials(
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    );
    print('[FCM] ADC obtained successfully');
    return client;
  }

  /// Check if service is ready to send notifications
  bool get isReady =>
      (_config?.enabled ?? false) &&
      ((_config?.consoleMode ?? false) || _httpClient != null);

  /// Check if running in console mode
  bool get isConsoleMode => _config?.consoleMode ?? false;

  /// Send a questionnaire notification to a patient's device.
  ///
  /// Per REQ-CAL-p00023-D: When a questionnaire is sent, the patient
  /// SHALL receive a push notification on their Mobile App.
  ///
  /// Uses data-only messages with a generic notification title/body
  /// to avoid putting PHI in the notification payload.
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
  /// removed from the patient's app.
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

  /// Internal method to send an FCM message via HTTP v1 API.
  Future<NotificationResult> _sendFcmMessage({
    required String fcmToken,
    required Map<String, String> data,
    required String messageType,
    required String patientId,
    String? notificationTitle,
    String? notificationBody,
  }) async {
    if (_config == null) {
      return NotificationResult.failure('Notification service not configured');
    }

    await _refreshIfNeeded();

    // Console mode - log to console instead of sending
    if (_config!.consoleMode) {
      print('');
      print('=' * 60);
      print('[FCM CONSOLE MODE] Would send $messageType:');
      print('  Token: ${fcmToken.substring(0, 20)}...');
      print('  Patient: $patientId');
      print('  Data: ${jsonEncode(data)}');
      if (notificationTitle != null) {
        print('  Notification: $notificationTitle - $notificationBody');
      }
      print('=' * 60);
      print('');

      await _logNotificationAudit(
        patientId: patientId,
        messageType: messageType,
        status: 'console',
        data: data,
      );

      return NotificationResult.success('console-mode');
    }

    if (_httpClient == null) {
      return NotificationResult.failure('FCM HTTP client not initialized');
    }

    try {
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/${_config!.projectId}/messages:send',
      );

      // Build the message payload
      final message = <String, dynamic>{'token': fcmToken, 'data': data};

      // Add optional notification (for system tray display)
      if (notificationTitle != null) {
        message['notification'] = {
          'title': notificationTitle,
          'body': notificationBody ?? '',
        };
      }

      // Android-specific: high priority for immediate delivery
      message['android'] = {'priority': 'high'};

      // iOS-specific: content-available for background processing
      message['apns'] = {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'content-available': 1},
        },
      };

      final response = await _httpClient!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final messageId = responseBody['name'] as String?;
        print('[FCM] Sent $messageType to patient $patientId: $messageId');

        await _logNotificationAudit(
          patientId: patientId,
          messageType: messageType,
          status: 'sent',
          messageId: messageId,
          data: data,
        );

        return NotificationResult.success(messageId);
      } else {
        final error = 'FCM API error: ${response.statusCode} ${response.body}';
        print('[FCM] Failed to send $messageType: $error');

        await _logNotificationAudit(
          patientId: patientId,
          messageType: messageType,
          status: 'failed',
          error: error,
          data: data,
        );

        return NotificationResult.failure(error);
      }
    } catch (e) {
      final error = e.toString();
      print('[FCM] Exception sending $messageType: $error');

      await _logNotificationAudit(
        patientId: patientId,
        messageType: messageType,
        status: 'failed',
        error: error,
        data: data,
      );

      return NotificationResult.failure(error);
    }
  }

  /// Log notification to audit table (FDA compliance)
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
      print('[FCM] Failed to log notification audit: $e');
    }
  }
}
