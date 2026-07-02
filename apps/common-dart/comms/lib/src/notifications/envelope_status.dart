// State machine for a single envelope:
//
//   pending ──insertPending──> sent ──delivered──> delivered
//                ╲
//                 ╲──markFailed──> failed
//
// `delivered` is reached when the mobile app fetches the envelope by
// id (fetchById marks it delivered server-side). `failed` is terminal
// from the server's perspective — an UNREGISTERED token cleanup or a
// retryable error both land here.

// Implements: DIARY-DEV-inbound-event-on-receipt/A — delivered stamped on first receipt
enum EnvelopeStatus {
  pending('pending'),
  sent('sent'),
  delivered('delivered'),
  failed('failed');

  const EnvelopeStatus(this.wire);

  /// Stable string used in the database and JSON.
  final String wire;

  /// Inverse of [wire]. Throws [FormatException] on unknown input.
  static EnvelopeStatus fromWire(String wire) {
    for (final status in EnvelopeStatus.values) {
      if (status.wire == wire) return status;
    }
    throw FormatException('Unknown envelope status wire value: $wire');
  }
}
