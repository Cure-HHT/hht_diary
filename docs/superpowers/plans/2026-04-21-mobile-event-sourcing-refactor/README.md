# CUR-1154: Mobile Event-Sourcing Refactor — Master Plan Index

**Ticket:** CUR-1154
**Design doc:** `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md`
**Status:** Plans written, execution not started
**Merge strategy:** one long-lived branch with 5 phases; each phase squashed locally to one commit at phase completion; final branch rebase-merged to `main` as 5 linear commits.

## Why 5 phases instead of 1 flat PR

Keeps `main` history structured enough for a future `git bisect` to narrow a regression to a specific phase (types / storage / materialization / sync / cutover), while concentrating all review and merge ceremony into a single PR. The 5 commits on `main` after rebase-merge are not the raw dev-branch history — they are curated checkpoints produced by an interactive rebase at each phase boundary.

Rejected alternatives:

- **5 independent PRs, squash-merged.** Gave the same `main` history but cost 5× the ceremony and exposed other developers to 4 intermediate "dead code" states during the window between merges.
- **1 PR, squash-merged.** Eliminated ceremony but collapsed `main` history to a single 60-file commit, losing bisect granularity.

## Branch, PR, and merge conventions

- **Branch**: `mobile-event-sourcing-refactor` — already created, lives in its dedicated worktree at `~/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/`. All Phase 1-5 work commits to this branch.
- **PR**: one draft PR opened during Phase 1 prep, kept in draft through Phases 1-4. Marked ready-for-review when Phase 5 is phase-reviewed.
- **Review cadence**: at each phase boundary, the author does an interactive rebase to squash that phase's dev commits into a single commit with a curated message (`[CUR-1154] Phase N: <summary>`), force-pushes with `--force-with-lease`, and comments on the PR: "Phase N ready — commits `<sha>..<sha>`." The reviewer looks at that commit range.
- **Merge**: once the PR is fully approved, use **rebase-merge** (not squash-merge). This requires the repo's "Allow rebase merging" option to be enabled alongside the existing squash-merge default — a per-repo setting change, not a per-PR choice.
- **PR title**: `[CUR-1154] Mobile event-sourcing refactor` — becomes irrelevant after rebase-merge (each phase commit carries its own subject on `main`), but CI still requires the `[CUR-1154]` prefix during the draft lifetime.
- **Before each phase push**: `git fetch origin main && git rebase origin/main` to stay current. Resolve conflicts if any. Phase 2 and Phase 5 have the highest conflict potential (see Cross-phase invariants).
- No `--no-verify`, no hook skipping. If a pre-commit hook fails, fix the cause.

## Phase sequence

| # | Plan file | Scope | Risk |
| - | --- | --- | --- |
| 1 | [PLAN_PHASE1_foundations.md](PLAN_PHASE1_foundations.md) | New `provenance` package + `EntryTypeDefinition` data type | None — pure additions |
| 2 | [PLAN_PHASE2_storage_backend.md](PLAN_PHASE2_storage_backend.md) | `StorageBackend` abstract + `SembastBackend` concrete; `EventRepository` delegates through it | Low — behavior preserved |
| 3 | [PLAN_PHASE3_materialization.md](PLAN_PHASE3_materialization.md) | `DiaryEntry` view, materializer, `rebuildMaterializedView()` | Low — view populated but not yet read by UI |
| 4 | [PLAN_PHASE4_sync.md](PLAN_PHASE4_sync.md) | `Destination`, `SubscriptionFilter`, `DestinationRegistry`, `FifoEntry`, `SyncPolicy`, drain loop, `sync_cycle()` | Low — machinery in place, nothing calls it yet |
| 5 | [PLAN_PHASE5_cutover.md](PLAN_PHASE5_cutover.md) | `EntryService`, `EntryTypeRegistry`, `PrimaryDiaryServerDestination`, widget registry, triggers, screen updates, delete `NosebleedService` / `QuestionnaireService` | High — behavior change, old code removed |

Each phase must be green before the next starts: all tests pass, `flutter analyze` clean, CI green on the draft PR.

## REQ citation convention

**Grammar** (from `spec/requirements-spec.md`): `REQ-{prefix}{number}[-{assertion}]` where:
- `prefix` ∈ {`p` PRD, `o` Ops, `d` Dev}
- `number` is 5 digits
- `assertion` is a single uppercase letter `[A-Z]`

**Comment placement** (user directive for this ticket): citations go **immediately above the function or method that implements them**, not at the top of the file. File-level `// IMPLEMENTS REQUIREMENTS:` headers (currently present in e.g. `nosebleed_service.dart`) are preserved where they exist on existing files, but all **new** code uses per-function citations only.

**Format:**

```dart
// Implements: REQ-p00004-A+B — append-only event; record every data change as
// a separate event.
Future<AppendResult> appendEvent(Txn txn, Event event) async { ... }
```

- Single assertion: `// Implements: REQ-p00004-A — <short prose>`
- Multi-assertion (same REQ): `// Implements: REQ-p00004-A+B+E — <prose>`
- Multi-REQ: two `// Implements:` lines, one per REQ family. Do not mix families behind a single `+`.
- For tests: `// Verifies: REQ-p00004-A — <prose>`, placed immediately above the `test(...)` call. Also embed the assertion ID at the start of the test description string so `elspais` picks it up as a TEST node:

```dart
// Verifies: REQ-p00004-A — hash chain detects tampering.
test('REQ-p00004-A: hash chain detects tampering', () { ... });
```

For a `group()` covering multiple assertions, use a `///` doc comment:

```dart
/// Verifies REQ-p00004-A, REQ-p00004-B, REQ-p00004-I
group('hash chain', () { ... });
```

Test files MUST end in `_test.dart`.

## Applicable REQ assertions (master list)

From design doc §13 plus discovered sub-assertions. Full list in each phase plan's task cards.

| REQ | Title | Assertions | Source spec |
| --- | --- | --- | --- |
| REQ-p00004 | Immutable Audit Trail via Event Sourcing | A, B, C, D, E, F, G, I, L | `spec/prd-database.md` |
| REQ-p00006 | Offline-First Data Entry | A, B, C, D, E, F, G, H, I | `spec/prd-diary-app.md` |
| REQ-p00013 | Complete Data Change History | A, B, C, D, E | `spec/prd-database.md` |
| REQ-p01001 | Offline Event Queue with Automatic Synchronization | A, B, C, D, E, F, G, H, I, J, K, L, M, N | `spec/prd-event-sourcing-system.md` |
| REQ-p01067 | NOSE HHT Questionnaire | A, B, C, D, E, G, H, I | `spec/prd-questionnaire-nose-hht.md` |
| REQ-p01068 | HHT Quality of Life Questionnaire | A, B, C, D, E, F, G, H | `spec/prd-questionnaire-qol.md` |
| REQ-p00049 | Ancillary Platform Services | A | `spec/prd-services.md` (sub-A only for FCM-triggered sync) |
| REQ-d00004 | Local-First Data Entry Implementation | A, B, C, D, E, F, G | `spec/dev-app.md` |
| REQ-d00113 | Deleted Questionnaire Submission Handling | A, B, C, D, E, F | `spec/dev-questionnaire.md` |

## New assertions to be written during execution

The design doc §14 lists spec gaps. Each phase's "Create assertions if missing" step adds the needed assertions to the appropriate spec file. The new assertions land in one new DEV spec:

**File to create in Phase 1:** `spec/dev-event-sourcing-mobile.md`

It will accumulate assertions across the 5 phases:

| Phase | Assertions added to dev-event-sourcing-mobile.md |
| -- | --- |
| 1 | `REQ-d?????`: `ProvenanceEntry` schema, append rule, `identifier` and `transform_version` semantics |
| 1 | `REQ-d?????`: `EntryTypeDefinition` schema, `effective_date_path` dialect, `widget_id` registry contract |
| 2 | `REQ-d?????`: `StorageBackend` transaction contract, `backend_state` key-value bookkeeping |
| 2 | `REQ-d?????`: event schema (drop `server_timestamp`, add `entry_type`, restrict `event_type`) |
| 3 | `REQ-d?????`: `diary_entries` materialized view schema, rebuild semantics, effective_date fallback |
| 4 | `REQ-d?????`: per-destination FIFO semantics (strict order, `exhausted` wedge, backoff curve, `SyncPolicy` constants) |
| 4 | `REQ-d?????`: `sync_cycle()` trigger contract (foreground-only, reentrancy guard) |
| 5 | `REQ-d?????`: `EntryService` API, no-op detection rule |
| 5 | `REQ-d?????`: compile-time sponsor-repo destination registration ABI |

The exact REQ numbers get assigned at phase time — they come from the `elspais` MCP (`discover_requirements("next available REQ-d")`). The REQ-numbers placeholder `d?????` in each phase plan gets resolved in the "Create assertions if missing" step.

## Requirement discovery

Use the `discover_requirements("<query>")` MCP tool (elspais) for:

1. Finding existing applicable assertions for a task (e.g., `discover_requirements("offline-first mobile event store")` before Phase 2 Task 6's event-append work).
2. Claiming the next available REQ-d number when writing new assertions (e.g., `discover_requirements("next available REQ-d")` at the start of each phase's spec-additions task).

Each task that writes to a spec file records the `discover_requirements` query and the returned assertion IDs into its TASK_FILE as `APPLICABLE_ASSERTIONS: REQ-xxx-Y, REQ-yyy-Z`. That record is how reviewers trace test/implementation coverage back to the authoritative spec.

## Entry-type identifiers (internal data tags)

Used as `event.entry_type` values and as keys in `EntryTypeRegistry`.

| Entry type | Purpose | Widget |
| --- | --- | --- |
| `epistaxis_event` | Patient-recorded nosebleed (with startTime, endTime, intensity, notes) | `epistaxis_form_v1` |
| `no_epistaxis_event` | "No nosebleeds today" calendar mark for a given date | `epistaxis_form_v1` (display-only variant) |
| `unknown_day_event` | "Don't remember" calendar mark for a given date | `epistaxis_form_v1` (display-only variant) |
| `nose_hht_survey` | NOSE HHT validated instrument (29 questions) | `survey_renderer_v1` |
| `hht_qol_survey` | HHT Quality of Life validated instrument (4 questions) | `survey_renderer_v1` |

Rationale: `_event` vs `_survey` separates point-in-time patient-recorded occurrences from administered validated instruments. `epistaxis` (clinical term for nosebleed) keeps the name study-agnostic. `nose_hht` is retained for the survey because "NOSE HHT" is the published name of the validated instrument.

UI text stays patient-facing ("nosebleed", not "epistaxis") — these identifiers are internal data tags, not user-visible strings.

## TDD cadence (applies to every task in every phase)

1. Baseline: confirm `dart test` / `flutter test` pass on the branch as-is.
2. Write failing tests first — for each assertion being implemented, one or more test cases with `// Verifies: REQ-xxx-Y` markers.
3. Run tests; confirm they fail for the right reason (not a typo).
4. Write minimum implementation to make tests pass, with per-function `// Implements: REQ-xxx-Y` markers.
5. Run tests; confirm they pass.
6. Run `flutter analyze` / `dart analyze`; confirm clean.
7. Commit. Commit subjects during phase development may be granular (`"Implement ProvenanceEntry"`, `"Add appendHop helper"`) — they get squashed at phase boundary into a single curated commit.

No test is allowed to pass without a corresponding implementation marker. No implementation is allowed to land without a corresponding `// Verifies:` test.

## Test layering

- **Unit tests** (`test/**/*_test.dart`): pure-Dart logic in `apps/common-dart/*/test/`; widget and service logic in `apps/daily-diary/clinical_diary/test/`. Run with `flutter test` or `dart test`.
- **Integration tests** (`integration_test/**/*_test.dart`): end-to-end flows under `apps/daily-diary/clinical_diary/integration_test/`. Run with `flutter test integration_test/`. Phase 5 is where the bulk of integration-test updates land because that's where the UI cutover happens.

Mocks: the existing test suite uses `mockito` and `package:flutter_test`. Do not introduce new mock frameworks.

## Cross-phase invariants

Things that must be true at the end of every phase, not just Phase 5:

1. `dart test` in every touched pure-Dart package passes.
2. `flutter test` in `clinical_diary` passes.
3. `flutter analyze` in `clinical_diary` returns zero errors.
4. The installed app still boots, shows the home screen, and can record a nosebleed through the current NosebleedService path — until Phase 5 removes that path. A developer running Phases 1-4 locally sees no behavior change.
5. No dead-letter code on the branch: anything added that is not yet wired from a production code path is either exercised by tests or gated behind a single call site that is TODO-commented with the phase that will wire it (e.g., `// Wired in Phase 5 (see PLAN_PHASE5_cutover.md)`).
6. Each phase's final commit (post-squash) has a subject starting `[CUR-1154] Phase N: ...` so `main` history is grep-friendly.

## Phase-boundary squash procedure

At the end of each phase, before requesting phase review:

1. All TASK_FILEs for the phase are complete.
2. Final intra-phase commits are made (TDD granular).
3. Interactive rebase: `git rebase -i origin/main` — squash all intra-phase commits belonging to this phase into one commit. Earlier phases' squashed commits remain as-is.
4. Commit message format: `[CUR-1154] Phase N: <one-line summary>` followed by a body listing the main changes and the phase-level REQs introduced.
5. Force-push with lease: `git push --force-with-lease`.
6. Comment on PR: "Phase N ready for review — commit `<sha>`. Range from previous: `<prev_sha>..<sha>`."
7. Wait for phase review to be addressed before starting the next phase's tasks (or address feedback and re-squash in place).

## Recovery after context loss

After `/clear` or compaction:

1. Read this README.
2. `git log --oneline origin/main..HEAD` — the squashed phase commits on the branch tell you how far you got.
3. If the top commit's subject is `[CUR-1154] Phase N: ...`, you are between phases; open `PLAN_PHASE{N+1}_*.md` to find the next task.
4. If the top commit is granular (no `Phase N:` prefix yet), you are mid-phase; open the current phase's plan and find the first unchecked box. Read the corresponding TASK_FILE for in-progress notes.

## Archive

When all 5 phases are complete, phase-reviewed, the PR is approved, and the rebase-merge to `main` has landed:

- [ ] Verify `main` has 5 new commits matching the 5 phase-completion subjects.
- [ ] Move this directory: `mv docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor ~/archive/2026-04-21/CUR-1154/`
- [ ] Close CUR-1154 in Linear with a link to the merged PR and the 5 commit SHAs on `main`.
- [ ] Update `memory/project_event_sourcing_refactor_out_of_scope.md` — mark mobile-side items complete; portal-ingestion items remain open.
