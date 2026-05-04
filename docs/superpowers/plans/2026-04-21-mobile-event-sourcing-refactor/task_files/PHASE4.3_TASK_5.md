# PHASE 4.3 TASK 5 — markFinal & appendAttempt tolerate missing FIFO row / store

## Summary

`SembastBackend.markFinal` and `SembastBackend.appendAttempt` now no-op
(return without throwing) when the target FIFO row is missing or the
destination's FIFO store was never registered. Both methods emit a
warning-level diagnostic via a new visible-for-testing `debugLogSink`
field so the no-op is observable without requiring a global logger.

This closes the drain/unjam + drain/delete race documented in design
§6.6: `drain()` calls `await destination.send(wirePayload)` outside any
storage transaction, and a concurrent user operation
(`unjamDestination`, `deleteDestination`) may remove the target row
before `drain`'s subsequent `markFinal`/`appendAttempt` transaction
runs. Before this change, the second transaction would throw
`StateError` and surface a stack trace for what is the correct outcome
(work done, user asked for the row to be gone).

The one-way transition rule in `markFinal` (pending -> sent|exhausted
only; no re-transition of an already-terminal entry) is orthogonal to
this tolerance and is preserved.

Implements: REQ-d00127-A, REQ-d00127-B, REQ-d00127-C.

## Race diagram (design §6.6)

```text
  drain task                         user op (unjam / deleteDestination)
  ----------                         ------------------------------------
  readFifoHead() -> head row R
  await send(R.wirePayload)   --->   opens txn, deletes R (and maybe the
  (no storage txn held)              whole FIFO store)
  markFinal(R) / appendAttempt(R)
     -- before: StateError (row gone, but drain's work is a correct
        outcome; the row was supposed to disappear)
     -- after:  no-op + warning (REQ-d00127-A/B + C)
```

## REQ-d00127 assertion coverage

- **REQ-d00127-A** — `lib/src/storage/sembast_backend.dart`: `markFinal`
  returns without throwing and invokes `debugLogSink` when
  `records.isEmpty`. In Sembast, a never-written store has zero records,
  so the same branch covers "unknown destination" and "row deleted from a
  known destination" — documented in the method's doc comment.
- **REQ-d00127-A** — `lib/src/storage/storage_backend.dart`: abstract
  method doc comment specifies the no-op + warning contract for any
  conforming backend.
- **REQ-d00127-A** — `test/storage/sembast_backend_fifo_test.dart`: two
  tests — one for missing row in an existing FIFO, one for a
  never-registered FIFO store.
- **REQ-d00127-B** — same three sites, analogous coverage for
  `appendAttempt`.
- **REQ-d00127-C** — `lib/src/storage/sembast_backend.dart`: package-
  private `_defaultLogSink(...)` routes through `dart:developer` at
  `level: 900`; `SembastBackend.debugLogSink` field (`void
  Function(String)?`) defaults to it; `markFinal` / `appendAttempt`
  invoke it with the exact message format specified in the task.
- **REQ-d00127-C** — `test/storage/sembast_backend_fifo_test.dart`:
  three tests — one per method verifying the warning message names the
  method, the entry id, the destination id, and the "drain/unjam"
  expected-race string; one guard test verifying no warning fires on a
  happy-path call.

## TDD sequence

1. **Red**: Replaced the two existing `throwsStateError` tests
   (`appendAttempt throws when entry does not exist`, `markFinal throws
   when entry does not exist`) with four REQ-d00127-A/B tests asserting
   no-op behavior (missing row + missing store × both methods). Added
   three REQ-d00127-C tests exercising `backend.debugLogSink = logs.add`
   to capture the warning text. `flutter test
   test/storage/sembast_backend_fifo_test.dart` failed with compile
   errors on the missing `debugLogSink` setter — expected red.
2. **Green**: In `sembast_backend.dart`: imported `dart:developer`,
   added package-private `_defaultLogSink`, added `debugLogSink` field
   (`void Function(String)? = _defaultLogSink`), replaced both
   `StateError` throws in `records.isEmpty` branches with
   `debugLogSink?.call(...)` + `return`, kept the one-way-transition
   `StateError` intact. Updated doc comments on abstract `markFinal` /
   `appendAttempt` in `storage_backend.dart`.
3. **Verify**: `flutter test` — **310 / 310 green**. `dart analyze` —
   **No issues found!**

## Test counts

- Baseline (pre-task-5): **305 / 305**.
- Final: **310 / 310**. Delta: +5 net.
  - +2 REQ-d00127-A (markFinal missing-row, markFinal missing-store)
  - +2 REQ-d00127-B (appendAttempt missing-row, appendAttempt
    missing-store)
  - +3 REQ-d00127-C (markFinal warning contents, appendAttempt warning
    contents, happy-path silence)
  - -2 existing tests replaced (the two `throwsStateError` tests that
    asserted the old behavior). Same `entryId does not exist` scenarios
    are still exercised — now with no-op + warning assertions instead.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**

## Files touched

- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  — imported `dart:developer`; added `_defaultLogSink`; added
  `debugLogSink` field; replaced `records.isEmpty -> StateError` with
  `debugLogSink?.call(...)` + `return` in `markFinal` and
  `appendAttempt`; expanded method doc comments; preserved one-way
  transition `StateError`.
- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  — expanded doc comments on abstract `appendAttempt` and `markFinal`
  to specify the no-op + warning contract. Signatures unchanged.
- `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`
  — replaced 2 `throwsStateError` tests; added 4 no-op tests
  (REQ-d00127-A×2, REQ-d00127-B×2); added 3 warning-log tests
  (REQ-d00127-C).

No external callers of the old `StateError` throw existed — a repo-wide
grep confirmed only `drain.dart` calls `markFinal` / `appendAttempt` in
production, and the change is strictly more tolerant.
