# PHASE 4.3 TASK 15 — rehabilitateExhaustedRow + rehabilitateAllExhausted (REQ-d00132)

## Summary

Added the lighter-weight counterpart to `unjamDestination`:

- `rehabilitateExhaustedRow(destId, fifoRowId, backend)` flips a single
  exhausted FIFO row back to `pending`; `attempts[]` is preserved
  (REQ-d00132-B). Unknown row or non-exhausted status throws
  `ArgumentError` before a transaction opens (REQ-d00132-A).
- `rehabilitateAllExhausted(destId, backend)` flips every exhausted row
  on the destination in one transaction and returns the count of rows
  flipped (REQ-d00132-C). Short-circuits before opening a transaction
  when no exhausted row exists.
- Both ops are permitted on an ACTIVE destination (REQ-d00132-D) — no
  deactivation precondition, unlike unjam. A concurrent drain that
  reads the row right after rehab simply sees a newly-pending row,
  which is the intended outcome.

Three new abstract methods on `StorageBackend` back the op:

- `readFifoRow(destId, entryId) -> FifoEntry?` — read a single row by
  entry_id; returns `null` on unknown row / unknown destination.
- `exhaustedRowsOf(destId) -> List<FifoEntry>` — every row with
  `final_status == exhausted`, sorted by `sequence_in_queue` ascending.
- `setFinalStatusTxn(txn, destId, entryId, status)` — narrowly-scoped
  `exhausted -> pending` flip. Rejects any `status != pending` with
  `ArgumentError` so the one-way `pending -> sent|exhausted` rule in
  `markFinal` is not weakened by a second write path. Preserves
  `attempts[]` and clears `sent_at`.

Implements: REQ-d00132-A, REQ-d00132-B, REQ-d00132-C, REQ-d00132-D.

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **365 / 365 green**.
   `dart analyze` clean.
2. **Red — tests first**: wrote seven tests in
   `test/ops/rehabilitate_test.dart` with a
   `_setupDestinationWithMixedFifo` helper modeled on the one in
   `unjam_test.dart` but that ALSO seeds one `AttemptResult` per
   exhausted row so REQ-d00132-B can observe attempts[] preservation.
   The destination is left ACTIVE (no endDate) by default — REQ-d00132-D
   is exercised by one of the tests reading the schedule and asserting
   `endDate == null` before calling rehabilitate.
   - REQ-d00132-A: unknown row → ArgumentError.
   - REQ-d00132-A: pending row → ArgumentError.
   - REQ-d00132-A: sent row → ArgumentError (also covers the
     sent-but-not-exhausted branch of the existence-and-status check).
   - REQ-d00132-B: exhausted → pending; attempts[] preserved
     byte-for-byte.
   - REQ-d00132-D: rehabilitate works on an active destination
     (endDate == null).
   - REQ-d00132-C: bulk rehab of 1 sent + 3 exhausted + 2 pending →
     returns 3; remaining status counts: sent=1, pending=5 (2 original +
     3 rehabilitated), exhausted=0.
   - REQ-d00132-C: bulk rehab on a destination with no exhausted rows
     returns 0; no rows change.
   Ran `flutter test test/ops/rehabilitate_test.dart` — compilation
   failed on missing imports as expected.
3. **Green — implementation**:
   - `lib/src/storage/storage_backend.dart`: added three abstract
     methods (`readFifoRow`, `exhaustedRowsOf`, `setFinalStatusTxn`)
     under a new "Rehabilitate helpers (REQ-d00132)" section with doc
     comments naming the REQ-d00132-A/B/C assertions.
   - `lib/src/storage/sembast_backend.dart`: implemented all three in
     a new "Rehabilitate helpers (REQ-d00132)" section. `readFifoRow`
     is a `Finder` by `entry_id`, `limit: 1`. `exhaustedRowsOf` is a
     `Finder` by `final_status == exhausted` sorted by
     `sequence_in_queue` asc. `setFinalStatusTxn` rejects any
     `status != pending` with `ArgumentError`, finds the row by
     `entry_id`, clears `sent_at`, writes the new `final_status`, and
     leaves `attempts` untouched. Missing row → StateError (caller is
     expected to have verified existence via `readFifoRow`).
   - `lib/src/ops/rehabilitate.dart`: created with `rehabilitateExhaustedRow`
     and `rehabilitateAllExhausted`. Existence + status preconditions
     are checked BEFORE opening the transaction so a mis-call does not
     hold a write lock. The bulk variant short-circuits to `return 0`
     when no exhausted row exists, so the no-op path also does not
     open a transaction.
   - `test/storage/storage_backend_contract_test.dart` and
     `test/event_repository_test.dart`: added the three new method
     overrides on `_InMemoryBackend` (UnimplementedError) and
     `_SpyBackend` (delegate forwarders) to keep the abstract class
     concrete in both test doubles.
   Reran rehab tests — **7 / 7 green**.
4. **Full-suite verify**: `flutter test` — **372 / 372 green** (+7 vs
   baseline). `dart analyze` clean.

## Test counts

- Baseline: **365 / 365**.
- Final: **372 / 372**. Delta: **+7**.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found!**

## Files touched

### Created

- `apps/common-dart/append_only_datastore/lib/src/ops/rehabilitate.dart`
- `apps/common-dart/append_only_datastore/test/ops/rehabilitate_test.dart`
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.3_TASK_15.md`
  (this file).

### Modified

- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  - Added `readFifoRow`, `exhaustedRowsOf`, `setFinalStatusTxn`
    abstract methods under a new "Rehabilitate helpers (REQ-d00132)"
    section.
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  - Implemented the three new methods in a new "Rehabilitate helpers
    (REQ-d00132)" section.
- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`
  - Added `UnimplementedError` overrides for the three new methods on
    `_InMemoryBackend`.
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
  - Added delegate forwarders for the three new methods on
    `_SpyBackend`.

## Notes

- `setFinalStatusTxn` is deliberately narrowly scoped to the
  `exhausted -> pending` flip. Rejecting any other `status` with
  `ArgumentError` preserves `markFinal`'s one-way
  `pending -> sent|exhausted` invariant — those two paths own their
  transitions and the test doubles / Sembast impl don't have to pick
  which one owns a `pending -> pending` no-op or a `sent -> pending`
  undo. If a future requirement needs either, it will land as an
  explicit new method rather than as a widening here.
- `sent_at` is cleared defensively on the flip. Under the current
  markFinal contract, an exhausted row never has a `sent_at` set
  (`sent_at` is only stamped on the `sent` transition). Leaving a
  stale value on a rehabilitated row would make the newly-pending row
  look like it had already been delivered to the send-log; clearing
  it here closes that risk even though the current write paths never
  produce it.
- The bulk variant reads the exhausted list BEFORE opening the
  transaction. This is safe because a concurrent writer cannot
  transition `exhausted -> anything` (the markFinal one-way rule
  rejects retransition), so the snapshot cannot become stale by the
  time the transaction commits — the only way a row in the snapshot
  disappears is via `deleteDestination` (which drops the whole store)
  or a future rehabilitation race where another call to
  `setFinalStatusTxn` beats ours. The second case is a legitimate
  race that either variant would lose; the short-circuit at
  `exhausted.isEmpty` covers the first.
- The ops live under `lib/src/ops/` alongside `unjam.dart`. The
  directory is not yet exported from the top-level library — like
  `unjam`, these are consumed by tests directly and will be wired
  into `DestinationRegistry` in a later consolidation task.
- The "permitted on an active destination" assertion (REQ-d00132-D)
  is exercised by one of the rehab tests reading the schedule and
  asserting `endDate == null` before calling through. It is also
  implicit in the helper, which does not deactivate the destination
  between setup and the rehabilitate call.
