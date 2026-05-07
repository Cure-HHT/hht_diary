/// Return value from `StorageBackend.appendEvent`, identifying the
/// sequence number that was advanced and the tamper-detection hash stamped
/// on the new event record.
// Implements: REQ-d00117-C — appendEvent co-advances the event log and the
// sequence counter inside the same transaction; callers receive both values
// in this single result.
class AppendResult {
  const AppendResult({required this.sequenceNumber, required this.eventHash});

  /// Decode from a JSON map with snake_case keys. Throws [FormatException]
  /// on missing or wrong-typed fields.
  factory AppendResult.fromJson(Map<String, Object?> json) {
    final seq = json['sequence_number'];
    if (seq is! int) {
      throw const FormatException(
        'AppendResult: missing or non-int "sequence_number"',
      );
    }
    final hash = json['event_hash'];
    if (hash is! String) {
      throw const FormatException(
        'AppendResult: missing or non-string "event_hash"',
      );
    }
    return AppendResult(sequenceNumber: seq, eventHash: hash);
  }

  /// Monotonic counter value stamped on the event (per-device log order).
  final int sequenceNumber;

  /// SHA-256 hex digest over the canonical event contents including
  /// `previous_event_hash`; persisted on the row and returned for callers
  /// that need to reference the hash without re-reading the row.
  final String eventHash;

  /// Encode to snake_case JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'sequence_number': sequenceNumber,
    'event_hash': eventHash,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppendResult &&
          sequenceNumber == other.sequenceNumber &&
          eventHash == other.eventHash;

  @override
  int get hashCode => Object.hash(sequenceNumber, eventHash);

  @override
  String toString() =>
      'AppendResult(sequenceNumber: $sequenceNumber, eventHash: $eventHash)';
}
