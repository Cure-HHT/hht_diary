// Universal transport contract. Each communication channel (FCM today;
// email and Slack in Phase 3) implements [Channel] with a
// channel-specific [ChannelMessage] subtype. Consumers depend on the
// abstraction; the per-channel impl handles auth, network calls, and
// channel-specific payload shape.

import 'package:comms/src/dispatch_result.dart';

/// Marker base for messages carried by a [Channel]. Channel-specific
/// fields (e.g. `fcmToken`, `userVisible`) live on the subclass.
abstract class ChannelMessage {
  const ChannelMessage();
}

/// Synchronous-looking dispatch contract. Implementations may be async;
/// callers always await the [DispatchResult].
// Implements: DIARY-DEV-pluggable-push-transport/A — pluggable transport contract
abstract class Channel<T extends ChannelMessage> {
  /// Stable identifier used in metric tags and logs (e.g. `'fcm'`).
  String get name;

  /// Send [message]. Implementations MUST run `PayloadGuard` before any
  /// network I/O so a PHI leak fails closed instead of being mailed.
  Future<DispatchResult> dispatch(T message);
}
