// FCM HTTP v1 channel. Builds the per-message payload, runs PayloadGuard,
// POSTs through the AdcClient's authenticated http.Client, and maps
// FCM responses to DispatchResult terminals.

import 'dart:convert';

import 'package:comms/src/channel.dart';
import 'package:comms/src/channels/fcm/adc_client.dart';
import 'package:comms/src/channels/fcm/fcm_message.dart';
import 'package:comms/src/compliance/payload_guard.dart';
import 'package:comms/src/dispatch_result.dart';
import 'package:comms/src/push_channel.dart';
import 'package:http/http.dart' as http;

/// FCM HTTP v1 transport. It is both the legacy `Channel<FcmMessage>` and the
/// transport-neutral [PushChannel] adapter: [send] maps a [PushTarget] /
/// [PushMessage] onto an [FcmMessage] and delegates to [dispatch], so the FCM
/// payload-building + PayloadGuard + response-mapping logic lives in one place.
// Implements: DIARY-DEV-pluggable-push-transport/A — FcmChannel is the FCM
//   adapter of the neutral PushChannel seam.
// Implements: DIARY-DEV-push-payload-phi-safety/B — runs PayloadGuard before network egress
class FcmChannel implements Channel<FcmMessage>, PushChannel {
  FcmChannel({
    required this.projectId,
    AdcClient? adcClient,
    this.consoleMode = false,
    Duration? sendTimeout,
  }) : _adcClient = adcClient ?? AdcClient(),
       _sendTimeout = sendTimeout ?? const Duration(seconds: 10);

  /// Firebase project ID the messages are addressed through.
  /// Multi-sponsor deployments converge on `cure-hht-admin` so a
  /// single Firebase project hosts all FCM tokens.
  final String projectId;

  /// When true, the channel logs the dispatch intent and returns
  /// `DispatchResult.success('console-mode')` without an HTTP call.
  /// Used for local dev without ADC + for the FCM_CONSOLE_MODE env
  /// flag in [the legacy] portal_functions/notification_service.
  final bool consoleMode;

  final AdcClient _adcClient;
  final Duration _sendTimeout;

  @override
  String get name => 'fcm';

  /// [PushChannel] entrypoint. Maps the neutral target/message onto an
  /// [FcmMessage] (the [PushTarget.routingToken] is the FCM registration
  /// token) and delegates to [dispatch].
  @override
  Future<DispatchResult> send(PushTarget target, PushMessage message) {
    return dispatch(
      FcmMessage(
        fcmToken: target.routingToken,
        data: message.data,
        userVisible: message.userVisible,
        notificationTitle: message.title,
        notificationBody: message.body,
      ),
    );
  }

  /// FCM v1 endpoint. Computed lazily from [projectId].
  Uri get _endpoint => Uri.parse(
    'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
  );

  @override
  Future<DispatchResult> dispatch(FcmMessage message) async {
    // Guard runs before any network I/O so a PHI leak fails closed
    // (DIARY-DEV-push-payload-phi-safety). Title/body and every data value are checked.
    if (message.notificationTitle != null) {
      PayloadGuard.assertSafeText(
        message.notificationTitle!,
        fieldName: 'fcmMessage.notificationTitle',
      );
    }
    if (message.notificationBody != null) {
      PayloadGuard.assertSafeText(
        message.notificationBody!,
        fieldName: 'fcmMessage.notificationBody',
      );
    }
    PayloadGuard.assertSafeStringMap(
      message.data,
      fieldPrefix: 'fcmMessage.data',
    );

    if (consoleMode) {
      return const DispatchResult.success('console-mode');
    }

    final client = await _adcClient.getClient();
    final body = jsonEncode({'message': _buildMessagePayload(message)});

    final response = await client
        .post(
          _endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_sendTimeout);

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      // FCM v1 returns the message resource name (e.g.
      // `projects/cure-hht-admin/messages/0:1234567890`). Use it
      // verbatim as the messageId.
      final messageId = responseBody['name'] as String?;
      return DispatchResult.success(messageId ?? '');
    }

    if (_isUnregistered(response)) {
      return const DispatchResult.unregisteredToken();
    }

    return DispatchResult.failure(
      'FCM API error: ${response.statusCode} ${response.body}',
    );
  }

  /// Builds the `message` object for the FCM v1 request body. The
  /// APNS split (priority 10 + alert vs. priority 5 + content-available)
  /// is driven by [FcmMessage.userVisible] — see DIARY-PRD-notification-behavior / S3.3.
  Map<String, dynamic> _buildMessagePayload(FcmMessage message) {
    final payload = <String, dynamic>{
      'token': message.fcmToken,
      'data': message.data,
    };

    if (message.userVisible && message.notificationTitle != null) {
      payload['notification'] = <String, dynamic>{
        'title': message.notificationTitle,
        'body': message.notificationBody ?? '',
      };
    }

    // Android: 'high' for both alert + silent — Android does not have
    // the alert/silent priority distinction iOS imposes; data messages
    // wake the app regardless.
    payload['android'] = const <String, dynamic>{'priority': 'high'};

    // apns-push-type is REQUIRED on iOS 13+. FCM v1 does NOT auto-add
    // it (contrary to older Firebase docs). Without `background` on a
    // silent push, APNs drops the message even though FCM returns 200.
    // Alert pushes get `alert`; silent get `background`. See
    // https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns#Add-headers-to-the-notification-request
    payload['apns'] = message.userVisible
        ? const <String, dynamic>{
            'headers': {'apns-priority': '10', 'apns-push-type': 'alert'},
          }
        : const <String, dynamic>{
            'headers': {'apns-priority': '5', 'apns-push-type': 'background'},
            'payload': {
              'aps': {'content-available': 1},
            },
          };

    return payload;
  }

  /// Returns true when the FCM response signals a permanently dead
  /// token (DIARY-DEV-pluggable-push-transport). The OutboxWriter routes this into
  /// `DispatchResult.unregisteredToken` so the caller can deactivate
  /// the row in `participant_fcm_tokens`.
  bool _isUnregistered(http.Response response) {
    // A 404 from FCM v1 always means the token is not registered.
    // Some 400s also carry an UNREGISTERED errorCode buried under
    // `error.details[].errorCode`; parse the body for that case.
    if (response.statusCode == 404) return true;
    if (response.statusCode == 400) {
      try {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final error = parsed['error'] as Map<String, dynamic>?;
        final details = error?['details'] as List<dynamic>?;
        if (details == null) return false;
        for (final detail in details) {
          if (detail is Map<String, dynamic> &&
              detail['errorCode'] == 'UNREGISTERED') {
            return true;
          }
        }
      } on FormatException {
        // Body wasn't JSON — fall through to non-unregistered.
      }
    }
    return false;
  }

  /// Releases the underlying ADC client. After dispose, the channel
  /// must not be used; create a new instance instead.
  void dispose() {
    _adcClient.dispose();
  }
}
