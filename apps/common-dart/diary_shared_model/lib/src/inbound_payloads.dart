// Implements: DIARY-DEV-shared-events-catalog/A+D
//   Refines: DIARY-PRD-mobile-notifications
//
// Typed payload schemas for the two diary-originated inbound/device-routing
// events (`fcm_message_received`, `fcm_token_registered`). Diary-authored into
// the shared model per the established post-freeze split (the diary authors its
// diary-originated payloads; the portal authors the [P] ones). The portal reads
// these for delivery audit + device routing, so they are cross-wire.
//
// The one cross-cutting contract is the ECHOED `flowToken` on
// `fcm_message_received` (surface P5): when the portal minted a flowToken for an
// outgoing intent, the diary echoes it on receipt so the portal can stitch
// `assigned -> delivered -> received` across the non-event-sourced FCM hop.
//
// Per DIARY-DEV-shared-events-catalog/D these payloads carry no OTP / recovery /
// session tokens. The FCM registration token is a device-routing identifier (how
// the push service reaches the device), not an authentication credential.
library;

/// The delivery path an inbound message arrived on.
enum InboundChannel {
  /// Firebase Cloud Messaging push (primary).
  fcm,

  /// Foreground/background polling backup.
  poll;

  static InboundChannel? fromWire(String? value) {
    if (value == null) return null;
    for (final c in InboundChannel.values) {
      if (c.name == value) return c;
    }
    return null;
  }
}

/// Payload for an `fcm_message_received` event — the audit fact that an inbound
/// message of [messageType] arrived via [channel] at [receivedAt], correlated by
/// the echoed [flowToken] when the portal minted one (P5).
class FcmMessageReceivedPayload {
  const FcmMessageReceivedPayload({
    required this.receivedAt,
    required this.channel,
    required this.messageType,
    this.flowToken,
  });

  /// ISO 8601 timestamp of receipt.
  final String receivedAt;

  /// The path the message arrived on (FCM push or polling backup).
  final InboundChannel channel;

  /// The inbound message's `type` (e.g. `tombstone`, `questionnaire_assigned`).
  final String messageType;

  /// The portal-minted correlation token echoed back, when present. Not a secret.
  final String? flowToken;

  factory FcmMessageReceivedPayload.fromJson(Map<String, Object?> json) {
    final channel = InboundChannel.fromWire(json['channel'] as String?);
    if (channel == null) {
      throw FormatException('invalid inbound channel: ${json['channel']}');
    }
    return FcmMessageReceivedPayload(
      receivedAt: json['received_at']! as String,
      channel: channel,
      messageType: json['message_type']! as String,
      flowToken: json['flowToken'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'received_at': receivedAt,
    'channel': channel.name,
    'message_type': messageType,
    if (flowToken != null) 'flowToken': flowToken,
  };
}

/// The device platform an FCM token was minted for.
enum DevicePlatform {
  android,
  ios;

  static DevicePlatform? fromWire(String? value) {
    if (value == null) return null;
    for (final p in DevicePlatform.values) {
      if (p.name == value) return p;
    }
    return null;
  }
}

/// Payload for an `fcm_token_registered` event — the device-routing [token]
/// minted/refreshed for [platform] at [registeredAt].
class FcmTokenRegisteredPayload {
  const FcmTokenRegisteredPayload({
    required this.token,
    required this.platform,
    required this.registeredAt,
  });

  /// The FCM registration token (device-routing identifier, not a credential).
  final String token;

  /// The device platform the token was minted for.
  final DevicePlatform platform;

  /// ISO 8601 timestamp the token was minted/refreshed.
  final String registeredAt;

  factory FcmTokenRegisteredPayload.fromJson(Map<String, Object?> json) {
    final platform = DevicePlatform.fromWire(json['platform'] as String?);
    if (platform == null) {
      throw FormatException('invalid device platform: ${json['platform']}');
    }
    return FcmTokenRegisteredPayload(
      token: json['token']! as String,
      platform: platform,
      registeredAt: json['registered_at']! as String,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'platform': platform.name,
    'registered_at': registeredAt,
  };
}
