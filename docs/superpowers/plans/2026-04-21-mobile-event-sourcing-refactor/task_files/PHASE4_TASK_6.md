# PHASE 4 TASK 6 — SyncPolicy

## What landed

`SyncPolicy` — compile-time constants plus `backoffFor(attemptCount, {Random? random})`.

Constants (REQ-d00123-A..F):

- `initialBackoff`: 60 seconds
- `backoffMultiplier`: 5.0
- `maxBackoff`: 2 hours
- `jitterFraction`: 0.1
- `maxAttempts`: 20
- `periodicInterval`: 15 minutes

`backoffFor(attemptCount)` formula:

    baseline = min(initialBackoff * backoffMultiplier^attemptCount, maxBackoff)
    jitter   = uniform(-jitterFraction, +jitterFraction)
    backoff  = baseline * (1 + jitter)

Design notes:

- Jitter is applied *after* the cap, so `backoffFor(3+)` lands at ~2h ± 12min. If jitter were applied before the cap, a large attemptCount could produce values *below* the intended cap via the negative-jitter branch, misleadingly suggesting we've reset the retry cadence.
- The optional `random` parameter gives tests deterministic jitter. Production calls pass `null` and pick up a process-wide default `Random`. A `Random?` parameter was chosen over a constructor-injected policy class because `SyncPolicy` is stateless and has no runtime configuration.
- Negative `attemptCount` is a caller bug; rejected with `ArgumentError` rather than producing a near-zero degenerate backoff.

## Tests (16)

- 6 constants tests (one per assertion A..F)
- `backoffFor(0) ≈ 60s ± 10%`
- `backoffFor(1) ≈ 300s (60*5) ± 10%`
- `backoffFor(2) ≈ 1500s (60*5*5) ± 10%`
- `backoffFor(3) ≈ capped at 7200s (2h) ± 10%`
- `backoffFor(n)` stays at cap for large n (3, 5, 10, 19, 20)
- Same seed produces the same jitter (determinism)
- Jitter is actually applied (non-trivially varies across 200 seeds)
- Jitter stays within `±jitterFraction` across 500 seeds
- `backoffFor` without a seed returns a value in the jitter range
- `backoffFor` rejects negative attemptCount

## Verification

- `flutter test test/sync/sync_policy_test.dart`: 16 passed.
- `flutter analyze`: No issues found.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart` (new, 75 lines)
- `apps/common-dart/append_only_datastore/test/sync/sync_policy_test.dart` (new, 16 tests)
