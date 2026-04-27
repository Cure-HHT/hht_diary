# Phase 3 Task 3: EntryTypeDefinitionLookup abstract interface

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Applicable assertions

- REQ-d00121-A — lookup supplies the `EntryTypeDefinition` that lets `Materializer.apply` remain pure.
- REQ-d00116-A — lookup's key matches `EntryTypeDefinition.id` (enforced by callers; documented).

## Files changed

- `apps/common-dart/append_only_datastore/pubspec.yaml` — added `trial_data_types` as a path dependency (required so `lib/` can refer to `EntryTypeDefinition`).
- `apps/common-dart/append_only_datastore/lib/src/materialization/entry_type_definition_lookup.dart` — new abstract class with single method `EntryTypeDefinition? lookup(String entryTypeId)`. Includes `// Implements: REQ-d00121-A` per-class marker and an `// ignore: one_member_abstracts` (the single-method class is deliberate; it names the DI seam used by the materializer and future production registries).
- `apps/common-dart/append_only_datastore/test/test_support/map_entry_type_definition_lookup.dart` — test-only concrete; wraps an unmodifiable `Map<String, EntryTypeDefinition>`. Constructor takes a map; `fromDefinitions` constructor takes a list and indexes by `id`, throwing `ArgumentError` on duplicate ids.
- `apps/common-dart/append_only_datastore/test/materialization/entry_type_definition_lookup_test.dart` — 6 tests covering contract (`REQ-d00121-A`) and the test double's behaviors.

## TDD evidence

1. Wrote test file first referencing both classes. Test run produced 4 `Error: Method not found` / `Undefined name` compile-time errors for `MapEntryTypeDefinitionLookup` — expected failure for the right reason.
2. Implemented the abstract class and the test double.
3. Re-ran tests → 6/6 passed.

## Decisions

- **`lookup` returns `null` (not throws)** for unknown ids. Matches the plan's guidance; callers that need a hard error (e.g., `rebuildMaterializedView` when an event references an unregistered `entry_type`) wrap the null in a `StateError` at the call site. Keeps this interface simple and the error semantics at the point where context is richest.
- **`MapEntryTypeDefinitionLookup` kept under `test/test_support/`** — not exported from `lib/`. Rationale: apps construct their real registry via the compile-time sponsor-repo path in Phase 5. Exposing the map-wrapping double from `lib/` would invite apps to use it accidentally.
- **`fromDefinitions` throws on duplicate ids** rather than last-wins. Silent shadowing in an entry-type registry is a bug; surfacing it at construction catches it during development.
- **`// ignore: one_member_abstracts`** on the class declaration. The analyzer's style suggestion (use a typedef/function instead) conflicts with the plan's requirement for an abstract class and loses the documentation value of a named type. Kept the abstract class and suppressed the lint inline with a comment that would be easy to revisit.

## Verification

- `flutter test test/materialization/entry_type_definition_lookup_test.dart` → 6/6 passing.
- `flutter analyze` → "No issues found."

## Commit

- `[CUR-1154] Add EntryTypeDefinitionLookup interface`

## Task complete

Interface and test double in place. Ready for Task 4 (Materializer.apply).
