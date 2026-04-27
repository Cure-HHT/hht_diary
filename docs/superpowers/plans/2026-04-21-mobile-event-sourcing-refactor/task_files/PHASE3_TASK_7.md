# Phase 3 Task 7: Version bump and CHANGELOG

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Version bump

- `apps/common-dart/append_only_datastore/pubspec.yaml` — `0.1.0+3 → 0.2.0` (minor bump; new public API surface).

## CHANGELOG entry

Added `## 0.2.0 (2026-04-22) - CUR-1154 Phase 3: materialization` section at the top of `CHANGELOG.md` describing:

- New public surface: `Materializer`, `EntryTypeDefinitionLookup`, `rebuildMaterializedView`.
- StorageBackend surface change: new `clearEntries(Txn)` abstract method.
- Dependency addition: `trial_data_types` is now a regular dependency.
- Spec: REQ-d00121 (9 assertions).
- Noted that the materializer is shipped unwired; Phase 5 wires it into `EntryService.record`.

## Full verification

| Package | Tests | Analyze |
| --- | --- | --- |
| `apps/common-dart/append_only_datastore` | 204/204 PASS | No issues found |
| `apps/daily-diary/clinical_diary` | 1098/1098 PASS (1 skipped, pre-existing) | No issues found |

## Commit

- `[CUR-1154] Bump append_only_datastore for Phase 3`

## Task complete

Version and CHANGELOG updated. Full suite still green across touched packages. Ready for Task 8 (phase-boundary squash and phase-review request).
