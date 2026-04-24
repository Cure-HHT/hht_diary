/// One historical send attempt for a FifoEntry.
///
/// Attempts accumulate on the entry across the drain loop's retries; they
/// are never dropped. `outcome` is a wire-format string discriminator —
/// `"ok"`, `"transient"`, or `"permanent"` — matching the three variants of
/// SendResult. It is deliberately a string rather than an enum at this
/// layer so that a destination's judgment on response categorization can
/// evolve without ABI pressure on this persisted record.
// Implements: REQ-d00119-B — attempts[] entries carry attempted_at,
// outcome, error_message, http_status. Persisted permanently on the
// FifoEntry (REQ-d00119-D).
class AttemptResult {
  const AttemptResult({
    required this.attemptedAt,
    required this.outcome,
    this.errorMessage,
    this.httpStatus,
  });

  /// Decode from snake_case JSON; throws [FormatException] on missing
  /// required or wrong-typed fields.
  factory AttemptResult.fromJson(Map<String, Object?> json) {
    final attemptedAtRaw = json['attempted_at'];
    if (attemptedAtRaw is! String) {
      throw const FormatException(
        'AttemptResult: missing or non-string "attempted_at"',
      );
    }
    final outcome = json['outcome'];
    if (outcome is! String) {
      throw const FormatException(
        'AttemptResult: missing or non-string "outcome"',
      );
    }
    final errorMessage = json['error_message'];
    if (errorMessage != null && errorMessage is! String) {
      throw const FormatException(
        'AttemptResult: "error_message" must be a String when present',
      );
    }
    final httpStatus = json['http_status'];
    if (httpStatus != null && httpStatus is! int) {
      throw const FormatException(
        'AttemptResult: "http_status" must be an int when present',
      );
    }
    return AttemptResult(
      attemptedAt: DateTime.parse(attemptedAtRaw),
      outcome: outcome,
      errorMessage: errorMessage as String?,
      httpStatus: httpStatus as int?,
    );
  }

  /// UTC instant (or timezone-offset-explicit) at which the drain loop ran
  /// `destination.send()` for the head entry.
  final DateTime attemptedAt;

  /// `"ok"` | `"transient"` | `"permanent"` — matches SendResult variants.
  final String outcome;

  /// Human-readable error string from the destination; null on `outcome="ok"`.
  final String? errorMessage;

  /// HTTP status code when the destination is HTTP-based; null otherwise
  /// (e.g., network failure before a response was received).
  final int? httpStatus;

  /// Encode to snake_case JSON. Optional fields are emitted with explicit
  /// null so the wire contract distinguishes absent-because-null from
  /// absent-because-missing.
  Map<String, Object?> toJson() => <String, Object?>{
    'attempted_at': attemptedAt.toIso8601String(),
    'outcome': outcome,
    'error_message': errorMessage,
    'http_status': httpStatus,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptResult &&
          attemptedAt == other.attemptedAt &&
          outcome == other.outcome &&
          errorMessage == other.errorMessage &&
          httpStatus == other.httpStatus;

  @override
  int get hashCode =>
      Object.hash(attemptedAt, outcome, errorMessage, httpStatus);

  @override
  String toString() =>
      'AttemptResult(attemptedAt: ${attemptedAt.toIso8601String()}, '
      'outcome: $outcome, errorMessage: $errorMessage, '
      'httpStatus: $httpStatus)';
}
