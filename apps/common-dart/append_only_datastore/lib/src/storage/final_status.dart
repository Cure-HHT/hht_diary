/// Terminal state of a FifoEntry within its destination's FIFO.
///
/// Transitions are one-way: a `pending` entry moves to `sent` on successful
/// delivery or to `exhausted` after repeated failure. Once an entry is
/// non-`pending` it is retained forever as a send-log record; the FIFO never
/// deletes it (REQ-d00119-D).
// Implements: REQ-d00119-C — exactly three legal values: pending | sent |
// exhausted. No other values are legal.
enum FinalStatus {
  pending,
  sent,
  exhausted;

  /// Parse a wire-format string; throws [FormatException] on unknown input.
  factory FinalStatus.fromJson(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    throw FormatException(
      'FinalStatus: unknown value "$raw" '
      '(legal values: pending | sent | exhausted)',
    );
  }

  /// Serialize to the wire-format string used in persisted records.
  String toJson() => name;
}
