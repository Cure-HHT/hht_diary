// IMPLEMENTS REQUIREMENTS:
//   REQ-d00170 (REQ-IDEMPOT): Idempotency policy enum + cache entry
//   value type used by IdempotencyStore implementations.

/// Per-action declaration of how the dispatcher treats `idempotencyKey`.
///
/// - [none]: caller MUST NOT pass a key; if they do, it is ignored.
/// - [optional]: caller MAY pass a key; without one, no replay protection.
/// - [required]: caller MUST pass a key; absence is a parse-stage denial.
//
// Implements: REQ-d00170-A,B,C — three policies; dispatcher behavior per
// each documented in REQ-d00168 (DISPATCH) and IdempotencyStore tests.
enum Idempotency { none, optional, required }

/// A cached dispatch outcome stored in the `IdempotencyStore`.
//
// Implements: REQ-d00170-D — `resultJson` is the prior result; lookup hit
// returns this verbatim. `emittedEventIds` is the audit-trail link to the
// events written by the original dispatch.
class IdempotencyEntry {
  const IdempotencyEntry({
    required this.resultJson,
    required this.emittedEventIds,
    required this.recordedAt,
    required this.expiresAt,
  });

  final Map<String, dynamic> resultJson;
  final List<String> emittedEventIds;
  final DateTime recordedAt;
  final DateTime expiresAt;

  bool isExpired({required DateTime now}) => !expiresAt.isAfter(now);
}

/// Default TTL for idempotency cache entries when an action does not
/// override.
//
// Implements: REQ-d00170-F — 24 hours unless the action specifies
// otherwise via its `idempotencyTtl` getter.
const Duration defaultIdempotencyTtl = Duration(hours: 24);
