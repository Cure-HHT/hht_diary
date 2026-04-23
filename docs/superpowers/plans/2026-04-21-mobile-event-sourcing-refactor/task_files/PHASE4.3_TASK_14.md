# PHASE 4.3 TASK 14 — unjamDestination (REQ-d00131)

## Summary

Added `unjamDestination(destId, registry, backend)`: the operator-visible
recovery procedure for a wedged destination FIFO. On a deactivated
destination, unjam deletes every pending row, leaves sent and exhausted
rows untouched (audit trail), and rewinds `fill_cursor` to the largest
`event_id_range.last_seq` across sent rows — or to `-1` when no sent
row exists. Returns an `UnjamResult` carrying `deletedPending` and
`rewoundTo` for operator diagnostics.

Two new abstract methods on `StorageBackend` back the transactional
body:

- `deletePendingRowsTxn(txn, destId) -> int` — delete every row where
  `final_status == pending`; returns the deleted count.
- `maxSentSequenceTxn(txn, destId) -> int?` — max
  `event_id_range.last_seq` across `final_status == sent` rows, or
  `null` when the destination has no sent rows.

Both run inside the caller's transaction so the delete + cursor rewind
commit atomically with one another. The whole unjam runs in one
`backend.transaction` body, so a rollback leaves the FIFO and the
cursor observably unchanged.

Implements: REQ-d00131-A, REQ-d00131-B, REQ-d00131-C, REQ-d00131-D,
REQ-d00131-E.

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **358 / 358 green**.
   `dart analyze` clean.
2. **Red — tests first**: wrote six tests in
   `test/ops/unjam_test.dart` with a `_setupDestinationWithMixedFifo`
   helper that seeds a destination with `sentCount / exhaustedCount /
   pendingCount` FIFO rows at contiguous sequence numbers (sent first,
   then exhausted, then pending), calls `markFinal` for each
   terminal-state row, and advances `fill_cursor` to the last enqueued
   row so the rewind is observable:
   - REQ-d00131-A: unjam on active destination (endDate null) throws
     StateError.
   - REQ-d00131-A: unjam with future endDate still throws StateError.
   - REQ-d00131-B+C: deletes pending, preserves sent + exhausted.
     Asserts on the raw FIFO rows via `sembast.StoreRef.find` for
     ground truth.
   - REQ-d00131-D: rewinds fill_cursor to last sent row's last_seq
     (sent rows at seq 1-2 → rewoundTo == 2).
   - REQ-d00131-D: rewinds to -1 when no sent rows exist.
   - REQ-d00131-E: UnjamResult type check + field population.
   Ran `flutter test test/ops/unjam_test.dart` — **6 failed** as
   expected (unjamDestination not defined).
3. **Green — implementation**:
   - `lib/src/storage/storage_backend.dart`: added abstract
     `deletePendingRowsTxn` and `maxSentSequenceTxn` methods with
     REQ-d00131-B/C/D doc comments.
   - `lib/src/storage/sembast_backend.dart`: implemented both via
     sembast `Finder`. `deletePendingRowsTxn` uses
     `store.delete(txn, finder: Filter.equals('final_status',
     pending.toJson()))` and returns the int return value directly
     (intMapStore scalar key type). `maxSentSequenceTxn` uses
     `SortOrder('event_id_range.last_seq', false)` with `limit: 1` so
     Sembast handles the max computation via its dotted-path sort.
   - `lib/src/ops/unjam.dart`: created new file with
     `unjamDestination`; precondition check runs before opening the
     transaction so a misuse does not hold a write lock. Inside the
     transaction: delete pending → compute rewind target → write
     cursor → return UnjamResult.
   - `test/storage/storage_backend_contract_test.dart` and
     `test/event_repository_test.dart`: added the two new method
     overrides on `_InMemoryBackend` (UnimplementedError) and
     `_SpyBackend` (delegate forwarders) to keep the abstract class
     concrete in both test doubles.
   Reran unjam tests — **6 / 6 green**.
4. **Full-suite verify**: `flutter test` — **364 / 364 green**
   (+6 vs baseline). `dart analyze` clean after fixing two
   unrelated-to-behavior lints in the new test file (a non-visible
   doc-comment reference and an unnecessary escaped apostrophe in a
   test name).

## Test counts

- Baseline: **358 / 358**.
- Final: **364 / 364**. Delta: **+6**.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found!**

## Files touched

### Created

- `apps/common-dart/append_only_datastore/lib/src/ops/unjam.dart`
- `apps/common-dart/append_only_datastore/test/ops/unjam_test.dart`
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.3_TASK_14.md`
  (this file).

### Modified

- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  - Added `deletePendingRowsTxn` and `maxSentSequenceTxn` abstract
    methods with REQ-d00131-B/C/D doc comments.
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  - Implemented both new methods in a new "Unjam helpers" section.
- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`
  - Added `UnimplementedError` overrides for the two new methods on
    `_InMemoryBackend`.
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
  - Added delegate forwarders for the two new methods on
    `_SpyBackend`.

## Notes

- `UnjamResult` was already defined in
  `destination_schedule.dart` (Task 10), so Task 14 only consumed it.
- The unjam op lives under `lib/src/ops/` per the Phase 4.3 plan
  (`Task 14 files` list); this is the first file under that
  directory. The directory is intentionally not exported from the
  top-level library yet — unjam is plumbing for `DestinationRegistry.unjamDestination`
  (a later consolidation task) and is imported directly by tests until
  then.
- The deactivation precondition (`endDate == null || endDate > now`)
  is checked BEFORE opening the transaction so a mis-call does not
  hold a write lock across the StateError path.
- `deletePendingRowsTxn` returns `0` on an unknown destination because
  Sembast stores are lazily-created: a never-written FIFO store
  simply has zero records. No separate "does the store exist?" probe
  is needed.
- `maxSentSequenceTxn` relies on Sembast's dotted-path sort order
  (`SortOrder('event_id_range.last_seq', false)`) to compute the max
  without pulling every row into memory. `limit: 1` guarantees we
  only pay for the single winning row.
- Single-event batches set `event_id_range.firstSeq == lastSeq`, so
  the rewind target equals the event's `sequence_number` as expected.
  Multi-event batches would have `lastSeq` equal to the batch's max
  sequence_number, which is also the correct rewind target (it is
  the upper bound of what has been successfully delivered).
