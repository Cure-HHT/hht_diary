// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// FCM notification service for receiving push notifications on mobile.
// Handles token management, permission requests, and message routing.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level background message handler (must be a top-level function).
/// Called when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Message received: ${message.messageId}');
  debugPrint('[FCM Background] Data: ${message.data}');
  // Background messages are handled when the app is opened via
  // getInitialMessage() or onMessageOpenedApp stream.
  // Task creation happens in the foreground handler or on app resume.
}

/// Callback type for when FCM data messages are received
typedef OnFcmDataMessage = void Function(Map<String, dynamic> data);

/// FCM notification service for the mobile app.
///
/// Handles:
/// - Permission requests (iOS requires explicit permission)
/// - FCM token retrieval and refresh
/// - Foreground/background message handling
/// - Deep-linking from notification taps
class MobileNotificationService {
  MobileNotificationService({required this.onDataMessage, this.onTokenRefresh});

  /// Callback when a data message is received (foreground or background resume)
  final OnFcmDataMessage onDataMessage;

  /// Callback when the FCM token is refreshed
  final ValueChanged<String>? onTokenRefresh;

  late final FirebaseMessaging _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  String? _currentToken;

  /// Current FCM token (null if not yet retrieved)
  String? get currentToken => _currentToken;

  /// Initialize the notification service.
  ///
  /// Call this after Firebase.initializeApp() in main.dart.
  Future<void> initialize() async {
    _messaging = FirebaseMessaging.instance;

    // Set up background handler (must be done before any other FCM calls)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (iOS requires explicit consent)
    await _requestPermission();

    // Get the initial FCM token
    await _getToken();

    // Listen for token refreshes
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      debugPrint('[FCM] Token refreshed');
      _currentToken = token;
      onTokenRefresh?.call(token);
    });

    // Handle foreground messages
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Handle notification taps that opened the app from background
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
    );

    // Check if the app was opened from a terminated state via notification tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App opened from terminated state via notification');
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Request notification permissions.
  ///
  /// On iOS, this shows a system dialog asking the user for permission.
  /// On Android 13+, this requests POST_NOTIFICATIONS permission.
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission();

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] User denied notification permissions');
    }
  }

  /// Get the FCM registration token.
  Future<void> _getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        debugPrint('[FCM] Token: ${_currentToken!.substring(0, 20)}...');
        onTokenRefresh?.call(_currentToken!);
      } else {
        debugPrint('[FCM] No token available');
      }
    } catch (e, stack) {
      debugPrint('[FCM] Error getting token: $e');
      debugPrint('[FCM] Stack: $stack');
    }
  }

  /// Handle a message received while the app is in the foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Message: ${message.messageId}');
    debugPrint('[FCM Foreground] Data: ${message.data}');

    if (message.data.isNotEmpty) {
      onDataMessage(message.data);
    }
  }

  /// Handle a notification tap that opened the app from background.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM Opened] Message: ${message.messageId}');
    debugPrint('[FCM Opened] Data: ${message.data}');

    if (message.data.isNotEmpty) {
      onDataMessage(message.data);
    }
  }

  /// Clean up subscriptions.
  void dispose() {
    _foregroundSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}
