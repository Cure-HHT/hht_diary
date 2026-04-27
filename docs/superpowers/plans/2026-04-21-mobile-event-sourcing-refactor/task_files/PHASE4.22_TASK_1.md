# Phase 4.22 Task 1 — Baseline + Worklog

## Goal

Capture pre-Phase-4.22 test counts, analyze status, and confirm pre-conditions
(Phase 4.22 surface absent, system entry types ship `materialize: false`)
before any code change. Create `PHASE_4.22_WORKLOG.md` at repo root.

## Baseline Measurements

### Tests (all green)

- `apps/common-dart/event_sourcing_datastore` (`flutter test`): **668 tests passed**
- `apps/common-dart/provenance` (`dart test`): **45 tests passed**
- `apps/common-dart/event_sourcing_datastore/example` (`flutter test`): **81 tests passed**

### Static Analysis (all clean)

- `event_sourcing_datastore` (`flutter analyze`): No issues found
- `event_sourcing_datastore/example` (`flutter analyze`): No issues found
- `provenance` (`dart analyze`): No issues found

### Phase 4.22 Surface Absent

`grep -rnE "includeSystemEvents|originatorHop|isLocallyOriginated"
apps/common-dart/event_sourcing_datastore/lib/` returned **zero hits**.

The Phase 4.22 surface does not yet exist in the implementation — green-field
add for this phase as expected.

### Dedupe-by-Content Anchor

`grep -n "aggregateHistory.last"
apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` returned a
single hit at **line 385** (`final prior = aggregateHistory.last;`). This is
the anchor point Task 3 will refine.

### System Entry Types `materialize: false`

`apps/common-dart/event_sourcing_datastore/lib/src/security/system_entry_types.dart`
contains **10 actual code occurrences** of `materialize: false` (lines
90, 98, 106, 114, 122, 130, 138, 146, 154, 162) — one per reserved system
entry type. Plus one docstring reference at line 74. Matches the expected 10.

## Artifacts Created

- `PHASE_4.22_WORKLOG.md` (repo root)
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_1.md` (this file)

## Outcome

All baseline pre-conditions satisfied. Phase 4.22 implementation work may
proceed with Task 2.
