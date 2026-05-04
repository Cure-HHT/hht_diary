# Master Plan Phase 4.3: Dynamic destinations, batch FIFO, EntryService/Registry/bootstrap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 4.3 of 6 (new phase inserted 2026-04-22 between 4 and 5)
**Status**: Not Started
**Depends on**: Phase 4 squashed and phase-reviewed
**Design doc**: `docs/superpowers/2026-04-22-dynamic-destinations-and-demo-design.md` (§6 is this phase's scope)

## Scope

Library additions and retrofits that the demo in Phase 4.6 depends on. Three categories:

1. **Retrofits surfaced by the demo design** — `SyncPolicy` becomes a value object injectable into `drain`/`syncCycle`; `StorageBackend.markFinal`/`appendAttempt` tolerate missing row/store (closes the one non-trivial concurrency race documented in design §6.6).

2. **New library features** — dynamic destination lifecycle (add/remove, start/end dates, historical replay, graceful + hard deactivation), batch-capable FIFO (one row = one wire transaction = one or more events), `fill_cursor` per-destination watermark, unjam/rehabilitate ops.

3. **Pulled forward from Phase 5** — `EntryService.record` (with no-op detection, atomic write path, post-write `syncCycle` kick), `EntryTypeRegistry`, `bootstrapAppendOnlyDatastore`. Phase 5's plan is annotated accordingly; Phase 5 shrinks to cutover-only work.

**Produces:**
- `apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart` — refactored to value object.
- `apps/common-dart/append_only_datastore/lib/src/sync/fill_batch.dart` — new.
- `apps/common-dart/append_only_datastore/lib/src/destinations/destination.dart` — interface widened.
- `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart` — dynamic mutation API.
- `apps/common-dart/append_only_datastore/lib/src/destinations/destination_schedule.dart` — new; per-destination `startDate`/`endDate` storage.
- `apps/common-dart/append_only_datastore/lib/src/storage/fifo_entry.dart` — `event_ids: List<String>`, `event_id_range`.
- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` — `markFinal`/`appendAttempt` tolerate missing; `fill_cursor` accessors; batch-aware `enqueueFifo`; `readFifoHead` skips exhausted.
- `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart` — SendPermanent continues (skip); SendTransient-at-max continues.
- `apps/common-dart/append_only_datastore/lib/src/sync/sync_cycle.dart` — per-destination `fillBatch(dest)` then `drain(dest)`.
- `apps/common-dart/append_only_datastore/lib/src/ops/unjam.dart` — new.
- `apps/common-dart/append_only_datastore/lib/src/ops/rehabilitate.dart` — new.
- `apps/common-dart/append_only_datastore/lib/src/entry_service.dart` — new.
- `apps/common-dart/append_only_datastore/lib/src/entry_type_registry.dart` — new.
- `apps/common-dart/append_only_datastore/lib/src/bootstrap.dart` — new.
- `spec/dev-event-sourcing-mobile.md` — new REQ topics: `REQ-SYNCPOLICY-INJECTABLE`, `REQ-SKIPMISSING`, `REQ-BATCH`, `REQ-DYNDEST`, `REQ-REPLAY`, `REQ-UNJAM`, `REQ-REHAB`, `REQ-ENTRY`, `REQ-BOOTSTRAP`.

**Does not produce:**
- No UI code. The demo app is Phase 4.6.
- No HTTP, no FCM, no lifecycle triggers, no connectivity-plus. Phase 5.
- No real destinations. The demo's `DemoDestination` is Phase 4.6. `PrimaryDiaryServerDestination` is Phase 5.
- No screen updates in `clinical_diary`. Phase 5.

## Execution Rules

Read [README.md](README.md) in full before starting. TDD cadence, REQ citation format, phase-squash procedure, cross-phase invariants, and REQ-d discovery via `discover_requirements("...")` all apply.

Read design doc `docs/superpowers/2026-04-22-dynamic-destinations-and-demo-design.md` §5 (decisions) and §6 (library spec) before Task 3. Before Task 11 (fillBatch), re-read §6.4. Before Task 14 (unjam), re-read §6.2.

Phase 4 is assumed complete and squashed before Task 1. Some of this phase's refactors touch Phase-4 files (FifoEntry shape, drain logic, StorageBackend signatures); those touches are called out per-task.

## Applicable REQ assertions

Numbers claimed at Task 3 via `discover_requirements("next available REQ-d")`. All land in `spec/dev-event-sourcing-mobile.md`.

| REQ topic | Scope | Assertions |
| --- | --- | --- |
| `REQ-SYNCPOLICY-INJECTABLE` | value-object refactor + optional override | A, B, C |
| `REQ-SKIPMISSING` | `markFinal`/`appendAttempt` no-op on missing | A, B, C |
| `REQ-BATCH` | FIFO-row-as-batch; `canAddToBatch`; `fill_cursor`; `fillBatch` | A-H |
| `REQ-DYNDEST` | `addDestination`, `setStartDate`/`setEndDate`, `deactivate`, `delete` | A-I |
| `REQ-REPLAY` | historical replay on `setStartDate(past)` | A, B, C |
| `REQ-UNJAM` | precondition, pending-deletion, exhausted-preserve, rewind | A-E |
| `REQ-REHAB` | single-row and bulk variants | A-D |
| `REQ-ENTRY` | `EntryService.record` contract | A-I (REQ-ENTRY-D revised per design §6.8) |
| `REQ-BOOTSTRAP` | single init point, collision detection | A-D |

Plus existing applicable: `REQ-p00004`, `REQ-p00006`, `REQ-p00013`, `REQ-p01001`, `REQ-DEST`, `REQ-DRAIN`, `REQ-SYNC`, `REQ-d00004`. (`REQ-DEST-D/G` and `REQ-DRAIN-A/D/E/G/H` were already revised in `PLAN_PHASE4_sync.md` for this phase's batch-FIFO + skip-exhausted shape.)

REQ citation placement: `// Implements: REQ-xxx-Y — <prose>` per-function; `// Verifies: REQ-xxx-Y — <prose>` per-test, and the assertion ID must start the test description: `test('REQ-xxx-Y: description', () { ... })`.

---

## Plan

### Task 1: Baseline verification

**TASK_FILE**: `PHASE4.3_TASK_1.md`

- [ ] **Confirm Phase 4 complete**: `git log --oneline` shows Phase 4's squashed commit `[CUR-1154] Phase 4: ...` as HEAD (or immediately behind review fixups).
- [ ] **Stay on shared branch** `mobile-event-sourcing-refactor`.
- [ ] **Rebase onto main**: `git fetch origin main && git rebase origin/main`. Four squashed phase commits should remain.
- [ ] **Baseline tests green**: `(cd apps/common-dart/append_only_datastore && dart test)` passes. `(cd apps/common-dart/provenance && dart test)` passes. `(cd apps/common-dart/trial_data_types && dart test)` passes. `(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)` passes with no errors.
- [ ] **Create TASK_FILE** recording: Phase 4 completion SHA, baseline test results.

---

### Task 2: Parent plan file updates

**TASK_FILE**: `PHASE4.3_TASK_2.md`

Surgical annotations to two plan files. No code.

**Files:**
- Modify: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md`
- Modify: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE5_cutover.md`

- [ ] **README phase-table update**: add rows for 4.3 and 4.6 between Phase 4 and Phase 5. Exact markdown diff for the "Phase sequence" table:

```markdown
| # | Plan file | Scope | Risk |
| - | --- | --- | --- |
| 1 | [PLAN_PHASE1_foundations.md](PLAN_PHASE1_foundations.md) | New `provenance` package + `EntryTypeDefinition` data type | None — pure additions |
| 2 | [PLAN_PHASE2_storage_backend.md](PLAN_PHASE2_storage_backend.md) | `StorageBackend` abstract + `SembastBackend` concrete; `EventRepository` delegates through it | Low — behavior preserved |
| 3 | [PLAN_PHASE3_materialization.md](PLAN_PHASE3_materialization.md) | `DiaryEntry` view, materializer, `rebuildMaterializedView()` | Low — view populated but not yet read by UI |
| 4 | [PLAN_PHASE4_sync.md](PLAN_PHASE4_sync.md) | `Destination`, `SubscriptionFilter`, `DestinationRegistry`, `FifoEntry`, `SyncPolicy`, drain loop, `sync_cycle()` (batch-FIFO + skip-exhausted per 2026-04-22 design) | Low — machinery in place, nothing calls it yet |
| 4.3 | [PLAN_PHASE4.3_library.md](PLAN_PHASE4.3_library.md) | Dynamic destinations, batch-FIFO migration, unjam/rehabilitate, `EntryService`/`EntryTypeRegistry`/`bootstrap` pulled forward | Medium — large library phase |
| 4.6 | [PLAN_PHASE4.6_demo.md](PLAN_PHASE4.6_demo.md) | Flutter Linux-desktop demo app at `append_only_datastore/example/` | Low — no production callers |
| 5 | [PLAN_PHASE5_cutover.md](PLAN_PHASE5_cutover.md) | `PrimaryDiaryServerDestination`, `portalInboundPoll`, widget registry, triggers, screen updates, delete `NosebleedService` / `QuestionnaireService` (shrunk: EntryService/Registry/bootstrap moved to 4.3) | High — behavior change, old code removed |
```

- [ ] **PLAN_PHASE5 annotations**: Prepend a short `> **Note (2026-04-22):** ...` block at the top of PLAN_PHASE5_cutover.md after its metadata header, listing the three tasks that moved to Phase 4.3 (EntryService creation, EntryTypeRegistry creation, bootstrap creation). Tasks 3, 4, 5 inside PLAN_PHASE5 get an inline `> Moved to Phase 4.3 (2026-04-22)` prefix. Don't delete them — a Phase-5 reader needs to know what is handled upstream.

- [ ] **Dev-spec path check**: confirm `spec/dev-event-sourcing-mobile.md` exists (Phase 1 created it per parent plan README). If absent, create with the standard template header (title, description, INDEX entry); flag to user before proceeding.

- [ ] **Commit**: `git add docs/superpowers/plans/... && git commit -m "[CUR-1154] Phase 4.3: Insert 4.3/4.6 into plan index; annotate moved Phase 5 tasks"`.

---

### Task 3: Spec additions — claim REQ-d numbers and write new REQ topics

**TASK_FILE**: `PHASE4.3_TASK_3.md`

Nine new REQ topics land in `spec/dev-event-sourcing-mobile.md`. Numbers claimed via `discover_requirements("next available REQ-d")` — one query returns nine consecutive REQ-d numbers, or nine queries if the tool issues one at a time.

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md`

- [ ] **Run `discover_requirements("next available REQ-d")`** nine times (or batched), record each returned REQ-d number into TASK_FILE with its mapped topic.
- [ ] **Run `discover_requirements("destination lifecycle schedule batch")`** and record existing applicable assertions into TASK_FILE.
- [ ] **Run `discover_requirements("event service atomic transaction no-op")`** and record existing applicable assertions.
- [ ] **Write the nine new REQ topics** into `spec/dev-event-sourcing-mobile.md`, each with the assertion text below. Replace the placeholder REQ-d numbers with claimed ones.

**REQ-SYNCPOLICY-INJECTABLE** — assertions A-C:
- A: `SyncPolicy` SHALL be a value class with `final` fields and a `const` constructor. Default values remain as `SyncPolicy.defaults` (a `static const` instance).
- B: `drain()` and `syncCycle()` SHALL accept an optional `SyncPolicy? policy` parameter; when null, they SHALL fall back to `SyncPolicy.defaults`.
- C: Existing Phase-4 call sites (tests, internal uses) that read `SyncPolicy.initialBackoff` (etc.) as static members continue to compile via the `defaults` instance-member form `SyncPolicy.defaults.initialBackoff`; the refactor SHALL produce a deprecation-free migration (no `@Deprecated` shims).

**REQ-SKIPMISSING** — assertions A-C:
- A: `StorageBackend.markFinal(destId, entryId, finalStatus)` SHALL be a no-op (return without throwing) if the FIFO row identified by `entryId` does not exist in the destination's FIFO store.
- B: `StorageBackend.appendAttempt(destId, entryId, attempt)` SHALL be a no-op on missing row or missing FIFO store, same as `markFinal`.
- C: Both methods SHALL emit a diagnostic log line (at `warning` level) when they no-op due to a missing target: `"markFinal: row $entryId absent from FIFO $destId; skipping (expected during unjam/delete race)"`.

**REQ-BATCH** — assertions A-H:
- A: `FifoEntry.event_ids` SHALL be a non-empty `List<String>` identifying every event included in the batch.
- B: `FifoEntry.event_id_range` SHALL be a pair `(first_seq: int, last_seq: int)` from the contained events' `sequence_number`s — used for cursor math.
- C: `FifoEntry.wire_payload` SHALL be one `WirePayload` covering the entire batch.
- D: `Destination.transform(List<Event> batch)` SHALL produce one `WirePayload`; it SHALL NOT be called with an empty batch.
- E: `Destination.canAddToBatch(List<Event> currentBatch, Event candidate)` SHALL be called by `fillBatch` each time a candidate is considered; returning `false` SHALL end the current batch and either flush it (if non-empty and time-window or size warrants) or leave the candidate for the next tick.
- F: `Destination.maxAccumulateTime: Duration` SHALL be honored by `fillBatch`: a batch with only one event SHALL NOT flush until `now() - batch.first.client_timestamp >= maxAccumulateTime` OR `canAddToBatch` has returned false (indicating size cap).
- G: `backend_state` SHALL store `fill_cursor_{destination_id}: int` for each registered destination — the last `sequence_number` that has been promoted into any FIFO row (pending, sent, or exhausted).
- H: `fillBatch(destination)` SHALL be idempotent: repeated invocations with no new matching events SHALL produce no new FIFO rows and SHALL NOT advance `fill_cursor`.

**REQ-DYNDEST** — assertions A-I:
- A: `DestinationRegistry.addDestination(Destination d)` SHALL register `d` at any time after bootstrap. `d.id` SHALL be unique; collision throws `ArgumentError`.
- B: `Destination.allowHardDelete: bool get` SHALL default to `false` in the abstract class contract; concrete destinations opt in explicitly.
- C: `DestinationRegistry.setStartDate(String id, DateTime startDate)` SHALL throw `StateError` if the destination already has a non-null `startDate`. Once set, it is immutable for the lifetime of this destination registration.
- D: If `setStartDate` is called with `startDate <= now()`, the library SHALL trigger historical replay synchronously in the same transaction (see `REQ-REPLAY`).
- E: If `setStartDate` is called with `startDate > now()`, no replay occurs; events accumulate in `event_log` and are batched into the FIFO only after wall-clock crosses `startDate` (enforced by `fillBatch`'s window check).
- F: `DestinationRegistry.setEndDate(String id, DateTime endDate)` SHALL return a `SetEndDateResult` enum: `closed` (endDate <= now), `scheduled` (endDate > now), `applied` (no relative-time state change).
- G: `DestinationRegistry.deactivateDestination(String id)` SHALL be equivalent to `setEndDate(id, DateTime.now())` and SHALL return `closed`.
- H: `DestinationRegistry.deleteDestination(String id)` SHALL throw `StateError` if the destination's `allowHardDelete == false`. When allowed, it SHALL unregister the destination and hard-delete its FIFO store in one transaction.
- I: `fillBatch(dest)` SHALL filter candidates by `event.client_timestamp >= dest.startDate AND event.client_timestamp <= min(dest.endDate, now())`. Events outside this window are never enqueued to this destination.

**REQ-REPLAY** — assertions A-C:
- A: Historical replay SHALL be a single-transaction walk of `event_log` from `fill_cursor + 1` forward, filtering by `dest.subscriptionFilter` AND the time window from `REQ-DYNDEST-I`.
- B: Replay SHALL use the destination's own `canAddToBatch` and `transform` to produce FIFO rows identical in shape to those `fillBatch` produces during live operation.
- C: A new event appended DURING replay (same Dart isolate, sembast transaction serialization) SHALL NOT be double-enqueued: the `record` transaction waits behind the replay transaction; when `record` runs, `fillBatch` re-evaluates candidates since the current `fill_cursor` (which replay has already advanced).

**REQ-UNJAM** — assertions A-E:
- A: `unjamDestination(String id)` SHALL throw `StateError` if the destination is active (`endDate == null` or `endDate > now()`). The destination MUST be deactivated first.
- B: Inside one transaction, unjam SHALL delete every FIFO row where `final_status == pending`.
- C: Inside the same transaction, unjam SHALL leave every FIFO row where `final_status == exhausted` untouched (audit preservation).
- D: Inside the same transaction, unjam SHALL rewind `fill_cursor` to `max(event_id_range.last_seq from rows where final_status == sent)`, or to `-1` if no such row exists.
- E: `unjamDestination` SHALL return `UnjamResult { deletedPending: int, rewoundTo: int }`.

**REQ-REHAB** — assertions A-D:
- A: `rehabilitateExhaustedRow(String destId, String fifoRowId)` SHALL throw `ArgumentError` if the row doesn't exist or its `final_status != exhausted`.
- B: On success, the row's `final_status` SHALL be set to `pending`; `attempts[]` SHALL be preserved unchanged.
- C: `rehabilitateAllExhausted(String destId)` SHALL flip every exhausted row on this destination to pending and return the count.
- D: Rehabilitate SHALL be permitted on an active destination (unlike unjam).

**REQ-ENTRY** — assertions A-I (A-C, E-I match Phase-5 PLAN_PHASE5 Task 2; **D is revised per design §6.8**):
- A: `EntryService.record({entryType, aggregateId, eventType, answers, checkpointReason?, changeReason?})` SHALL be the sole write API invoked by widgets.
- B: `EntryService` SHALL assign `event_id`, `sequence_number`, `previous_event_hash`, `event_hash`, and the first `ProvenanceEntry` atomically before the write.
- C: `eventType` SHALL be one of `finalized`, `checkpoint`, `tombstone`. Any other value SHALL cause `EntryService.record` to throw `ArgumentError` before any I/O.
- D *(revised)*: `EntryService.record` SHALL perform the local write path in one `StorageBackend.transaction()`: append event, run materializer, upsert `diary_entries` row, increment sequence counter. Per-destination FIFO fan-out is DEFERRED to `fillBatch` (invoked on the next `syncCycle` tick). The transaction SHALL NOT invoke any destination's `transform` or `send`.
- E: A failure inside step D (materializer or storage error) SHALL abort the whole write — no event appended.
- F: `EntryService.record` SHALL detect no-ops: if the computed content hash of `(event_type, canonical(answers), checkpoint_reason, change_reason)` equals the hash of the most recent event on the same aggregate, the call SHALL return successfully without writing.
- G: After a successful write, `EntryService` SHALL invoke `syncCycle()` fire-and-forget (`unawaited`). The caller MAY NOT rely on sync completion before returning.
- H: `EntryService` SHALL validate that `entryType` is registered in the `EntryTypeRegistry` before accepting the write.
- I: `EntryService` SHALL populate the event's migration-bridge top-level fields (`client_timestamp`, `device_id`, `software_version`) from `metadata.provenance[0]`.

**REQ-BOOTSTRAP** — assertions A-D (identical to PLAN_PHASE5 Task 2):
- A: `bootstrapAppendOnlyDatastore({backend, entryTypes, destinations})` SHALL be the single entry point for initializing the datastore from an app's `main()`.
- B: The function SHALL register all supplied `EntryTypeDefinition` entries into the `EntryTypeRegistry` before any `Destination` is registered.
- C: The function SHALL register all supplied `Destination` instances into the `DestinationRegistry` via `addDestination`. (Registry is no longer boot-frozen per `REQ-DYNDEST-A`; additional destinations may be added at runtime.)
- D: Destinations with `id` collisions SHALL cause bootstrap to throw; the app SHALL NOT proceed to UI rendering.

- [ ] **Update `spec/INDEX.md`** with the nine new REQ-d IDs and their content hashes (computed with the repo's existing REQ-content-hash tool, likely `tools/requirements/recompute-hashes.py` or similar).
- [ ] **Commit**: `git add spec/dev-event-sourcing-mobile.md spec/INDEX.md && git commit -m "[CUR-1154] Phase 4.3 spec additions: batch FIFO, dynamic destinations, unjam/rehab, EntryService/bootstrap"`.

---

### Task 4: SyncPolicy value-object refactor

**TASK_FILE**: `PHASE4.3_TASK_4.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart`
- Modify: `apps/common-dart/append_only_datastore/test/sync/sync_policy_test.dart` (existing Phase-4 tests; adapt to value-object form)
- Modify: `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/sync/sync_cycle.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/sync/fake_destination.dart` (test double) if it references SyncPolicy by static.

**Applicable assertions**: REQ-SYNCPOLICY-INJECTABLE-A, B, C.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests** in `sync_policy_test.dart`:

```dart
// Verifies: REQ-SYNCPOLICY-INJECTABLE-A — value object with final fields.
test('REQ-SYNCPOLICY-INJECTABLE-A: SyncPolicy can be const-constructed with custom values', () {
  const policy = SyncPolicy(
    initialBackoff: Duration(seconds: 2),
    backoffMultiplier: 3.0,
    maxBackoff: Duration(minutes: 1),
    jitterFraction: 0.2,
    maxAttempts: 5,
    periodicInterval: Duration(seconds: 30),
  );
  expect(policy.initialBackoff, const Duration(seconds: 2));
  expect(policy.backoffMultiplier, 3.0);
});

// Verifies: REQ-SYNCPOLICY-INJECTABLE-A — defaults static const.
test('REQ-SYNCPOLICY-INJECTABLE-A: SyncPolicy.defaults matches prior Phase-4 constants', () {
  expect(SyncPolicy.defaults.initialBackoff, const Duration(seconds: 60));
  expect(SyncPolicy.defaults.backoffMultiplier, 5.0);
  expect(SyncPolicy.defaults.maxBackoff, const Duration(hours: 2));
  expect(SyncPolicy.defaults.jitterFraction, 0.1);
  expect(SyncPolicy.defaults.maxAttempts, 20);
  expect(SyncPolicy.defaults.periodicInterval, const Duration(minutes: 15));
});

// Verifies: REQ-SYNCPOLICY-INJECTABLE-A — backoffFor uses instance values.
test('REQ-SYNCPOLICY-INJECTABLE-A: backoffFor reflects instance values, not statics', () {
  const fast = SyncPolicy(
    initialBackoff: Duration(seconds: 1),
    backoffMultiplier: 1.0,
    maxBackoff: Duration(seconds: 10),
    jitterFraction: 0.0,
    maxAttempts: 3,
    periodicInterval: Duration(seconds: 1),
  );
  expect(fast.backoffFor(0), const Duration(seconds: 1));
  expect(fast.backoffFor(1), const Duration(seconds: 1)); // mult=1
  expect(fast.backoffFor(5), const Duration(seconds: 1)); // mult=1 capped
});
```

- [ ] **Run tests; confirm failure** for the right reason (SyncPolicy's current shape is static-only).

- [ ] **Refactor `sync_policy.dart`** to a value class:

```dart
// Implements: REQ-SYNCPOLICY-INJECTABLE-A — value object form.
class SyncPolicy {
  final Duration initialBackoff;
  final double backoffMultiplier;
  final Duration maxBackoff;
  final double jitterFraction;
  final int maxAttempts;
  final Duration periodicInterval;

  const SyncPolicy({
    required this.initialBackoff,
    required this.backoffMultiplier,
    required this.maxBackoff,
    required this.jitterFraction,
    required this.maxAttempts,
    required this.periodicInterval,
  });

  // Implements: REQ-SYNCPOLICY-INJECTABLE-A — defaults preserved from Phase 4.
  static const SyncPolicy defaults = SyncPolicy(
    initialBackoff: Duration(seconds: 60),
    backoffMultiplier: 5.0,
    maxBackoff: Duration(hours: 2),
    jitterFraction: 0.1,
    maxAttempts: 20,
    periodicInterval: Duration(minutes: 15),
  );

  Duration backoffFor(int attemptCount, {Random? random}) {
    // identical algorithm to Phase 4, but reading instance fields instead of statics.
    // ... (preserve existing jitter math)
  }
}
```

- [ ] **Write failing tests** for optional-param threading in `drain_test.dart` and `sync_cycle_test.dart`:

```dart
// Verifies: REQ-SYNCPOLICY-INJECTABLE-B — drain falls back to defaults when policy is null.
test('REQ-SYNCPOLICY-INJECTABLE-B: drain(destination) with no policy param uses defaults', () async {
  // ... existing drain test body, no policy arg passed
});

// Verifies: REQ-SYNCPOLICY-INJECTABLE-B — drain uses custom policy when provided.
test('REQ-SYNCPOLICY-INJECTABLE-B: drain(destination, policy: fast) applies custom backoff', () async {
  const fast = SyncPolicy(initialBackoff: Duration(milliseconds: 50), /* ... */);
  // transient failure, verify retry cadence matches fast.initialBackoff
});
```

- [ ] **Add optional param to `drain`**:

```dart
// Implements: REQ-SYNCPOLICY-INJECTABLE-B — drain accepts policy override.
Future<void> drain(
  Destination destination, {
  required StorageBackend backend,
  Clock? clock,
  SyncPolicy? policy,
}) async {
  final effective = policy ?? SyncPolicy.defaults;
  // ... rest of drain, reading effective.<field> throughout
}
```

Same for `syncCycle`. Propagate `policy` to per-destination `drain` calls.

- [ ] **Update any `_FakeDestination` / test helpers** that referenced `SyncPolicy.initialBackoff` statically → `SyncPolicy.defaults.initialBackoff`.

- [ ] **Run all tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: Refactor SyncPolicy to injectable value object"`.

---

### Task 5: StorageBackend markFinal/appendAttempt tolerate missing

**TASK_FILE**: `PHASE4.3_TASK_5.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (abstract signatures + doc comments)
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` (concrete)
- Modify: `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`

**Applicable assertions**: REQ-SKIPMISSING-A, B, C.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-SKIPMISSING-A — markFinal no-op on missing row.
test('REQ-SKIPMISSING-A: markFinal on nonexistent row does not throw', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  // no entries enqueued
  expect(() => backend.markFinal('primary', 'nonexistent-id', FinalStatus.sent),
         returnsNormally);
});

// Verifies: REQ-SKIPMISSING-A — markFinal no-op on missing store (destination unknown).
test('REQ-SKIPMISSING-A: markFinal on missing FIFO store does not throw', () async {
  final backend = await openInMemoryBackend();
  expect(() => backend.markFinal('never-registered', 'any-id', FinalStatus.exhausted),
         returnsNormally);
});

// Verifies: REQ-SKIPMISSING-B — appendAttempt same tolerance.
test('REQ-SKIPMISSING-B: appendAttempt on missing row does not throw', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  expect(() => backend.appendAttempt('primary', 'nonexistent-id',
         AttemptResult.transient(attemptedAt: DateTime.now(), error: 'x')),
         returnsNormally);
});

// Verifies: REQ-SKIPMISSING-C — warning logged.
test('REQ-SKIPMISSING-C: markFinal on missing row logs a warning', () async {
  final backend = await openInMemoryBackend();
  final logs = <String>[];
  // inject a logger into backend (test support)
  backend.debugLogSink = logs.add;
  await backend.markFinal('primary', 'nonexistent-id', FinalStatus.sent);
  expect(logs.where((l) => l.contains('markFinal') && l.contains('absent')), isNotEmpty);
});
```

- [ ] **Run tests; confirm failure** (current Phase-4 implementation throws on missing).

- [ ] **Update doc comments on abstract `StorageBackend`**:

```dart
abstract class StorageBackend {
  /// Marks a FIFO row's final status.
  ///
  /// Implements: REQ-SKIPMISSING-A — if the row or the destination's FIFO
  /// store does not exist, this method SHALL be a no-op (return without
  /// throwing). A warning SHALL be logged at level `warning`. This tolerance
  /// exists to close the drain-mid-flight race documented in design §6.6:
  /// drain's `await send()` is non-transactional, and a concurrent user op
  /// (unjam, deleteDestination) may remove the row before drain's subsequent
  /// markFinal transaction runs.
  Future<void> markFinal(String destId, String entryId, FinalStatus status);

  /// Appends an attempt to a FIFO row's attempts[].
  ///
  /// Implements: REQ-SKIPMISSING-B — same no-op-on-missing behavior as markFinal.
  Future<void> appendAttempt(String destId, String entryId, AttemptResult attempt);
  // ...
}
```

- [ ] **Update `SembastBackend.markFinal` and `appendAttempt` implementations**:

```dart
// Implements: REQ-SKIPMISSING-A — tolerate missing row or missing store.
@override
Future<void> markFinal(String destId, String entryId, FinalStatus status) async {
  final store = _fifoStoreOrNull(destId);
  if (store == null) {
    _log.warning('markFinal: FIFO store for destination "$destId" absent; skipping (expected during unjam/delete race)');
    return;
  }
  final record = await store.record(entryId).get(_db);
  if (record == null) {
    _log.warning('markFinal: row $entryId absent from FIFO $destId; skipping (expected during unjam/delete race)');
    return;
  }
  // ... existing update logic
}
```

- [ ] **Add `debugLogSink` hook** to `SembastBackend` (guarded with `@visibleForTesting`) so tests can capture warnings without depending on the app-wide logger.

- [ ] **Run tests; confirm pass.** Run `dart analyze`.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: markFinal/appendAttempt tolerate missing row/store (REQ-SKIPMISSING)"`.

---

### Task 6: FifoEntry shape migration — event_ids, event_id_range, batch wire_payload

**TASK_FILE**: `PHASE4.3_TASK_6.md`

Breaking change to the Phase-4 `FifoEntry` shape. Because Phase 4 is done but has no production caller, the migration is purely code + test; no data migration.

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/fifo_entry.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (enqueueFifo signature)
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` (enqueueFifo impl, persistence schema)
- Modify: every test file that constructs FifoEntry or calls enqueueFifo (`test/storage/*.dart`, `test/destinations/*.dart`, `test/sync/*.dart`)

**Applicable assertions**: REQ-BATCH-A, B, C.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests** in `fifo_entry_test.dart`:

```dart
// Verifies: REQ-BATCH-A — event_ids is a non-empty List<String>.
test('REQ-BATCH-A: FifoEntry.event_ids is a non-empty List', () {
  final entry = FifoEntry.create(
    destinationId: 'primary',
    eventIds: ['evt-1', 'evt-2', 'evt-3'],
    eventIdRange: (firstSeq: 10, lastSeq: 12),
    wirePayload: WirePayload(bytes: utf8.encode('{"batch":[...]}'),
                             contentType: 'application/json',
                             transformVersion: 'v1'),
    // ...
  );
  expect(entry.eventIds, hasLength(3));
  expect(entry.eventIds, contains('evt-1'));
});

// Verifies: REQ-BATCH-B — event_id_range available.
test('REQ-BATCH-B: FifoEntry.eventIdRange provides first_seq and last_seq', () {
  final entry = FifoEntry.create(/* ... */, eventIdRange: (firstSeq: 10, lastSeq: 12));
  expect(entry.eventIdRange.firstSeq, 10);
  expect(entry.eventIdRange.lastSeq, 12);
});

// Verifies: REQ-BATCH-C — single wire_payload for the batch.
test('REQ-BATCH-C: FifoEntry has one wirePayload covering all events', () {
  final payload = WirePayload(bytes: utf8.encode('{"batch": [e1,e2,e3]}'),
                              contentType: 'application/json',
                              transformVersion: 'v1');
  final entry = FifoEntry.create(/* ... */, wirePayload: payload);
  expect(entry.wirePayload, payload);
});

// Verifies: empty-batch rejection at construction.
test('REQ-BATCH-A: FifoEntry.create with empty eventIds throws ArgumentError', () {
  expect(() => FifoEntry.create(/* ... */, eventIds: []), throwsArgumentError);
});
```

- [ ] **Run tests; confirm failure** (current Phase-4 FifoEntry has scalar event_id).

- [ ] **Update `FifoEntry`**:

```dart
class FifoEntry {
  final String destinationId;
  final int sequenceInQueue;
  final List<String> eventIds;                    // REQ-BATCH-A
  final EventIdRange eventIdRange;                 // REQ-BATCH-B
  final WirePayload wirePayload;                   // REQ-BATCH-C
  final DateTime enqueuedAt;
  final List<AttemptResult> attempts;
  final FinalStatus finalStatus;
  final DateTime? sentAt;

  FifoEntry({/* ... */})
    : assert(eventIds.isNotEmpty, 'FifoEntry.eventIds must be non-empty (REQ-BATCH-A)');
  // toJson / fromJson updated; see sembast persistence below.
}

typedef EventIdRange = ({int firstSeq, int lastSeq});
```

- [ ] **Update `StorageBackend.enqueueFifo` signature**:

```dart
// Implements: REQ-BATCH-A+B+C — enqueue a batch as one FIFO row.
Future<FifoEntry> enqueueFifo(
  String destinationId,
  List<StoredEvent> batch,
  WirePayload wirePayload,
);
```

Replaces the Phase-4 signature that took a single `StoredEvent` + `WirePayload`. Extract `eventIds` and `eventIdRange` inside the implementation.

- [ ] **Update `SembastBackend.enqueueFifo`** accordingly. Sembast row schema: `eventIds` stored as a JSON array of strings; `eventIdRange` stored as `{first_seq: int, last_seq: int}`.

- [ ] **Update every test that called `enqueueFifo`** — convert single-event enqueues to single-element batches. Write a test helper `enqueueSingle(backend, dest, event)` that wraps the new shape for legibility in tests that don't care about batching.

- [ ] **Update every test that constructed a FifoEntry** — wrap event_id into `eventIds: [event_id]`, add `eventIdRange: (firstSeq: event.sequence_number, lastSeq: event.sequence_number)`.

- [ ] **Run all tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: FifoEntry batch shape migration (REQ-BATCH)"`.

---

### Task 7: fill_cursor persistence in backend_state

**TASK_FILE**: `PHASE4.3_TASK_7.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (add accessors)
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` (store under key `fill_cursor_<destId>` in backend_state)
- Modify: `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`

**Applicable assertions**: REQ-BATCH-G.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-BATCH-G — fill_cursor per destination.
test('REQ-BATCH-G: readFillCursor returns -1 when unset', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  expect(await backend.readFillCursor('primary'), -1);
});

test('REQ-BATCH-G: writeFillCursor then readFillCursor round-trips', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  await backend.writeFillCursor('primary', 42);
  expect(await backend.readFillCursor('primary'), 42);
});

test('REQ-BATCH-G: writeFillCursor inside a transaction participates in atomicity', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  // attempt an advance + a failing operation in one tx; confirm rollback
  try {
    await backend.transaction((txn) async {
      await backend.writeFillCursorTxn(txn, 'primary', 100);
      throw StateError('force rollback');
    });
  } catch (_) {}
  expect(await backend.readFillCursor('primary'), -1); // rolled back
});

test('REQ-BATCH-G: fill_cursor is per-destination', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  await backend.registerDestination('secondary');
  await backend.writeFillCursor('primary', 10);
  await backend.writeFillCursor('secondary', 99);
  expect(await backend.readFillCursor('primary'), 10);
  expect(await backend.readFillCursor('secondary'), 99);
});
```

- [ ] **Run tests; confirm failure** (methods don't exist yet).

- [ ] **Add abstract signatures to `StorageBackend`**:

```dart
// Implements: REQ-BATCH-G — per-destination fill cursor.
Future<int> readFillCursor(String destId);
Future<void> writeFillCursor(String destId, int sequenceNumber);
Future<void> writeFillCursorTxn(Txn txn, String destId, int sequenceNumber);
```

- [ ] **Implement in `SembastBackend`** — store under `backend_state` key `fill_cursor_$destId`. Read returns -1 if unset.

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: Per-destination fill_cursor in backend_state (REQ-BATCH-G)"`.

---

### Task 8: readFifoHead skips exhausted

**TASK_FILE**: `PHASE4.3_TASK_8.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` (readFifoHead filter)
- Modify: `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`

**Applicable assertions**: REQ-DRAIN-A (already revised in PLAN_PHASE4_sync.md).

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-DRAIN-A — readFifoHead returns first pending, not first row.
test('REQ-DRAIN-A: readFifoHead skips exhausted rows and returns first pending', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  final e1 = await enqueueSingle(backend, 'primary', mkEvent(seq: 1));
  final e2 = await enqueueSingle(backend, 'primary', mkEvent(seq: 2));
  final e3 = await enqueueSingle(backend, 'primary', mkEvent(seq: 3));
  await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
  await backend.markFinal('primary', e2.entryId, FinalStatus.exhausted);
  final head = await backend.readFifoHead('primary');
  expect(head?.entryId, e3.entryId);
  expect(head?.finalStatus, FinalStatus.pending);
});

// Verifies: REQ-DRAIN-A — readFifoHead returns null when only sent and exhausted exist.
test('REQ-DRAIN-A: readFifoHead returns null when no pending rows remain', () async {
  final backend = await openInMemoryBackend();
  await backend.registerDestination('primary');
  final e1 = await enqueueSingle(backend, 'primary', mkEvent(seq: 1));
  await backend.markFinal('primary', e1.entryId, FinalStatus.exhausted);
  expect(await backend.readFifoHead('primary'), isNull);
});
```

- [ ] **Run tests; confirm failure** (current impl returns first-inserted, not first-pending).

- [ ] **Update `SembastBackend.readFifoHead`**:

```dart
// Implements: REQ-DRAIN-A — return first pending row; exhausted rows are skipped.
@override
Future<FifoEntry?> readFifoHead(String destId) async {
  final store = _fifoStoreOrNull(destId);
  if (store == null) return null;
  final finder = Finder(
    filter: Filter.equals('final_status', FinalStatus.pending.toJson()),
    sortOrders: [SortOrder('sequence_in_queue')],
    limit: 1,
  );
  final record = await store.findFirst(_db, finder: finder);
  return record == null ? null : FifoEntry.fromMap(record.value);
}
```

- [ ] **Run tests; confirm pass.** Run the existing drain tests too — they should still pass, because the revised drain semantics (Task 13) are the consumer of this change. The Phase-4 drain tests were updated when PLAN_PHASE4_sync.md was revised.

- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: readFifoHead skips exhausted rows (REQ-DRAIN-A)"`.

---

### Task 9: Destination interface widening

**TASK_FILE**: `PHASE4.3_TASK_9.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/destinations/destination.dart`
- Modify: `apps/common-dart/append_only_datastore/test/test_support/fake_destination.dart` (test double)
- Modify: every test that constructs a `_FakeDestination` to include the new interface surface

**Applicable assertions**: REQ-DEST-D (already revised in PLAN_PHASE4_sync.md), REQ-BATCH-D, E, F, REQ-DYNDEST-B.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests** in `destination_test.dart`:

```dart
// Verifies: REQ-BATCH-D — transform takes a batch.
test('REQ-BATCH-D: Destination.transform(List<Event>) produces one WirePayload', () async {
  final dest = _FakeDestination(
    id: 'test',
    scriptedResults: [],
    batchCapacity: 10,
  );
  final payload = await dest.transform([mkEvent(seq: 1), mkEvent(seq: 2)]);
  expect(payload.bytes, isNotEmpty);
});

// Verifies: REQ-BATCH-D — empty batch is invalid input (guard).
test('REQ-BATCH-D: Destination.transform rejects empty batch', () async {
  final dest = _FakeDestination(/* ... */);
  expect(() => dest.transform([]), throwsArgumentError);
});

// Verifies: REQ-BATCH-E — canAddToBatch returns false at capacity.
test('REQ-BATCH-E: canAddToBatch returns true under capacity, false at capacity', () {
  final dest = _FakeDestination(id: 'test', batchCapacity: 2, scriptedResults: []);
  expect(dest.canAddToBatch([], mkEvent(seq: 1)), isTrue);
  expect(dest.canAddToBatch([mkEvent(seq: 1)], mkEvent(seq: 2)), isTrue);
  expect(dest.canAddToBatch([mkEvent(seq: 1), mkEvent(seq: 2)], mkEvent(seq: 3)), isFalse);
});

// Verifies: REQ-BATCH-F — maxAccumulateTime available.
test('REQ-BATCH-F: Destination.maxAccumulateTime default is Duration.zero', () {
  final dest = _FakeDestination(id: 'test', scriptedResults: []);
  expect(dest.maxAccumulateTime, Duration.zero);
});

// Verifies: REQ-DYNDEST-B — allowHardDelete default false.
test('REQ-DYNDEST-B: Destination.allowHardDelete defaults to false', () {
  final dest = _FakeDestination(id: 'test', scriptedResults: []);
  expect(dest.allowHardDelete, isFalse);
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Widen the abstract `Destination` interface**:

```dart
abstract class Destination {
  String get id;
  SubscriptionFilter get filter;
  String get wireFormat;

  /// Implements: REQ-BATCH-F
  Duration get maxAccumulateTime;

  /// Implements: REQ-DYNDEST-B
  bool get allowHardDelete;

  /// Implements: REQ-BATCH-E — destination-owned batching rule.
  bool canAddToBatch(List<Event> currentBatch, Event candidate);

  /// Implements: REQ-BATCH-D / REQ-DEST-D — batch transform.
  Future<WirePayload> transform(List<Event> batch);

  Future<SendResult> send(WirePayload payload);
}
```

- [ ] **Update `_FakeDestination`**:

```dart
class _FakeDestination implements Destination {
  _FakeDestination({
    required this.id,
    required this.scriptedResults,
    this.batchCapacity = 1,
    this.maxAccumulateTime = Duration.zero,
    this.allowHardDelete = false,
  });

  @override final String id;
  @override SubscriptionFilter get filter => SubscriptionFilter.any();
  @override String get wireFormat => 'fake-v1';
  @override final Duration maxAccumulateTime;
  @override final bool allowHardDelete;

  final int batchCapacity;
  final List<SendResult> scriptedResults;
  int _idx = 0;

  @override
  bool canAddToBatch(List<Event> current, Event candidate) =>
      current.length < batchCapacity;

  @override
  Future<WirePayload> transform(List<Event> batch) async {
    if (batch.isEmpty) {
      throw ArgumentError('_FakeDestination.transform called with empty batch');
    }
    return WirePayload(
      bytes: utf8.encode(jsonEncode({'events': batch.map((e) => e.eventId).toList()})),
      contentType: 'application/json',
      transformVersion: 'fake-v1',
    );
  }

  @override
  Future<SendResult> send(WirePayload p) async {
    if (_idx >= scriptedResults.length) {
      throw StateError('_FakeDestination ran out of scripted results');
    }
    return scriptedResults[_idx++];
  }
}
```

- [ ] **Update every existing test** that constructs `_FakeDestination` — add `batchCapacity` where relevant (default 1 keeps per-event behavior for tests that don't care about batching).

- [ ] **Run all tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: Destination interface widened for batching (REQ-BATCH, REQ-DYNDEST-B)"`.

---

### Task 10: DestinationRegistry dynamic mutation API

**TASK_FILE**: `PHASE4.3_TASK_10.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/destinations/destination_schedule.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (schedule persistence + delete store)
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/destinations/destination_registry_dynamic_test.dart`

**Applicable assertions**: REQ-DYNDEST-A, C, F, G, H.

- [ ] **Baseline tests green.**

- [ ] **Create `destination_schedule.dart`**:

```dart
// Implements: REQ-DYNDEST — per-destination schedule state.
class DestinationSchedule {
  final DateTime? startDate;
  final DateTime? endDate;
  const DestinationSchedule({this.startDate, this.endDate});

  bool get isDormant => startDate == null;
  bool isActiveAt(DateTime now) =>
      startDate != null &&
      startDate!.compareTo(now) <= 0 &&
      (endDate == null || endDate!.compareTo(now) > 0);
}

enum SetEndDateResult { closed, scheduled, applied }

class UnjamResult {
  final int deletedPending;
  final int rewoundTo;
  const UnjamResult({required this.deletedPending, required this.rewoundTo});
}
```

- [ ] **Write failing tests** in `destination_registry_dynamic_test.dart`:

```dart
// Verifies: REQ-DYNDEST-A — addDestination at any time.
test('REQ-DYNDEST-A: addDestination after bootstrap registers the destination', () async {
  final reg = DestinationRegistry();
  reg.addDestination(_FakeDestination(id: 'later', scriptedResults: []));
  expect(reg.all().map((d) => d.id), contains('later'));
});

// Verifies: REQ-DYNDEST-A — id collision throws.
test('REQ-DYNDEST-A: addDestination with duplicate id throws ArgumentError', () {
  final reg = DestinationRegistry();
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: []));
  expect(() => reg.addDestination(_FakeDestination(id: 'x', scriptedResults: [])),
         throwsArgumentError);
});

// Verifies: REQ-DYNDEST-C — startDate immutable.
test('REQ-DYNDEST-C: setStartDate twice throws StateError', () async {
  final reg = DestinationRegistry(backend: await openInMemoryBackend());
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: []));
  await reg.setStartDate('x', DateTime(2026, 4, 1));
  expect(() => reg.setStartDate('x', DateTime(2026, 4, 15)),
         throwsStateError);
});

// Verifies: REQ-DYNDEST-F — setEndDate return codes.
test('REQ-DYNDEST-F: setEndDate in past returns closed', () async {
  final reg = DestinationRegistry(backend: await openInMemoryBackend());
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: []));
  final result = await reg.setEndDate('x', DateTime.now().subtract(const Duration(hours: 1)));
  expect(result, SetEndDateResult.closed);
});

test('REQ-DYNDEST-F: setEndDate in future returns scheduled', () async {
  final reg = DestinationRegistry(backend: await openInMemoryBackend());
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: []));
  final result = await reg.setEndDate('x', DateTime.now().add(const Duration(days: 7)));
  expect(result, SetEndDateResult.scheduled);
});

// Verifies: REQ-DYNDEST-G — deactivateDestination is shorthand.
test('REQ-DYNDEST-G: deactivateDestination returns closed and sets endDate near-now', () async {
  final reg = DestinationRegistry(backend: await openInMemoryBackend());
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: []));
  final before = DateTime.now();
  final result = await reg.deactivateDestination('x');
  expect(result, SetEndDateResult.closed);
  final sched = await reg.scheduleOf('x');
  expect(sched.endDate!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
  expect(sched.endDate!.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
});

// Verifies: REQ-DYNDEST-H — deleteDestination gated on allowHardDelete.
test('REQ-DYNDEST-H: deleteDestination throws when allowHardDelete is false', () async {
  final reg = DestinationRegistry(backend: await openInMemoryBackend());
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: [], allowHardDelete: false));
  expect(() => reg.deleteDestination('x'), throwsStateError);
});

test('REQ-DYNDEST-H: deleteDestination succeeds when allowHardDelete is true, destroys FIFO', () async {
  final backend = await openInMemoryBackend();
  final reg = DestinationRegistry(backend: backend);
  reg.addDestination(_FakeDestination(id: 'x', scriptedResults: [], allowHardDelete: true));
  // enqueue one batch so FIFO exists
  await enqueueSingle(backend, 'x', mkEvent(seq: 1));
  await reg.deleteDestination('x');
  expect(reg.all().map((d) => d.id), isNot(contains('x')));
  expect(await backend.readFifoHead('x'), isNull); // FIFO destroyed
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Update `DestinationRegistry`**:

```dart
class DestinationRegistry {
  final StorageBackend backend;
  final Map<String, Destination> _destinations = {};
  final Map<String, DestinationSchedule> _schedules = {};

  DestinationRegistry({required this.backend});

  // Implements: REQ-DYNDEST-A — dynamic registration.
  void addDestination(Destination d) {
    if (_destinations.containsKey(d.id)) {
      throw ArgumentError('Destination "${d.id}" already registered');
    }
    _destinations[d.id] = d;
    _schedules[d.id] = const DestinationSchedule();  // dormant
    // persist schedule too (so it survives app restart)
    unawaited(backend.writeSchedule(d.id, const DestinationSchedule()));
  }

  List<Destination> all() => _destinations.values.toList(growable: false);

  Destination? byId(String id) => _destinations[id];

  Future<DestinationSchedule> scheduleOf(String id) async {
    // prefer in-memory; fall back to persisted on cold start
    return _schedules[id] ?? await backend.readSchedule(id) ?? const DestinationSchedule();
  }

  // Implements: REQ-DYNDEST-C+D+E — immutable startDate; trigger replay if past.
  Future<void> setStartDate(String id, DateTime startDate) async {
    final current = await scheduleOf(id);
    if (current.startDate != null) {
      throw StateError('startDate for "$id" is immutable (REQ-DYNDEST-C); current = ${current.startDate}');
    }
    final newSched = DestinationSchedule(startDate: startDate, endDate: current.endDate);
    _schedules[id] = newSched;

    await backend.transaction((txn) async {
      await backend.writeScheduleTxn(txn, id, newSched);
      if (startDate.compareTo(DateTime.now()) <= 0) {
        // Historical replay in same transaction (REQ-REPLAY).
        await runHistoricalReplay(txn, _destinations[id]!, newSched, backend);
      }
    });
  }

  // Implements: REQ-DYNDEST-F — mutable endDate with return code.
  Future<SetEndDateResult> setEndDate(String id, DateTime endDate) async {
    final current = await scheduleOf(id);
    final newSched = DestinationSchedule(startDate: current.startDate, endDate: endDate);
    _schedules[id] = newSched;
    await backend.writeSchedule(id, newSched);

    final now = DateTime.now();
    final wasClosed = current.endDate != null && current.endDate!.compareTo(now) <= 0;
    final isClosed = endDate.compareTo(now) <= 0;
    if (!wasClosed && isClosed) return SetEndDateResult.closed;
    if (!wasClosed && !isClosed) return SetEndDateResult.scheduled;
    if (wasClosed && !isClosed) return SetEndDateResult.scheduled;
    return SetEndDateResult.applied;
  }

  // Implements: REQ-DYNDEST-G.
  Future<SetEndDateResult> deactivateDestination(String id) =>
      setEndDate(id, DateTime.now());

  // Implements: REQ-DYNDEST-H.
  Future<void> deleteDestination(String id) async {
    final d = _destinations[id];
    if (d == null) throw ArgumentError('Unknown destination "$id"');
    if (!d.allowHardDelete) {
      throw StateError('Destination "$id" has allowHardDelete=false; use deactivate instead');
    }
    await backend.transaction((txn) async {
      await backend.deleteFifoStoreTxn(txn, id);
      await backend.deleteScheduleTxn(txn, id);
    });
    _destinations.remove(id);
    _schedules.remove(id);
  }
}
```

- [ ] **Add `StorageBackend` methods** for schedule persistence and FIFO-store hard-delete:

```dart
Future<DestinationSchedule?> readSchedule(String destId);
Future<void> writeSchedule(String destId, DestinationSchedule schedule);
Future<void> writeScheduleTxn(Txn txn, String destId, DestinationSchedule schedule);
Future<void> deleteScheduleTxn(Txn txn, String destId);
Future<void> deleteFifoStoreTxn(Txn txn, String destId);
```

Implement in `SembastBackend` — schedule stored in `backend_state` under `schedule_$destId`; `deleteFifoStoreTxn` drops the entire `fifo_$destId` store.

- [ ] **Note on `runHistoricalReplay(txn, ...)`**: this function is defined in Task 12. Here it's forward-referenced; the test for `setStartDate(past)` replay triggering is in Task 12.

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: DestinationRegistry dynamic mutation (REQ-DYNDEST)"`.

---

### Task 11: fillBatch implementation

**TASK_FILE**: `PHASE4.3_TASK_11.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/sync/fill_batch.dart`
- Create: `apps/common-dart/append_only_datastore/test/sync/fill_batch_test.dart`

**Applicable assertions**: REQ-BATCH-E, F, G, H; REQ-DYNDEST-I.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests** in `fill_batch_test.dart`:

```dart
// Verifies: REQ-BATCH-H — fillBatch idempotent when no new candidates.
test('REQ-BATCH-H: fillBatch with no new matching events is a no-op', () async {
  final backend = await openInMemoryBackend();
  final dest = _FakeDestination(id: 'x', scriptedResults: [], batchCapacity: 5);
  final reg = DestinationRegistry(backend: backend)..addDestination(dest);
  await reg.setStartDate('x', DateTime.now().subtract(const Duration(days: 1)));
  // no events in event_log
  await fillBatch(dest, backend: backend, schedule: await reg.scheduleOf('x'));
  expect(await backend.readFifoHead('x'), isNull);
  expect(await backend.readFillCursor('x'), -1);
});

// Verifies: REQ-BATCH-E — canAddToBatch controls batch size.
test('REQ-BATCH-E: fillBatch respects canAddToBatch boundary', () async {
  final backend = await openInMemoryBackend();
  await appendEvents(backend, count: 7);  // adds events seq 1..7 to event_log
  final dest = _FakeDestination(id: 'x', scriptedResults: [], batchCapacity: 3,
                                 maxAccumulateTime: Duration.zero);
  final reg = DestinationRegistry(backend: backend)..addDestination(dest);
  await reg.setStartDate('x', DateTime.now().subtract(const Duration(days: 1)));
  // One fillBatch call should produce one FIFO row of 3 events.
  await fillBatch(dest, backend: backend, schedule: await reg.scheduleOf('x'));
  final head = await backend.readFifoHead('x');
  expect(head?.eventIds, hasLength(3));
  expect(await backend.readFillCursor('x'), 3);
});

// Verifies: REQ-BATCH-F — maxAccumulateTime holds a single-event batch.
test('REQ-BATCH-F: fillBatch with 1 candidate and maxAccumulateTime>0 does not flush yet', () async {
  final backend = await openInMemoryBackend();
  await appendEvents(backend, count: 1);  // single fresh event
  final dest = _FakeDestination(id: 'x', scriptedResults: [], batchCapacity: 10,
                                 maxAccumulateTime: const Duration(seconds: 5));
  final reg = DestinationRegistry(backend: backend)..addDestination(dest);
  await reg.setStartDate('x', DateTime.now().subtract(const Duration(days: 1)));
  await fillBatch(dest, backend: backend, schedule: await reg.scheduleOf('x'));
  expect(await backend.readFifoHead('x'), isNull);  // held
  expect(await backend.readFillCursor('x'), -1);     // cursor not advanced
});

// Verifies: REQ-DYNDEST-I — events outside window not enqueued.
test('REQ-DYNDEST-I: fillBatch skips events with client_timestamp < startDate', () async {
  final backend = await openInMemoryBackend();
  final ancient = DateTime(2020, 1, 1);
  await appendEventAt(backend, seq: 1, clientTimestamp: ancient);
  await appendEventAt(backend, seq: 2, clientTimestamp: DateTime.now());
  final dest = _FakeDestination(id: 'x', scriptedResults: [], batchCapacity: 10);
  final reg = DestinationRegistry(backend: backend)..addDestination(dest);
  await reg.setStartDate('x', DateTime.now().subtract(const Duration(hours: 1)));
  // startDate is 1h ago; ancient event is excluded; seq=2 is included.
  await fillBatch(dest, backend: backend, schedule: await reg.scheduleOf('x'));
  final head = await backend.readFifoHead('x');
  expect(head?.eventIds, hasLength(1));
});

// Verifies: REQ-DYNDEST-I — events after endDate not enqueued.
test('REQ-DYNDEST-I: fillBatch skips events with client_timestamp > endDate', () async {
  // similar setup; set endDate 30 seconds in the past; events from 1 minute ago are in, events from now are out
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Create `fill_batch.dart`** with the algorithm from design §6.4:

```dart
// Implements: REQ-BATCH-E+F+G+H; REQ-DYNDEST-I — promote matching events into a FIFO batch.
Future<void> fillBatch(
  Destination destination, {
  required StorageBackend backend,
  required DestinationSchedule schedule,
  Clock? clock,
}) async {
  final now = (clock ?? const SystemClock()).now();
  if (schedule.startDate == null) return;                   // dormant
  final upper = schedule.endDate == null
      ? now
      : (schedule.endDate!.compareTo(now) < 0 ? schedule.endDate! : now);
  if (schedule.startDate!.compareTo(upper) > 0) return;     // window closed before open

  final fillCursor = await backend.readFillCursor(destination.id);
  final candidates = await backend.findEvents(
    afterSequence: fillCursor,
    clientTimestampRange: (start: schedule.startDate!, end: upper),
  );
  if (candidates.isEmpty) return;

  final matching = candidates.where(destination.filter.matches).toList();
  if (matching.isEmpty) {
    // advance cursor past non-matching events so we don't re-evaluate them
    await backend.writeFillCursor(destination.id, candidates.last.sequenceNumber);
    return;
  }

  // assemble a batch
  final batch = <StoredEvent>[matching.first];
  for (final c in matching.skip(1)) {
    if (destination.canAddToBatch(batch, c)) {
      batch.add(c);
    } else {
      break;
    }
  }

  final age = now.difference(batch.first.clientTimestamp);
  if (batch.length == 1 && age < destination.maxAccumulateTime) {
    return;  // hold single-event batch until accumulate window elapses
  }

  final wirePayload = await destination.transform(batch);
  await backend.transaction((txn) async {
    await backend.enqueueFifoTxn(txn, destination.id, batch, wirePayload);
    await backend.writeFillCursorTxn(txn, destination.id, batch.last.sequenceNumber);
  });
}
```

Add `StorageBackend.findEvents({required int afterSequence, required ({DateTime start, DateTime end}) clientTimestampRange})` if it doesn't already exist — implement in SembastBackend with a finder.

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: fillBatch algorithm (REQ-BATCH, REQ-DYNDEST-I)"`.

---

### Task 12: Historical replay

**TASK_FILE**: `PHASE4.3_TASK_12.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart` (add runHistoricalReplay)
- Modify: `apps/common-dart/append_only_datastore/lib/src/sync/fill_batch.dart` (add transactional variant for use during replay)
- Create: `apps/common-dart/append_only_datastore/test/destinations/historical_replay_test.dart`

**Applicable assertions**: REQ-DYNDEST-D, E; REQ-REPLAY-A, B, C.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-DYNDEST-D + REQ-REPLAY-A — setStartDate in the past triggers replay.
test('REQ-DYNDEST-D: setStartDate with past date batches all matching historical events', () async {
  final backend = await openInMemoryBackend();
  await appendEvents(backend, count: 5);  // events 1..5 all within the last hour
  final dest = _FakeDestination(id: 'x', scriptedResults: [], batchCapacity: 2);
  final reg = DestinationRegistry(backend: backend)..addDestination(dest);

  await reg.setStartDate('x', DateTime.now().subtract(const Duration(hours: 1)));

  // All 5 events should be enqueued in batches of 2: rows of 2, 2, 1.
  final rows = await backend.readAllFifoRows('x');
  expect(rows, hasLength(3));
  expect(rows[0].eventIds, hasLength(2));
  expect(rows[1].eventIds, hasLength(2));
  expect(rows[2].eventIds, hasLength(1));
  expect(await backend.readFillCursor('x'), 5);
});

// Verifies: REQ-DYNDEST-E — future startDate does NOT trigger replay.
test('REQ-DYNDEST-E: setStartDate in the future leaves FIFO empty', () async {
  final backend = await openInMemoryBackend();
  await appendEvents(backend, count: 3);  // events 1..3 now
  final dest = _FakeDestination(id: 'x', scriptedResults: [], batchCapacity: 10);
  final reg = DestinationRegistry(backend: backend)..addDestination(dest);

  await reg.setStartDate('x', DateTime.now().add(const Duration(days: 1)));

  expect(await backend.readFifoHead('x'), isNull);
  expect(await backend.readFillCursor('x'), -1);
});

// Verifies: REQ-REPLAY-C — events appended DURING replay serialize correctly.
test('REQ-REPLAY-C: events appended after replay start land via live fillBatch, not duplicated', () async {
  // Seed 3 events; call setStartDate(past) → 3 events replayed.
  // Then append 2 more events via EntryService.record → separate fillBatch picks them up on next tick.
  // Verify no event_id appears in more than one FIFO row.
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Implement `runHistoricalReplay`** in `destination_registry.dart` (called from `setStartDate` per Task 10's forward reference):

```dart
// Implements: REQ-REPLAY-A+B — walk event_log in the same transaction, batch via destination's rules.
Future<void> runHistoricalReplay(
  Txn txn,
  Destination destination,
  DestinationSchedule schedule,
  StorageBackend backend,
) async {
  final now = DateTime.now();
  final upper = schedule.endDate == null
      ? now
      : (schedule.endDate!.compareTo(now) < 0 ? schedule.endDate! : now);

  final candidates = await backend.findEventsTxn(
    txn,
    afterSequence: -1,
    clientTimestampRange: (start: schedule.startDate!, end: upper),
  );
  final matching = candidates.where(destination.filter.matches).toList();
  if (matching.isEmpty) return;

  // Build batches per destination.canAddToBatch.
  var i = 0;
  while (i < matching.length) {
    final batch = <StoredEvent>[matching[i]];
    i++;
    while (i < matching.length && destination.canAddToBatch(batch, matching[i])) {
      batch.add(matching[i]);
      i++;
    }
    final wirePayload = await destination.transform(batch);
    await backend.enqueueFifoTxn(txn, destination.id, batch, wirePayload);
  }

  await backend.writeFillCursorTxn(txn, destination.id, matching.last.sequenceNumber);
}
```

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: Historical replay on setStartDate(past) (REQ-DYNDEST-D, REQ-REPLAY)"`.

---

### Task 13: Drain update — SendPermanent continues

**TASK_FILE**: `PHASE4.3_TASK_13.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart`
- Modify: `apps/common-dart/append_only_datastore/test/sync/drain_test.dart` (tests already updated in PLAN_PHASE4_sync.md Task 7 — verify they now exist and adjust as needed)

**Applicable assertions**: REQ-DRAIN-D, E (both already revised in PLAN_PHASE4_sync.md).

- [ ] **Baseline tests green** (these should include the updated REQ-DRAIN-D/E tests from PLAN_PHASE4_sync.md).

- [ ] **Verify test coverage**: confirm `drain_test.dart` has:
  - `REQ-DRAIN-D`: SendPermanent marks exhausted and CONTINUES (drain advances to next pending).
  - `REQ-DRAIN-E`: SendTransient at maxAttempts marks exhausted and CONTINUES.
  - `REQ-DRAIN-A`: readFifoHead returns first pending past exhausted.
  - `REQ-DRAIN-H`: strict order within pending; exhausted is skipped.
  - `REQ-SKIPMISSING` coverage (already added in Task 5).

- [ ] **Update `drain()` in `drain.dart`** — change `return` to `continue` on SendPermanent and SendTransient-at-max:

```dart
Future<void> drain(
  Destination destination, {
  required StorageBackend backend,
  Clock? clock,
  SyncPolicy? policy,
}) async {
  final effective = policy ?? SyncPolicy.defaults;
  final theClock = clock ?? const SystemClock();

  while (true) {
    final head = await backend.readFifoHead(destination.id);
    if (head == null) return;                                          // REQ-DRAIN-A
    if (_backoffNotElapsed(head, effective, theClock)) return;          // REQ-DRAIN-B

    final result = await destination.send(head.wirePayload);
    final attempt = AttemptResult.from(result, at: theClock.now());
    await backend.appendAttempt(destination.id, head.entryId, attempt);  // REQ-DRAIN-G + REQ-SKIPMISSING

    switch (result) {
      case SendOk _:
        await backend.markFinal(destination.id, head.entryId, FinalStatus.sent);
        continue;                                                        // REQ-DRAIN-C
      case SendPermanent _:
        await backend.markFinal(destination.id, head.entryId, FinalStatus.exhausted);
        continue;                                                        // REQ-DRAIN-D (CHANGED: was return)
      case SendTransient _:
        if (head.attempts.length + 1 >= effective.maxAttempts) {
          await backend.markFinal(destination.id, head.entryId, FinalStatus.exhausted);
          continue;                                                      // REQ-DRAIN-E (CHANGED: was return)
        }
        return;                                                          // REQ-DRAIN-F
    }
  }
}
```

- [ ] **Run tests; confirm pass.** Add per-function `// Implements:` comments matching assertion letters.

- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: drain skips exhausted (REQ-DRAIN-D+E)"`.

---

### Task 14: unjamDestination

**TASK_FILE**: `PHASE4.3_TASK_14.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/ops/unjam.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (need helpers: deletePendingRows, maxSentSequence)
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/ops/unjam_test.dart`

**Applicable assertions**: REQ-UNJAM-A, B, C, D, E.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-UNJAM-A — precondition enforced.
test('REQ-UNJAM-A: unjam on active destination throws StateError', () async {
  final (reg, dest) = await setupActiveDestination();
  expect(() => unjamDestination(dest.id, registry: reg, backend: reg.backend),
         throwsStateError);
});

// Verifies: REQ-UNJAM-B, C — pending deleted; exhausted preserved.
test('REQ-UNJAM-B+C: unjam deletes pending rows and preserves exhausted rows', () async {
  final (backend, reg, dest) = await setupDestinationWithMixedFifo(
    sentCount: 2, exhaustedCount: 3, pendingCount: 4);
  await reg.deactivateDestination(dest.id);
  final r = await unjamDestination(dest.id, registry: reg, backend: backend);
  expect(r.deletedPending, 4);
  final rows = await backend.readAllFifoRows(dest.id);
  expect(rows.where((x) => x.finalStatus == FinalStatus.sent).length, 2);
  expect(rows.where((x) => x.finalStatus == FinalStatus.exhausted).length, 3);
  expect(rows.where((x) => x.finalStatus == FinalStatus.pending).length, 0);
});

// Verifies: REQ-UNJAM-D — rewind to last sent.
test('REQ-UNJAM-D: unjam rewinds fill_cursor to last successfully sent event', () async {
  final (backend, reg, dest) = await setupDestinationWithMixedFifo(
    sentCount: 2,   // events 1-2
    exhaustedCount: 3, // events 3-5
    pendingCount: 4);  // events 6-9
  await reg.deactivateDestination(dest.id);
  final r = await unjamDestination(dest.id, registry: reg, backend: backend);
  expect(r.rewoundTo, 2);  // last sent event's sequence_number
  expect(await backend.readFillCursor(dest.id), 2);
});

// Verifies: REQ-UNJAM-D with no sent rows.
test('REQ-UNJAM-D: unjam rewinds to -1 when no rows are sent', () async {
  final (backend, reg, dest) = await setupDestinationWithMixedFifo(
    sentCount: 0, exhaustedCount: 2, pendingCount: 2);
  await reg.deactivateDestination(dest.id);
  final r = await unjamDestination(dest.id, registry: reg, backend: backend);
  expect(r.rewoundTo, -1);
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Create `unjam.dart`**:

```dart
// Implements: REQ-UNJAM-A+B+C+D+E — delete pending, preserve exhausted, rewind cursor.
Future<UnjamResult> unjamDestination(
  String destId, {
  required DestinationRegistry registry,
  required StorageBackend backend,
}) async {
  final schedule = await registry.scheduleOf(destId);
  if (schedule.endDate == null || schedule.endDate!.compareTo(DateTime.now()) > 0) {
    throw StateError('unjam requires destination "$destId" to be deactivated first (REQ-UNJAM-A)');
  }

  return backend.transaction((txn) async {
    final deletedPending = await backend.deletePendingRowsTxn(txn, destId);
    final lastSentSeq = await backend.maxSentSequenceTxn(txn, destId) ?? -1;
    await backend.writeFillCursorTxn(txn, destId, lastSentSeq);
    return UnjamResult(deletedPending: deletedPending, rewoundTo: lastSentSeq);
  });
}
```

Add to `StorageBackend`:

```dart
Future<int> deletePendingRowsTxn(Txn txn, String destId);   // returns count deleted
Future<int?> maxSentSequenceTxn(Txn txn, String destId);    // returns event_id_range.last_seq of latest sent row, or null
```

Implement in `SembastBackend` using finders.

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: unjamDestination (REQ-UNJAM)"`.

---

### Task 15: rehabilitateExhaustedRow + rehabilitateAllExhausted

**TASK_FILE**: `PHASE4.3_TASK_15.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/ops/rehabilitate.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (add exhaustedRowsOf, setFinalStatusTxn)
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/ops/rehabilitate_test.dart`

**Applicable assertions**: REQ-REHAB-A, B, C, D.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-REHAB-A — row must exist and be exhausted.
test('REQ-REHAB-A: rehabilitate unknown row throws ArgumentError', () async {
  final (backend, _, _) = await setupDestination();
  expect(() => rehabilitateExhaustedRow('primary', 'nope', backend: backend),
         throwsArgumentError);
});

test('REQ-REHAB-A: rehabilitate pending row throws ArgumentError', () async {
  final (backend, _, dest) = await setupDestinationWithMixedFifo(pendingCount: 1);
  final row = (await backend.readAllFifoRows(dest.id)).first;
  expect(() => rehabilitateExhaustedRow(dest.id, row.entryId, backend: backend),
         throwsArgumentError);
});

// Verifies: REQ-REHAB-B — status flipped, attempts preserved.
test('REQ-REHAB-B: exhausted row flips to pending; attempts[] unchanged', () async {
  final (backend, _, dest) = await setupDestinationWithMixedFifo(exhaustedCount: 1);
  final row = (await backend.readAllFifoRows(dest.id))
      .firstWhere((r) => r.finalStatus == FinalStatus.exhausted);
  final originalAttempts = row.attempts.length;
  await rehabilitateExhaustedRow(dest.id, row.entryId, backend: backend);
  final updated = (await backend.readAllFifoRows(dest.id))
      .firstWhere((r) => r.entryId == row.entryId);
  expect(updated.finalStatus, FinalStatus.pending);
  expect(updated.attempts.length, originalAttempts);
});

// Verifies: REQ-REHAB-C — bulk variant.
test('REQ-REHAB-C: rehabilitateAllExhausted flips all exhausted to pending, returns count', () async {
  final (backend, _, dest) = await setupDestinationWithMixedFifo(exhaustedCount: 3);
  final count = await rehabilitateAllExhausted(dest.id, backend: backend);
  expect(count, 3);
  expect((await backend.readAllFifoRows(dest.id))
      .where((r) => r.finalStatus == FinalStatus.exhausted), isEmpty);
});

// Verifies: REQ-REHAB-D — active destination allowed.
test('REQ-REHAB-D: rehabilitate works on active destination', () async {
  // destination is active (no endDate)
  final (backend, _, dest) = await setupDestinationWithMixedFifo(exhaustedCount: 1);
  final row = (await backend.readAllFifoRows(dest.id))
      .firstWhere((r) => r.finalStatus == FinalStatus.exhausted);
  // does not throw (unlike unjam)
  await rehabilitateExhaustedRow(dest.id, row.entryId, backend: backend);
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Create `rehabilitate.dart`**:

```dart
// Implements: REQ-REHAB-A+B+D — single-row rehabilitation.
Future<void> rehabilitateExhaustedRow(
  String destId,
  String fifoRowId, {
  required StorageBackend backend,
}) async {
  final row = await backend.readFifoRow(destId, fifoRowId);
  if (row == null) throw ArgumentError('Unknown FIFO row "$fifoRowId" on destination "$destId"');
  if (row.finalStatus != FinalStatus.exhausted) {
    throw ArgumentError('Row "$fifoRowId" is ${row.finalStatus}, not exhausted');
  }
  await backend.transaction((txn) =>
      backend.setFinalStatusTxn(txn, destId, fifoRowId, FinalStatus.pending));
}

// Implements: REQ-REHAB-C — bulk variant.
Future<int> rehabilitateAllExhausted(
  String destId, {
  required StorageBackend backend,
}) async {
  final exhausted = await backend.exhaustedRowsOf(destId);
  await backend.transaction((txn) async {
    for (final row in exhausted) {
      await backend.setFinalStatusTxn(txn, destId, row.entryId, FinalStatus.pending);
    }
  });
  return exhausted.length;
}
```

Add to `StorageBackend`:

```dart
Future<FifoEntry?> readFifoRow(String destId, String entryId);
Future<List<FifoEntry>> exhaustedRowsOf(String destId);
Future<void> setFinalStatusTxn(Txn txn, String destId, String entryId, FinalStatus status);
```

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: rehabilitateExhaustedRow + rehabilitateAllExhausted (REQ-REHAB)"`.

---

### Task 16: EntryService.record pulled forward

**TASK_FILE**: `PHASE4.3_TASK_16.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/entry_service.dart`
- Create: `apps/common-dart/append_only_datastore/test/entry_service_test.dart`

**Applicable assertions**: REQ-ENTRY-A, B, C, D (revised), E, F, G, H, I.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests** — one test per assertion:

```dart
// Verifies: REQ-ENTRY-C — invalid eventType rejected before I/O.
test('REQ-ENTRY-C: record with unknown eventType throws ArgumentError', () async {
  final svc = await buildEntryService();
  expect(() => svc.record(
    entryType: 'demo_note', aggregateId: 'agg-A',
    eventType: 'not-a-real-event-type' as dynamic,
    answers: {},
  ), throwsArgumentError);
});

// Verifies: REQ-ENTRY-H — unregistered entry_type rejected.
test('REQ-ENTRY-H: record with unregistered entryType throws ArgumentError', () async {
  final svc = await buildEntryService(registry: EntryTypeRegistry());  // empty
  expect(() => svc.record(
    entryType: 'unregistered-type', aggregateId: 'agg-A',
    eventType: EventType.finalized, answers: {},
  ), throwsArgumentError);
});

// Verifies: REQ-ENTRY-B — atomic event assembly.
test('REQ-ENTRY-B: record assigns event_id, sequence_number, hashes, provenance atomically', () async {
  final svc = await buildEntryService();
  await svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                   eventType: EventType.finalized, answers: {'x': 1});
  final events = await svc.backend.findEvents(afterSequence: -1);
  expect(events, hasLength(1));
  final e = events.first;
  expect(e.eventId, isNotEmpty);
  expect(e.sequenceNumber, 1);
  expect(e.eventHash, isNotEmpty);
  expect(e.metadata.provenance, hasLength(1));
});

// Verifies: REQ-ENTRY-D (revised) — local transaction only; no FIFO writes.
test('REQ-ENTRY-D: record does NOT write to any FIFO; fan-out deferred to fillBatch', () async {
  final (backend, reg, dest) = await setupActiveDestination();
  final svc = EntryService(backend: backend, registry: reg,
                           entryTypes: EntryTypeRegistry()..register(demoNoteDefn));
  await svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                   eventType: EventType.finalized, answers: {'x': 1});
  expect(await backend.readFifoHead(dest.id), isNull);  // no FIFO row yet
  expect(await backend.readFillCursor(dest.id), -1);    // cursor unchanged
});

// Verifies: REQ-ENTRY-F — no-op detection.
test('REQ-ENTRY-F: record with duplicate content on same aggregate is a no-op', () async {
  final svc = await buildEntryService();
  await svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                   eventType: EventType.finalized, answers: {'x': 1});
  await svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                   eventType: EventType.finalized, answers: {'x': 1});  // identical
  final events = await svc.backend.findEvents(afterSequence: -1);
  expect(events, hasLength(1));  // second call was no-op
});

// Verifies: REQ-ENTRY-F — no-op detection does NOT suppress legitimate transitions.
test('REQ-ENTRY-F: checkpoint then finalized with same answers both recorded', () async {
  final svc = await buildEntryService();
  await svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                   eventType: EventType.checkpoint, answers: {'x': 1});
  await svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                   eventType: EventType.finalized, answers: {'x': 1});
  expect(await svc.backend.findEvents(afterSequence: -1), hasLength(2));
});

// Verifies: REQ-ENTRY-G — post-write syncCycle kicked fire-and-forget.
test('REQ-ENTRY-G: record completes without awaiting syncCycle', () async {
  // use a test hook that records syncCycle invocations
  // assert: invocation count == 1 after record() returns, but return time is sub-100ms even if syncCycle takes seconds
});

// Verifies: REQ-ENTRY-E — materializer failure aborts the whole write.
test('REQ-ENTRY-E: materializer error aborts the transaction; no event appended', () async {
  final svc = await buildEntryServiceWithBrokenMaterializer();
  expect(() => svc.record(entryType: 'demo_note', aggregateId: 'agg-A',
                          eventType: EventType.finalized, answers: {'x': 1}),
         throwsA(isA<MaterializerException>()));
  expect(await svc.backend.findEvents(afterSequence: -1), isEmpty);
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Create `entry_service.dart`**:

```dart
// Implements: REQ-ENTRY-A — the sole write API.
class EntryService {
  final StorageBackend backend;
  final DestinationRegistry destinationRegistry;
  final EntryTypeRegistry entryTypes;
  final Materializer materializer;
  final SyncCycleTrigger syncCycleTrigger;   // invoked fire-and-forget post-write

  EntryService({
    required this.backend,
    required this.destinationRegistry,
    required this.entryTypes,
    required this.materializer,
    required this.syncCycleTrigger,
  });

  // Implements: REQ-ENTRY-A+B+C+D+E+F+G+H+I — single write path with no-op detection.
  Future<void> record({
    required String entryType,
    required String aggregateId,
    required EventType eventType,
    required Map<String, dynamic> answers,
    String? checkpointReason,
    String? changeReason,
  }) async {
    // REQ-ENTRY-C — eventType validation (pre-I/O).
    if (!EventType.values.contains(eventType)) {
      throw ArgumentError('Unknown eventType $eventType');
    }

    // REQ-ENTRY-H — entryType registered.
    if (!entryTypes.isRegistered(entryType)) {
      throw ArgumentError('Unregistered entryType "$entryType" (REQ-ENTRY-H)');
    }

    // REQ-ENTRY-F — no-op detection.
    final latest = await backend.latestEventOn(aggregateId);
    if (latest != null) {
      final candidateHash = _contentHash(eventType, answers, checkpointReason, changeReason);
      final existingHash = _contentHash(latest.eventType, latest.data,
                                         latest.checkpointReason, latest.changeReason);
      if (candidateHash == existingHash) return;  // no-op
    }

    // REQ-ENTRY-B — atomic event assembly.
    await backend.transaction((txn) async {
      final seq = await backend.nextSequenceNumberTxn(txn);
      final prevHash = latest?.eventHash;
      final now = DateTime.now();
      final provenance0 = ProvenanceEntry.now(
        hop: 'mobile-device',
        identifier: await _deviceId(),
        softwareVersion: await _softwareVersion(),
      );
      final event = StoredEvent(
        eventId: Uuid().v4(),
        aggregateId: aggregateId,
        aggregateType: entryTypes.byId(entryType)!.aggregateType,
        entryType: entryType,
        eventType: eventType,
        sequenceNumber: seq,
        userId: _currentUserId(),
        // REQ-ENTRY-I — migration-bridge top-level fields.
        deviceId: provenance0.identifier,
        softwareVersion: provenance0.softwareVersion,
        clientTimestamp: provenance0.receivedAt,
        previousEventHash: prevHash,
        data: _buildData(answers, checkpointReason),
        metadata: {
          'change_reason': changeReason ?? 'initial',
          'provenance': [provenance0.toJson()],
        },
      ).withComputedHash();

      // REQ-ENTRY-D (revised) — local-only transaction; no FIFO writes here.
      await backend.appendEventTxn(txn, event);
      await materializer.applyTxn(txn, event);  // REQ-ENTRY-E — throw propagates; txn rolls back
    });

    // REQ-ENTRY-G — fire-and-forget syncCycle.
    unawaited(syncCycleTrigger.kick());
  }

  String _contentHash(EventType t, Map<String, dynamic> answers, String? ckpt, String? change) {
    final canonical = jsonEncode({
      'event_type': t.name,
      'answers': _canonicalizeMap(answers),
      'checkpoint_reason': ckpt,
      'change_reason': change,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}
```

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: EntryService.record (REQ-ENTRY pulled forward from Phase 5)"`.

---

### Task 17: EntryTypeRegistry pulled forward

**TASK_FILE**: `PHASE4.3_TASK_17.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/entry_type_registry.dart`
- Create: `apps/common-dart/append_only_datastore/test/entry_type_registry_test.dart`

**Applicable assertions**: REQ-BOOTSTRAP-B (via bootstrap).

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
test('EntryTypeRegistry: register and byId round-trip', () {
  final reg = EntryTypeRegistry();
  final defn = EntryTypeDefinition(id: 'demo_note', version: 'v0', /* ... */);
  reg.register(defn);
  expect(reg.byId('demo_note'), defn);
});

test('EntryTypeRegistry: duplicate id throws ArgumentError', () {
  final reg = EntryTypeRegistry();
  final defn = EntryTypeDefinition(id: 'demo_note', version: 'v0', /* ... */);
  reg.register(defn);
  expect(() => reg.register(defn), throwsArgumentError);
});

test('EntryTypeRegistry: isRegistered', () {
  final reg = EntryTypeRegistry();
  reg.register(EntryTypeDefinition(id: 'x', version: 'v0', /* ... */));
  expect(reg.isRegistered('x'), isTrue);
  expect(reg.isRegistered('y'), isFalse);
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Create `entry_type_registry.dart`**:

```dart
class EntryTypeRegistry {
  final Map<String, EntryTypeDefinition> _defs = {};

  void register(EntryTypeDefinition defn) {
    if (_defs.containsKey(defn.id)) {
      throw ArgumentError('EntryTypeDefinition "${defn.id}" already registered');
    }
    _defs[defn.id] = defn;
  }

  EntryTypeDefinition? byId(String id) => _defs[id];
  bool isRegistered(String id) => _defs.containsKey(id);
  List<EntryTypeDefinition> all() => _defs.values.toList(growable: false);
}
```

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: EntryTypeRegistry (pulled forward from Phase 5)"`.

---

### Task 18: bootstrapAppendOnlyDatastore pulled forward

**TASK_FILE**: `PHASE4.3_TASK_18.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/bootstrap.dart`
- Create: `apps/common-dart/append_only_datastore/test/bootstrap_test.dart`

**Applicable assertions**: REQ-BOOTSTRAP-A, B, C, D.

- [ ] **Baseline tests green.**

- [ ] **Write failing tests**:

```dart
// Verifies: REQ-BOOTSTRAP-A+B+C — single init, types before destinations.
test('REQ-BOOTSTRAP-A+B+C: bootstrap wires types and destinations', () async {
  final backend = await openInMemoryBackend();
  final types = [demoNoteDefn, redButtonDefn];
  final dests = [_FakeDestination(id: 'primary', scriptedResults: [])];
  final (typeReg, destReg) = await bootstrapAppendOnlyDatastore(
    backend: backend, entryTypes: types, destinations: dests);
  expect(typeReg.all(), hasLength(2));
  expect(destReg.all(), hasLength(1));
});

// Verifies: REQ-BOOTSTRAP-D — id collision throws.
test('REQ-BOOTSTRAP-D: destination id collision throws', () async {
  final backend = await openInMemoryBackend();
  final dests = [
    _FakeDestination(id: 'x', scriptedResults: []),
    _FakeDestination(id: 'x', scriptedResults: []),
  ];
  expect(() => bootstrapAppendOnlyDatastore(
    backend: backend, entryTypes: [], destinations: dests),
    throwsArgumentError);
});
```

- [ ] **Run tests; confirm failure.**

- [ ] **Create `bootstrap.dart`**:

```dart
// Implements: REQ-BOOTSTRAP-A+B+C+D — single init, types before destinations, collision detection.
Future<(EntryTypeRegistry, DestinationRegistry)> bootstrapAppendOnlyDatastore({
  required StorageBackend backend,
  required List<EntryTypeDefinition> entryTypes,
  required List<Destination> destinations,
}) async {
  final typeReg = EntryTypeRegistry();
  for (final defn in entryTypes) {
    typeReg.register(defn);
  }
  final destReg = DestinationRegistry(backend: backend);
  for (final d in destinations) {
    destReg.addDestination(d);  // throws on collision (REQ-BOOTSTRAP-D)
  }
  return (typeReg, destReg);
}
```

- [ ] **Run tests; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: bootstrapAppendOnlyDatastore (pulled forward from Phase 5)"`.

---

### Task 19: End-to-end integration smoke test

**TASK_FILE**: `PHASE4.3_TASK_19.md`

Validates the full Phase-4.3 surface works together: bootstrap → record → fillBatch → drain → sent. No new REQs; asserts the composition.

**Files:**
- Create: `apps/common-dart/append_only_datastore/test/integration/end_to_end_test.dart`

- [ ] **Baseline tests green.**

- [ ] **Write the integration test**:

```dart
test('Phase 4.3 end-to-end: bootstrap → record → fillBatch → drain → sent', () async {
  final backend = await openInMemoryBackend();
  final dest = _FakeDestination(
    id: 'primary',
    scriptedResults: [const SendOk()],  // 1 batch = 1 SendOk
    batchCapacity: 5,
  );

  final (typeReg, destReg) = await bootstrapAppendOnlyDatastore(
    backend: backend,
    entryTypes: [demoNoteDefn],
    destinations: [dest],
  );

  await destReg.setStartDate('primary', DateTime.now().subtract(const Duration(hours: 1)));

  final syncTrigger = _TestSyncTrigger();
  final svc = EntryService(
    backend: backend,
    destinationRegistry: destReg,
    entryTypes: typeReg,
    materializer: Materializer(backend: backend),
    syncCycleTrigger: syncTrigger,
  );

  // record one event
  await svc.record(
    entryType: 'demo_note', aggregateId: 'agg-A',
    eventType: EventType.finalized, answers: {'title': 'hello'},
  );

  // syncCycle fires fillBatch (promotes to FIFO) then drain (sends SendOk)
  await syncCycle(
    destinationRegistry: destReg,
    backend: backend,
    policy: const SyncPolicy.defaults,  // will rebind with fast policy below if flaky
  );

  final rows = await backend.readAllFifoRows('primary');
  expect(rows, hasLength(1));
  expect(rows.first.finalStatus, FinalStatus.sent);
  expect(rows.first.eventIds, hasLength(1));
});
```

- [ ] **Run; confirm pass.** `dart analyze` clean.
- [ ] **Commit**: `git commit -am "[CUR-1154] Phase 4.3: End-to-end integration smoke test"`.

---

### Task 20: Phase-squash prep

**TASK_FILE**: `PHASE4.3_TASK_20.md`

- [ ] **Confirm all Phase 4.3 tasks complete**: baseline every TASK_FILE has its checklist green.
- [ ] **Rebase onto main**: `git fetch origin main && git rebase origin/main`. Resolve conflicts. (Phase 2/5 have historically been the highest-conflict phases; 4.3 is additive-heavy, should be lower risk.)
- [ ] **Run all tests one more time**:
  - `(cd apps/common-dart/append_only_datastore && dart test)` green.
  - `(cd apps/common-dart/provenance && dart test)` green.
  - `(cd apps/common-dart/trial_data_types && dart test)` green.
  - `(cd apps/daily-diary/clinical_diary && flutter test)` green.
  - `(cd apps/daily-diary/clinical_diary && flutter analyze)` zero errors.
- [ ] **Cross-phase invariant check**: the installed `clinical_diary` app still boots and records a nosebleed through the legacy `NosebleedService` path (Phase 5 is what removes it).
- [ ] **Interactive rebase** to squash all Phase 4.3 intra-phase commits into one:
  ```
  git rebase -i origin/main
  ```
  Squash all commits since the Phase 4 squashed commit. Commit message:
  ```
  [CUR-1154] Phase 4.3: Dynamic destinations, batch FIFO, EntryService/Registry/bootstrap forward

  - SyncPolicy refactored to injectable value object (REQ-SYNCPOLICY-INJECTABLE).
  - StorageBackend.markFinal/appendAttempt tolerate missing row/store (REQ-SKIPMISSING).
  - FifoEntry shape: event_ids: List<String>, event_id_range; single wire_payload per batch (REQ-BATCH).
  - Per-destination fill_cursor in backend_state; readFifoHead skips exhausted (REQ-BATCH-G, REQ-DRAIN-A).
  - Destination interface widened: maxAccumulateTime, allowHardDelete, canAddToBatch, transform(List<Event>) (REQ-BATCH, REQ-DYNDEST-B).
  - DestinationRegistry: dynamic addDestination/setStartDate/setEndDate/deactivate/delete (REQ-DYNDEST).
  - fillBatch algorithm and historical replay on setStartDate(past) (REQ-BATCH, REQ-DYNDEST-D/E, REQ-REPLAY).
  - Drain: SendPermanent and SendTransient-at-max continue past exhausted (REQ-DRAIN-D+E revised).
  - Unjam and rehabilitate ops (REQ-UNJAM, REQ-REHAB).
  - EntryService.record with no-op detection and deferred FIFO fan-out (REQ-ENTRY pulled forward from Phase 5, D revised).
  - EntryTypeRegistry and bootstrapAppendOnlyDatastore (REQ-BOOTSTRAP pulled forward from Phase 5).
  - Parent plan: inserted 4.3/4.6 rows; annotated PLAN_PHASE5 moved tasks.
  - Phase 4's PLAN_PHASE4_sync.md REQ-DEST-D/G, REQ-DRAIN-A/D/E/G/H already revised 2026-04-22 alongside this phase.
  ```
- [ ] **Force-push with lease**: `git push --force-with-lease`.
- [ ] **Comment on PR**: "Phase 4.3 ready for review — commit `<sha>`. Range from Phase 4: `<prev_sha>..<sha>`."
- [ ] **Wait for phase review** before starting Phase 4.6.

---

## Cross-phase invariants at end of Phase 4.3

Per README §"Cross-phase invariants":

1. `dart test` in every touched pure-Dart package passes.
2. `flutter test` in `clinical_diary` passes (no changes in that tree from this phase, but verify anyway).
3. `flutter analyze` in `clinical_diary` returns zero errors.
4. The installed `clinical_diary` still boots, shows the home screen, and records a nosebleed through the legacy `NosebleedService` path (still intact until Phase 5).
5. No dead-letter code: every new library feature is exercised either by unit tests in this phase or by the Phase 4.6 demo (scheduled for next phase). The pulled-forward `EntryService`/`EntryTypeRegistry`/`bootstrap` have complete unit-test coverage in this phase; the demo is where they get exercised together through a real Flutter app.
6. Final commit subject starts `[CUR-1154] Phase 4.3:`.
