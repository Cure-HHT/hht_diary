// IMPLEMENTS REQUIREMENTS:
//   REQ-d00197: Outbox-Write-Then-Dispatch Sequencing (durable insertPending
//               with idempotent ON CONFLICT DO NOTHING)
//   REQ-d00194: PHI-Safe FCM Payload (rows go through PayloadGuard
//               before reaching the repo via OutboxWriter)
//   REQ-d00195: Mobile Notifications Polling (findSince + markDelivered)
//
// Postgres implementation of `comms.NotificationRepository` for the
// sponsor portal (envelope writer side). Inserts and status updates
// run with `UserContext.service` — the orchestrator owns the row's
// lifecycle. Patient-scoped reads use `UserContext.patient(patientId)`
// so the `notifications_patient_select` RLS policy clamps the result
// set to that patient even if a query forgets the `WHERE patient_id`
// predicate (defense in depth).
//
// JSONB <-> Map<String, dynamic> conversion happens at the boundary —
// payloads are jsonEncoded on insert and jsonDecoded on read so the
// in-memory Envelope is always Dart-native.

import 'dart:convert';

import 'package:comms/comms.dart';

import '../database.dart';

class PgNotificationRepository implements NotificationRepository {
  PgNotificationRepository({Database? database})
    : _db = database ?? Database.instance;

  final Database _db;

  @override
  Future<void> insertPending(Envelope envelope) async {
    // INSERT runs with service_role — the writer is the action handler,
    // not the patient. ON CONFLICT DO NOTHING makes a writer retry
    // after a crash idempotent: if the row already exists at the same
    // id, the second attempt is a no-op rather than a duplicate.
    await _db.executeWithContext(
      '''
      INSERT INTO notifications (
        notification_id,
        patient_id,
        notification_type,
        title,
        body,
        user_visible,
        payload,
        status,
        created_at
      )
      VALUES (
        @notificationId,
        @patientId,
        @notificationType::notification_type,
        @title,
        @body,
        @userVisible,
        @payload::jsonb,
        @status,
        @createdAt
      )
      ON CONFLICT (notification_id) DO NOTHING
      ''',
      parameters: {
        'notificationId': envelope.notificationId,
        'patientId': envelope.participantId,
        'notificationType': envelope.type.wire,
        'title': envelope.title,
        'body': envelope.body,
        'userVisible': envelope.userVisible,
        'payload': jsonEncode(envelope.payload),
        'status': envelope.status.wire,
        'createdAt': envelope.createdAt.toUtc(),
      },
      context: UserContext.service,
    );
  }

  @override
  Future<Envelope?> findById(String id, {required String participantId}) async {
    final result = await _db.executeWithContext(
      '''
      SELECT notification_id, patient_id, notification_type::text,
             title, body, user_visible, payload::text, status,
             message_id, last_error,
             created_at, sent_at, delivered_at
      FROM notifications
      WHERE notification_id = @id AND patient_id = @patientId
      LIMIT 1
      ''',
      parameters: {'id': id, 'patientId': participantId},
      context: UserContext.participant(participantId),
    );
    if (result.isEmpty) return null;
    return _rowToEnvelope(result.first);
  }

  @override
  Future<List<Envelope>> findSince(
    DateTime since, {
    required String participantId,
    required int limit,
  }) async {
    final result = await _db.executeWithContext(
      '''
      SELECT notification_id, patient_id, notification_type::text,
             title, body, user_visible, payload::text, status,
             message_id, last_error,
             created_at, sent_at, delivered_at
      FROM notifications
      WHERE patient_id = @patientId
        AND created_at > @since
      ORDER BY created_at ASC
      LIMIT @limit
      ''',
      parameters: {
        'patientId': participantId,
        'since': since.toUtc(),
        'limit': limit,
      },
      context: UserContext.participant(participantId),
    );
    return result.map(_rowToEnvelope).toList();
  }

  @override
  Future<void> markSent(String id, String messageId) async {
    await _db.executeWithContext(
      '''
      UPDATE notifications
      SET status = 'sent',
          message_id = @messageId,
          sent_at = COALESCE(sent_at, now())
      WHERE notification_id = @id
        AND status = 'pending'
      ''',
      parameters: {'id': id, 'messageId': messageId},
      context: UserContext.service,
    );
  }

  @override
  Future<void> markFailed(String id, String error) async {
    await _db.executeWithContext(
      '''
      UPDATE notifications
      SET status = 'failed',
          last_error = @error
      WHERE notification_id = @id
      ''',
      parameters: {'id': id, 'error': error},
      context: UserContext.service,
    );
  }

  @override
  Future<void> markDeliveredIfNull(
    List<String> ids, {
    required String participantId,
  }) async {
    if (ids.isEmpty) return;
    // Idempotent — only stamps rows where delivered_at IS NULL. A
    // duplicate fetch (mobile racing across two devices, or retry
    // after a transient network blip) does not bump the timestamp.
    await _db.executeWithContext(
      '''
      UPDATE notifications
      SET status = 'delivered',
          delivered_at = now()
      WHERE notification_id = ANY (@ids)
        AND patient_id = @patientId
        AND delivered_at IS NULL
      ''',
      parameters: {'ids': ids, 'patientId': participantId},
      context: UserContext.participant(participantId),
    );
  }

  /// Turn a SELECT row into an [Envelope]. Keeps all SQL-specific
  /// shape mapping in one place — column order is locked to the
  /// SELECT lists above so a column reorder there is caught here.
  Envelope _rowToEnvelope(List<dynamic> row) {
    final payloadText = row[6] as String;
    final payload = jsonDecode(payloadText) as Map<String, dynamic>;
    return Envelope(
      notificationId: row[0] as String,
      participantId: row[1] as String,
      type: NotificationType.fromWire(row[2] as String),
      title: row[3] as String,
      body: row[4] as String?,
      userVisible: row[5] as bool,
      payload: payload,
      status: EnvelopeStatus.fromWire(row[7] as String),
      messageId: row[8] as String?,
      error: row[9] as String?,
      createdAt: (row[10] as DateTime).toUtc(),
      sentAt: row[11] != null ? (row[11] as DateTime).toUtc() : null,
      deliveredAt: row[12] != null ? (row[12] as DateTime).toUtc() : null,
    );
  }
}
