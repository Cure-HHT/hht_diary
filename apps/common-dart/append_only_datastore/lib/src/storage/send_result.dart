/// Categorized outcome of a single `destination.send()` call.
///
/// The drain loop switches on the three subclasses:
/// - [SendOk]: the payload was delivered; mark the FIFO head `sent` and
///   continue draining.
/// - [SendTransient]: retry later per SyncPolicy; `httpStatus` optional
///   because not every destination is HTTP-based.
/// - [SendPermanent]: the payload will never be accepted as-is; mark the
///   FIFO head `exhausted` and wedge this destination's FIFO.
///
/// The translation from a raw HTTP or IO response to a [SendResult] is a
/// per-destination judgment — default categorization is `2xx -> SendOk`,
/// `5xx/network -> SendTransient`, `4xx -> SendPermanent`, with
/// destination-level carve-outs possible (see design doc §8.1, §11.1).
// Implements: REQ-p01001-L — three-category send outcome classification
// so the drain loop can make retry vs. wedge decisions without destination-
// specific knowledge.
sealed class SendResult {
  const SendResult();
}

/// The destination accepted the payload.
class SendOk extends SendResult {
  const SendOk();

  @override
  bool operator ==(Object other) => other is SendOk;

  @override
  int get hashCode => (SendOk).hashCode;

  @override
  String toString() => 'SendOk()';
}

/// The destination is temporarily unable to accept the payload. The drain
/// loop SHALL retry after a backoff per SyncPolicy.
class SendTransient extends SendResult {
  const SendTransient({required this.error, this.httpStatus});

  /// Operator-readable error string.
  final String error;

  /// HTTP status code, when the destination is HTTP-based; null otherwise.
  final int? httpStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SendTransient &&
          error == other.error &&
          httpStatus == other.httpStatus;

  @override
  int get hashCode => Object.hash(SendTransient, error, httpStatus);

  @override
  String toString() => 'SendTransient(error: $error, httpStatus: $httpStatus)';
}

/// The destination will not accept the payload, and retry would not change
/// that. The drain loop SHALL mark the FIFO head `exhausted` and stop
/// draining this destination until operator action (REQ-d00119-C).
class SendPermanent extends SendResult {
  const SendPermanent({required this.error});

  /// Operator-readable error string.
  final String error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SendPermanent && error == other.error;

  @override
  int get hashCode => Object.hash(SendPermanent, error);

  @override
  String toString() => 'SendPermanent(error: $error)';
}
