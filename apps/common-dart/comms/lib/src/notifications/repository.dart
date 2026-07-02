// Storage abstraction. The concrete Postgres implementation lives in
// the consuming app (Phase 1B), not in this package — the app owns
// its connection pool, RLS context, and sponsor schema. Tests inject
// in-memory fakes that implement this interface directly.

import 'package:comms/src/notifications/envelope.dart';

// Implements: DIARY-DEV-inbound-event-on-receipt/A — persistence surface for received envelopes
abstract class NotificationRepository {
  /// Insert a freshly-built envelope in `pending` status. Idempotent on
  /// `notification_id` — implementations SHOULD use INSERT ... ON
  /// CONFLICT DO NOTHING so a writer retry after a crash re-uses the
  /// same id without duplicate rows.
  Future<void> insertPending(Envelope envelope);

  /// Fetch a single envelope. The [participantId] argument enforces RLS at
  /// the query level so a leaked id from another participant does not
  /// surface. Returns null when no row exists for the (id, participant)
  /// pair — distinguishes "not found" from "permission denied".
  Future<Envelope?> findById(String id, {required String participantId});

  /// Polled by the mobile app on resume / wake. Returns envelopes
  /// created strictly after [since], scoped to the participant. Implementations
  /// MUST cap the result at [limit] rows even if the participant has more —
  /// the mobile fetches the rest with a fresher [since] cursor.
  Future<List<Envelope>> findSince(
    DateTime since, {
    required String participantId,
    required int limit,
  });

  /// Transition a row from `pending` to `sent`. The [messageId] is the
  /// channel-returned id (e.g. FCM resource name).
  Future<void> markSent(String id, String messageId);

  /// Transition a row to `failed`. The OutboxWriter passes
  /// `'UNREGISTERED'` here when the FCM token is dead so an audit query
  /// can distinguish dead-token cleanups from retryable errors.
  Future<void> markFailed(String id, String error);

  /// Mark each id `delivered` if and only if the row is currently
  /// non-delivered (i.e. the delivered_at column is null). Idempotent
  /// — a duplicate fetch from mobile must not re-stamp the timestamp.
  Future<void> markDeliveredIfNull(
    List<String> ids, {
    required String participantId,
  });
}
