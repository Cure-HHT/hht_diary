# PHASE 4.3 TASK 6 - FifoEntry batch-per-row migration

## Summary

Migrated `FifoEntry` from single-event-per-row to batch-per-row shape and
retargeted `StorageBackend.enqueueFifo` from a caller-built entry to a
batch-aware `(destinationId, List<StoredEvent> batch, WirePayload)`
signature that returns the persisted `FifoEntry`.

The three new/changed fields on `FifoEntry`:

- `eventIds: List<String>` (was scalar `eventId`) - non-empty, every
  event_id in the batch (REQ-d00128-A).
- `eventIdRange: EventIdRange` (new) - a Dart 3 record typedef
  `({int firstSeq, int lastSeq})` drawn from the sequence_numbers of the
  contained events; used by cursor-advancement math (REQ-d00128-B).
- `wirePayload: Map<String, Object?>` (unchanged shape, new meaning) -
  one payload covering every event in the batch; no per-event payload
  is stored (REQ-d00128-C).

Sembast persistence shape: `event_ids` is a JSON array of strings;
`event_id_range` is `{"first_seq": int, "last_seq": int}`. The legacy
scalar `event_id` key is REMOVED from the wire shape - no
backward-compatibility shim (we have no production callers on `main`).

Implements: REQ-d00128-A, REQ-d00128-B, REQ-d00128-C.

## New public signature

```text
Future<FifoEntry> enqueueFifo(
  String destinationId,
  List<StoredEvent> batch,
  WirePayload wirePayload,
);
```

The backend:

- Rejects an empty `batch` with `ArgumentError` (REQ-d00128-A).
- Derives `entry_id` from `batch.first.eventId` (stable correlation
  into `diary_entries` for single-event batches).
- Derives `event_ids` from `batch.map((e) => e.eventId)` (REQ-d00128-A).
- Derives `event_id_range` from
  `(batch.first.sequenceNumber, batch.last.sequenceNumber)` (REQ-d00128-B).
- Decodes `wirePayload.bytes` as UTF-8 JSON and stores the decoded
  `Map` as the row's `wire_payload` (REQ-d00128-C). Non-Map / non-JSON
  bytes are rejected with `ArgumentError` rather than silently
  corrupting the row.
- Opens its own atomic transaction for the write (Phase-4.3 plan; the
  later `enqueueFifoTxn(txn, ...)` for replay / fill_batch composition
  is Tasks 10-12).
- Assigns `sequence_in_queue` as `max(existing store key) + 1` in the
  same transaction so the Sembast int key and payload
  `sequence_in_queue` stay in lockstep (Phase-2 Prereq A, Option 1).
- Returns the constructed `FifoEntry`.

## TDD sequence

1. **Baseline**: `flutter test` - **310 / 310 green**.
2. **Red**: Added `test/storage/fifo_entry_test.dart` with 11 new
   REQ-d00128 tests covering:
   - REQ-d00128-A: `eventIds` non-empty, empty-at-construction rejected
     (AssertionError), fromJson rejection of missing/wrong-type/empty
     `event_ids`, unmodifiable parsed list.
   - REQ-d00128-B: `eventIdRange` record type + JSON round-trip of
     `first_seq`/`last_seq`, fromJson rejection of missing/malformed
     `event_id_range`.
   - REQ-d00128-C: `wirePayload` as a single batch-covering Map.
   - +A+B+C: full round-trip preserves new shape; legacy `event_id`
     scalar is NOT emitted.
   - Equality distinguishes entries differing only in `eventIds` or
     `eventIdRange`.
   Tests fail with expected `getter not defined for type 'FifoEntry'`
   errors.
3. **Green**: Reshaped `FifoEntry`:
   - Added `EventIdRange` typedef.
   - Replaced scalar `eventId` with `List<String> eventIds`.
   - Added `EventIdRange eventIdRange`.
   - Constructor `assert(eventIds.isNotEmpty, ...)` (REQ-d00128-A;
     runtime fromJson also rejects empty/missing).
   - `fromJson` validates new fields, wraps `eventIds` in
     `List<String>.unmodifiable`.
   - `toJson` emits `event_ids` array and `event_id_range` Map; does
     NOT emit legacy `event_id` scalar.
   - `==`, `hashCode`, `toString` updated.
   All 11 new REQ-d00128 tests green.
4. **Retarget the backend contract**: changed `StorageBackend.enqueueFifo`
   abstract signature to `(destId, batch, wirePayload) -> Future<FifoEntry>`
   and updated `SembastBackend.enqueueFifo` per the design above.
5. **Update call sites** (all in the test suite - no production callers
   exist on `main`):
   - `test/storage/sembast_backend_fifo_test.dart` - rewrote to drive
     `enqueueFifo` through the new batch-aware helper; dropped the
     three "rejects non-pending / non-empty attempts / non-null
     sent_at" tests (not enforceable under the new signature since the
     backend constructs the `FifoEntry` internally); added
     REQ-d00128-A empty-batch rejection test.
   - `test/sync/drain_test.dart` - replaced every
     `backend.transaction((txn) async { await backend.enqueueFifo(txn,
     dest, _mkFifoEntry(...)) });` with a `_enqueueRow` helper that
     calls the new signature.
   - `test/sync/sync_cycle_test.dart` - same transformation with an
     `_enqueueOne` helper.
   - `test/storage/storage_backend_contract_test.dart` and
     `test/event_repository_test.dart` - updated the stub/delegator
     overrides to match the new `enqueueFifo` signature.
   - `test/storage/value_types_test.dart` - converted the `FifoEntry`
     group's `makeSample` to the batch shape and renamed the flagship
     round-trip test to `REQ-d00119-B + REQ-d00128-A+B+C`.
6. **Test helper**: added
   `test/test_support/fifo_entry_helpers.dart` exposing:
   - `singleEventFifoEntry(...)` (plan-specified helper for tests
     that construct a `FifoEntry` directly).
   - `storedEventFixture(...)` - minimal `StoredEvent` fixture.
   - `wirePayloadJson(...)` - build a JSON-encoded `WirePayload`.
   - `enqueueSingle(backend, dest, {eventId, sequenceNumber, ...})` -
     wrap a single-event batch through the new `enqueueFifo` signature
     for tests that do not care about batching.
7. **Verify**: `flutter test` - **319 / 319 green**. `dart analyze` -
   **No issues found!**
8. **Cross-package analyze**:
   `(cd apps/daily-diary/clinical_diary && flutter analyze)` -
   **No issues found!** (clinical_diary does not depend on
   `FifoEntry`'s internal shape.)

## Test counts

- Baseline (pre-task-6): **310 / 310**.
- Final: **319 / 319**. Delta: **+9 net**.
  - +11 new REQ-d00128 tests in `test/storage/fifo_entry_test.dart`.
  - -3 `enqueueFifo rejects ...` tests in
    `test/storage/sembast_backend_fifo_test.dart` that asserted
    properties of a caller-built `FifoEntry`; not enforceable under
    the new signature which constructs the entry inside the backend.
  - +1 REQ-d00128-A empty-batch rejection test in
    `test/storage/sembast_backend_fifo_test.dart`.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found.**

## Files touched

- `apps/common-dart/append_only_datastore/lib/src/storage/fifo_entry.dart`
  - replaced scalar `eventId` with `eventIds: List<String>`, added
  `eventIdRange: EventIdRange` typedef, empty-batch assert, updated
  `fromJson` / `toJson` / `==` / `hashCode` / `toString`.
- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  - new `enqueueFifo(destId, batch, wirePayload) -> Future<FifoEntry>`
  abstract signature; expanded doc comment; imported `WirePayload`.
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  - new `enqueueFifo` impl that derives `entry_id`/`event_ids`/
  `event_id_range` from the batch, decodes `WirePayload.bytes` as
  UTF-8 JSON for the stored Map, opens its own transaction; renamed
  `_registerFifoDestination` helper to
  `_registerFifoDestinationSembast(Transaction, String)` since the
  new call-site no longer holds a `_SembastTxn` (it uses the Sembast
  `Transaction` directly); `exhaustedFifos` now reports
  `head.eventIds.first` as `headEventId` (first event of the batch
  is the operator-facing identifier).
- `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`
  - re-export the new `EventIdRange` typedef alongside `FifoEntry`.
- `apps/common-dart/append_only_datastore/test/storage/fifo_entry_test.dart`
  - NEW file - 11 REQ-d00128 tests.
- `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`
  - rewrote to drive `enqueueFifo` through `enqueueSingle`; dropped
  the 3 caller-built-entry rejection tests; added REQ-d00128-A
  empty-batch rejection.
- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`
  - stub `enqueueFifo` override updated to new signature; imported
  `WirePayload`.
- `apps/common-dart/append_only_datastore/test/storage/value_types_test.dart`
  - `FifoEntry` group converted to batch shape.
- `apps/common-dart/append_only_datastore/test/sync/drain_test.dart`
  - replaced every in-txn enqueue with an `_enqueueRow` helper.
- `apps/common-dart/append_only_datastore/test/sync/sync_cycle_test.dart`
  - replaced every in-txn enqueue with an `_enqueueOne` helper.
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
  - forwarding `enqueueFifo` override updated to new signature.
- `apps/common-dart/append_only_datastore/test/test_support/fifo_entry_helpers.dart`
  - NEW file - `singleEventFifoEntry`, `storedEventFixture`,
  `wirePayloadJson`, `enqueueSingle`.

## Non-mechanical call-site changes (for the record)

1. The three "enqueueFifo rejects a bad caller-built entry" tests were
   **dropped**, not rewritten. Under the new signature the backend
   constructs the FifoEntry itself from the batch + WirePayload with
   `finalStatus = pending`, `attempts = []`, `sentAt = null` hard-
   coded; a caller cannot supply any of those bad values. The empty-
   batch rejection test replaces them as the sole caller-facing
   pre-condition.
2. The "caller supplies nonsense sequence_in_queue" test collapsed
   to "backend assigns 1, 2, 3 monotonically" (same semantics, no
   nonsense caller input to ignore).
3. `ExhaustedFifoSummary.headEventId` now reports the first event_id
   of the batch (`head.eventIds.first`). For single-event batches -
   every call site in the suite - this equals the row's `entry_id`.
4. The `WirePayload.bytes` field must encode a JSON object; the
   Sembast backend decodes it back to a `Map` for persistence so
   drain's read path can re-encode via `jsonEncode(head.wirePayload)`.
   Non-JSON / non-object bytes raise `ArgumentError` at enqueue
   rather than corrupting the row - all existing `drain_test` and
   `sync_cycle_test` payloads already conform.
5. The legacy `Txn` parameter on `StorageBackend.enqueueFifo` is
   gone. The Phase-4.3 plan's later `enqueueFifoTxn(txn, ...)` for
   replay / fill_batch composition is a separate follow-up
   (Tasks 10 / 11 / 12); Task 6 only ships the standalone variant.
