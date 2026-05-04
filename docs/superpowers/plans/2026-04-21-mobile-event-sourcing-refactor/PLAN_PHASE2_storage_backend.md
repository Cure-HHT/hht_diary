# Master Plan Phase 2: `StorageBackend` abstract + `SembastBackend` concrete

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 2 of 5
**Status**: Not Started
**Depends on**: Phase 1 squashed and phase-reviewed

## Scope

Introduce the `StorageBackend` abstraction (pure-Dart contract) and a concrete `SembastBackend` implementation. Refactor `EventRepository` internally to delegate through the backend. Rename the current Sembast `metadata` store to `backend_state` to eliminate the name collision with the event-level `metadata` field. Define but do not populate the `diary_entries` view store and the per-destination FIFO stores — their methods exist and are unit-tested, but no production caller uses them until Phase 3 and Phase 4 respectively.

**Produces:**
- `StorageBackend` and `Txn` abstract classes in `append_only_datastore`.
- Supporting value types: `AppendResult`, `DiaryEntry`, `FifoEntry`, `AttemptResult`, `FinalStatus`, `ExhaustedFifoSummary`, `SendResult` sealed class.
- `SembastBackend` concrete implementation covering all of the interface.
- `EventRepository` refactored to call `StorageBackend` methods; its public API is unchanged, so all existing callers (`NosebleedService`, existing tests) keep working.
- Rename of the Sembast `metadata` `StoreRef` to `backend_state`. Code-only rename; no migration needed (greenfield system, per `project_greenfield_status.md`).

**Does not produce:** any new user-facing behavior. A developer running the branch at the end of Phase 2 sees no app-level change.

**Explicit non-goals:**
- Does NOT enforce the new `event_type ∈ {finalized, checkpoint, tombstone}` restriction. `NosebleedService` still writes `"NosebleedRecorded"` until Phase 5.
- Does NOT change the `aggregate_id` format. The `diary-YYYY-M-D` pattern still flows through `EventRepository.append()` unchanged.
- Does NOT populate `diary_entries`. The upsert methods exist; no writer calls them yet.

## Execution Rules

Read the directory [README.md](README.md) and design doc §6, §7.1, §7.2, §7.3 before starting Task 1.

Every data type gets per-function `// Implements:` markers. Every test gets a per-test `// Verifies:` marker and an assertion ID in the test description string. Files end in `_test.dart`.

---

## Plan

### Task 1: Baseline verification

**TASK_FILE**: `PHASE2_TASK_1.md`

- [ ] **Confirm Phase 1 is complete**: on the shared branch, `git log --oneline` should show the Phase 1 squashed commit (`[CUR-1154] Phase 1: ...`) as either HEAD or immediately behind any in-flight review-feedback commits. If not, stop and complete Phase 1 first.
- [ ] **Stay on the shared branch**: `git checkout mobile-event-sourcing-refactor`. (No new branch is created — this is the same branch used for all 5 phases.)
- [ ] **Rebase onto main** in case main moved during Phase 1 review: `git fetch origin main && git rebase origin/main`. Resolve conflicts if any (none expected from Phase 1 — pure additions).
- [ ] **Baseline tests**:
  - `(cd apps/common-dart/append_only_datastore && flutter test)` — green
  - `(cd apps/common-dart/trial_data_types && dart test)` — green
  - `(cd apps/common-dart/provenance && dart test)` — green (Phase 1 output)
  - `(cd apps/daily-diary/clinical_diary && flutter test)` — green
  - `(cd apps/daily-diary/clinical_diary && flutter analyze)` — clean
- [ ] **Create TASK_FILE** capturing baseline output and the Phase 1 completion SHA.

---

### Task 2: Spec additions for storage contract and event schema

**TASK_FILE**: `PHASE2_TASK_2.md`

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md` (created in Phase 1)
- Modify: `spec/INDEX.md` (add any new REQ numbers)

Three new REQs, claimed via `discover_requirements("next available REQ-d")` (record in TASK_FILE; substitute throughout the plan before commit). Also run `discover_requirements("storage backend transaction event append-only")` to find existing applicable assertions and cite them in TASK_FILE as `APPLICABLE_ASSERTIONS: ...`.

**REQ-d00117 — `StorageBackend` transaction contract** (assertions A-F):
- A: `StorageBackend.transaction(body)` SHALL execute `body` inside a single atomic Sembast transaction such that all `Txn`-bound writes commit together or roll back together.
- B: A `Txn` handle SHALL NOT be valid outside the lexical scope of its `transaction()` body.
- C: `StorageBackend.appendEvent(txn, event)` SHALL write to the event log and increment the sequence counter within the same `Txn`; either both land or neither lands.
- D: `StorageBackend.upsertEntry(txn, entry)` SHALL replace the entire `diary_entries` row for that aggregate_id (whole-row replace, not partial merge).
- E: `StorageBackend.enqueueFifo(txn, destinationId, fifoEntry)` SHALL append the entry with `final_status = "pending"` and an empty `attempts[]` list.
- F: Key-value bookkeeping (sequence counter, schema version) SHALL live in a Sembast store named `backend_state`. The name `metadata` SHALL NOT be used for this purpose to avoid collision with the event-level `metadata` field.

**REQ-d00118 — event schema changes** (assertions A-D):
- A: Events SHALL carry a first-class `entry_type` string field (e.g., `"epistaxis_event"`, `"nose_hht_survey"`).
- B: Events SHALL NOT carry a `server_timestamp` field. The previous (device-clock) value SHALL be dropped; the server stamps its own `DEFAULT now()` on ingest.
- C: Top-level event fields `client_timestamp`, `device_id`, `software_version` SHALL be populated as exact duplicates of `metadata.provenance[0].received_at`, `metadata.provenance[0].identifier`, `metadata.provenance[0].software_version`. This duplication is a migration bridge (design doc §11.2).
- D: `aggregate_id` SHALL be a UUID for entries written via `EntryService.record()` (Phase 5). Entries written via the legacy `EventRepository.append()` path MAY continue to use the `diary-YYYY-M-D` date-bucket pattern until the legacy path is removed in Phase 5.

**REQ-d00119 — per-destination FIFO semantics** (first round of assertions A-D; fuller set in Phase 4):
- A: Each registered destination SHALL have exactly one FIFO store identified by `destination_id`.
- B: A FIFO entry SHALL carry: `entry_id`, `event_id`, `sequence_in_queue`, `wire_payload`, `wire_format`, `transform_version`, `enqueued_at`, `attempts[]`, `final_status`, `sent_at`.
- C: `final_status` SHALL be one of `"pending"`, `"sent"`, `"exhausted"`. No other values are legal.
- D: Once a FIFO entry's `final_status` changes from `"pending"`, the entry SHALL NOT be deleted. The entry becomes a permanent send-log record (FDA/ALCOA).

- [ ] **Baseline**: repo clean of uncommitted changes except TASK_FILEs.
- [ ] **Create TASK_FILE**.
- [ ] **Write the three REQs** into `spec/dev-event-sourcing-mobile.md`. Use the grammar in `spec/requirements-spec.md`.
- [ ] **Update `spec/INDEX.md`** with new REQ rows.
- [ ] **Commit**: "Add StorageBackend contract assertions (CUR-1154)".

---

### Task 3: New value types — `AppendResult`, `DiaryEntry`, `FifoEntry` and friends

**TASK_FILE**: `PHASE2_TASK_3.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/append_result.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/diary_entry.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/fifo_entry.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/attempt_result.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/final_status.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/send_result.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/exhausted_fifo_summary.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/value_types_test.dart`

**Applicable assertions:** REQ-d00119-B, REQ-d00119-C; reference REQ-d00117-E.

- [ ] **Baseline**: tests green from Task 1.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** (`value_types_test.dart`) covering:
  - `AppendResult` (fields: `sequence_number`, `event_hash`) — round-trip + equality.
  - `DiaryEntry` (fields per design §7.1: `entry_id`, `entry_type`, `effective_date`, `current_answers`, `is_complete`, `is_deleted`, `latest_event_id`, `updated_at`) — round-trip + equality.
  - `FifoEntry` — round-trip + equality. Assert: all nine design-doc-§7.1 columns are present. Assert: `final_status` is typed as `FinalStatus` enum, not a raw string.
  - `AttemptResult` (fields: `attempted_at`, `outcome`, `error_message`, `http_status`) — round-trip.
  - `FinalStatus` enum — exactly three values: `pending`, `sent`, `exhausted`. Confirm via `FinalStatus.values.length == 3` and each value's `name` matches the design-doc string.
  - `SendResult` sealed hierarchy — `SendOk`, `SendTransient { error, httpStatus? }`, `SendPermanent { error }`. Confirm `sealed` exhaustiveness (switch without default compiles).
  - `ExhaustedFifoSummary` (fields: `destination_id`, `head_entry_id`, `head_event_id`, `exhausted_at`, `last_error`) — round-trip.
- [ ] **Run tests**; expect compile failures for undefined types.
- [ ] **Implement** each value class as immutable (`final` fields, `const` constructor, `==`/`hashCode`). Per-class `// Implements:` markers referencing the applicable REQ assertion.
  - `FifoEntry` class annotation: `// Implements: REQ-d00119-B+C — carries all nine columns; final_status typed to the three legal values.`
  - `FinalStatus` enum annotation: `// Implements: REQ-d00119-C — exactly three legal values: pending | sent | exhausted.`
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: `flutter analyze` clean in this package.
- [ ] **Commit**: "Add storage-layer value types (CUR-1154)".

---

### Task 4: Refactor `Event` shape — drop `server_timestamp`, add `entry_type`

**TASK_FILE**: `PHASE2_TASK_4.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/infrastructure/repositories/event_repository.dart` (the `StoredEvent` class definition)
- Modify: `apps/common-dart/append_only_datastore/test/event_repository_test.dart`

**Applicable assertions:** REQ-d00118-A, REQ-d00118-B, REQ-d00118-C.

- [ ] **Baseline**: tests green from Task 3.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** in `event_repository_test.dart` (new test cases; keep existing ones):
  - Appending an event supplies an `entry_type` parameter and the resulting `StoredEvent.entryType` matches (REQ-d00118-A).
  - An appended event's `serverTimestamp` field is absent; attempting to access it is a compile error (the field must be removed from the class). Cover this with a doc-comment test assertion: a `// Verifies:` comment noting "this is a compile-time assertion: the class has no serverTimestamp field." Then in the test, confirm `toJson()` output map does NOT contain the key `"server_timestamp"` (REQ-d00118-B).
  - Top-level `device_id`, `client_timestamp`, `software_version` equal `metadata['provenance'][0]['identifier' / 'received_at' / 'software_version']` when provenance is supplied (REQ-d00118-C). Note: this test asserts the duplication rule; it is checked by the `EventRepository.append` code path in Task 6, not by `StoredEvent` itself.
- [ ] **Run tests**; expect failures.
- [ ] **Modify `StoredEvent`**:
  - Remove the `serverTimestamp` field. Update `toJson`/`fromJson` to stop writing/reading it. (Greenfield: no legacy-field tolerance required.)
  - Add `final String entryType` field. Update constructor signature, `toJson`, `fromJson`.
  - Add class annotation: `// Implements: REQ-d00118-A+B — first-class entry_type field; server_timestamp removed.`
- [ ] **Update every existing `StoredEvent` constructor call** in this file and in tests to pass `entryType`. For existing code paths (nosebleed), `entryType = "epistaxis_event"` is the correct value; for QoL the existing code has no entry_type today — defer that to Phase 5 where QuestionnaireService is replaced.
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Refactor Event schema: add entry_type, drop server_timestamp (CUR-1154)".

---

### Task 5: Define `StorageBackend` and `Txn` abstract classes

**TASK_FILE**: `PHASE2_TASK_5.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/txn.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`

**Applicable assertions:** REQ-d00117-A, REQ-d00117-B.

- [ ] **Baseline**: tests green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** using a tiny in-memory fake backend (`_InMemoryBackend` defined inline in the test file). The fake simulates `transaction()` semantics with a map-per-store and explicit commit/rollback. Tests:
  - Successful body returns value and all writes are visible afterwards (REQ-d00117-A happy path).
  - Thrown exception inside body rolls back all writes (REQ-d00117-A atomicity).
  - Calling a `Txn`-bound method outside the `transaction()` scope throws `StateError` (REQ-d00117-B).
- [ ] **Run tests**; expect failures for undefined classes.
- [ ] **Implement** `StorageBackend` as an abstract class with the full method signature list per design-doc §7.3. Every method gets a `// Implements:` comment citing the relevant contract assertion.
- [ ] **Implement `Txn`** as an abstract class with no exposed state (concrete backends store Sembast-transaction handles inside their own subclasses).
- [ ] Make the failing tests pass by fleshing out `_InMemoryBackend`.
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add StorageBackend and Txn abstract classes (CUR-1154)".

---

### Task 6: Implement `SembastBackend` — transaction wrapper, event append, event queries

**TASK_FILE**: `PHASE2_TASK_6.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/sembast_backend_event_test.dart`

**Applicable assertions:** REQ-d00117-A, REQ-d00117-C, REQ-d00117-F; REQ-p00004-A+B+I (append-only + tamper prevention); REQ-d00004-A+D+E (Sembast offline-first, mirrors server schema).

- [ ] **Baseline**: tests green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** using a `newDatabaseFactoryMemory()` in-memory Sembast for isolation. Cover:
  - `transaction()` atomicity with two writes that both land.
  - `transaction()` rollback when `body` throws.
  - `appendEvent()` writes to the `events` store and increments `backend_state['sequence_counter']` atomically.
  - `findEventsForAggregate(id)` returns events ordered by `sequence_number`.
  - `findAllEvents(afterSequence: X, limit: N)` applies both filters correctly, returns `List<Event>` in order.
  - `nextSequenceNumber()` returns monotonically increasing values across transactions.
  - `readSchemaVersion()` / `writeSchemaVersion(txn, v)` round-trip via `backend_state['schema_version']`.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `SembastBackend`**:
  - Constructor takes a `DatabaseFactory` and a path; opens the database lazily.
  - `StoreRef<int, Map<String, Object?>>('events')` unchanged.
  - `StoreRef<String, Object?>('backend_state')` — renamed from `metadata` (REQ-d00117-F).
  - `StoreRef<String, Map<String, Object?>>('diary_entries')` — new (stubbed; no writes in Phase 2 beyond test coverage).
  - `StoreRef<int, Map<String, Object?>>` family for each FIFO — created on demand, named `fifo_{destination_id}`.
  - Concrete `_SembastTxn implements Txn` wraps Sembast's `Transaction`.
  - Per-method `// Implements:` citations. For `appendEvent`: `// Implements: REQ-d00117-C, REQ-p00004-A+B — append-only, sequence increment in same txn.`
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "SembastBackend: transaction + event methods (CUR-1154)".

---

### Task 7: Implement `SembastBackend` — `diary_entries` CRUD

**TASK_FILE**: `PHASE2_TASK_7.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/sembast_backend_entries_test.dart`

**Applicable assertions:** REQ-d00117-D.

Note: this task adds the CRUD methods. The materializer that produces `DiaryEntry` rows lives in Phase 3. Phase 2 only tests the backend primitives in isolation.

- [ ] **Baseline**: tests green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `upsertEntry(txn, entry)` stores a row keyed by `entry_id`; reading back via `findEntries(entryType: ...)` returns it.
  - Calling `upsertEntry` a second time with the same `entry_id` and different fields REPLACES the row (not merges). Verify by checking a field that was in the first write but not the second is absent (REQ-d00117-D whole-row replace).
  - `findEntries(entryType: "x")` filter matches only rows with that entryType.
  - `findEntries(isComplete: true)`, `findEntries(isDeleted: true)`, `findEntries(dateFrom: d1, dateTo: d2)` each work independently and in combination.
- [ ] **Run tests**; expect failures.
- [ ] **Implement** `upsertEntry`, `findEntries`. Per-method `// Implements: REQ-d00117-D — whole-row replace.`
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "SembastBackend: diary_entries CRUD (CUR-1154)".

---

### Task 8: Implement `SembastBackend` — FIFO CRUD

**TASK_FILE**: `PHASE2_TASK_8.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart`

**Applicable assertions:** REQ-d00117-E, REQ-d00119-A, REQ-d00119-B, REQ-d00119-C, REQ-d00119-D.

- [ ] **Baseline**: tests green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `enqueueFifo(txn, destId, entry)` stores the entry; a subsequent `readFifoHead(destId)` returns the first-enqueued entry (FIFO ordering, REQ-d00119-A via per-store identity).
  - Enqueueing multiple entries preserves insertion order; `readFifoHead` always returns the oldest `pending`.
  - `appendAttempt(destId, entryId, attempt)` appends to the entry's `attempts[]` list. The entry's `final_status` remains unchanged by `appendAttempt`.
  - `markFinal(destId, entryId, FinalStatus.sent)` sets `final_status` and `sent_at`; the entry is NOT deleted (REQ-d00119-D — always retained as send-log).
  - After marking the head `sent`, the next `readFifoHead` call returns the next pending entry.
  - After marking the head `exhausted`, `readFifoHead` returns `null` (the FIFO is wedged — head is the exhausted entry, which is not `pending`).
  - `anyFifoExhausted()` returns `true` iff at least one FIFO across all destinations has any exhausted entry at its head.
  - `exhaustedFifos()` returns a summary per wedged FIFO with the head entry's details.
  - Enqueuing into destination A does not affect destination B's FIFO.
- [ ] **Run tests**; expect failures.
- [ ] **Implement** all FIFO methods. Store name pattern: `fifo_{destinationId}`. Per-method `// Implements:` markers.
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "SembastBackend: FIFO CRUD (CUR-1154)".

---

### Task 9: Refactor `EventRepository` to delegate through `StorageBackend`

**TASK_FILE**: `PHASE2_TASK_9.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/infrastructure/repositories/event_repository.dart`
- Modify: `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/core/di/datastore.dart` — wire `StorageBackend` injection

**Applicable assertions:** REQ-d00117-A, REQ-d00117-C, REQ-d00117-F; existing `EventRepository` REQs stay (REQ-p00004-A+B+E+I+L, REQ-d00004-D+E).

- [ ] **Baseline**: tests green.
- [ ] **Create TASK_FILE**.
- [ ] **Add failing test** in `event_repository_test.dart`: construct an `EventRepository` with an injected `StorageBackend` fake; assert that calling `.append(...)` dispatches to `backend.appendEvent(...)` inside `backend.transaction()`. Use the in-memory backend fake from Task 5 (exported for reuse).
- [ ] **Add failing test** that the repository still preserves the hash chain: append three events, verify `event_hash` of each equals SHA-256 of the canonical bytes including `previous_event_hash`. (This test may already exist — keep it; ensure it still passes after refactor.)
- [ ] **Run tests**; expect failures on the new dispatch test.
- [ ] **Refactor `EventRepository`**:
  - Constructor takes `StorageBackend backend` (dependency-injected). Existing callers pass a `SembastBackend` instance.
  - The `append(...)` method wraps its body in `backend.transaction((txn) async { ... backend.appendEvent(txn, ...); backend.nextSequenceNumber(txn); ... })`.
  - `getEventsForAggregate`, `getAllEvents`, `getLatestSequenceNumber`, `verifyIntegrity` delegate to the backend's read methods.
  - The sync-marker methods (`getUnsyncedEvents`, `markEventsSynced`, `getUnsyncedCount`) — these will be deleted in Phase 5 when FIFO-based sync replaces per-event sync markers. For Phase 2 they KEEP their current behavior by reading/writing a `syncedAt` field on the event. Add a `// TODO(CUR-1154, Phase 5): replaced by per-destination FIFO (REQ-p01001-D). Delete these methods when the last caller is migrated.`
  - Preserve the public API (method names, parameter lists, return types) byte-exact. All existing callers (`NosebleedService`, existing tests) MUST continue to work.
  - Each refactored method gets a per-function `// Implements:` marker.
- [ ] **Rename Sembast `metadata` store → `backend_state`** everywhere it is referenced. Update DI wiring to open the new store name. Greenfield: no migration required. (REQ-d00117-F.)
- [ ] **Run tests**; expect pass — existing and new.
- [ ] **Run `(cd apps/daily-diary/clinical_diary && flutter test)`** to confirm NosebleedService still works via the refactored repository. Expected: all green.
- [ ] **Lint**: clean.
- [ ] **Commit**: "EventRepository delegates through StorageBackend; rename metadata→backend_state (CUR-1154)".

---

### Task 10: Public library exports

**TASK_FILE**: `PHASE2_TASK_10.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Export** the following from the top-level library barrel:
  - `StorageBackend`, `Txn`, `SembastBackend`
  - `AppendResult`, `DiaryEntry`, `FifoEntry`, `AttemptResult`, `FinalStatus`, `ExhaustedFifoSummary`
  - `SendResult`, `SendOk`, `SendTransient`, `SendPermanent`
- [ ] **Confirm** no new symbols leak accidentally — every `export` statement is intentional.
- [ ] **Run tests and analyze** one more time across all three common-dart packages and `clinical_diary`.
- [ ] **Commit**: "Export StorageBackend public surface (CUR-1154)".

---

### Task 11: Version bump + CHANGELOG

**TASK_FILE**: `PHASE2_TASK_11.md`

- [ ] **Bump `append_only_datastore` version** (minor bump: new public surface).
- [ ] **Update `append_only_datastore/CHANGELOG.md`** with bullets for StorageBackend, SembastBackend, value types, backend_state rename.
- [ ] **Full verification**:
  - `(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)`
  - `(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)`
- [ ] **Commit**: "Bump append_only_datastore and update changelog (CUR-1154)".

---

### Task 12: Phase-boundary squash and request phase review

**TASK_FILE**: `PHASE2_TASK_12.md`

- [ ] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`. Phase 1's squashed commit and any in-progress Phase 2 work must remain — resolve conflicts preserving both. Phase 2's `metadata → backend_state` rename is a known hot spot for conflicts with any other PR that touched `sembast_backend.dart` or `EventRepository`.
- [ ] **Full verification**: `flutter test` / `flutter analyze` across all touched packages.
- [ ] **Interactive rebase to squash Phase 2 commits**: `git rebase -i origin/main` — leave the Phase 1 squashed commit as-is (`pick`), and squash every commit made during Phase 2 into a single commit with message:

  ```
  [CUR-1154] Phase 2: Add StorageBackend abstraction and SembastBackend

  - StorageBackend / Txn abstract classes; SembastBackend concrete
  - New value types: AppendResult, DiaryEntry, FifoEntry, AttemptResult,
    FinalStatus, ExhaustedFifoSummary, SendResult hierarchy
  - EventRepository refactored to delegate through StorageBackend
  - Sembast "metadata" store renamed to "backend_state"
  - Event schema: added entry_type, dropped server_timestamp
  - spec/dev-event-sourcing-mobile.md: REQ-d00117, REQ-d00118, REQ-d00119

  Public API of EventRepository is byte-exact. FIFO and diary_entries
  methods on the backend are unit-tested but unwired until Phase 5.
  ```

  Substitute real REQ-d numbers for REQ-d00117, REQ-d00118, REQ-d00119 before committing.
- [ ] **Force-push with lease**: `git push --force-with-lease`.
- [ ] **Comment on PR**: "Phase 2 ready for review — commit `<sha>`. Range from Phase 1 end: `<phase1_sha>..<sha>`. Review focus: `StorageBackend` contract, `SembastBackend` correctness, the `metadata → backend_state` rename, and event-schema changes (`entry_type` added, `server_timestamp` dropped)."
- [ ] **Wait for phase review**. Address feedback by committing fixups and re-running the interactive rebase in place.
- [ ] **Record phase-completion SHA** in TASK_FILE before starting Phase 3.

---

## Recovery

After `/clear` or context compaction:
1. Read this file.
2. Read [README.md](README.md) for conventions.
3. Find the first unchecked box.
4. Read the corresponding `PHASE2_TASK_N.md`.

Archive procedure is whole-ticket (after rebase-merge) — see [README.md](README.md) Archive section.
