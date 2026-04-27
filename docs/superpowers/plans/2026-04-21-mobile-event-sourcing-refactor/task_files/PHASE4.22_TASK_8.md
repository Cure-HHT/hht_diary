# Phase 4.22 Task 8 — Receiver-stays-passive invariant tests + materialize:false regression test (REQ-d00154-D, REQ-d00154-E, REQ-d00129-O)

## Goal

Verification-only task: write tests that prove two already-true invariants are still true. No library code changes.

1. **Receiver-stays-passive invariant (REQ-d00154-E + REQ-d00129-O)**: `EventStore.ingestEvent` (and by extension `EventStore.ingestBatch`, which routes through the same `_ingestOneInTxn`) SHALL NOT mutate `DestinationRegistry`, `EntryTypeRegistry`, or any per-destination FIFO state on the receiver. Bridged system audit events are stored in `event_log` only — they SHALL NOT trigger any registry-mutation or FIFO side effect.
2. **System entry types ship `materialize: false` (REQ-d00154-D)**: All 10 reserved system entry type definitions auto-registered by `bootstrapAppendOnlyDatastore` ship `materialize: false`. Regression intent: a future refactor that flips one of these to `true` would silently start firing materializers on cross-aggregate stream events (out of scope for Phase 4.22 — by REQ-d00154-D and the materializer's outer `def.materialize` gate, system audits never reach view-side projection).

## TDD Sequence

### Step 1 — Read `apps/common-dart/event_sourcing_datastore/lib/src/security/system_entry_types.dart`

Confirmed exports (re-exported by the package barrel `lib/event_sourcing_datastore.dart`):

- `kReservedSystemEntryTypeIds: Set<String>` — canonical 10-element set of reserved ids.
- `kSystemEntryTypes: List<EntryTypeDefinition>` — the 10 `EntryTypeDefinition` records auto-registered by `bootstrapAppendOnlyDatastore`. Every record ships `materialize: false`.

The 10 ids are:

1. `security_context_redacted`
2. `security_context_compacted`
3. `security_context_purged`
4. `system.destination_registered`
5. `system.destination_start_date_set`
6. `system.destination_end_date_set`
7. `system.destination_deleted`
8. `system.destination_wedge_recovered`
9. `system.retention_policy_applied`
10. `system.entry_type_registry_initialized`

### Step 2 — Write the materialize:false regression test

Approach: bootstrap an `AppendOnlyDatastore` and iterate over `kReservedSystemEntryTypeIds`, looking up each definition via `datastore.entryTypes.byId(id)`. This exercises the actual auto-registered `EntryTypeDefinition` instances rather than re-importing the internal `kSystemEntryTypes` list — so the test fails if a future refactor changes the bootstrap registration path or strips the `materialize: false` flag from a reserved entry type.

The test also asserts `kReservedSystemEntryTypeIds.length == 10` so adding a new system entry type forces an explicit decision on whether the new id ships `materialize: false`.

### Step 3 — Write the receiver-stays-passive invariant tests

Strategy: bootstrap two `AppendOnlyDatastore` instances with distinct `Source.identifier` values (one ORIGINATOR, one RECEIVER). The originator emits real system audit events as a side effect of its own configuration calls; those audit events are read off the originator's event log and shipped to the receiver via `EventStore.ingestEvent`. Then assert the receiver's registries / FIFOs are byte-identical pre vs post ingest, and that the audit was nonetheless stored in the receiver's `event_log`.

Two real bootstrapped datastores (rather than hand-rolling `StoredEvent` + Chain 1 hash + receiver Chain 2 stamping) keeps the test focused on the invariant under test — receiver passivity — without re-implementing the wire format.

Three scenarios in `test/ingest/ingest_does_not_mutate_local_state_test.dart`:

- **(a) `system.destination_registered`**: originator calls `addDestination` to emit a fresh audit. Receiver ingests. Asserts receiver's `DestinationRegistry.all()` IDs unchanged; the originator-side destination id (carried in `data.id`) does NOT appear on the receiver; the audit IS in the receiver's `event_log`.
- **(b) `system.entry_type_registry_initialized`**: originator bootstraps with a user entry type registered (`demo_note`); receiver bootstraps with no user entry types. Receiver ingests originator's bootstrap-emitted registry-init audit. Asserts receiver's `EntryTypeRegistry.all()` IDs unchanged and exactly equal to the 10 reserved system ids; `demo_note` does NOT appear on the receiver; audit IS in receiver's `event_log` under the originator's install aggregate.
- **(c) `system.destination_wedge_recovered`**: originator schedules its destination, appends one user event, runs `fillBatch` to enqueue a FIFO row, then calls `tombstoneAndRefill` to emit the wedge-recovery audit. Receiver ingests. Asserts receiver's FIFO snapshot (`listFifoEntries`) is byte-identical pre vs post (entryId + sequenceInQueue + finalStatus per row); `data.target_row_id` (an originator-private FIFO row id) does NOT appear in receiver FIFO; receiver `destinations.byId('orig-dest')` is null; audit IS in receiver's `event_log`.

The test file uses a minimal `_NoopDestination` extending `Destination` (filter, maxAccumulateTime, canAddToBatch, transform, send all stubbed — `send` throws if invoked because the tests never drain the receiver's FIFO; the rows exist for a passivity comparison only).

### Step 4 — Run tests; expect green on first run

```text
00:00 +1: All tests passed!  // materialize_false (1 test)
00:00 +3: All tests passed!  // receiver-passive (3 tests)
```

All 4 new tests pass on first run with no library changes. The invariants are already held by the existing implementation:

- The 10 reserved system entry types in `lib/src/security/system_entry_types.dart` all carry `materialize: false`.
- `EventStore._ingestOneInTxn` does not call `DestinationRegistry.addDestination`, `EntryTypeRegistry.register`, `tombstoneAndRefill`, or any FIFO write API — it only verifies Chain 1, idempotency-checks, stamps Chain 2 receiver provenance, recomputes `event_hash`, persists via `appendEvent`, and fires materializers gated on `def.materialize` (which short-circuits for system entry types per REQ-d00154-D).

### Step 5 — Run full suite

```text
00:06 +703: All tests passed!
```

Full lib suite: 699 (Task 7 baseline) -> 703 (+4 new tests).

### Step 6 — Analyze

```text
Analyzing event_sourcing_datastore...
No issues found! (ran in 0.8s)
```

Clean after fixing one `prefer_is_empty` lint inside the test's local `_NoopDestination` (`currentBatch.length < 1` -> `currentBatch.isEmpty`).

## Files Touched

### test/ — new files (only)

- `apps/common-dart/event_sourcing_datastore/test/security/system_entry_types_materialize_false_test.dart` (1 test, ~75 lines).
- `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_does_not_mutate_local_state_test.dart` (3 tests + `_NoopDestination` minimal Destination double, ~370 lines).

### lib/

No library changes. This is a verification-only task.

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 8 checkbox flipped; Task 8 details section appended.
- This file (`PHASE4.22_TASK_8.md`).

## Outcome

Receiver-stays-passive (REQ-d00154-E, REQ-d00129-O) is now covered by tests on every ingest mutation surface:

- A bridged `system.destination_registered` does not register a destination on the receiver.
- A bridged `system.entry_type_registry_initialized` does not register entry types on the receiver.
- A bridged `system.destination_wedge_recovered` does not touch the receiver's FIFO state.
- In every case the audit lands in the receiver's `event_log` for forensic / cross-hop observability (REQ-d00154-F admission), but the receiver's runtime configuration remains driven exclusively by its own local API calls.

The materialize:false regression test (REQ-d00154-D) covers the 10-element invariant: any future refactor that adds a new system entry type or flips an existing one to `materialize: true` will fail this test loudly, forcing an explicit Phase 4.22-spec-aware decision.

Test count: 699 -> 703.
