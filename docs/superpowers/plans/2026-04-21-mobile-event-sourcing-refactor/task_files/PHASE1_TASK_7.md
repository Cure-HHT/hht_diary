# Phase 1 Task 7: Version bumps + CHANGELOGs

**Date:** 2026-04-21
**Status:** COMPLETE

## Plan-vs-reality

The plan called for manual version bumps at this step. In practice a pre-commit hook in this repo automatically bumps versions when code changes land:

- `trial_data_types` was automatically bumped 0.0.2+7 → 0.0.3+8 by the hook during the Task 6 commit (`f33f7177`). Several unrelated packages (`clinical_diary`, `portal-ui`, `diary_server`, `portal_server`, `diary_functions`, `portal_functions`, `eq`) got "build trigger" patch bumps in the same hook run — flagged in commit output. These are expected hook behavior, not CUR-1154-specific.
- `provenance` was NOT auto-bumped — likely because the hook treats a brand-new package as already at its intended initial version. I manually bumped it 0.0.1 → 0.1.0 (first functional release milestone per plan).

## Changes this task

| File | Change |
| --- | --- |
| `apps/common-dart/provenance/pubspec.yaml` | `version: 0.0.1` → `0.1.0` |
| `apps/common-dart/provenance/CHANGELOG.md` | Created with 0.1.0 entry describing `ProvenanceEntry` and `appendHop` |
| `apps/common-dart/trial_data_types/CHANGELOG.md` | Added 0.0.3+8 entry describing `EntryTypeDefinition`; preserved the prior 0.0.1 stub |

## Final verification

| Command | Result |
| --- | --- |
| `cd apps/common-dart/provenance && dart test` | 27 tests pass |
| `cd apps/common-dart/provenance && dart analyze` | No issues found |
| `cd apps/common-dart/trial_data_types && dart test` | 51 tests pass |
| `cd apps/common-dart/trial_data_types && dart analyze` | No issues found |
| `cd apps/daily-diary/clinical_diary && flutter analyze` | No issues found |

clinical_diary is unchanged from baseline — Phase 1 added no code that clinical_diary depends on yet.

## Task complete

Ready for Task 8 (phase-boundary squash and request phase review).
