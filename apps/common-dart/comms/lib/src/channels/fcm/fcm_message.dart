// Channel-specific message for the FCM transport. Carries everything
// FcmChannel needs to build the HTTP v1 API payload — no domain-level
// notification fields (NotificationType, Envelope) are present here so
// the transport stays decoupled from the notifications protocol.

import 'package:comms/src/channel.dart';

/// Payload addressed to a single FCM device token.
///
/// The split between [userVisible] alerts and silent data pushes is
/// driven by the caller, not inferred from [notificationTitle]. iOS
/// treats the two as mutually exclusive (priority 10 + alert vs.
/// priority 5 + content-available); FcmChannel maps `userVisible` to
/// the matching APNS headers/payload (see DIARY-PRD-notification-behavior and the S3.3
/// commit for context).
// Implements: DIARY-DEV-pluggable-push-transport/A — FCM-specific transport message
// Implements: DIARY-DEV-push-payload-phi-safety/A — data field carries opaque ids only
class FcmMessage extends ChannelMessage {
  const FcmMessage({
    required this.fcmToken,
    required this.data,
    required this.userVisible,
    this.notificationTitle,
    this.notificationBody,
  });

  /// Device-specific FCM registration token. One device → one active
  /// token at a time per `participant_fcm_tokens` invariant.
  final String fcmToken;

  /// FCM data payload — string-keyed, string-valued. Mobile
  /// dispatchers route on `data.type` (e.g. `'participant_status_update'`,
  /// `'questionnaire_locked'`). All values are PHI-checked by
  /// `PayloadGuard` before dispatch.
  final Map<String, String> data;

  /// True for alerts shown on the lock screen / banner. False for
  /// silent data-only pushes that wake the app to refresh state
  /// without UI (e.g. `questionnaire_deleted`).
  final bool userVisible;

  /// Lock-screen title; required when [userVisible] is true. MUST NOT
  /// contain PHI — `PayloadGuard` enforces.
  final String? notificationTitle;

  /// Lock-screen body line; optional even when [userVisible] is true
  /// (some platforms render title-only). Same PHI constraints as
  /// [notificationTitle].
  final String? notificationBody;
}
