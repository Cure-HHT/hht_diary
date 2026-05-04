# PHASE 4.3 TASK 4 — Refactor SyncPolicy to an injectable value object

## Summary

Refactored `SyncPolicy` from a static-only "constants bag" into a value
class with `final` fields, a `const` constructor, and a `static const
SyncPolicy.defaults` instance. Threaded an optional `SyncPolicy? policy`
parameter through `drain()` and `SyncCycle`; when null, both fall back to
`SyncPolicy.defaults`. Migrated every Phase-4 call site that previously
referenced `SyncPolicy.<field>` statically to `SyncPolicy.defaults.<field>`
in one refactoring pass — no `@Deprecated` shims.

Implements: REQ-d00126-A, REQ-d00126-B, REQ-d00126-C. Preserves REQ-d00123
numeric constants exactly (60s / 5.0 / 2h / 0.1 / 20 / 15min).

## REQ-d00126 assertion coverage

- **REQ-d00126-A** — `lib/src/sync/sync_policy.dart`: `SyncPolicy` value
  class with `const` constructor + `static const SyncPolicy defaults`.
- **REQ-d00126-A** — `test/sync/sync_policy_test.dart`: three new
  dedicated tests plus a custom-policy curve sanity-check.
- **REQ-d00126-B** — `lib/src/sync/drain.dart`: `SyncPolicy? policy`
  parameter with `policy ?? SyncPolicy.defaults` fallback.
- **REQ-d00126-B** — `lib/src/sync/sync_cycle.dart`: `SyncPolicy? policy`
  field + constructor param; propagated into `drain()`.
- **REQ-d00126-B** — `test/sync/drain_test.dart`: two new tests
  (injected-policy-honored, null-falls-back-to-defaults).
- **REQ-d00126-B** — `test/sync/sync_cycle_test.dart`: one new test
  verifying `SyncCycle` threads the injected policy through to `drain()`.
- **REQ-d00126-C** — `test/sync/sync_policy_test.dart`: REQ-d00123-A..F
  tests now read `SyncPolicy.defaults.<field>` (no static members survive
  on the class).
- **REQ-d00126-C** — `test/sync/drain_test.dart`: the lone
  `SyncPolicy.maxAttempts` static reference migrated to
  `SyncPolicy.defaults.maxAttempts`.

## TDD sequence

1. Red: rewrote `sync_policy_test.dart` against the value-object shape;
   added three new REQ-d00126-A tests and one custom-policy curve test;
   added two REQ-d00126-B tests in `drain_test.dart` and one in
   `sync_cycle_test.dart`; migrated the lone static call site in
   `drain_test.dart` (`SyncPolicy.maxAttempts - 1`) to
   `SyncPolicy.defaults.maxAttempts - 1`. Ran `flutter test` — compile
   errors on `SyncPolicy.defaults`, `const SyncPolicy(...)` constructor,
   and `SyncCycle(policy: ...)`, exactly as expected.
2. Green: converted `SyncPolicy` to a value class with a `const`
   constructor and a `static const SyncPolicy defaults`; made
   `backoffFor` an instance method; added `SyncPolicy? policy` to `drain`
   and `SyncCycle`; migrated drain's two Phase-4 static call sites to the
   `effective.<field>` form.
3. Verify: `flutter test` all green (305/305); `dart analyze` clean;
   `flutter analyze apps/daily-diary/clinical_diary` clean.

## Test counts

- Baseline (pre-refactor, pre-new-tests): **298 / 298**.
- Final: **305 / 305**. Delta: +7 tests (3 REQ-d00126-A + 1 custom-curve
  sanity + 2 REQ-d00126-B in drain + 1 REQ-d00126-B in sync_cycle).
- No test deletions. The REQ-d00123-A..F tests were rewritten (same
  count, same IDs) to read `SyncPolicy.defaults.<field>` instead of
  `SyncPolicy.<field>`.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found!** (0.9s).

## Files touched

- `apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart`
  — value class, const constructor, `static const SyncPolicy defaults`,
  instance-method `backoffFor`.
- `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart`
  — added `SyncPolicy? policy` parameter; reads `effective.backoffFor` and
  `effective.maxAttempts`.
- `apps/common-dart/append_only_datastore/lib/src/sync/sync_cycle.dart`
  — added `SyncPolicy? policy` constructor param and `_policy` field;
  propagates to `drain()`.
- `apps/common-dart/append_only_datastore/test/sync/sync_policy_test.dart`
  — rewrote REQ-d00123-A..F tests against `SyncPolicy.defaults.<field>`;
  added REQ-d00126-A block and custom-policy curve test.
- `apps/common-dart/append_only_datastore/test/sync/drain_test.dart`
  — migrated static `SyncPolicy.maxAttempts` reference; added two new
  REQ-d00126-B tests.
- `apps/common-dart/append_only_datastore/test/sync/sync_cycle_test.dart`
  — added `SyncPolicy` import; added REQ-d00126-B policy-propagation test.

No external callers of `SyncPolicy.initialBackoff` etc. existed outside
this package — a repo-wide grep confirmed the only call sites were the
ones listed above.
