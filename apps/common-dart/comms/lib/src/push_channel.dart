// Implements: DIARY-DEV-pluggable-push-transport/A — transport-neutral send
//   seam. The dispatch reactor depends on [PushChannel], not on any wire type;
//   FcmChannel is one adapter and LocalSocketPushChannel is another.
//
// Transport-neutral push contract. A push is "wake/notify this participant's
// device", addressed by a [PushTarget] (who + which device-routing identifier)
// carrying a [PushMessage] (what). The literal wire — FCM HTTP v1, a local WS
// frame, email later — lives entirely behind a [PushChannel] impl. Callers
// (the NotificationDispatchReactor) construct the neutral target/message and
// never know which transport carried it.

import 'package:comms/src/dispatch_result.dart';

/// Who to push to. The [routingToken] is "a device-routing identifier, not a
/// credential": for FCM it is the registration token; for the local-socket
/// transport it is the device id the client registered over its WS. The
/// transport decides whether it routes on [participantId] (look up the live
/// connection) or [routingToken] (address the device directly).
class PushTarget {
  const PushTarget({
    required this.participantId,
    required this.platform,
    required this.routingToken,
  });

  /// The recipient participant. Local transports route on this to find the
  /// participant's live device connection.
  final String participantId;

  /// Device platform tag from the `participant_fcm_tokens` row
  /// (`android` / `ios` / `linux` / `web`).
  final String platform;

  /// Opaque device-routing identifier (FCM token, or a local device id).
  final String routingToken;
}

/// What to push — the transport-neutral counterpart of `FcmMessage`. [data] is
/// the string/string payload the device dispatches on (`data['type']`,
/// `data['flowToken']`). [userVisible] selects an alert (with [title]/[body])
/// vs. a silent wake; transports map it to their own priority semantics.
class PushMessage {
  const PushMessage({
    required this.data,
    required this.userVisible,
    this.title,
    this.body,
  });

  /// String-keyed, string-valued data payload. PHI-checked by `PayloadGuard`
  /// inside the transport before any egress.
  final Map<String, String> data;

  /// True for a lock-screen/banner alert; false for a silent data-only wake.
  final bool userVisible;

  /// Alert title; present only when [userVisible] is true. MUST NOT carry PHI.
  final String? title;

  /// Optional alert body line. Same PHI constraints as [title].
  final String? body;
}

/// Transport-neutral push channel. Implementations own auth, network, and the
/// channel-specific wire shape, and MUST run `PayloadGuard` before any egress.
// Implements: DIARY-DEV-pluggable-push-transport/A
abstract class PushChannel {
  /// Stable identifier used in metric tags and logs (e.g. `'fcm'`, `'local'`).
  String get name;

  /// Deliver [message] to [target]. Returns a [DispatchResult] terminal; a
  /// transport that cannot reach the device returns `failure(...)` (never
  /// throws for an absent recipient) so the reactor records an audit event
  /// rather than crashing.
  Future<DispatchResult> send(PushTarget target, PushMessage message);
}
