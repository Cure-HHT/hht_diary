// Implements: DIARY-DEV-pluggable-push-transport/A — local-stack adapter of the
//   neutral PushChannel seam (selected by PUSH_MODE=local).
// Implements: DIARY-DEV-pluggable-push-transport/C — routes by participantId to
//   the participant's live diary WS via [LocalPushRegistry]; an absent
//   connection is a recorded dispatch failure, never a thrown crash.
import 'package:comms/comms.dart';

import 'local_push_registry.dart';

/// [PushChannel] that delivers over the diary's live local-push WebSocket
/// instead of FCM. Used on the local-stack so the EVS portal can drive
/// real-time push to a web/Linux diary with no emulator and no live FCM.
///
/// The frame shape mirrors what FCM data messages carry, so the device's
/// receipt path is identical: `{'type': 'push', 'data': {...}}` where `data`
/// is the same string/string payload (`type`, `flowToken`) the FCM path uses.
class LocalSocketPushChannel implements PushChannel {
  LocalSocketPushChannel(this._registry);

  final LocalPushRegistry _registry;

  @override
  String get name => 'local';

  @override
  Future<DispatchResult> send(PushTarget target, PushMessage message) async {
    // Run the same PHI guard the FCM transport runs before egress, so the
    // local path can never become a quieter way to leak PHI off-device.
    if (message.title != null) {
      PayloadGuard.assertSafeText(message.title!, fieldName: 'push.title');
    }
    if (message.body != null) {
      PayloadGuard.assertSafeText(message.body!, fieldName: 'push.body');
    }
    PayloadGuard.assertSafeStringMap(message.data, fieldPrefix: 'push.data');

    final frame = <String, dynamic>{
      'type': 'push',
      'userVisible': message.userVisible,
      if (message.title != null) 'title': message.title,
      if (message.body != null) 'body': message.body,
      'data': message.data,
    };

    final delivered = _registry.deliver(target.participantId, frame);
    if (delivered == 0) {
      // No live diary connection — analogous to FCM's no-active-token. The
      // reactor records this as notification_dispatch_failed; it never throws.
      return const DispatchResult.failure('no_live_connection');
    }
    return DispatchResult.success('local:$delivered');
  }
}
