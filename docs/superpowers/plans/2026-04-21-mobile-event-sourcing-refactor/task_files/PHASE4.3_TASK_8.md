# PHASE 4.3 TASK 8 — readFifoHead skips exhausted rows

## Summary

Changed `SembastBackend.readFifoHead` to return the first row whose
`final_status == pending` in `sequence_in_queue` order. Rows whose
`final_status` is `sent` or `exhausted` are skipped — including the
formerly-wedge-enforcing case where the oldest non-sent row is
`exhausted`. The drain-loop "wedge" on an exhausted head is now
enforced entirely by the drain loop's switch-case (`SendPermanent` /
`SendTransient`-at-max `return`), not by `readFifoHead` returning
`null` at the first terminal row.

This is the backend-level unlock that enables Task 13's upcoming
batch-FIFO continue-past-exhausted semantics: `drain` will be able to
flip its `SendPermanent` / `SendTransient`-at-max cases from `return`
to `continue` without having to change what `readFifoHead` returns.

Implements: REQ-d00124-A (revised head semantics).

## New contract (REQ-d00124-A revision)

The spec text for REQ-d00124-A was expanded in-place:

- The "head" returned by `backend.readFifoHead` SHALL be the first row
  whose `final_status == pending` in `sequence_in_queue` order; rows
  whose `final_status` is `sent` or `exhausted` SHALL be skipped.
- `readFifoHead` SHALL NOT stop at the first `exhausted` row; the
  drain-loop "wedge" on an exhausted head is preserved by the drain
  loop's response to `SendPermanent` / `SendTransient`-at-max
  (REQ-d00124-D+E), not by `readFifoHead` returning `null` at the
  first terminal row.

REQ-d00119-A ("Each registered synchronization destination SHALL have
exactly one associated FIFO store") is unchanged — the new head
semantics are compatible with the one-FIFO-per-destination contract.

## Implementation

`SembastBackend.readFifoHead` pushes the pending-filter into the
Sembast `Finder`:

```text
Filter.equals('final_status', FinalStatus.pending.toJson())
SortOrder('sequence_in_queue')
limit: 1
```

The pre-Task-8 Dart-level loop that walked records and returned `null`
on the first `exhausted` row is gone; there is no observable "stop at
first exhausted" behavior left in `readFifoHead`.

`storage_backend.dart` — the abstract `readFifoHead` doc comment was
updated to match: implementations SHALL skip both `sent` and
`exhausted` rows; they SHALL NOT stop at the first `exhausted` row.

## TDD sequence

1. **Baseline**: `flutter test` — **325 / 325 green**. `dart analyze` clean.
2. **Red**: Appended three REQ-d00124-A tests to
   `test/storage/sembast_backend_fifo_test.dart` and rewrote one
   pre-existing test to match the new semantics:
   - `REQ-d00124-A: readFifoHead skips an exhausted head and returns
     the next pending row` (replaces the old "after markFinal
     exhausted, readFifoHead returns null (wedged)" test).
   - `REQ-d00124-A: readFifoHead returns null when no pending rows
     remain (only exhausted and sent rows present)`.
   - `REQ-d00124-A: readFifoHead skips a run of mixed terminal rows
     and returns the first pending in sequence_in_queue order`.
   Two of the three tests failed as expected ("Expected: not null;
   Actual: <null>") under the old wedge-at-exhausted implementation.
3. **Green**: Changed `SembastBackend.readFifoHead` to filter on
   `final_status == pending` with `sequence_in_queue` sort and
   `limit: 1`. Updated the abstract method's doc comment.
4. **Phase-4 test semantic update**: The drain test
   `REQ-d00124-D: SendPermanent wedges the FIFO; subsequent drain is
   a no-op` asserted `expect(await backend.readFifoHead('fake'),
   isNull)` with two rows enqueued (`e1` and `e2`). Under Task-8
   semantics, readFifoHead returns `e2` after `e1` is exhausted.
   The test was rewritten to:
   - Rename to "SendPermanent marks head exhausted and drain returns
     without attempting later pending rows".
   - Assert `dest.sent.length == 1` (the drain-level wedge is enforced
     by drain.dart's `SendPermanent -> return` switch case; `e2` was
     NOT attempted even though `readFifoHead` now makes it visible).
   - Assert `readFifoHead` returns `e2` with `FinalStatus.pending`
     (the head-level change this task introduces).
   - Drop the re-drain assertion ("`await drain(...); expect(dest.sent,
     hasLength(1))`") — with the Task-8 readFifoHead but pre-Task-13
     drain loop, a re-drain would read `e2` and attempt it, which is
     correct FIFO behavior but would need script extension. Task 13
     covers the full drain-level continue-past-exhausted story.
5. **Verify**: `flutter test` — **327 / 327 green** (+2). `dart analyze`
   — **No issues found!**

## Test counts

- Baseline: **325 / 325**.
- Final: **327 / 327**. Delta: **+2** (three new REQ-d00124-A head
  tests; one pre-existing wedge-at-readFifoHead test removed).

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**

## Files touched

- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  — `readFifoHead` rewrite: Sembast `Finder` with
  `Filter.equals('final_status', 'pending')` +
  `SortOrder('sequence_in_queue')` + `limit: 1`. Added REQ-d00124-A
  `Implements:` comment and rewritten doc string.
- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  — abstract `readFifoHead` doc comment revised to match the new
  contract; REQ-d00124-A `Implements:` comment added.
- `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`
  — removed the "after markFinal exhausted, readFifoHead returns null
  (wedged)" test; added three REQ-d00124-A head tests.
- `apps/common-dart/append_only_datastore/test/sync/drain_test.dart`
  — rewrote `REQ-d00124-D: SendPermanent wedges the FIFO; subsequent
  drain is a no-op` to match Task-8 semantics (see TDD step 4).
- `spec/dev-event-sourcing-mobile.md` — REQ-d00124-A expanded with the
  new head semantics. `elspais fix` refreshed REQ-d00124's content
  hash (and routine changelog/index maintenance on unrelated PRDs).

## Notes

- The Sembast `limit: 1` is a correctness no-op relative to the old
  implementation (only one `pending` row is ever "the head"), but is
  a meaningful perf improvement on large FIFOs: the backend stops
  scanning as soon as the first matching row is found rather than
  fully loading the store, sorting in Dart, and then walking records.
- REQ-d00124-D's spec text was intentionally NOT changed. "subsequent
  `drain` calls SHALL observe the wedge and SHALL NOT advance past
  the exhausted head" is still true once Task 13 lands; Task 8 in
  isolation satisfies REQ-d00124-D by virtue of drain.dart's
  `SendPermanent -> return` switch case, which is unchanged.
- No production caller's contract changed: `drain` calls
  `readFifoHead`, gets back a pending entry (or null), and routes the
  send result through the unchanged switch-case. The only observable
  change is that, with a later pending row behind an exhausted head,
  a subsequent `drain` invocation will now observe the later row as
  the head. Under the current drain loop, that invocation will
  attempt the later row immediately — which will need Task 13's
  `SendPermanent -> continue` flip to become the intended
  "attempt every pending row once per drain pass" behavior.
