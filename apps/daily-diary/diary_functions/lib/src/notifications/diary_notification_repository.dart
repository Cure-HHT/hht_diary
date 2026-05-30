// IMPLEMENTS REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling (read-side handlers + delivery stamping)
//
// Diary-side `comms.NotificationRepository` impl. Used by the
// `envelopeFetchHandler` and `envelopeSinceHandler` factories that
// the diary_server mounts under /api/v1/notifications. Read-only —
// the writer-side methods (insertPending, markSent, markFailed) are
// owned by portal_functions and throw if invoked here.
//
// RLS note: diary_functions's `Database` does not currently set the
// `app.current_patient_id` session variable, so the patient-scoping
// RLS policies cannot rely on it through this connection. Defense in
// depth still works because:
//   * every query in this repo includes an explicit
//     `WHERE patient_id = @patientId` predicate
//   * the patientResolver upstream of the handler factories has
//     already mapped the JWT to a single patient_id
//   * the `notifications_service_all` policy lets the diary
//     connection (which authenticates as a service-grade role on the
//     diary side) read freely — RLS is a backstop for the portal
//     side, not the only line of defence here
//
// If/when diary's Database grows UserContext-style support, this
// repo can be tightened to the same RLS shape as
// PgNotificationRepository in portal_functions.

import 'dart:convert';

import 'package:comms/comms.dart';

import '../database.dart';

class DiaryNotificationRepository implements NotificationRepository {
  DiaryNotificationRepository({Database? database})
    : _db = database ?? Database.instance;

  final Database _db;

  @override
  Future<void> insertPending(Envelope envelope) {
    throw UnsupportedError(
      'DiaryNotificationRepository is read-only. Envelope writes happen on '
      'the portal side via PgNotificationRepository (REQ-d00197).',
    );
  }

  @override
  Future<void> markSent(String id, String messageId) {
    throw UnsupportedError(
      'DiaryNotificationRepository is read-only. markSent runs on portal side.',
    );
  }

  @override
  Future<void> markFailed(String id, String error) {
    throw UnsupportedError(
      'DiaryNotificationRepository is read-only. markFailed runs on portal side.',
    );
  }

  @override
  Future<Envelope?> findById(String id, {required String participantId}) async {
    final result = await _db.execute(
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
      table: 'notifications',
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
    final result = await _db.execute(
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
      table: 'notifications',
    );
    return result.map(_rowToEnvelope).toList();
  }

  @override
  Future<void> markDeliveredIfNull(
    List<String> ids, {
    required String participantId,
  }) async {
    if (ids.isEmpty) return;
    // Idempotent — only stamps rows where delivered_at IS NULL. A
    // duplicate fetch from the same or another device cannot bump
    // the timestamp.
    await _db.execute(
      '''
      UPDATE notifications
      SET status = 'delivered',
          delivered_at = now()
      WHERE notification_id = ANY (@ids)
        AND patient_id = @patientId
        AND delivered_at IS NULL
      ''',
      parameters: {'ids': ids, 'patientId': participantId},
      table: 'notifications',
    );
  }

  /// Turn a SELECT row into an [Envelope]. Column order locked to the
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
