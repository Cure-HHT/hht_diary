# Phase 4.22 Task 7 — Materialize-on-ingest in `_ingestOneInTxn` (REQ-d00121-K, REQ-d00145-N) — closes Phase 4.9 deferral

## Goal

Add a materializer loop to `EventStore._ingestOneInTxn` so receivers project ingested events into materialized views identically to local-appended events. The loop is symmetric with the loop in `_appendInTxn`: same gates, same per-event atomicity, same throw-rolls-back semantics. This is the central change of Phase 4.22 and closes the Phase 4.9 design spec §398 deferral ("Destination-side materializer / fold strategy ... is a separate design").

REQs implemented: **REQ-d00121-K, REQ-d00145-N**. Cross-references: **REQ-d00154-D** (system entry types ship `materialize: false` so the outer gate short-circuits on ingest just as on append).

## TDD Sequence

### Step 1 — Read the existing materializer loop in `_appendInTxn`

`_appendInTxn` (lines 498-519): outer gate `if (def.materialize)`; inner gate `if (!m.appliesTo(event)) continue`; calls `m.targetVersionFor(...)`, `m.promoter(...)`, then `m.applyInTxn(...)` with `aggregateHistory` passed as `List<StoredEvent>.unmodifiable(aggregateHistory)`. The `aggregateHistory` variable is read on line 418 BEFORE `appendEvent` (line 482), so it represents prior events excluding the new one. The materializer loop runs AFTER `appendEvent` so the new event lives in the event_log when materializers do their writes.

### Step 2 — Read `_ingestOneInTxn`

`_ingestOneInTxn` (lines 648-731): verifies Chain 1, idempotency-checks by `event_id`, stamps a receiver `ProvenanceEntry` (Chain 2 fields), recomputes `event_hash` into `updatedEvent` (line 717), then persists via `backend.appendEvent(txn, updatedEvent)` (line 724). The variable name carrying the receiver-stamped event is `updatedEvent`. Both call paths (`ingestEvent` and `ingestBatch`) wrap `_ingestOneInTxn` in `backend.transaction(...)`, so any throw propagating out of `_ingestOneInTxn` rolls back the entire enclosing transaction (which is the whole batch on the `ingestBatch` path).

### Step 3 — Write failing tests

Created `apps/common-dart/event_sourcing_datastore/test/event_store/event_store_ingest_materialize_test.dart` with 4 tests under group `EventStore ingest path materializer loop (REQ-d00121-K, REQ-d00145-N)`:

- `REQ-d00121-K + REQ-d00145-N: ingestEvent populates diary_entries view from a freshly-ingested user event` — sender and receiver bootstrapped via `bootstrapAppendOnlyDatastore` with `DiaryEntriesMaterializer`; sender appends `demo_note` finalized; receiver `ingestEvent`s; asserts `findEntries(entryType: 'demo_note')` returns one row with the expected answers, `is_complete: true`, `latest_event_id == original.eventId`.
- `REQ-d00121-K: ingestBatch projects each event in batch into diary_entries view` — three distinct `demo_note` events on the sender, one batch envelope, `ingestBatch` on the receiver; asserts three rows in `diary_entries`, one per `aggregateId`, with the correct per-event `idx`.
- `REQ-d00145-A + REQ-d00121-K: materializer throw rolls back entire ingestBatch (no events landed, no view rows)` — receiver bootstrapped with a `_ThrowingTestMaterializer` that throws on its 2nd `applyInTxn` call; 3-event batch; asserts the call throws `StateError`, no user events in the receiver's log (system bootstrap audit excluded by `kReservedSystemEntryTypeIds`), no rows in `diary_entries`.
- `REQ-d00154-D: ingested system events do NOT fire materializers (def.materialize:false short-circuits the outer gate)` — receiver bootstrapped with a `_RecordingMaterializer` that captures every `applyInTxn` call; the sender pane's bootstrap step has already emitted a `system.entry_type_registry_initialized` event under the sender's `source.identifier` aggregate; that event is read off the sender's log and shipped via `ingestBatch`; asserts the receiver admits it into its event log AND that `recording.applied.length` is unchanged.

### Step 4 — Run tests; expect failure

```text
00:00 +0 -4: Some tests failed.
```

Tests 1, 2, 3 fail (no materializer fires on ingest currently). Test 4 also fails initially because the original test seed used `eventType: 'recorded'` which `_validateAppendInputs` rejects — fixed by reading the bootstrap-emitted system event off the sender's log instead of synthesizing one. After that adjustment, tests 1, 2, 3 fail and test 4 passes incidentally (no materializer firing on anything yet, including system events).

### Step 5 — Implement the materializer block in `_ingestOneInTxn`

In `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`, after step 4 (build `updatedEvent`) and before step 5 (return outcome), add:

```dart
// 5. Read prior aggregate history before appendEvent so the
//    materializer receives "events strictly before the new one"
//    in symmetry with the append path's loop.
final aggregateHistory = await backend.findEventsForAggregateInTxn(
  txn,
  updatedEvent.aggregateId,
);

// 6. Persist via the same path as origin appends.
await backend.appendEvent(txn, updatedEvent);

// 7. Fire materializers symmetric with the local-append path.
// Implements: REQ-d00121-K, REQ-d00145-N — the ingest-path materializer
//   loop runs with the same gates as the local-append loop
//   (`def.materialize` outer gate + `m.appliesTo(event)` inner gate),
//   inside the same transaction as `appendEvent`. System entry types
//   ship `materialize: false` (REQ-d00154-D) so the outer gate
//   short-circuits before any materializer is consulted. A
//   materializer or promoter throw propagates out of `_ingestOneInTxn`
//   and rolls back the entire ingest transaction (REQ-d00145-A
//   all-or-nothing batch atomicity preserved).
final def = entryTypes.byId(updatedEvent.entryType);
if (def != null && def.materialize) {
  for (final m in materializers) {
    if (!m.appliesTo(updatedEvent)) continue;
    final target = await m.targetVersionFor(
      txn,
      backend,
      updatedEvent.entryType,
    );
    final promoted = m.promoter(
      entryType: updatedEvent.entryType,
      fromVersion: updatedEvent.entryTypeVersion,
      toVersion: target,
      data: updatedEvent.data,
    );
    await m.applyInTxn(
      txn,
      backend,
      event: updatedEvent,
      promotedData: promoted,
      def: def,
      aggregateHistory: List<StoredEvent>.unmodifiable(aggregateHistory),
    );
  }
}
```

The block is structurally symmetric with the loop in `_appendInTxn` (lines 498-519). Two intentional differences:

1. The append path looks up `def` non-null via `entryTypes.byId(entryType)!` (caller-supplied `entryType` is validated up front by `_validateAppendInputs`); the ingest path looks up via `entryTypes.byId(updatedEvent.entryType)` and tolerates `null` (a wire event whose `entry_type` is unknown to the receiver registry — falls through to "no materialize" gracefully; ingest already lets the event into the log so the receiver can later upgrade and rebuild via `rebuildView`). This preserves the receiver-stays-passive principle (REQ-d00154-E) — the lib does not mutate the registry on ingest.
2. `aggregateHistory` is read from `findEventsForAggregateInTxn` directly inside `_ingestOneInTxn` (not threaded down from a caller as in the append path) — this keeps the ingest method self-contained.

### Step 6 — Run new tests; expect green

```text
00:00 +4: All tests passed!
```

All 4 new tests pass.

### Step 7 — Run full suites

```text
00:05 +699: All tests passed!
```

Full lib suite: 695 (baseline) -> 699 (+4 new tests).

```text
01:05 +81: All tests passed!
```

Example suite: 81 / 81 passed. No regressions — existing `portal_sync_test` / `portal_soak_test` assert event counts and FIFO contents on the portal pane, not materialized-view rows, so they are unaffected by adding view writes on the ingest path.

### Step 8 — Analyze

```text
Analyzing event_sourcing_datastore...
No issues found! (ran in 0.8s)
```

```text
Analyzing example...
No issues found! (ran in 0.6s)
```

Three minor `unnecessary_parenthesis` lints in the test file were cleaned up (`(map[k]!.field)['idx']` -> `map[k]!.field['idx']`).

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`
  (~45 lines added inside `_ingestOneInTxn`: prior-history read, materializer loop annotated `// Implements: REQ-d00121-K, REQ-d00145-N`).

### test/ — new file

- `apps/common-dart/event_sourcing_datastore/test/event_store/event_store_ingest_materialize_test.dart` (4 tests, ~470 lines including `_RecordingMaterializer` and `_ThrowingTestMaterializer` test fixtures).

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 7 checkbox flipped; Task 7 details section appended.
- This file (`PHASE4.22_TASK_7.md`).

## Outcome

Receivers now project ingested user events into materialized views identically to local-appended events. The materializer loop on the ingest path is symmetric with the append-path loop:

- **Same gates**: outer `def.materialize` short-circuits system entry types (REQ-d00154-D); inner `m.appliesTo(event)` selects matching materializers.
- **Same atomicity**: per-event materializer writes happen inside the same transaction as `backend.appendEvent`, so the event log row and every view write land or rollback together (REQ-d00145-A all-or-nothing batch atomicity preserved).
- **Same throw semantics**: a materializer or promoter throw propagates out of `_ingestOneInTxn`, which rolls back the enclosing transaction (the entire batch on the `ingestBatch` path).

By REQ-d00121-A's purity property (`Materializer.apply` is a pure function), a receiver materializing a portal-bridged user event produces the same materialized-view shape as the originator producing it locally. This closes the Phase 4.9 design spec §398 deferral and unlocks Task 8 (receiver-stays-passive invariant tests + materialize:false regression test) and the subsequent demo / verification work in Tasks 9-11.
