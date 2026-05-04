# Phase 1 Task 3: Scaffold apps/common-dart/provenance/ package

**Date:** 2026-04-21
**Status:** COMPLETE
**Commit:** `35185db1`

## Files created

| Path | Purpose |
| --- | --- |
| `apps/common-dart/provenance/pubspec.yaml` | Pure Dart package, version 0.0.1, dev deps `test ^1.25.0` + `lints ^5.0.0`. No runtime dependencies. |
| `apps/common-dart/provenance/analysis_options.yaml` | Strict medical-software linter rules (copied from trial_data_types). Errors: missing_required_param, missing_return, parameter_assignments. Many style rules enabled. |
| `apps/common-dart/provenance/README.md` | Brief description; references REQ-d00115, design §6.5, and the implementation plan. |
| `apps/common-dart/provenance/.gitignore` | Dart/pub standard ignores, including `pubspec.lock` (library convention). |
| `apps/common-dart/provenance/lib/provenance.dart` | Empty library barrel; `library;` directive plus a note listing exports that Tasks 4 and 5 will add. |
| `apps/common-dart/provenance/test/.gitkeep` | Placeholder so `test/` is tracked before tests land. |

## Verification

| Command | Result |
| --- | --- |
| `dart pub get` | Resolved 48 transitive dependencies. |
| `dart analyze` | No issues found. |
| `dart test` | Exit code 79 ("No tests found") — expected at scaffolding stage. |

Pre-commit hook also ran `dart format` + `dart analyze` on the staged files; both passed. Markdown lint passed.

## Out of scope

- Runtime dependency on any other package. The package is pure-Dart and self-contained.
- No Flutter SDK dependency — matches `trial_data_types` pattern so the package can be reused on the portal server in a future phase.
- Downstream packages that will depend on `provenance` (`append_only_datastore`, `clinical_diary`) do not yet add it as a path dep. That wiring happens when the types are first consumed (Phase 2 Task 6 or later, and Phase 5 for clinical_diary).

## Task complete

Ready for Task 4 (implement `ProvenanceEntry` value type + tests for REQ-d00115-C+D+E+F).
