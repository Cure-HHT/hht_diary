// Test fixture: in-memory implementation of [NotificationRepository].
// Used by outbox_writer_test, envelope_fetch_handler_test, etc. to
// exercise the contract without spinning up Postgres.

import 'package:comms/comms.dart';

class InMemoryNotificationRepository implements NotificationRepository {
  final Map<String, Envelope> envelopes = <String, Envelope>{};

  /// Per-id audit of state transitions for assertion convenience.
  final List<String> transitions = <String>[];

  @override
  Future<void> insertPending(Envelope envelope) async {
    envelopes[envelope.notificationId] = envelope;
    transitions.add('insert:${envelope.notificationId}');
  }

  @override
  Future<Envelope?> findById(String id, {required String participantId}) async {
    final envelope = envelopes[id];
    if (envelope == null || envelope.participantId != participantId) {
      return null;
    }
    return envelope;
  }

  @override
  Future<List<Envelope>> findSince(
    DateTime since, {
    required String participantId,
    required int limit,
  }) async {
    final filtered =
        envelopes.values
            .where(
              (e) =>
                  e.participantId == participantId &&
                  e.createdAt.isAfter(since),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered.take(limit).toList();
  }

  @override
  Future<void> markSent(String id, String messageId) async {
    final existing = envelopes[id];
    if (existing == null) return;
    envelopes[id] = existing.copyWith(
      status: EnvelopeStatus.sent,
      messageId: messageId,
      sentAt: DateTime.now().toUtc(),
    );
    transitions.add('sent:$id');
  }

  @override
  Future<void> markFailed(String id, String error) async {
    final existing = envelopes[id];
    if (existing == null) return;
    envelopes[id] = existing.copyWith(
      status: EnvelopeStatus.failed,
      error: error,
    );
    transitions.add('failed:$id:$error');
  }

  @override
  Future<void> markDeliveredIfNull(
    List<String> ids, {
    required String participantId,
  }) async {
    for (final id in ids) {
      final existing = envelopes[id];
      if (existing == null || existing.participantId != participantId) continue;
      if (existing.deliveredAt != null) continue;
      envelopes[id] = existing.copyWith(
        status: EnvelopeStatus.delivered,
        deliveredAt: DateTime.now().toUtc(),
      );
      transitions.add('delivered:$id');
    }
  }
}

/// Stub channel that records dispatches and returns a configured result.
class FakeFcmChannel implements Channel<FcmMessage> {
  FakeFcmChannel({this.next = const DispatchResult.success('msg-fake')});

  DispatchResult next;
  final List<FcmMessage> dispatches = <FcmMessage>[];

  @override
  String get name => 'fcm';

  @override
  Future<DispatchResult> dispatch(FcmMessage message) async {
    dispatches.add(message);
    return next;
  }
}
