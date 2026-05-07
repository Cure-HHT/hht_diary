import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';

/// Metadata extracted from a `BatchEnvelope` minus its events list.
/// Persisted on a FIFO row when the row's `wire_format == "esd/batch@1"`,
/// so that drain can reconstruct the wire bytes deterministically by
/// re-encoding `(envelope_metadata + events resolved via findEventById)`.
///
/// The fields are immutable once set — they are part of the FIFO row's
/// identity for retry determinism (REQ-d00119-K).
// Implements: REQ-d00119-K — envelope-metadata value type for native
// FIFO rows; supports retry-deterministic re-encoding at drain time.
class BatchEnvelopeMetadata {
  const BatchEnvelopeMetadata({
    required this.batchFormatVersion,
    required this.batchId,
    required this.senderHop,
    required this.senderIdentifier,
    required this.senderSoftwareVersion,
    required this.sentAt,
  });

  /// Build from a parsed [BatchEnvelope]. Drops the `events` list — the
  /// drain path resolves events via `findEventById` and reattaches them
  /// at encode time.
  // Implements: REQ-d00119-K — extract envelope identity from a parsed
  // BatchEnvelope, dropping the events list.
  factory BatchEnvelopeMetadata.fromEnvelope(BatchEnvelope env) {
    return BatchEnvelopeMetadata(
      batchFormatVersion: env.batchFormatVersion,
      batchId: env.batchId,
      senderHop: env.senderHop,
      senderIdentifier: env.senderIdentifier,
      senderSoftwareVersion: env.senderSoftwareVersion,
      sentAt: env.sentAt,
    );
  }

  // Implements: REQ-d00119-K — restore envelope metadata from a serialized
  // map (sembast row deserialization).
  factory BatchEnvelopeMetadata.fromMap(Map<String, Object?> m) {
    return BatchEnvelopeMetadata(
      batchFormatVersion: m['batch_format_version']! as String,
      batchId: m['batch_id']! as String,
      senderHop: m['sender_hop']! as String,
      senderIdentifier: m['sender_identifier']! as String,
      senderSoftwareVersion: m['sender_software_version']! as String,
      sentAt: DateTime.parse(m['sent_at']! as String),
    );
  }

  final String batchFormatVersion;
  final String batchId;
  final String senderHop;
  final String senderIdentifier;
  final String senderSoftwareVersion;
  final DateTime sentAt;

  /// Reconstruct a full [BatchEnvelope] by attaching events. Used by the
  /// drain path: after `findEventById` resolves each event in `event_ids`,
  /// the events are passed here to rebuild the envelope and `.encode()`
  /// is called to produce wire bytes.
  // Implements: REQ-d00119-K — reattach events for retry-deterministic
  // re-encode at drain time.
  BatchEnvelope toEnvelope(List<Map<String, Object?>> events) {
    return BatchEnvelope(
      batchFormatVersion: batchFormatVersion,
      batchId: batchId,
      senderHop: senderHop,
      senderIdentifier: senderIdentifier,
      senderSoftwareVersion: senderSoftwareVersion,
      sentAt: sentAt,
      events: events,
    );
  }

  // Implements: REQ-d00119-K — serialize envelope metadata for sembast
  // row persistence.
  Map<String, Object?> toMap() => <String, Object?>{
    'batch_format_version': batchFormatVersion,
    'batch_id': batchId,
    'sender_hop': senderHop,
    'sender_identifier': senderIdentifier,
    'sender_software_version': senderSoftwareVersion,
    'sent_at': sentAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchEnvelopeMetadata &&
          batchFormatVersion == other.batchFormatVersion &&
          batchId == other.batchId &&
          senderHop == other.senderHop &&
          senderIdentifier == other.senderIdentifier &&
          senderSoftwareVersion == other.senderSoftwareVersion &&
          sentAt == other.sentAt;

  @override
  int get hashCode => Object.hash(
    batchFormatVersion,
    batchId,
    senderHop,
    senderIdentifier,
    senderSoftwareVersion,
    sentAt,
  );

  @override
  String toString() =>
      'BatchEnvelopeMetadata(batchId: $batchId, '
      'senderHop: $senderHop, sentAt: $sentAt)';
}
