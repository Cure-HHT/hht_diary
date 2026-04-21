# Master Plan Phase 1: Foundations — `provenance` package + `EntryTypeDefinition`

**Branch**: `mobile-event-sourcing-refactor` (shared across all 5 phases)
**Ticket**: CUR-1154
**Phase**: 1 of 5
**Status**: Not Started

## Scope

Add pure-Dart data types used by every subsequent phase. Zero runtime integration: nothing in `clinical_diary` calls any of this code until Phase 5.

**Produces:**
- New package `apps/common-dart/provenance/` exporting `ProvenanceEntry` and `appendHop(...)`.
- New type `EntryTypeDefinition` in existing `apps/common-dart/trial_data_types/`.
- New spec file `spec/dev-event-sourcing-mobile.md` with assertions for both new types.

**Does not produce:** any change to `append_only_datastore`, `NosebleedService`, `QuestionnaireService`, or any screen. No change to on-disk event schema.

## Execution Rules

These rules apply to EVERY task below. Do not skip steps. Do not reorder.

Read the directory [README.md](README.md) and the design doc `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` (§6.4 and §6.5) before starting Task 1.

Per-function REQ citation format (user directive):

```dart
// Implements: REQ-d?????-A+B — short prose.
ProvenanceEntry appendHop(List<ProvenanceEntry> chain, ProvenanceEntry hop) { ... }
```

Tests use `// Verifies:` with the assertion ID also echoed into the test description string (see README "REQ citation convention").

---

## Plan

### Task 1: Baseline verification, clean up pre-existing state, commit plans, open draft PR

**TASK_FILE**: `PHASE1_TASK_1.md`

The worktree at `~/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/` is already checked out on branch `mobile-event-sourcing-refactor`. No branch creation needed. A few housekeeping steps come before Phase 1 implementation starts.

- [ ] **Confirm branch**: `git branch --show-current` returns `mobile-event-sourcing-refactor`. If not, stop.
- [ ] **Triage pre-existing uncommitted state**: as of 2026-04-21 the working tree has a mix of CUR-1154-related and unrelated changes. Inspect via `git status`:
  - `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` — CUR-1154 design doc; stage for commit.
  - `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/` — this plan directory; stage for commit.
  - `.elspais.toml`, `.elspais.toml.old` — elspais MCP debugging; NOT CUR-1154 related. Stash, move to a separate branch, or have the user deal with these before Phase 1 starts. Do not commit them to `mobile-event-sourcing-refactor`.
  - `apps/sponsor-portal/tool/deployment-doctor.sh` — NOT CUR-1154 related. Same treatment.
  - Any other uncommitted file: ask the user.
- [ ] **Commit the CUR-1154 planning docs**: `git add docs/superpowers/ && git commit -m "[CUR-1154] Add design doc and 5-phase implementation plan"`. This commit is the foundation for the branch; it is distinct from the 5 phase commits that follow and lands on `main` as a 6th commit when the PR rebase-merges.
- [ ] **Baseline tests** on the branch as it now stands:
  - `(cd apps/common-dart/trial_data_types && dart test)` green
  - `(cd apps/common-dart/append_only_datastore && flutter test)` green
  - `(cd apps/common-dart/provenance && dart test)` — this package does not exist yet; command should report "no package"; that is fine.
  - `(cd apps/daily-diary/clinical_diary && flutter test)` green
  - `(cd apps/daily-diary/clinical_diary && flutter analyze)` clean — record any pre-existing warnings so they do not get blamed on this refactor
- [ ] **Push the branch**: `git push -u origin mobile-event-sourcing-refactor`. If the branch already exists on origin (it may), just `git push`.
- [ ] **Open the draft PR** (before any implementation starts) so CI exercises the branch early and the PR URL is available for all 5 phases to reference:
  - `gh pr create --draft --title "[CUR-1154] Mobile event-sourcing refactor" --body "<body>"` where `<body>` links to the design doc, this directory's [README.md](README.md), notes that the PR is developed in 5 phases with phase-by-phase review (force-push + comment per phase), and notes that the PR will be rebase-merged (not squash-merged) so `main` receives 6 curated commits (1 planning + 5 phase commits).
  - Record the PR URL in TASK_FILE.
- [ ] **Verify repo settings support rebase-merge**: `gh repo view --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed`. Expected: `rebaseMergeAllowed: true`. If `false`, surface to the user — they control this setting and noted they will enable it before merge time.
- [ ] **Create TASK_FILE** capturing baseline output, planning-commit SHA, and PR URL.

Expected: all baseline commands pass. If any test fails on the branch, stop and surface that to the user — do not start Phase 1 implementation on a red tree.

---

### Task 2: Create `spec/dev-event-sourcing-mobile.md` with provenance and entry-type-definition assertions

**TASK_FILE**: `PHASE1_TASK_2.md`

**Files:**
- Create: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md` (add the two new REQs to the dev-level table)

- [ ] **Baseline**: confirm `git status` shows the branch checked out and no uncommitted changes except the plan files.
- [ ] **Create TASK_FILE**: `PHASE1_TASK_2.md`.
- [ ] **Find applicable existing assertions**: `discover_requirements("chain of custody provenance audit trail")` and `discover_requirements("entry type definition questionnaire widget")`. Record results in TASK_FILE as `APPLICABLE_ASSERTIONS: ...`.
- [ ] **Claim next REQ-d numbers**: `discover_requirements("next available REQ-d")` returns the next two slots. Record in TASK_FILE as the real numbers for `REQ-PROV` and `REQ-ETD`, then substitute the real numbers everywhere in this plan before committing.
- [ ] **Write the spec**. Use `spec/requirements-spec.md` as the grammar reference. The file must include two REQs.

  **REQ 1 — `ProvenanceEntry`** assertions (expected A-F):

  - A: System SHALL append exactly one `ProvenanceEntry` to `metadata.provenance` on each hop that receives an event.
  - B: System SHALL NOT mutate any prior `ProvenanceEntry` in the chain.
  - C: Each `ProvenanceEntry` SHALL carry: `hop` (string), `received_at` (ISO 8601 with timezone), `identifier` (string), `software_version` (string), optional `transform_version` (string).
  - D: `identifier` SHALL be the device UUID for the `"mobile-device"` hop; for server hops it SHALL be the server instance identifier.
  - E: `software_version` SHALL follow the format `"<package-name>@<semver>[+<build>]"`.
  - F: `transform_version` SHALL be non-null when and only when this hop's incoming wire payload was produced by a transform at the previous hop.

  **REQ 2 — `EntryTypeDefinition`** assertions (expected A-G):

  - A: An `EntryTypeDefinition` SHALL carry an `id` string that matches the `event.entry_type` value for all events of this type.
  - B: An `EntryTypeDefinition` SHALL carry a `version` string that matches `event.data.questionnaire_version` for all events of this type.
  - C: An `EntryTypeDefinition` SHALL carry a `widget_id` string that is a key into the Flutter widget registry.
  - D: An `EntryTypeDefinition` MAY carry a nullable `effective_date_path` string; when non-null it SHALL be a JSON path into `data.answers` usable by the materializer (§7.3 of design doc).
  - E: When `effective_date_path` is null or does not resolve, the materializer SHALL fall back to the `client_timestamp` of the first event on the aggregate.
  - F: An `EntryTypeDefinition` SHALL carry a `widget_config` JSON payload; its shape is determined by `widget_id`.
  - G: An `EntryTypeDefinition` MAY carry an optional `destination_tags` list of strings used by `SubscriptionFilter` matching.

- [ ] **Update `spec/INDEX.md`**: add both new REQs to the "dev-" table with their file pointers and content hashes. Compute hashes per the convention in existing INDEX.md entries (check one of them to see the hash algorithm — if unclear, leave placeholder and note in TASK_FILE to resolve in a follow-up).
- [ ] **Verify**: `tools/requirements/` — if a requirements validator script exists, run it and confirm no errors. Otherwise note in TASK_FILE that validation was manual.
- [ ] **Commit** with subject referencing CUR-1154 and body describing the two REQs added. Append commit SHA to TASK_FILE.

---

### Task 3: Create `apps/common-dart/provenance/` package scaffolding

**TASK_FILE**: `PHASE1_TASK_3.md`

**Files:**
- Create: `apps/common-dart/provenance/pubspec.yaml`
- Create: `apps/common-dart/provenance/analysis_options.yaml`
- Create: `apps/common-dart/provenance/README.md`
- Create: `apps/common-dart/provenance/.gitignore`
- Create: `apps/common-dart/provenance/lib/provenance.dart` (empty library stub for now)
- Create: `apps/common-dart/provenance/test/.gitkeep`

- [ ] **Baseline**: `(cd apps/common-dart && ls)` — confirm no `provenance/` directory yet.
- [ ] **Create TASK_FILE**.
- [ ] **Write `pubspec.yaml`**. Pure Dart (no Flutter SDK). Model after `trial_data_types/pubspec.yaml`:
  - `name: provenance`
  - `description: "Chain-of-custody provenance types for cross-system event flow - REQ-d?????"` (the REQ-PROV number from Task 2)
  - `version: 0.0.1`
  - `environment: sdk: ^3.10.1`
  - `dependencies: {}` (no runtime deps; the helper is a pure function)
  - `dev_dependencies: test: ^1.25.0`, `lints: ^5.0.0`
- [ ] **Write `analysis_options.yaml`** including `package:lints/recommended.yaml`.
- [ ] **Write `README.md`**: one short paragraph pointing to the design doc §6.5 and the spec REQ.
- [ ] **Write `lib/provenance.dart`** as an empty `library;` declaration for now.
- [ ] **Verify**: `(cd apps/common-dart/provenance && dart pub get)` succeeds.
- [ ] **Commit**: "Scaffold provenance package (CUR-1154)".

---

### Task 4: Implement `ProvenanceEntry`

**TASK_FILE**: `PHASE1_TASK_4.md`

**Files:**
- Create: `apps/common-dart/provenance/lib/src/provenance_entry.dart`
- Modify: `apps/common-dart/provenance/lib/provenance.dart` (add export)
- Create: `apps/common-dart/provenance/test/provenance_entry_test.dart`

**Applicable assertions:** REQ-PROV-C, REQ-PROV-D, REQ-PROV-E, REQ-PROV-F.

- [ ] **Baseline**: `(cd apps/common-dart/provenance && dart test)` — expected: no tests found (green trivially).
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** for `ProvenanceEntry`. File: `test/provenance_entry_test.dart`. Each test group gets a `/// Verifies REQ-PROV-X` doc comment; each `test(...)` gets a `// Verifies:` comment above and the assertion ID at the start of the description string. Cover:
  - Construct an entry with all required fields and confirm every getter round-trips.
  - `toJson() / fromJson()` round-trip preserves all fields including null `transform_version`.
  - `fromJson()` throws `FormatException` on a missing required field.
  - `received_at` serializes as an ISO 8601 string including timezone offset.
  - `identifier` format test: a mobile-device entry with a device UUID, a server entry with an instance id (both shapes legal; no validation in the type itself — document that validation is the caller's responsibility).
  - `software_version` format check: the type accepts the full `"package@semver+build"` shape verbatim (no parsing in the type).
  - `transform_version` is null-when-absent, non-null-when-present.
  - Two entries with identical fields are `==` (value equality) and have equal `hashCode`.
- [ ] **Run tests**: `(cd apps/common-dart/provenance && dart test)`; expected: failures referencing undefined `ProvenanceEntry`.
- [ ] **Implement `ProvenanceEntry`** as an immutable value class (final fields, `const` constructor, `==` and `hashCode` overrides). Above the class, a one-line `// Implements: REQ-PROV-C+D+E+F — <prose>` comment. Each non-trivial method (`toJson`, `fromJson`, `copyWith` if needed) gets its own per-function `// Implements:` if it embodies a specific assertion.
- [ ] **Run tests**; expected: all pass.
- [ ] **Lint**: `(cd apps/common-dart/provenance && dart analyze)`; expected: no issues.
- [ ] **Update library export**: add `export 'src/provenance_entry.dart';` to `lib/provenance.dart`.
- [ ] **Commit**: "Add ProvenanceEntry value type (CUR-1154)".

---

### Task 5: Implement `appendHop()` helper

**TASK_FILE**: `PHASE1_TASK_5.md`

**Files:**
- Create: `apps/common-dart/provenance/lib/src/append_hop.dart`
- Modify: `apps/common-dart/provenance/lib/provenance.dart` (add export)
- Create: `apps/common-dart/provenance/test/append_hop_test.dart`

**Applicable assertions:** REQ-PROV-A, REQ-PROV-B.

- [ ] **Baseline**: `(cd apps/common-dart/provenance && dart test)` — expected green from Task 4.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** for `appendHop(chain, hop) -> List<ProvenanceEntry>`. Cover:
  - Appending to an empty list yields a one-entry list.
  - Appending to a non-empty list yields a list with length + 1.
  - The returned list is a new `List`, not a mutation of the input. The input list MUST compare equal to its pre-call state after the call returns (REQ-PROV-B: no mutation of prior entries).
  - The newly-appended entry is at the tail.
  - Appending the same entry twice yields two equal entries at positions N and N+1 (no deduplication).
- [ ] **Run tests**; expect failures for undefined `appendHop`.
- [ ] **Implement** `appendHop()` as a pure function returning `List<ProvenanceEntry>.unmodifiable([...chain, hop])`. Above it:
  ```dart
  // Implements: REQ-PROV-A+B — append exactly one ProvenanceEntry on each
  // hop; never mutate prior entries. Returned list is unmodifiable so callers
  // cannot break the invariant downstream either.
  ```
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: `dart analyze` clean.
- [ ] **Update library export**: add `export 'src/append_hop.dart';` to `lib/provenance.dart`.
- [ ] **Commit**: "Add appendHop helper (CUR-1154)".

---

### Task 6: Implement `EntryTypeDefinition` in `trial_data_types`

**TASK_FILE**: `PHASE1_TASK_6.md`

**Files:**
- Create: `apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart`
- Modify: `apps/common-dart/trial_data_types/lib/trial_data_types.dart` (add export and REQ-ETD to header)
- Create: `apps/common-dart/trial_data_types/test/entry_type_definition_test.dart`

**Applicable assertions:** REQ-ETD-A, REQ-ETD-B, REQ-ETD-C, REQ-ETD-D, REQ-ETD-F, REQ-ETD-G.

(Assertion E — materializer fallback — is tested in Phase 3, not here. The type carries the `effective_date_path` field; the fallback behavior lives in the materializer.)

- [ ] **Baseline**: `(cd apps/common-dart/trial_data_types && dart test)` — expected green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** for `EntryTypeDefinition`:
  - Construct with all required fields (`id`, `version`, `name`, `widget_id`, `widget_config`) — all getters round-trip.
  - `effective_date_path` defaults to null; can be set to a dotted path like `"startTime"` or `"answers.date"`.
  - `destination_tags` defaults to null; can be set to a `List<String>`.
  - `toJson() / fromJson()` round-trip preserves everything, including nulls.
  - `fromJson()` throws `FormatException` if any required field is missing.
  - Value equality: same fields → `==` and equal `hashCode`.
  - `widget_config` round-trips arbitrary JSON (use a map with nested lists and strings as the fixture).
- [ ] **Run tests**; expect failures.
- [ ] **Implement `EntryTypeDefinition`** as an immutable value class. Per-function `// Implements:` markers for the constructor, `toJson`, and `fromJson`.
  - Constructor annotation: `// Implements: REQ-ETD-A+B+C+F+G — carries the seven fields called out in the design doc §6.4.`
  - `fromJson`: `// Implements: REQ-ETD-C+F — decoder rejects payloads missing the required widget_id / widget_config fields.`
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: `dart analyze` clean.
- [ ] **Update library export**: add `export 'src/entry_type_definition.dart';` to `lib/trial_data_types.dart` and add `//   REQ-d?????: EntryTypeDefinition` to the file-level header block.
- [ ] **Commit**: "Add EntryTypeDefinition type (CUR-1154)".

---

### Task 7: Version bumps and CHANGELOG

**TASK_FILE**: `PHASE1_TASK_7.md`

**Files:**
- Modify: `apps/common-dart/provenance/pubspec.yaml` (from 0.0.1 → 0.1.0 since first functional release)
- Modify: `apps/common-dart/trial_data_types/pubspec.yaml` (bump patch version)
- Modify/Create: `apps/common-dart/provenance/CHANGELOG.md`
- Modify/Create: `apps/common-dart/trial_data_types/CHANGELOG.md`

- [ ] **Baseline**: `(cd apps/common-dart/provenance && dart test)` and `(cd apps/common-dart/trial_data_types && dart test)` both green.
- [ ] **Create TASK_FILE**.
- [ ] **Bump `provenance` to 0.1.0** and add a `CHANGELOG.md` entry describing `ProvenanceEntry` and `appendHop`.
- [ ] **Bump `trial_data_types`** by patch and add a `CHANGELOG.md` entry describing `EntryTypeDefinition`.
- [ ] **Verify** one last time: all tests green in both packages; `dart analyze` clean in both; `flutter analyze` in `clinical_diary` unchanged from baseline.
- [ ] **Commit**: "Bump versions and changelog for Phase 1 (CUR-1154)".

---

### Task 8: Phase-boundary squash and request phase review

**TASK_FILE**: `PHASE1_TASK_8.md`

- [ ] **Rebase onto main** (in case main moved during phase work): `git fetch origin main && git rebase origin/main`. Resolve conflicts if any.
- [ ] **Full verification one more time**: `dart test` / `flutter test` / `flutter analyze` across all touched packages.
- [ ] **Interactive rebase to squash Phase 1 commits**: `git rebase -i origin/main`. Squash every commit made during Phase 1 (should be 6-7 granular commits from Tasks 2-7) into a single commit with message:

  ```
  [CUR-1154] Phase 1: Add provenance package and EntryTypeDefinition

  Introduces pure-Dart data types used by all subsequent phases:
  - ProvenanceEntry value type + appendHop() helper (new provenance package)
  - EntryTypeDefinition value type (trial_data_types)
  - spec/dev-event-sourcing-mobile.md with REQ-PROV and REQ-ETD

  No runtime integration — this code is reached only by tests until Phase 5
  wires it into the EntryService write path.
  ```

  Substitute the real REQ-d numbers (from Task 2's discover_requirements call) for REQ-PROV and REQ-ETD in the body before committing.
- [ ] **Force-push with lease**: `git push --force-with-lease`. CI runs on the draft PR.
- [ ] **Comment on PR**: "Phase 1 ready for review — commit `<sha>`. Review focus: pure-Dart data types and their spec assertions. No runtime integration."
- [ ] **Wait for phase review**. Address feedback by committing fixups and re-running the interactive rebase in place (the Phase 1 squashed commit stays as the single Phase 1 commit; fixup commits get folded in).
- [ ] **Record phase-completion SHA** in TASK_FILE before starting Phase 2.

---

## Recovery

After `/clear` or context compaction:
1. Read this file.
2. Read the directory [README.md](README.md) for conventions.
3. Find the first unchecked box — that is where you resume.
4. Read the corresponding `PHASE1_TASK_N.md` for context on work already done.

Archive procedure is whole-ticket (after rebase-merge lands all 5 phase commits on main) — see [README.md](README.md) Archive section.
