// Persist-then-dispatch helper. One method, one sequence:
//
//   1. PayloadGuard (envelope-level — title, body, serialized payload)
//   2. repo.insertPending — durable record before any network egress;
//      a crash mid-flight leaves a `pending` row that operators can
//      reconcile in Phase 2.
//   3. channel.dispatch (FcmChannel re-runs PayloadGuard at the
//      message level, then POSTs)
//   4. repo.markSent / markFailed — closes the row out
//   5. onUnregistered — fires only for dead-token terminal so the app
//      can deactivate the row in `participant_fcm_tokens`.

import 'dart:convert';

import 'package:comms/src/channel.dart';
import 'package:comms/src/channels/fcm/fcm_message.dart';
import 'package:comms/src/compliance/payload_guard.dart';
import 'package:comms/src/notifications/envelope.dart';
import 'package:comms/src/notifications/repository.dart';

/// Coordinator between the persisted envelope, the FCM transport, and
/// the optional dead-token callback. One instance per (repo, channel)
/// pair — typically wired at server startup.
// Implements: DIARY-DEV-pluggable-push-transport/A — single egress site; UNREGISTERED triggers token deactivation
// Implements: DIARY-DEV-push-payload-phi-safety/B — guard runs before persistence
// Implements: DIARY-DEV-inbound-event-on-receipt/A — transitions envelope state machine
class OutboxWriter {
  OutboxWriter({
    required this.repo,
    required this.channel,
    this.onUnregistered,
  });

  final NotificationRepository repo;

  /// Today the only channel; sibling writers (EmailOutboxWriter,
  /// SlackOutboxWriter) will land in Phase 3. Keeping the field
  /// channel-typed (vs. generic) means the writer can construct a
  /// `FcmMessage` from the envelope without a per-channel adapter.
  final Channel<FcmMessage> channel;

  /// Optional callback invoked when the channel terminates with
  /// UNREGISTERED. Apps wire this to deactivate the matching row in
  /// `participant_fcm_tokens` so subsequent sends do not re-target the
  /// dead token.
  final Future<void> Function(String fcmToken)? onUnregistered;

  /// Persist + dispatch + close out [envelope]. Returns the persisted
  /// `notification_id` regardless of dispatch outcome — failures are
  /// captured in the row's `status`/`error` columns so the caller can
  /// surface them without a thrown exception interrupting the audit
  /// trail.
  Future<String> send(Envelope envelope, {required String fcmToken}) async {
    // PHI guard at the envelope level — runs before any persistence so
    // a tripped guard never leaves a pending row behind.
    PayloadGuard.assertSafeText(envelope.title, fieldName: 'envelope.title');
    if (envelope.body != null) {
      PayloadGuard.assertSafeText(envelope.body!, fieldName: 'envelope.body');
    }
    PayloadGuard.assertSafeText(
      jsonEncode(envelope.payload),
      fieldName: 'envelope.payload',
    );

    await repo.insertPending(envelope);

    final message = _toFcmMessage(envelope, fcmToken);
    final result = await channel.dispatch(message);

    if (result.unregistered) {
      await repo.markFailed(envelope.notificationId, 'UNREGISTERED');
      final cb = onUnregistered;
      if (cb != null) {
        await cb(fcmToken);
      }
    } else if (result.success) {
      await repo.markSent(envelope.notificationId, result.messageId ?? '');
    } else {
      await repo.markFailed(envelope.notificationId, result.error ?? 'unknown');
    }

    return envelope.notificationId;
  }

  /// Convert an [Envelope] into the FCM-specific message shape.
  /// Silent envelopes (`userVisible == false`) drop the title/body so
  /// FcmChannel emits a priority-5 + content-available payload.
  FcmMessage _toFcmMessage(Envelope envelope, String fcmToken) {
    final data = <String, String>{
      'type': envelope.type.wire,
      'notification_id': envelope.notificationId,
      // Domain payload values flatten to strings — FCM data values must
      // be strings on the wire.
      for (final entry in envelope.payload.entries)
        entry.key: entry.value.toString(),
    };
    return FcmMessage(
      fcmToken: fcmToken,
      data: data,
      userVisible: envelope.userVisible,
      notificationTitle: envelope.userVisible ? envelope.title : null,
      notificationBody: envelope.userVisible ? envelope.body : null,
    );
  }
}
