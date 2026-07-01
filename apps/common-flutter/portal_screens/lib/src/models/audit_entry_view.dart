import 'package:flutter/foundation.dart';

/// One row in the Audit Logs table.
///
/// Snapshot value type — built fresh by the wiring layer from the raw `/audit`
/// HTTP response on each fetch/refresh and handed to `AuditLogsScreen`. Owns
/// its own data; no dependency on `event_sourcing` audit envelope types.
@immutable
class AuditEntryView {
  /// Stable identifier for the entry — typically `event_id` from the raw
  /// payload. Used as the [Key] when rendering the row, so an in-place
  /// refresh diffs cleanly.
  final String id;

  /// When the action occurred. Parsed once by the wiring layer from the
  /// row's ISO-8601 string so the screen never re-parses on rebuild.
  final DateTime timestamp;

  /// Human-readable actor name (e.g. "Terry Wilson"). Empty string when the
  /// initiator is automation rather than a person.
  final String actorName;

  /// Actor's active role at the time of the action (e.g. "Admin",
  /// "Administrator"). Drives the small subtitle under [actorName] in the
  /// row. Empty string for non-user initiators.
  final String actorRole;

  /// Actor's email address. Rendered as the small subtitle under [actorName]
  /// in the row so the cell shows the person's name on top and their email
  /// below. Empty string for non-user initiators, or when it would merely
  /// duplicate [actorName] (no display name was resolved).
  final String actorEmail;

  /// One-line activity description, pre-rendered for the row. Examples:
  /// "Created user account for Dr. Emily Parker",
  /// "Activation email sent to Jennifer Martinez".
  final String activityLabel;

  /// The Participant ID this entry pertains to, for the Participant ID column
  /// in the Study Coordinator Audit Log View. Empty string when the entry has
  /// no participant association (e.g. user-account or system events).
  final String participantId;

  /// The full audit JSON record, retained for the row's expanded "details"
  /// view. Kept as an opaque map because the expanded panel currently
  /// renders it via `JsonEncoder.withIndent` — no need to model every
  /// possible audit shape at the UI layer.
  final Map<String, dynamic> raw;

  const AuditEntryView({
    required this.id,
    required this.timestamp,
    required this.actorName,
    required this.actorRole,
    required this.activityLabel,
    this.actorEmail = '',
    this.participantId = '',
    required this.raw,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEntryView &&
          id == other.id &&
          timestamp == other.timestamp &&
          actorName == other.actorName &&
          actorRole == other.actorRole &&
          actorEmail == other.actorEmail &&
          activityLabel == other.activityLabel &&
          participantId == other.participantId &&
          mapEquals(raw, other.raw);

  /// Hashes scalar fields only; the raw payload is excluded because it's
  /// effectively keyed by [id] anyway and recursive map hashing is wasted
  /// work on every row.
  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    actorName,
    actorRole,
    actorEmail,
    activityLabel,
    participantId,
  );

  @override
  String toString() =>
      'AuditEntryView(id: $id, timestamp: $timestamp, '
      'actorName: $actorName, actorRole: $actorRole, '
      'actorEmail: $actorEmail, activityLabel: $activityLabel, '
      'participantId: $participantId)';
}
