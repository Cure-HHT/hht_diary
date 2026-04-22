/// Summary of one wedged FIFO returned by `StorageBackend.exhaustedFifos()`.
///
/// Used by operator-facing diagnostics to identify which destination's FIFO
/// is blocked and on which entry. The entry remains in its FIFO with
/// `final_status = "exhausted"`; this summary carries the derived fields
/// a UI or log needs to show without replaying the whole FIFO.
// Implements: REQ-d00119-C+D — exhausted wedge is observable without
// scanning the FIFO; the underlying entry is retained as a send-log record.
class ExhaustedFifoSummary {
  const ExhaustedFifoSummary({
    required this.destinationId,
    required this.headEntryId,
    required this.headEventId,
    required this.exhaustedAt,
    required this.lastError,
  });

  /// Decode from snake_case JSON; throws [FormatException] on missing or
  /// wrong-typed fields.
  factory ExhaustedFifoSummary.fromJson(Map<String, Object?> json) {
    final destinationId = json['destination_id'];
    if (destinationId is! String) {
      throw const FormatException(
        'ExhaustedFifoSummary: missing or non-string "destination_id"',
      );
    }
    final headEntryId = json['head_entry_id'];
    if (headEntryId is! String) {
      throw const FormatException(
        'ExhaustedFifoSummary: missing or non-string "head_entry_id"',
      );
    }
    final headEventId = json['head_event_id'];
    if (headEventId is! String) {
      throw const FormatException(
        'ExhaustedFifoSummary: missing or non-string "head_event_id"',
      );
    }
    final exhaustedAtRaw = json['exhausted_at'];
    if (exhaustedAtRaw is! String) {
      throw const FormatException(
        'ExhaustedFifoSummary: missing or non-string "exhausted_at"',
      );
    }
    final lastError = json['last_error'];
    if (lastError is! String) {
      throw const FormatException(
        'ExhaustedFifoSummary: missing or non-string "last_error"',
      );
    }
    return ExhaustedFifoSummary(
      destinationId: destinationId,
      headEntryId: headEntryId,
      headEventId: headEventId,
      exhaustedAt: DateTime.parse(exhaustedAtRaw),
      lastError: lastError,
    );
  }

  /// The destination whose FIFO is wedged.
  final String destinationId;

  /// entry_id of the FIFO head entry whose final_status is exhausted.
  final String headEntryId;

  /// event_id carried by that FIFO head entry.
  final String headEventId;

  /// Timestamp of the attempt that produced the exhausted verdict (the last
  /// entry in the head's `attempts[]` list).
  final DateTime exhaustedAt;

  /// `error_message` from the exhausting attempt; surfaced to operators
  /// directly.
  final String lastError;

  /// Encode to snake_case JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'destination_id': destinationId,
    'head_entry_id': headEntryId,
    'head_event_id': headEventId,
    'exhausted_at': exhaustedAt.toIso8601String(),
    'last_error': lastError,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExhaustedFifoSummary &&
          destinationId == other.destinationId &&
          headEntryId == other.headEntryId &&
          headEventId == other.headEventId &&
          exhaustedAt == other.exhaustedAt &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
    destinationId,
    headEntryId,
    headEventId,
    exhaustedAt,
    lastError,
  );

  @override
  String toString() =>
      'ExhaustedFifoSummary(destinationId: $destinationId, '
      'headEntryId: $headEntryId, headEventId: $headEventId, '
      'exhaustedAt: ${exhaustedAt.toIso8601String()}, '
      'lastError: $lastError)';
}
