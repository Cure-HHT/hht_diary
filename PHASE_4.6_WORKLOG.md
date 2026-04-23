# Phase 4.6 Worklog

One section per completed task. Current state only — no diff narration.

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.6_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.

("phase" here denotes each numbered task of Phase 4.6; the full Phase 4.6 lands as one squashed commit per the user's preference. Per the user's kickoff direction, Phase 4.6 uses a single consolidated review at phase end — mirroring Phase 4.4 / 4.5.)

---

## Scope decision (kickoff, 2026-04-23)

Phase 4.5 carries re-evaluated at 4.6 kickoff — all three dropped:

- **Storage-health query/stream surface** — no demo journey consumes it; signal would never flip on a Linux-desktop review walk.
- **`FailureInjector` test seam** — the demo already *is* the failure injector at the Destination layer (`DemoDestination.connection` + `sendLatency`); backend-level injection has no UI and no journey.
- **`EntryService.record` / `EventStore.append` classification wrap** — library polishing with no observable demo effect; deserves its own phase when a real consumer (portal ingest, background sync) lands.

Net: Phase 4.6 proceeds exactly as `PLAN_PHASE4.6_demo.md` is written. No plan edits beyond the REQ-d placeholder substitutions required by Task 1.

Out-of-scope-entirely items remain out of scope (storage-failure audit log, MaterializedView read-corruption recovery — per memory `project_event_sourcing_refactor_out_of_scope.md`).

---

## Plan

`docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.6_demo.md` — 16 tasks building a Flutter Linux-desktop sandbox at `apps/common-dart/append_only_datastore/example/` that exercises every library feature shipped in Phases 4 / 4.3 / 4.4 via live UI. Acceptance = reviewer-walked nine-scenario USER_JOURNEYS. No widget tests, no integration tests, no CI (design non-goals §4.2). Unit tests on value objects (styles palette, demo types, demo destination, demo sync policy, app state).

## Task 1: Baseline verification

### Git state

- HEAD before rebase: `b2cf5699` (Phase 4.5 tip, from memory)
- `origin/main` moved one commit (`5f430f7b..9f4aa87d`) during Phase 4.4/4.5 — CUR-1111 admin_action_log constraint fix. Main's change touches `diary_functions/questionnaire_submit.dart` + four pubspec version bumps + two SQL files; zero overlap with `append_only_datastore/`.
- Rebased the 64-commit branch onto `origin/main` with `-X ours` (keeps main's newer pubspec versions at conflict points; no real code conflicts). New HEAD: `abcf3315`. All Phase 4.4 + 4.5 artifacts intact (`storage_exception.dart`, `classifyStorageException`, EventStore, materialization lib, security sidecar).
- Carried `.githooks/pre-commit` working-tree change (ELSPAIS_VERSION unset fix) stashed through the rebase and restored afterward — orthogonal to Phase 4.6.

### Baseline tests (post-rebase)

- `append_only_datastore` (`flutter test`): **472 pass**; `dart analyze --fatal-infos` clean
- `provenance` (`dart test`): **31 pass**; `dart analyze` clean
- `trial_data_types` (`dart test`): **59 pass**; `dart analyze` clean
- `clinical_diary` (`flutter test`): **1098 pass** (1 skip); `flutter analyze` clean

### REQ-d number substitution

Plan authored before Phase 4.3 landed; its applicable-REQ table used topic-name placeholders. Substitutions (from `spec/dev-event-sourcing-mobile.md` and library REQ-citation headers):

| Plan placeholder | Actual REQ-d | Title |
| --- | --- | --- |
| REQ-ENTRY | REQ-d00133 | EntryService.record Contract |
| REQ-BOOTSTRAP | REQ-d00134 | bootstrapAppendOnlyDatastore Contract |
| REQ-SYNCPOLICY | REQ-d00126 | SyncPolicy Injectable Value Object |
| REQ-SYNCCYCLE | REQ-d00125 | sync_cycle() Orchestrator and Trigger Contract |
| REQ-DEST | REQ-d00122 | Destination Contract for Per-Destination Sync |
| REQ-DYNDEST | REQ-d00129 | Dynamic Destination Lifecycle |
| REQ-REPLAY | REQ-d00130 | Historical Replay on Past startDate |
| REQ-TIMEWINDOW | REQ-d00129-I | (time-window clause of Dynamic Destination Lifecycle) |
| REQ-BATCH | REQ-d00128 | (batch shape, canAddToBatch, maxAccumulateTime, transform) |
| REQ-FIFO | REQ-d00119 | Per-Destination FIFO Queue Semantics |
| REQ-UNJAM | REQ-d00131 | Unjam Destination Operation |
| REQ-REHAB | REQ-d00132 | Rehabilitate Exhausted FIFO Row |
| REQ-SKIPMISSING | REQ-d00127 | markFinal and appendAttempt Tolerate Missing FIFO Row |

Plan's applicable-REQ table updated in-place with these substitutions.

### Library-surface notes (plan line 83 reconciliation)

Plan asked for these symbols to be exported from `package:append_only_datastore/append_only_datastore.dart`. Actual surface differs in three spots; demo adapts per plan's own "exact names must match the Phase-4.3-shipped API" admonition (lines 249, 347, 392, 463, 537 of the plan):

- `EntryTypeDefinition` — lives in `package:trial_data_types/trial_data_types.dart`, not in the datastore barrel. Example's `pubspec.yaml` will declare `trial_data_types` as a direct dep at Task 3.
- `Event` — canonical event value type is `StoredEvent` (exported). `Destination.canAddToBatch` / `transform` take `List<StoredEvent>`. Demo uses `StoredEvent` throughout.
- `syncCycle` — not a top-level function. `SyncCycle` is a class (exported); caller constructs one and invokes `.call()`. Demo's `main.dart` Timer.periodic will hold a `SyncCycle` instance and call `.call()`.

All other plan-required symbols are exported as expected: `bootstrapAppendOnlyDatastore`, `AppendOnlyDatastore`, `EntryService`, `EntryTypeRegistry`, `Destination`, `SubscriptionFilter`, `DestinationRegistry`, `WirePayload`, `SendOk`, `SendTransient`, `SendPermanent`, `SyncPolicy`, `rebuildMaterializedView`, `UnjamResult`, `SetEndDateResult`, plus Phase 4.4/4.5 additions (`EventStore`, `StorageException` + variants, `classifyStorageException`, `Materializer`, `DiaryEntriesMaterializer`, security sidecar).

### Bootstrap shape (plan Task 9 reconciliation)

`bootstrapAppendOnlyDatastore` actual signature:
- Requires `backend`, `source`, `entryTypes`, `destinations`; optional `materializers`, `syncCycleTrigger`.
- Returns `AppendOnlyDatastore` facade with fields `eventStore`, `entryTypes`, `destinations` (the DestinationRegistry), `securityContexts`.
- Demo's `main.dart` will additionally construct an `EntryService` (for the Task 12 lifecycle buttons) since the facade does not expose one, passing `backend`, `entryTypes`, `syncCycleTrigger`, `deviceInfo`.

Task 9 template in the plan will be adjusted to this shape during implementation (per plan's own explicit allowance).

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.6_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.
