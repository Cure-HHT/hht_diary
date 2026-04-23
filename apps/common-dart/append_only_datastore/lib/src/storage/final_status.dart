/// Terminal state of a FifoEntry within its destination's FIFO.
///
/// A FifoEntry's `finalStatus` is nullable: `null` means "not yet
/// terminal" (drain may attempt the row), and a non-null value is one
/// of three terminal states below. Once a FIFO entry's `finalStatus` is
/// non-null it is retained forever as an audit record; the FIFO never
/// deletes it (REQ-d00119-D). The sole code path that deletes a FIFO
/// row is REQ-d00144-C (the `tombstoneAndRefill` trail sweep), and
/// that path only deletes rows whose `finalStatus` is `null`.
// Implements: REQ-d00119-C — final_status is null or one of
// {sent, wedged, tombstoned}.
enum FinalStatus {
  sent,
  wedged,
  tombstoned;

  /// Parse a wire-format string; throws [FormatException] on unknown input.
  factory FinalStatus.fromJson(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    throw FormatException(
      'FinalStatus: unknown value "$raw" '
      '(legal values: sent | wedged | tombstoned)',
    );
  }

  /// Serialize to the wire-format string used in persisted records.
  String toJson() => name;
}
