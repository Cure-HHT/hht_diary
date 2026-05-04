# Phase 1 Task 6: EntryTypeDefinition in trial_data_types + tests

**Date:** 2026-04-21
**Status:** COMPLETE

## Files

- Created: `apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart` — immutable value class with deep-equals and deep-hash helpers for nested JSON.
- Created: `apps/common-dart/trial_data_types/test/entry_type_definition_test.dart` — 17 test cases.
- Modified: `apps/common-dart/trial_data_types/lib/trial_data_types.dart` — added `export 'src/entry_type_definition.dart';` and `//   REQ-d00116: EntryTypeDefinition Schema` to the file-level header block.

## Assertions covered

| Assertion | Coverage |
| --- | --- |
| REQ-d00116-A | Construct with `id`; toJson emits `id`; fromJson rejects missing or non-string `id` |
| REQ-d00116-B | Construct with `version`; round-trips; fromJson rejects missing |
| REQ-d00116-C | Construct with `name`; round-trips; fromJson rejects missing |
| REQ-d00116-D | Construct with `widgetId`; toJson emits `widget_id`; fromJson rejects missing or non-string |
| REQ-d00116-E | `widgetConfig` round-trips arbitrary nested JSON (map with lists of maps); fromJson rejects missing. **Materializer-fallback half of this assertion is covered in Phase 3.** |
| REQ-d00116-F | Optional `effectiveDatePath` (default null); accepts dotted path; round-trips null and non-null |
| REQ-d00116-G | Optional `destinationTags` list of strings; round-trips; parsing rejects non-list and non-string entries |

## Implementation notes

- `Map<String, dynamic>` for `widgetConfig` to match trial_data_types package conventions (rather than `Map<String, Object?>` used in provenance). Trade-off: slightly looser type-safety, consistent with other trial_data_types files.
- Hand-rolled deep `==` and `hashCode` for `widgetConfig` because Dart's default `Map` equality is referential, not structural. Required because the tests assert value equality across round-trips.
- `fromJson` raises `FormatException` with contextual messages for each missing/wrong-typed field.
- `destinationTags` parsing iterates the list and rejects non-string entries — preserves strong typing at boundary.
- Per-function `// Implements:` markers on constructor (`REQ-d00116-A+B+C+D+E+F+G`) and `fromJson` (`REQ-d00116-A+B+C+D+E` for required, `-F+G` for optional).

## TDD flow

1. Wrote 17 failing tests.
2. `dart test` — all failed with "Method not found: 'EntryTypeDefinition'" (expected).
3. Implemented the class.
4. `dart test` — all 51 passed (34 pre-existing + 17 new). `dart analyze` — 10 info-level lints:
   - 1 `comment_references` for `[SubscriptionFilter]` (Phase 4 type doesn't exist yet). Fixed: changed to `` `SubscriptionFilter` ``.
   - 9 `prefer_const_constructors` in the test file (the class has a `const` constructor).
5. `dart fix --apply` auto-fixed 23 issues (prefer_const_declarations, unnecessary_const, prefer_const_constructors) but over-applied: converted `final def = const EntryTypeDefinition(...)` on line 73 where `widgetConfig: payload` is a runtime variable, producing an `invalid_constant` error.
6. Manually reverted that one constructor call to non-const.
7. Re-ran: 51 tests pass, analyze clean.

## Task complete

All of REQ-d00116 (7 assertions A-G) now has implementation and tests, except for the Phase 3 half of assertion E (materializer fallback behavior). Ready for Task 7 (version bumps + CHANGELOG).
