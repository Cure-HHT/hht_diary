# Phase 1 review follow-up

**Date:** 2026-04-21 (same day as initial Phase 1 squash)
**Status:** COMPLETE for items 1-5, 7; Item 4 pushed back on; Item 6 awaiting user decision.

Catalogues the post-review changes applied on top of the squashed `[CUR-1154] Phase 1: ...` commit. This file does not modify the earlier per-task TASK_FILEs; those remain the record of each task's state at its original commit time.

## Items implemented

### Item 1: Replace hand-rolled deep equality with package:collection

`apps/common-dart/trial_data_types/pubspec.yaml` — added `collection: ^1.19.1` as a direct dependency (was transitive).

`apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart` — removed 80 lines of `_deepEquals` / `_deepHash` / `_mapDeepEquals` / `_mapDeepHash` / `_listDeepEquals` / `_listDeepHash` helpers; use `DeepCollectionEquality` from `package:collection` with a file-level `const DeepCollectionEquality _deepEq`. The XOR-based list hash (siblings in a list hashed identically under reordering) is now order-aware through `DeepCollectionEquality.hash`.

### Item 2: Reject offsetless received_at in ProvenanceEntry.fromJson

`apps/common-dart/provenance/lib/src/provenance_entry.dart` — added `_offsetPattern` regex `(Z|[+-]\d{2}(:?\d{2})?)$` that matches `Z`, `±HH:MM`, `±HHMM`, or `±HH`. `fromJson` checks it before `DateTime.parse()` and throws `FormatException` on offsetless input (which Dart would otherwise silently parse as local time, breaking ALCOA+ *Contemporaneous* in a cross-system audit chain).

Docstring tightened: the `identifier` and `softwareVersion` shape rules (REQ-d00115-D, -E) are called out as **permanent caller obligations** — not deferred validation. The source of each hop (device, diary server, portal) is the only place that knows which shape applies; there is no hop-ingress validator that can take ownership.

### Item 3: Map<String, Object?> uniformly across this PR's new types

`apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart` — changed `widgetConfig` field type and `fromJson`/`toJson` signatures from `Map<String, dynamic>` to `Map<String, Object?>`. Matches the stricter `Object?` already used by `provenance/lib/src/provenance_entry.dart` in this PR. Pre-existing `Map<String, dynamic>` patterns in other `trial_data_types` files are left alone (tech debt outside this PR's scope).

### Item 5: Missing tests added

`apps/common-dart/provenance/test/provenance_entry_test.dart` — four new tests in the `fromJson validation` group:
- `malformed received_at throws FormatException`
- `offsetless received_at (no Z, no +/-HH:MM) throws FormatException`
- `received_at with +HH:MM offset is accepted`
- `received_at with -HHMM (no colon) offset is accepted`

Test count: 27 → 31.

`apps/common-dart/trial_data_types/test/entry_type_definition_test.dart` — three new tests:
- `REQ-d00116-E: nested widgetConfig difference at depth >= 2 breaks equality` (catches degraded deep-equality)
- `REQ-d00116-G: destinationTags empty list is distinct from null (equality)`
- `REQ-d00116-G: destinationTags empty list vs null surface differently in toJson`

Test count: 51 → 54.

### Item 7: publish_to: none on provenance

`apps/common-dart/provenance/pubspec.yaml` — added `publish_to: none` so a stray `pub publish` cannot escape a medical-software internal package to pub.dev.

## Items not implemented

### Item 4: "trial_data_types is not held to the same analyzer standard as provenance"

Pushed back. `diff apps/common-dart/provenance/analysis_options.yaml apps/common-dart/trial_data_types/analysis_options.yaml` reports only trailing-whitespace differences. `trial_data_types` already has `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`, and the same ~60 linter rules. `dart analyze` is clean in both packages. The premise of the finding is incorrect.

### Item 6: Unrelated pubspec version bumps

Awaiting user decision. The 8 packages' `+1` build-number bumps (clinical_diary, portal-ui, diary_server, portal_server, diary_functions, portal_functions, eq, plus the trial_data_types code-change bump) came from a repo-level pre-commit hook that ran during the Task 6 commit, not from any manual action in this PR. Options: (a) document in PR body as intentional blanket rebuild trigger, (b) revert the bumps and rely on downstream services to bump themselves when they pick up new `trial_data_types`, or (c) ask the hook's owner to scope it narrower. Default if no user input: leave them and add a PR-body note.

## Verification

| Command | Result |
| --- | --- |
| `(cd apps/common-dart/provenance && dart test)` | 31 tests pass |
| `(cd apps/common-dart/provenance && dart analyze)` | No issues found |
| `(cd apps/common-dart/trial_data_types && dart test)` | 54 tests pass |
| `(cd apps/common-dart/trial_data_types && dart analyze)` | No issues found |
