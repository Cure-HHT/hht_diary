# Master Plan Phase 3: `DiaryEntry` materialization

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 3 of 5
**Status**: Not Started
**Depends on**: Phase 2 squashed and phase-reviewed

## Scope

Introduce the materializer — the pure function that folds an event into a `DiaryEntry` view row — and the disaster-recovery `rebuildMaterializedView()` helper. Leave the materializer **unwired**: nothing in `EventRepository.append()` or elsewhere calls it in production yet. Phase 5 is where `EntryService.record()` wires it into the write path.

Rationale for leaving unwired: the current `EventRepository.append()` path is driven by `NosebleedService`, which writes the legacy `aggregate_id = "diary-YYYY-M-D"` date-bucket pattern (not a per-entry UUID) and does not conform to the whole-answer-replace semantics the materializer assumes. Running the materializer on legacy writes would populate the `diary_entries` view with garbage. The materializer runs only when `EntryService` becomes the writer in Phase 5.

**Produces:**
- `apps/common-dart/append_only_datastore/lib/src/materialization/entry_type_definition_lookup.dart` — abstract lookup interface for Phase 5 to implement.
- `apps/common-dart/append_only_datastore/lib/src/materialization/materializer.dart` — `Materializer.apply(previous, event, def) -> DiaryEntry`.
- `apps/common-dart/append_only_datastore/lib/src/materialization/rebuild.dart` — `rebuildMaterializedView(backend, lookup) -> Future<int>` (returns rowcount).
- Comprehensive unit test coverage.

**Does not produce:** any call from production code to `Materializer.apply()` or `rebuildMaterializedView()`. No change to app behavior. Tests pass an in-memory `EntryTypeDefinitionLookup` stub.

## Execution Rules

Read [README.md](README.md), design doc §6.2 (event types), §7.1 (diary_entries shape), §7.4 (rebuild), §11.3 (materializer fallbacks), and the `StorageBackend` surface shipped at the end of Phase 2 before starting Task 1.

---

## Plan

### Task 1: Baseline verification

**TASK_FILE**: `PHASE3_TASK_1.md`

- [x] **Confirm Phase 2 complete**: on the shared branch, `git log --oneline` should show Phase 2's squashed commit as HEAD (or immediately behind any Phase-2-feedback fixups that have been folded in).
- [x] **Stay on shared branch** (no new branch creation).
- [x] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`.
- [x] **Baseline tests** — all green:
  - `(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)`
  - `(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)`
- [x] **Create TASK_FILE** with output and Phase 2 completion SHA.

---

### Task 2: Spec additions — materializer and rebuild

**TASK_FILE**: `PHASE3_TASK_2.md`

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md`

One new REQ, claimed via `discover_requirements("next available REQ-d")`. Also run `discover_requirements("materialized view CQRS event log projection")` and record existing applicable assertions in TASK_FILE.

**REQ-MAT — `diary_entries` materialization** (assertions A-I):

- A: `Materializer.apply(previous, event, def)` SHALL be a pure function of its inputs. No I/O, no clock reads, no random values.
- B: When `event.event_type == "finalized"`, the resulting `DiaryEntry` SHALL have `is_complete = true` and `current_answers` SHALL equal `event.data.answers` in full (whole-replacement, not merge).
- C: When `event.event_type == "checkpoint"`, the resulting `DiaryEntry` SHALL have `is_complete = false` and `current_answers` SHALL equal `event.data.answers` in full.
- D: When `event.event_type == "tombstone"`, the resulting `DiaryEntry` SHALL have `is_deleted = true`; all other fields SHALL carry over from the previous row.
- E: `latest_event_id` SHALL equal `event.event_id`. `updated_at` SHALL equal `event.client_timestamp`.
- F: `effective_date` SHALL be computed by resolving `def.effective_date_path` as a JSON path into `current_answers`. When the path is null or does not resolve (e.g., checkpoint event without the target field yet), `effective_date` SHALL fall back to the `client_timestamp` of the **first** event on this aggregate. The caller SHALL provide the first-event timestamp when known.
- G: `rebuildMaterializedView(backend, lookup)` SHALL read all events ordered by `sequence_number`, fold them through `Materializer.apply()`, and replace the entire `diary_entries` store with the result. Prior contents of `diary_entries` SHALL NOT be read as input.
- H: `rebuildMaterializedView` SHALL return the number of distinct `aggregate_id` values materialized.
- I: The `diary_entries` store SHALL be treated as a cache. Production code MAY NOT read `diary_entries` without the invariant that it is derivable from `event_log` by calling `rebuildMaterializedView`. This is an architectural assertion verified by code review, not by runtime checks.

- [x] **Baseline**.
- [x] **Create TASK_FILE**.
- [x] **Write REQ-MAT** into `spec/dev-event-sourcing-mobile.md`. (Allocated as REQ-d00121.)
- [x] **Update `spec/INDEX.md`** with the new REQ row. (Regenerated by `elspais fix`.)
- [x] **Commit**: "Add materializer contract assertions (CUR-1154)".

---

### Task 3: `EntryTypeDefinitionLookup` abstract interface

**TASK_FILE**: `PHASE3_TASK_3.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/materialization/entry_type_definition_lookup.dart`
- Create: `apps/common-dart/append_only_datastore/test/materialization/entry_type_definition_lookup_test.dart`

**Applicable assertions:** REQ-d00116-A (the lookup must agree with `EntryTypeDefinition.id`); REQ-MAT-A (materializer is pure — lookup provides the def it needs).

- [x] **Baseline**: green.
- [x] **Create TASK_FILE**.
- [x] **Write failing tests** for the interface. Include a simple `MapEntryTypeDefinitionLookup` concrete for use by tests elsewhere in Phase 3:
  - `lookup(id)` returns the matching `EntryTypeDefinition` by `id`.
  - Returns `null` (or throws `ArgumentError` — decide; document in code) when no match. Go with `null` return — callers switch on null for fallback behavior.
  - The test-only `MapEntryTypeDefinitionLookup` wraps a `Map<String, EntryTypeDefinition>`.
- [x] **Run tests**; expect failures.
- [x] **Implement** the abstract class with a single method `EntryTypeDefinition? lookup(String entryTypeId);`. Plus the test-only `MapEntryTypeDefinitionLookup` exported from a `test/test_support/` directory (not from `lib/`).
- [x] **Run tests**; expect pass.
- [x] **Lint**: clean.
- [x] **Commit**: "Add EntryTypeDefinitionLookup interface (CUR-1154)".

---

### Task 4: `Materializer.apply()` — pure folding function

**TASK_FILE**: `PHASE3_TASK_4.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/materialization/materializer.dart`
- Create: `apps/common-dart/append_only_datastore/test/materialization/materializer_test.dart`

**Applicable assertions:** REQ-MAT-A, B, C, D, E, F; REQ-p00004-E (current view derivable from events); REQ-p00004-L (view updated when new events arrive — the caller runs the materializer in the write path, per-function comment references this).

- [x] **Baseline**: green.
- [x] **Create TASK_FILE**.
- [x] **Write failing tests** (`materializer_test.dart`). Target signature:

  ```dart
  DiaryEntry apply({
    required DiaryEntry? previous,
    required Event event,
    required EntryTypeDefinition def,
    required DateTime firstEventTimestamp,
  });
  ```

  Test cases (each with `// Verifies:` marker and assertion-ID test description):

  - **Finalized from scratch** (`previous == null`, `event_type == "finalized"`): returns a `DiaryEntry` with `is_complete = true`, `is_deleted = false`, `current_answers == event.data.answers`, `latest_event_id == event.event_id`, `updated_at == event.client_timestamp`, `entry_id == event.aggregate_id`, `entry_type == event.entry_type`. (REQ-MAT-B, E)
  - **Checkpoint from scratch**: `is_complete = false`, otherwise same fields. (REQ-MAT-C)
  - **Finalized over existing finalized** (user editing): `current_answers` is fully replaced, `is_complete` stays `true`, `updated_at` advances to new event's timestamp. Critically: no field-level merge — a key present in the prior answers but absent in the new event is GONE. (REQ-MAT-B whole-replacement)
  - **Tombstone over existing finalized**: `is_deleted = true`, all other fields preserved (including `current_answers`, `is_complete`). (REQ-MAT-D)
  - **Tombstone from scratch** (shouldn't happen in practice but shouldn't crash): accept as valid — produces a row with `is_deleted = true` and empty `current_answers`.
  - **Effective date via JSON path** — def has `effective_date_path: "startTime"`; event.data.answers has `{"startTime": "2026-04-21T10:00:00Z", ...}`; resulting `effective_date == 2026-04-21`. (REQ-MAT-F)
  - **Effective date with nested path** — def has `effective_date_path: "answers.date"`; event.data.answers has `{"answers": {"date": "2026-04-21"}}`; path resolves. (REQ-MAT-F)
  - **Effective date fallback when path missing** — def has `effective_date_path: "startTime"`; event.data.answers is `{}` (checkpoint before user entered startTime); resulting `effective_date == firstEventTimestamp.date`. (REQ-MAT-F fallback)
  - **Effective date fallback when def.effective_date_path is null** — falls back to `firstEventTimestamp.date`.
  - **Pure function** — call `apply()` with the same inputs twice; get identical outputs. (REQ-MAT-A)
- [x] **Run tests**; expect failures for undefined `Materializer`.
- [x] **Implement `Materializer`** as a class with a single static method `apply(...)`. No instance state. The JSON-path resolution is an internal helper function — keep it a dotted-path dialect: `"a.b.c"` drills in; no array indexing, no filters (keep it minimal, note in a `// Implements: REQ-MAT-F — dotted-path dialect; arrays and filters out of scope.`).
  - Class annotation: `// Implements: REQ-MAT-A — pure function; no I/O, no clock, no randomness.`
  - `apply` per-method: `// Implements: REQ-MAT-B+C+D+E+F — fold event into view row per event_type.`
- [x] **Run tests**; expect pass.
- [x] **Lint**: clean.
- [x] **Commit**: "Implement Materializer.apply (CUR-1154)".

---

### Task 5: `rebuildMaterializedView()` helper

**TASK_FILE**: `PHASE3_TASK_5.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/materialization/rebuild.dart`
- Create: `apps/common-dart/append_only_datastore/test/materialization/rebuild_test.dart`

**Applicable assertions:** REQ-MAT-G, H; REQ-p00004-E (derivable view).

- [x] **Baseline**: green.
- [x] **Create TASK_FILE**.
- [x] **Write failing tests** using `SembastBackend` with an in-memory database and `MapEntryTypeDefinitionLookup` (from Task 3):
  - Empty `event_log` → `rebuildMaterializedView` returns `0`; `diary_entries` remains empty.
  - Three events on one aggregate (checkpoint → finalized → finalized) → returns `1`; the one resulting `DiaryEntry` reflects the final state.
  - Two events on aggregate A, one on aggregate B → returns `2`; both view rows present.
  - A tombstone event → the aggregate's row has `is_deleted = true` and remains in the view.
  - Rebuild after seeding `diary_entries` with garbage → the garbage is gone; only event-derived rows remain. (REQ-MAT-G: prior contents not read as input.)
  - Rebuild is idempotent: running it twice produces the same result.
- [x] **Run tests**; expect failures.
- [x] **Implement `rebuildMaterializedView(StorageBackend backend, EntryTypeDefinitionLookup lookup)`**:
  - Step 1: inside `backend.transaction()`, iterate all events via `backend.findAllEvents()`.
  - Step 2: group events by `aggregate_id`, preserving per-aggregate sequence order.
  - Step 3: for each group, compute `firstEventTimestamp = first.client_timestamp`, then fold via `Materializer.apply()`.
  - Step 4: clear the `diary_entries` store (delete all rows inside the transaction), then `upsertEntry` for each computed row.
  - Step 5: return the number of aggregates processed.
  - If the lookup returns `null` for an `entry_type`, throw `StateError` — the event log contains an unknown entry type, which is a data integrity problem. Log enough to diagnose.
  - Per-function: `// Implements: REQ-MAT-G+H — disaster-recovery rebuild; replaces view from event log in one transaction.`
- [x] **Run tests**; expect pass.
- [x] **Lint**: clean.
- [x] **Commit**: "Implement rebuildMaterializedView (CUR-1154)".

---

### Task 6: Public library exports

**TASK_FILE**: `PHASE3_TASK_6.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`

- [x] **Baseline**: green.
- [x] **Create TASK_FILE**.
- [x] **Export** `Materializer`, `EntryTypeDefinitionLookup`, `rebuildMaterializedView` from the top-level barrel.
- [x] **Keep `MapEntryTypeDefinitionLookup` out of `lib/`**. It lives under `test/test_support/` and is imported via relative path by tests. (Reason: it's a test double; we don't want apps to depend on it.)
- [x] **Commit**: "Export materialization public surface (CUR-1154)".

---

### Task 7: Version bump + CHANGELOG

**TASK_FILE**: `PHASE3_TASK_7.md`

- [x] **Bump `append_only_datastore` version** (minor bump).
- [x] **Update `CHANGELOG.md`** with bullets for Materializer, rebuildMaterializedView, EntryTypeDefinitionLookup.
- [x] **Full verification**:
  - `(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)`
  - `(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)` (no change expected)
- [x] **Commit**: "Bump append_only_datastore for Phase 3 (CUR-1154)".

---

### Task 8: Phase-boundary squash and request phase review

**TASK_FILE**: `PHASE3_TASK_8.md`

- [x] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`. Phases 1 and 2's squashed commits remain as-is. (main at `5f430f7b`, unchanged; no rebase needed.)
- [x] **Full verification**: `flutter test` / `flutter analyze` across all touched packages. (204 + 1098 tests pass; analyze clean on both packages.)
- [x] **Interactive rebase to squash Phase 3 commits**: `git rebase -i origin/main` — keep Phase 1 and Phase 2 commits as `pick`, squash all Phase 3 commits into one with message: (used `git reset --soft 508df506 && git commit` for equivalent result without interactive editor. Actual Phase 3 SHA is whatever `git log --oneline origin/main..HEAD` shows for the `[CUR-1154] Phase 3:` commit; intentionally not pinned here since folding task-file fixups keeps changing it.)

  ```
  [CUR-1154] Phase 3: Add materializer and rebuild helper

  - Materializer.apply(previous, event, def) — pure fold function
  - rebuildMaterializedView(backend, lookup) — disaster-recovery helper
  - EntryTypeDefinitionLookup abstract interface
  - spec/dev-event-sourcing-mobile.md: REQ-MAT

  Materializer is unwired in this phase. Phase 5 wires it into
  EntryService.record()'s transaction path.
  ```

- [ ] **Force-push with lease**. (Awaits user confirmation — visible, shared-state action.)
- [ ] **Comment on PR**: "Phase 3 ready for review — commit `<sha>`. Review focus: materializer correctness across the three event types, `effective_date_path` fallback behavior, rebuild idempotence. Materializer is still unwired." (Awaits user confirmation.)
- [ ] **Wait for phase review**. Address feedback via fixups + in-place rebase.
- [x] **Record phase-completion SHA** in TASK_FILE before starting Phase 4. (Recorded by reference — `git log origin/main..HEAD | grep 'Phase 3:'` — rather than pinning a literal SHA that goes stale on every amend.)

---

## Recovery

1. Read this file.
2. Read [README.md](README.md).
3. Find first unchecked box.
4. Read the matching `PHASE3_TASK_N.md`.

Archive procedure is whole-ticket (after rebase-merge) — see [README.md](README.md) Archive section.
