# PHASE 4.3 TASK 12 — Historical replay on past startDate

## Summary

Wired up the REQ-d00129-D replay hook Task 10 left as a `TODO(Task 12)`
in `DestinationRegistry.setStartDate`. When `setStartDate` is called
with a `startDate <= now()`, the registry now runs a new
`runHistoricalReplay` inside the same transaction that persists the
new schedule:

- `runHistoricalReplay(txn, destination, schedule, backend)` walks the
  event log past `fill_cursor` via `findAllEventsInTxn`, filters
  candidates by `destination.filter` and the time window
  `[startDate, min(endDate, now())]`, assembles greedy batches via
  `destination.canAddToBatch`, transforms each batch via
  `destination.transform`, and enqueues it via `enqueueFifoTxn`.
  When the window covers no matching events the cursor is advanced past
  the non-matching tail (matches `fillBatch`'s idempotent-cursor branch).
  Otherwise the cursor advances to the last replayed event's
  `sequence_number`.
- `DestinationRegistry.setStartDate` was refactored to open one
  transaction that performs the schedule write (via
  `writeScheduleTxn`) and, when `startDate <= now()`, invokes
  `runHistoricalReplay` inside the same transaction. The in-memory
  schedule cache is updated only after the transaction commits so a
  rollback does not leave the registry advertising a schedule that was
  not persisted.
- `startDate > now()` takes the else branch — no replay runs, matching
  REQ-d00129-E.

Implements: REQ-d00129-D, REQ-d00129-E, REQ-d00130-A, REQ-d00130-B,
REQ-d00130-C.

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **355 / 355 green**.
   `dart analyze` clean.
2. **Red**: added `test/destinations/historical_replay_test.dart` with
   three cases (REQ-d00129-D past-start replays; REQ-d00129-E
   future-start does nothing; REQ-d00130-C live `fillBatch` after
   replay does not double-enqueue). Ran the file: two failed (the past
   and the post-replay fillBatch assertions), one passed coincidentally
   (future-start: an unchanged no-op was already the behavior Task 10
   persisted).
3. **Green — implementation**:
   - Created `lib/src/sync/historical_replay.dart` with
     `runHistoricalReplay`. Algorithm mirrors `fillBatch` in filter
     semantics (time window + subscription filter + `canAddToBatch`
     batching + `transform`) but runs inside the caller's transaction,
     does not honor `maxAccumulateTime`, and iterates the entire
     historical tail in one pass.
   - Modified `lib/src/destinations/destination_registry.dart`:
     - Imported `historical_replay.dart`.
     - Replaced `setStartDate`'s non-transactional `backend.writeSchedule`
       call with `backend.transaction((txn) async { ... })` that calls
       `writeScheduleTxn` then (for past dates) `runHistoricalReplay`.
     - Dropped the `TODO(Task 12)` comment; updated the REQ citations
       to include REQ-d00129-D and REQ-d00129-E, plus the
       `startDate > now()` branch note.
     - Moved the in-memory schedule-cache update to after the
       transaction commits so a rollback does not desync the cache.
4. **Green — rerun**: new tests pass. Full suite: **358 / 358 green**
   (+3).
5. **Analyze**: `dart analyze` flagged one unused import in the new
   test file (a leftover from an earlier iteration); removed it. Final
   `dart analyze` — **No issues found.**
6. **Flutter analyze**: `flutter analyze` on
   `apps/daily-diary/clinical_diary` — **No issues found!**

## Test counts

- Baseline: **355 / 355**.
- Final: **358 / 358**. Delta: **+3**:
  - `historical_replay_test.dart`: REQ-d00129-D (past replay),
    REQ-d00129-E (future no-op), REQ-d00130-C (post-replay
    `fillBatch` doesn't double-enqueue).

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found!**

## Files touched

### Created

- `apps/common-dart/append_only_datastore/lib/src/sync/historical_replay.dart`
  — `runHistoricalReplay(Txn, Destination, DestinationSchedule,
  StorageBackend)`. Same filter + batching + transform contract as
  `fillBatch`; runs inside caller's transaction; iterates historical
  tail to completion in one pass; no `maxAccumulateTime` hold.
- `apps/common-dart/append_only_datastore/test/destinations/historical_replay_test.dart`
  — 3 tests covering REQ-d00129-D, REQ-d00129-E, REQ-d00130-C.

### Modified

- `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart`
  — `setStartDate` now opens one transaction that writes the schedule
  and (when `startDate <= now()`) runs `runHistoricalReplay` inside it.
  In-memory cache update moved after commit. Removed
  `TODO(Task 12)`; added REQ-d00129-D+E citations.

## Notes

- `runHistoricalReplay` deliberately does NOT honor
  `Destination.maxAccumulateTime`. The hold exists so a live
  single-event batch can accumulate a second event before flushing;
  historical events are not "live" arrivals, so the last batch flushes
  even if it is a single event.
- `runHistoricalReplay` uses `findAllEventsInTxn` (not `findAllEvents`)
  so the transactional read reflects any writes already staged in the
  same transaction. In practice `setStartDate`'s transaction writes
  only the schedule record before replay runs, so the event-log view
  is unaffected; the transactional read is there for correctness and
  future callers that may stage event writes alongside replay.
- REQ-d00130-C's serialization guarantee is provided by
  `StorageBackend.transaction`: a concurrent `record()` call waits
  behind the replay transaction and, when it runs, its `fillBatch`
  re-evaluates from the advanced `fill_cursor`. The test validates the
  observable consequence (no event_id appears in more than one FIFO
  row) with a batch-capacity-of-3 destination so replay produces a
  distinct row from the post-replay `fillBatch` — a replay that
  double-enqueued would produce more than 2 rows or overlapping
  `event_ids` between rows.
- No changes needed to `StorageBackend` or `SembastBackend` — every
  transactional primitive `runHistoricalReplay` needs
  (`findAllEventsInTxn`, `enqueueFifoTxn`, `writeFillCursorTxn`,
  `writeScheduleTxn`) landed in earlier phases.
