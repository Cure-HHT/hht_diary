# Master Plan Phase 4.5: Storage failure taxonomy

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 4.5 of 6
**Status**: Not Started
**Depends on**: Phase 4.4 squashed and phase-reviewed

## Goal

Land a sealed `StorageException` hierarchy and a `classifyStorageException` function that maps caught sembast / `dart:io` / decode-failure exceptions into three categories: **transient** (retryable), **permanent** (non-retryable, data intact), and **corrupt** (data integrity violated). No call sites consume the classifier in Phase 4.5 — it is a pure additive utility that Phase 4.6 can evaluate and wire up.

## Architecture

One new file `lib/src/storage/storage_exception.dart` holding:

- `sealed class StorageException implements Exception` with three subclasses: `StorageTransientException`, `StoragePermanentException`, `StorageCorruptException`. Each carries `message: String`, `cause: Object`, `stackTrace: StackTrace`.
- `StorageException classifyStorageException(Object error, StackTrace stack)` — pure function, pattern-matches known exception types to the three categories. Fallback is `StoragePermanentException` (conservative: treat unknown-as-permanent so a loop doesn't retry forever on genuinely unrecoverable state).

No changes to `StorageBackend`, `SembastBackend`, `EventStore`, `EntryService`, or any materializer. No new system entry types. No audit events.

## Tech Stack

Dart 3 (sealed classes, pattern matching). Test framework: `flutter_test`. Fault-injection for tests: raise the raw exceptions (`DatabaseException`, `FileSystemException`, `FormatException`, etc.) and call the classifier directly — no new mocking infrastructure.

## Scope boundaries

**In Phase 4.5:**
- `StorageException` sealed base + 3 variants (transient / permanent / corrupt).
- `classifyStorageException(error, stack) → StorageException`.
- Library barrel export.

**Deferred to Phase 4.6 (re-evaluate usefulness during 4.6 planning; drop if not earning their keep):**
- Storage-health query / stream surface (observable backend health to callers).
- `FailureInjector` test seam (dependency-injected fault source).
- `EntryService.record` / `EventStore.append` failure-classification wrap (catch → classify → rethrow typed).

**Out of scope entirely:**
- Storage-failure audit log (persisting storage errors as system events — a new reserved entry type would be needed; user explicitly scoped OUT on 2026-04-23).
- `MaterializedView` recovery on read corruption (detect corrupt view rows → skip-one / rebuild-one / rebuild-all; user explicitly scoped OUT on 2026-04-23).
- PostgreSQL `StorageBackend` classifier extensions (portal-side concern; Phase 4.5 classifier handles sembast + `dart:io` only).

`clinical_diary` / `NosebleedService` remain untouched; Phase 5 cuts them over.

## Execution rules

Read `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md` in full before starting. TDD cadence, REQ citation format, phase-squash procedure, and cross-phase invariants apply.

Phase 4.5 lands as one squashed commit. Per-task commit cadence during development is fine — the squash happens on PR-ready. Before phase-squash prep verification, all tests MUST be green.

Per-task controller workflow lives in `PHASE_4.5_WORKLOG.md`. Each task:
1. Implement the task per the steps below.
2. Append a brief outline of the finished work to `PHASE_4.5_WORKLOG.md` (status, not history).
3. Commit the changes.
4. Launch a sub-agent to review the commit (tell it NOT to read `docs/`).
5. Decide which review comments to address; log both addressed and dismissed to WORKLOG.
6. Commit review fixes.

Given the small phase size (5 tasks; ~1 new file + ~1 test file + barrel + spec + README update), a single consolidated review at the end — matching the Phase 4.4 approach — is acceptable instead of per-task review.

## Applicable REQ assertions

One new REQ-d topic, claimed at Task 2 via `discover_requirements("next available REQ-d")`. Lands in `spec/dev-event-sourcing-mobile.md` to keep the REQ corpus co-located with the existing `REQ-d00115..d00142` block.

| REQ topic | Scope | Assertions |
| --- | --- | --- |
| `REQ-STORAGE-FAILURE` (proposed wording: "Storage Failure Taxonomy") | sealed hierarchy; three categories; classifier fallback; cause preservation | A-G |

**Proposed assertions (final wording decided at Task 2 inside elspais):**

- **A** — `StorageException` is a sealed class with exactly three subclasses: `StorageTransientException`, `StoragePermanentException`, `StorageCorruptException`.
- **B** — A public function `classifyStorageException(Object error, StackTrace stack)` returns a `StorageException` for any input.
- **C** — Sembast `DatabaseException` codes for lock contention / concurrent-modification / timeout classify as `StorageTransientException`.
- **D** — `FormatException` on event-data decode and hash-chain mismatch (detected by `EventRepository` / `EventStore`) classify as `StorageCorruptException`.
- **E** — `dart:io` `FileSystemException` with permission / access errors, and any `StateError` / `ArgumentError` from the backend, classify as `StoragePermanentException`.
- **F** — An unrecognized input type is conservatively classified as `StoragePermanentException` (not transient) — the classifier must never cause an infinite retry loop.
- **G** — Every `StorageException` instance preserves the original `cause` (`Object`) and `stackTrace` (`StackTrace`) fields for diagnostic traceability.

REQ citation placement: `// Implements: REQ-xxx-Y — <prose>` per-function; `// Verifies: REQ-xxx-Y — <prose>` per-test; the assertion ID starts the test description: `test('REQ-xxx-Y: description', () { ... })`.

---

## Tasks

### Task 1: Baseline verification

- [ ] Confirm on branch `mobile-event-sourcing-refactor` at the squashed Phase 4.4 commit (`git log -1 --format="%s"` should start with `[CUR-1154] Phase 4.4`).
- [ ] Run all four test suites; record the counts in `PHASE_4.5_WORKLOG.md`:
  - `(cd apps/common-dart/append_only_datastore && flutter test)` — expect 453 pass (flutter_test SDK dep; `dart test` fails with "package test not found")
  - `(cd apps/common-dart/provenance && dart test)` — expect 31 pass
  - `(cd apps/common-dart/trial_data_types && dart test)` — expect 59 pass
  - `(cd apps/daily-diary/clinical_diary && flutter test)` — expect 1098 pass
- [ ] Run `dart analyze` / `flutter analyze` on each; expect clean.
- [ ] If any suite is red, stop and investigate before proceeding.
- [ ] Create `PHASE_4.5_WORKLOG.md` at worktree root scaffolded with the per-task controller workflow block (mirror the top-of-file block from `PHASE_4.4_WORKLOG.md`).

### Task 2: Parent plan README update + REQ claim

**README:**

- [ ] Insert a new row into the phase-sequence table in `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md` between the 4.4 row and the 4.6 row:

  ```
  | 4.5 | [PLAN_PHASE4.5_library.md](PLAN_PHASE4.5_library.md) | `StorageException` sealed hierarchy + `classifyStorageException` function (transient / permanent / corrupt) | Low — pure additive utility, no call sites in 4.5 |
  ```

**REQ claim via elspais:**

- [ ] `discover_requirements("next available REQ-d")` to claim the next `REQ-d00143` (or whatever the next free number is).
- [ ] `mutate_add_requirement` with title "Storage Failure Taxonomy", placed under the closest-fitting parent PRD. Candidate parents:
  - `REQ-p01002` (Optimistic Concurrency Control) — if an "error handling" super-topic exists
  - `REQ-p01018` (Audit / Security posture) — weakest fit; prefer not to use since audit log is OUT OF SCOPE
  - If no parent fits cleanly, place as a top-level REQ-d on `spec/dev-event-sourcing-mobile.md`.
- [ ] Add assertions A-G per the table above. Use elspais assertion-add tooling; keep prose close to the proposed wording but tighten where the reviewer prefers.
- [ ] `move_requirement` (if needed) into `spec/dev-event-sourcing-mobile.md` — matches placement of REQ-d00115..d00142.
- [ ] Regenerate `spec/INDEX.md` via `elspais fix`.

### Task 3: `StorageException` sealed hierarchy (TDD)

File: `apps/common-dart/append_only_datastore/lib/src/storage/storage_exception.dart`
Test file: `apps/common-dart/append_only_datastore/test/storage/storage_exception_test.dart`

**Red:**

- [ ] Write tests covering REQ-A (three variants exist, are each subclasses of the sealed base, cannot be otherwise extended — compile-time check via a pattern-match exhaustiveness test) and REQ-G (each variant preserves `cause` and `stackTrace`). Include:
  - One test per variant: constructed with `message`, `cause` (a `StateError`), `stackTrace` (`StackTrace.current`); assert fields round-trip; assert `toString()` contains `message` and `cause`.
  - One exhaustiveness test: a switch-expression over `StorageException` that compiles without a `default:` or `_:` arm, proving the sealed hierarchy has exactly the declared subclasses.

**Green:**

- [ ] Implement `sealed class StorageException implements Exception` with `final String message`, `final Object cause`, `final StackTrace stackTrace`, and a const constructor.
- [ ] Implement the three subclasses with `const` constructors forwarding to `super`.
- [ ] Override `toString()` once on the base: `"${runtimeType}: $message (cause: $cause)"`.
- [ ] REQ-citation comment immediately above the base class.

**Refactor:**

- [ ] Ensure `dart analyze --fatal-infos` clean.
- [ ] Ensure `dart format` clean.

### Task 4: `classifyStorageException` function (TDD)

Same file as Task 3 (append to `storage_exception.dart`) or sibling `storage_exception_classifier.dart` — choose based on file-size readability, but prefer one file for now since the classifier is ≤60 lines.

Test file: `apps/common-dart/append_only_datastore/test/storage/storage_exception_classifier_test.dart`

**Red:**

Test matrix covering REQ-B / C / D / E / F / G:

- [ ] Sembast `DatabaseException` with code `errDatabaseLocked` (or whichever sembast code signals transient contention; see `package:sembast/src/api/v2/database.dart` for the constants) → `StorageTransientException`. Use an actual sembast `DatabaseException` instance via `sembast_memory`, not a string fake.
- [ ] `TimeoutException` (`dart:async`) → `StorageTransientException`.
- [ ] `FormatException('bad JSON')` → `StorageCorruptException`.
- [ ] A custom `HashChainException` signal — if Phase 4.4 didn't introduce one, raise a `FormatException` with a message containing `"hash chain"` and classify based on that; otherwise pattern-match on the type. (Decide at Task 4 time; log the decision in WORKLOG.) → `StorageCorruptException`.
- [ ] `FileSystemException('permission denied', '/path')` (from `dart:io`) → `StoragePermanentException`.
- [ ] `StateError('closed')` → `StoragePermanentException`.
- [ ] `ArgumentError('bad param')` → `StoragePermanentException`.
- [ ] An arbitrary bare `Exception('???')` → `StoragePermanentException` (REQ-F fallback).
- [ ] Every classified result preserves `.cause == the original error` and `.stackTrace == the input stack` (REQ-G).

**Green:**

- [ ] Implement `StorageException classifyStorageException(Object error, StackTrace stack)` as a pure top-level function. Use Dart pattern-matching (`switch (error)` with type patterns) where possible; fall through to the `StoragePermanentException` default.
- [ ] REQ-citation comment immediately above the function.
- [ ] Keep imports minimal: `package:sembast/sembast.dart` for `DatabaseException`, `dart:async` for `TimeoutException`, `dart:io` for `FileSystemException`.

**Refactor:**

- [ ] `dart analyze --fatal-infos` clean.
- [ ] `dart format` clean.

### Task 5: Library barrel + phase-squash prep verification

**Barrel:**

- [ ] Add to `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`:

  ```dart
  export 'src/storage/storage_exception.dart'
      show
          StorageException,
          StorageTransientException,
          StoragePermanentException,
          StorageCorruptException,
          classifyStorageException;
  ```

- [ ] Confirm no other file needed a re-export (the classifier is standalone).

**Phase-squash prep verification:**

- [ ] Run all four suites; record the counts in `PHASE_4.5_WORKLOG.md`:
  - `append_only_datastore` (via `flutter test`) — expect 453 + (Task 3 test count) + (Task 4 test count) pass
  - `provenance` (via `dart test`) — expect 31 pass (unchanged)
  - `trial_data_types` (via `dart test`) — expect 59 pass (unchanged)
  - `clinical_diary` (via `flutter test`) — expect 1098 pass (unchanged)
- [ ] `dart analyze` / `flutter analyze` clean on each.
- [ ] `elspais` graph clean: no orphans, no broken references, no rewrite suggestions for the new REQ.
- [ ] `spec/INDEX.md` up-to-date (re-run `elspais fix` if needed).
- [ ] Append phase-summary section to `PHASE_4.5_WORKLOG.md` (final counts, REQ claimed, carry-overs to Phase 4.6 unchanged from this plan's scope-boundaries section).
- [ ] Launch one consolidated review sub-agent against the Phase 4.5 diff (commits since the squashed Phase 4.4 commit), explicitly telling it NOT to read `docs/`. Log addressed + dismissed comments to WORKLOG. Commit fixes if needed.

---

## Phase-squash procedure (reference)

Matches Phase 4.4:

1. Identify the Phase 4.4 squashed-commit SHA (the base for 4.5).
2. `git reset --soft <phase-4.4-sha>` on `mobile-event-sourcing-refactor`.
3. `git commit -m "[CUR-1154] Phase 4.5: StorageException taxonomy + classifier"` with a full body summarizing scope + final test counts + deferred/out-of-scope carry-overs.
4. `git push origin mobile-event-sourcing-refactor` (fast-forward from the Phase 4.4 squashed commit; no `--force` needed if no intermediate work has been pushed).

## Decisions reserved for execution

1. **REQ parent placement** — whether `REQ-STORAGE-FAILURE` hangs under an existing PRD or lives as a top-level `REQ-d`. Depends on what elspais surfaces as the closest fit at Task 2 time. If nothing fits, default to top-level on `spec/dev-event-sourcing-mobile.md`.
2. **`HashChainException` type** — whether Phase 4.4 introduced a dedicated exception type for hash-chain break, or whether the break surfaces as a `FormatException` with a recognizable message. Task 4 inspects `EventRepository` / `EventStore` sources and logs the decision in WORKLOG.
3. **Sembast error-code constants** — the exact identifier used for "database locked" / "concurrent modification" in the installed sembast version. Task 4 reads the sembast source / API and pins the constant at commit time.
4. **Commit bundling** — if the pre-commit hook's `dart analyze` requires the barrel export to match what's exported (i.e. Task 3 leaves types unexported and the analyzer complains about an unused public API), Task 3 and Task 5's barrel bump may need to land in the same commit. Decide at commit time; log in WORKLOG.
