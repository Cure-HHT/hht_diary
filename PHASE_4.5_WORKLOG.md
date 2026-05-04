# Phase 4.5 Worklog

One section per completed task. Current state only — no diff narration.

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.5_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.

("phase" here denotes each numbered task of Phase 4.5; the full Phase 4.5 lands as one squashed commit per the user's preference. Scope is small enough that a single consolidated review at phase end — mirroring Phase 4.4's approach — is agreed.)

---

## Plan

`docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.5_library.md` — 5 TDD tasks covering `StorageException` sealed hierarchy (3 variants: transient / permanent / corrupt), `classifyStorageException` function mapping sembast + `dart:io` + decode-failure exceptions to those variants, library barrel export, parent-README row insert, one new REQ-d topic claim ("Storage Failure Taxonomy", A-G), and full-suite verification.

## Task 1: Baseline verification

Phase 4.4 tip is `7f3aebcd`. All test suites green before Phase 4.5 work begins:
- `append_only_datastore` (`flutter test`): 453 tests pass; `dart analyze` clean
- `provenance` (`dart test`): 31 tests pass; `dart analyze` clean
- `trial_data_types` (`dart test`): 59 tests pass; `dart analyze` clean
- `clinical_diary` (`flutter test`): 1098 tests pass (1 skip); `flutter analyze` clean

Note: `append_only_datastore` uses `flutter_test` (SDK) as its test dep, so the runner is `flutter test`, not `dart test`. Plan corrected in-place.

## Task 2: Parent plan README update + REQ claim

Phase 4.5 row inserted between 4.4 and 4.6 in `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md`.

`REQ-d00143: Storage Failure Taxonomy` claimed via elspais; parent `REQ-p00006` (Offline-First Data Entry) via IMPLEMENTS. Assertions A-G cover sealed hierarchy, classifier signature, transient / corrupt / permanent mapping rules, conservative-fallback invariant, and cause / stackTrace preservation. Placed in `spec/dev-event-sourcing-mobile.md` at line 747 via `move_requirement`. `spec/INDEX.md` regenerated via `elspais fix` (drive-by changelog-section additions on prd-p00043, p70001, p01073, p01065, p00044 accepted).

Bundled-commit decision: Tasks 1-2 land as one commit (plan file + README row + WORKLOG scaffold + REQ claim), matching Phase 4.4's Tasks 1-2 cadence. The rest of Phase 4.5 uses per-task commits where analyze stays green, bundled where the pre-commit hook requires it.

## Task 3: StorageException sealed hierarchy

`lib/src/storage/storage_exception.dart` declares `sealed class StorageException implements Exception` with three subclasses: `StorageTransientException`, `StoragePermanentException`, `StorageCorruptException`. Each constructor takes `(String message, Object cause, StackTrace stackTrace)` and forwards to `super`. Each subclass overrides `toString()` with its literal class name to avoid `runtimeType.toString()` (which Dart lints as unsafe for release-mode tree-shaking).

Test file `test/storage/storage_exception_test.dart` — 6 tests:
- sealed pattern-match exhaustive over three variants (REQ-d00143-A)
- each variant is a subclass of `StorageException` and `Exception` (REQ-d00143-A)
- cause + stackTrace preservation on each variant (REQ-d00143-G)
- `toString()` diagnostic shape

**Final state:** `append_only_datastore` — 459 tests pass (+6 from baseline); `dart analyze --fatal-infos` clean.

## Task 4: classifyStorageException function

`lib/src/storage/storage_exception.dart` appends `StorageException classifyStorageException(Object error, StackTrace stack)` — a pure Dart-3 switch-expression mapping caught errors to the three variants. Never throws. Imports `dart:async`, `dart:io`, and `package:sembast/sembast.dart`.

Classification map:
- `TimeoutException` → `StorageTransientException`
- `FormatException` (including messages containing "hash chain") → `StorageCorruptException`
- `FileSystemException` → `StoragePermanentException`
- sembast `DatabaseException` (all four codes — `errBadParam`, `errDatabaseNotFound`, `errInvalidCodec`, `errDatabaseClosed`) → `StoragePermanentException`
- `StateError`, `ArgumentError` → `StoragePermanentException`
- Anything else → `StoragePermanentException` (REQ-F conservative fallback; unknown ≠ retryable)

**Design decision logged in code comment:** sembast `errInvalidCodec` classifies as permanent (wrong codec/key, on-disk data intact) rather than corrupt (data bytes damaged).

**REQ-C narrowed at task time:** original wording asserted sembast database-locked / concurrent-modification signals map to transient. Sembast does not surface those signals via `DatabaseException` — lock contention is handled internally. REQ-C rewritten to name `TimeoutException` + "backend-raised transient-failure signals (lock contention, concurrent modification, timeout)" generically, with an explicit note that the sembast-only classifier has no `DatabaseException` codes mapping to transient. INDEX.md regenerated via `elspais fix`.

Test file `test/storage/storage_exception_classifier_test.dart` — 12 tests covering all of REQ-B/C/D/E/F/G, including:
- sembast `DatabaseException.closed()` and `DatabaseException.invalidCodec(...)` → permanent
- unrecognized `Object()` → permanent AND not transient (explicit `isNot(StorageTransientException)`)
- identity-preservation of `.cause` and `.stackTrace` across all classified paths

**Final state:** `append_only_datastore` — 471 tests pass (+12 from Task 3); `dart analyze --fatal-infos` clean.

## Task 5: Library barrel + full-suite verification

Barrel `lib/append_only_datastore.dart` exports `StorageException`, `StorageTransientException`, `StoragePermanentException`, `StorageCorruptException`, `classifyStorageException` (alphabetical placement after `storage_backend.dart`, before `stored_event.dart`).

**All four suites green at Phase 4.5 tip:**
- `append_only_datastore` (via `flutter test`): 471 tests pass (+18 from Phase 4.4 tip); `dart analyze --fatal-infos` clean
- `provenance` (via `dart test`): 31 tests pass; `dart analyze` clean
- `trial_data_types` (via `dart test`): 59 tests pass; `dart analyze` clean
- `clinical_diary` (via `flutter test`): 1098 tests pass (1 skip); `flutter analyze` clean

**elspais graph:** 53 pre-existing `kind: code` orphans (none in `append_only_datastore`; unrelated to REQ-d00143). `has_broken_references: true` reflects pre-existing 289 cross-repo suppressed refs, same as Phase 4.4 baseline. `spec/INDEX.md` up to date — REQ-d00143 present at line 339 with hash `fdd444f1` after Task 4's REQ-C wording update.

**Carries to Phase 4.6 (unchanged):** storage-health query/stream surface, `FailureInjector` test seam, `EntryService.record` / `EventStore.append` failure-classification wrap — re-evaluate whether each earns its keep during 4.6 planning.

**Out of scope entirely (decided 2026-04-23):** storage-failure audit log, `MaterializedView` read-corruption recovery.

## Consolidated code review + fixes

One review sub-agent ran against the Phase 4.5 diff (commits `7f3aebcd..6d78a5ed`, `docs/` excluded). Three findings; two addressed, one dismissed.

**Addressed (2 of 3):**

1. **`DatabaseException.errInvalidCodec` reclassified from permanent to corrupt.** At the classifier layer, a codec-decode failure is caller-visible indistinguishable from on-disk byte damage; the conservative-information path is to raise the corrupt variant so a caller with a rebuild / operator-surface handler can act. Split the `DatabaseException` arm into two: `when e.code == errInvalidCodec` → `StorageCorruptException`; remaining lifecycle codes → `StoragePermanentException`. Updated REQ-d00143-D (added errInvalidCodec) and REQ-d00143-E (narrowed to lifecycle codes). Test renamed from `REQ-E: invalidCodec classifies as permanent` to `REQ-D: invalidCodec classifies as corrupt`.

2. **Coverage gap for `Error`-hierarchy inputs to the classifier.** Added a test case with `AssertionError` (a non-`Exception` `Error` subtype) verifying it falls to the wildcard arm as `StoragePermanentException`, preserves cause identity, and is explicitly NOT transient. Closes REQ-d00143-F coverage for the `Error` branch.

**Dismissed (1 of 3):**

3. **Test files import `src/` directly rather than via the barrel.** This matches the established project convention across all other storage tests (`initiator_test.dart`, `source_test.dart`, `stored_event_test.dart`, `storage_backend_views_test.dart`, etc.) — they all use `package:append_only_datastore/src/...`. A Phase 4.5 one-off barrel-import would be inconsistent with the rest of the test corpus. Worth revisiting as project-wide tech-debt, but not as a Phase 4.5 deviation.

**Post-review state:** `append_only_datastore` — 472 tests pass (+1 from pre-review); `dart analyze --fatal-infos` clean. REQ-d00143 hash `59ed82f7` (was `fdd444f1` pre-fix).
