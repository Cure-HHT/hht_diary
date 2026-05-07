// IMPLEMENTS REQUIREMENTS:
//   REQ-d00170-B: idempotency.required action with no key supplied is rejected
//   at parse-stage with a typed error before parseInput runs.

/// Thrown by the dispatcher's idempotency precondition check (Stage 4,
/// REQ-d00170-B) when an action declares `Idempotency.required` but the
/// caller did not supply an `idempotencyKey`.
///
/// The dispatcher converts this into a `parse_denied` denial event (same
/// stage as a parse failure). The error's [toString] includes "idempotency"
/// so that tests can match on the message without depending on the exact
/// wording.
class MissingIdempotencyKeyError extends ArgumentError {
  MissingIdempotencyKeyError(String actionName)
    : super(
        'idempotencyKey is required for action "$actionName" but was not supplied.',
      );
}
