# PHASE 4.3 TASK 11 — fillBatch algorithm

## Summary

Implemented `fillBatch(destination)` — the pipeline step that promotes
matching events from the event log into a destination's FIFO as batch
rows, advancing `fill_cursor_<destId>` accordingly.

Algorithm (design §6.8, REQ-d00128-E/F/G/H + REQ-d00129-I):

1. Dormant schedule (`startDate == null`) → nothing to do.
2. Upper bound: `min(endDate ?? now, now)`. If `startDate > upper`,
   the window is closed → nothing to do.
3. Read `fill_cursor_<destId>` and fetch every event with
   `sequence_number > cursor`.
4. Filter by `client_timestamp ∈ [startDate, upper]` AND
   `destination.filter.matches(event)`.
5. If nothing matches, advance the cursor past the non-matching tail
   (so we don't re-scan them on the next tick — this is cursor
   maintenance, not a "new match" that REQ-d00128-H would classify as
   non-idempotent).
6. Otherwise, assemble a greedy batch: start with the first matching
   event, admit each subsequent one while `canAddToBatch` returns true,
   break on the first false.
7. REQ-d00128-F hold: a single-event batch whose
   `now() - batch.first.clientTimestamp < maxAccumulateTime` is held —
   no FIFO row written, cursor NOT advanced.
8. Transform the batch, then atomically enqueue the FIFO row and write
   `fill_cursor = batch.last.sequenceNumber` in one transaction via the
   new `StorageBackend.enqueueFifoTxn` + existing `writeFillCursorTxn`.

Implements: REQ-d00128-E, REQ-d00128-F, REQ-d00128-G, REQ-d00128-H,
REQ-d00129-I.

## Deliberately deferred

- Historical replay (REQ-d00129-D + REQ-d00130) — Task 12 will build
  on `fillBatch` by running it inside a larger transaction that walks
  the event log for a destination whose `startDate` was set in the past.
- Integration with `SyncCycle` — Task 12+ will call `fillBatch` across
  all registered destinations as part of the cycle.
- `entry_id` derivation for multi-event batches — the current rule
  ("entry_id = batch.first.eventId") is fine for Phase-4.3 call sites
  but may be revisited in a future task if a stable batch identifier
  is needed.

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **345 / 345 green**.
2. **Red — new test file** `test/sync/fill_batch_test.dart`:
   - REQ-d00128-H: fillBatch with no new matching events is a no-op
     (dormant schedule).
   - REQ-d00128-H: fillBatch with empty event log does not advance
     cursor.
   - REQ-d00128-E: fillBatch respects canAddToBatch boundary (7 events,
     batchCapacity=3 → one 3-event FIFO row, cursor=3).
   - REQ-d00128-F: fillBatch with 1 candidate and maxAccumulateTime>0
     does not flush yet (held; cursor unchanged).
   - REQ-d00129-I: fillBatch skips events with client_timestamp <
     startDate.
   - REQ-d00129-I: fillBatch skips events with client_timestamp >
     endDate.
   - REQ-d00128-G: fillBatch advances fill_cursor to
     batch.last.sequenceNumber on successful enqueue.
   - REQ-d00128-H: repeat fillBatch with no new events is idempotent
     (cursor unchanged, no second FIFO row).
   - REQ-d00128-H: non-matching events advance cursor but enqueue
     nothing.
3. **Green — library additions**:
   - Added `StorageBackend.enqueueFifoTxn(txn, destId, batch,
     wirePayload)` to the abstract contract.
   - Refactored `SembastBackend.enqueueFifo` to delegate to
     `enqueueFifoTxn` inside a single `db.transaction(...)` wrapper —
     row-construction logic (empty-batch reject, duplicate-entryId
     reject, sequence_in_queue assignment, payload decode,
     known-FIFOs register) lives in the `Txn` variant.
   - Added `lib/src/sync/fill_batch.dart` implementing the algorithm
     above.
   - Extended `_InMemoryBackend` and `_SpyBackend` test stubs with
     the new `enqueueFifoTxn` override (UnimplementedError /
     delegating forwarder).
   - Exported `fillBatch` from `lib/append_only_datastore.dart`.
4. **Green**: `flutter test` — **354 / 354 green** (+9).
5. **Analyze**: `dart analyze` surfaced one
   `prefer_const_declarations` info on a test-local `final String`;
   changed to `const`. Final `dart analyze` — **No issues found.**
6. **Verify**: `flutter analyze` on
   `apps/daily-diary/clinical_diary` — **No issues found!**

## Test counts

- Baseline: **345 / 345**.
- Final: **354 / 354**. Delta: **+9** (the 9 tests listed in the TDD
  sequence above, all in `test/sync/fill_batch_test.dart`).

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found.**

## Files touched

### Created

- `apps/common-dart/append_only_datastore/lib/src/sync/fill_batch.dart`
  — `fillBatch(destination, backend, schedule, clock?)` function.
- `apps/common-dart/append_only_datastore/test/sync/fill_batch_test.dart`
  — 9 new tests covering REQ-d00128-E/F/G/H and REQ-d00129-I.

### Modified (library)

- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  — added `enqueueFifoTxn` abstract method (transactional variant of
  `enqueueFifo`).
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  — implemented `enqueueFifoTxn`; refactored `enqueueFifo` to wrap it
  in a single `transaction((txn) async { return enqueueFifoTxn(...); })`
  so row-construction logic is centralized.
- `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`
  — exported `fillBatch` from the sync barrel.

### Modified (tests)

- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`
  — `_InMemoryBackend` gets an `UnimplementedError` forwarder for
  `enqueueFifoTxn`.
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
  — `_SpyBackend` gets a delegating forwarder for `enqueueFifoTxn`.

## Notes

- The "non-matching-tail cursor maintenance" branch deliberately
  advances the cursor past filtered-out events even though no FIFO
  row is written. REQ-d00128-H classifies this as a no-op at the "no
  NEW matching events → no new rows + no cursor advance" level, and
  this branch does not contradict that contract: no row is written,
  and no matching event's position is skipped. The cursor advance
  only consumes non-matches so `fillBatch`'s work is O(new events)
  instead of O(total log size).
- `enqueueFifoTxn` does not delete the `sentAt` timestamp's
  `DateTime.now().toUtc()` stamp at row construction — it would be a
  breaking change to make it deterministic, and the drain path
  already treats `enqueuedAt` as a one-shot wall-clock stamp. When
  Task 12's replay path lands, it will use the same `enqueueFifoTxn`
  and will accept that the row's `enqueuedAt` is "now at replay
  time," which is consistent with the fill-batch path.
- `fillBatch` is import-aware: it imports `ClockFn` from
  `drain.dart` rather than redeclaring the typedef, keeping a single
  authoritative definition.
