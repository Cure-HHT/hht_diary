// IMPLEMENTS REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling (Envelope.type vocabulary)
//
// 3-value protocol vocabulary for the notification_type column. The
// fine-grained sub-actions (questionnaire_sent vs. _deleted vs.
// _finalized; disconnect vs. reconnect) live in the per-envelope
// `payload.action` so the enum stays small and database-friendly.

enum NotificationType {
  /// Any questionnaire lifecycle event — sent / deleted / unlocked /
  /// finalized. Sub-action is in `payload.action`.
  questionnaireUpdate('questionnaire_update'),

  /// Participant status transition — disconnect / reconnect /
  /// mark_not_participating / reactivate / start_trial. Sub-action in
  /// `payload.action`.
  participantStatusUpdate('patient_status_update'),

  /// Scheduled, time-based reminder (e.g. yesterday-reminder cron).
  reminder('reminder');

  const NotificationType(this.wire);

  /// Stable string used in the database, JSON, and FCM data payload.
  /// Distinct from `name` (Dart's enum-default camelCase) so a Dart
  /// rename never shifts the wire vocabulary.
  final String wire;

  /// Inverse of [wire]. Throws [FormatException] on unknown input —
  /// callers reading from JSON / DB should wrap with their own
  /// error context.
  static NotificationType fromWire(String wire) {
    for (final type in NotificationType.values) {
      if (type.wire == wire) return type;
    }
    throw FormatException('Unknown notification_type wire value: $wire');
  }
}
