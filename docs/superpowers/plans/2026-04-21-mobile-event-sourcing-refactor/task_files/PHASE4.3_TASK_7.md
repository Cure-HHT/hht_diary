# PHASE 4.3 TASK 7 — Per-destination fill_cursor persistence

## Summary

Added `readFillCursor` / `writeFillCursor` / `writeFillCursorTxn` to
`StorageBackend` with a Sembast implementation. The fill cursor is the
highest `sequence_number` that has been promoted into any FIFO row
(pending, sent, or exhausted) for a given destination; it is stored in
the `backend_state` key-value store under key
`fill_cursor_<destinationId>` and returns `-1` when unset.

Implements: REQ-d00128-G.

## New contract

```text
Future<int> readFillCursor(String destinationId);
Future<void> writeFillCursor(String destinationId, int sequenceNumber);
Future<void> writeFillCursorTxn(
  Txn txn,
  String destinationId,
  int sequenceNumber,
);
```

- `readFillCursor` is non-transactional and returns `-1` when the
  `fill_cursor_<destinationId>` key is absent from `backend_state`.
- `writeFillCursor` opens its own atomic Sembast transaction for the
  single KV write; for callers that do not already hold a `Txn`.
- `writeFillCursorTxn` participates in a surrounding transaction. On
  rollback, the cursor reverts to its pre-transaction value — used by
  the fill-batch path (later tasks) so the cursor advance is co-atomic
  with the enqueue and sequence-counter writes it accompanies.

Persistence key format: `fill_cursor_<destinationId>` under the
existing `backend_state` store (same store already used for
`sequence_counter`, `schema_version`, and `known_fifo_destinations`).

## TDD sequence

1. **Baseline**: `flutter test` — **320 / 320 green**. `dart analyze` clean.
2. **Red**: Appended four REQ-d00128-G tests to
   `test/storage/sembast_backend_fifo_test.dart`:
   - `readFillCursor returns -1 when unset`
   - `writeFillCursor then readFillCursor round-trips`
   - `writeFillCursor inside a transaction participates in atomicity
     (rollback confirms cursor was NOT advanced)`
   - `fill_cursor is per-destination (two destinations have
     independent cursors)`
   Tests fail to compile with "method isn't defined" errors on the
   new `SembastBackend` methods (as intended).
3. **Green**:
   - `lib/src/storage/storage_backend.dart` — added three abstract
     methods with REQ-d00128-G `Implements:` comments and doc strings.
   - `lib/src/storage/sembast_backend.dart` — implemented the three
     methods against `_backendStateStore.record('fill_cursor_<id>')`.
     `readFillCursor` returns `-1` when the record is absent.
     `writeFillCursor` opens its own Sembast transaction for the
     single-KV-write case. `writeFillCursorTxn` writes through the
     existing `_SembastTxn._sembastTxn` so it participates in the
     surrounding transaction's atomicity.
   - Updated the two existing test-only `StorageBackend` subclasses
     (`_InMemoryBackend` in `storage_backend_contract_test.dart`,
     `_SpyBackend` in `event_repository_test.dart`) to satisfy the
     expanded contract. `_InMemoryBackend` throws `UnimplementedError`
     (matches its pattern for FIFO / schema methods it does not
     exercise); `_SpyBackend` forwards to its `delegate`.
4. **Verify**: `flutter test` — **324 / 324 green** (+4). `dart
   analyze` — **No issues found!**

## Test counts

- Baseline: **320 / 320**.
- Final: **324 / 324**. Delta: **+4** (all REQ-d00128-G).

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**

## Files touched

- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  — new abstract methods `readFillCursor`, `writeFillCursor`,
  `writeFillCursorTxn` with REQ-d00128-G `Implements:` comments.
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  — concrete implementations; new private `_fillCursorKey` helper;
  uses the existing `_backendStateStore`.
- `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`
  — appended four REQ-d00128-G tests.
- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`
  — `_InMemoryBackend` stubs for the three new methods (throw
  UnimplementedError, matching its pattern).
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
  — `_SpyBackend` forwarding overrides for the three new methods.

## Notes

- The `-1` sentinel is specified by REQ-d00128-G and matches the
  "no row has yet been enqueued" state: the smallest valid
  `sequence_number` promoted into a FIFO is `0` (or `1` under the
  reserve-and-increment counter, which starts at `0` and increments
  on reserve). A sentinel of `-1` is strictly less than any real
  promoted sequence_number and so comparisons like
  `nextSeq > fillCursor` work uniformly on the first and subsequent
  fill cycles.
- The backend does NOT enforce monotonic advance of the cursor — the
  contract just stores what the caller provides. Monotonic-advance is
  policy owned by the fill-batch path (later Phase-4.3 tasks).
- No production caller uses these methods yet; they are scaffolding
  for the fill-batch / replay path landing in subsequent Task 8+.
