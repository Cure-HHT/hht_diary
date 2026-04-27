# Phase 1 Task 4: ProvenanceEntry value type + tests

**Date:** 2026-04-21
**Status:** COMPLETE

## Files

- Created: `apps/common-dart/provenance/lib/src/provenance_entry.dart` — 100 lines.
- Created: `apps/common-dart/provenance/test/provenance_entry_test.dart` — 19 test cases.
- Modified: `apps/common-dart/provenance/lib/provenance.dart` — added `export 'src/provenance_entry.dart';`.

## Assertions covered

| Assertion | Coverage |
| --- | --- |
| REQ-d00115-C | Constructor round-trip, toJson/fromJson round-trip, snake_case key emission, `received_at` ISO 8601 w/ Z suffix preserved, fromJson rejects missing or wrong-typed required fields, value equality |
| REQ-d00115-D | Tests construct both "mobile-device" (device UUID) and server ("diary-instance-42") identifier shapes and confirm the type accepts both without validation |
| REQ-d00115-E | Test confirms `"clinical_diary@1.2.3+45"` format round-trips verbatim through toJson |
| REQ-d00115-F | Non-null and null `transform_version` both round-trip; absent key treated as null; wrong-typed value throws FormatException |

REQ-d00115-A and REQ-d00115-B (append rules) are covered by Task 5 (`appendHop`).

## TDD flow

1. Wrote 19 failing tests first.
2. `dart test` — all 19 failed with "Method not found: 'ProvenanceEntry'" (expected).
3. Wrote implementation.
4. `dart test` — 18 passed, 1 failed (UUID regex bug: `\$` in a raw string is literal `\` + `$`, not end-of-string anchor). Plus 1 analyzer info for `[appendHop]` comment_references (the function doesn't exist yet).
5. Fixed both: regex changed to `r'^[0-9a-f-]{36}$'`; doc comment changed from `[appendHop]` to ``appendHop()``.
6. `dart test` — All 19 passed.
7. `dart analyze` — No issues found.

## Implementation notes

- Immutable value class: `final` fields, `const` constructor, `==` and `hashCode` overrides, `toString`.
- `fromJson` helper `_requireString(json, key)` raises `FormatException` with a descriptive message for missing/wrong-typed required fields.
- `transform_version` validated separately (allowed null; if present, must be String).
- `received_at` parsed via `DateTime.parse()` with `FormatException` catch that re-wraps with a contextual prefix.
- `toJson` emits snake_case keys and ISO 8601 `received_at` preserving the source timezone (UTC → Z suffix).
- Per-function `// Implements: REQ-d00115-C+D+E+F` on the constructor, `// Implements: REQ-d00115-C` on `fromJson` and `toJson`.

## Out of scope (Task 5)

`appendHop()` — the helper that enforces REQ-d00115-A (exactly one append per hop) and REQ-d00115-B (no mutation of prior entries). Comes in the next commit.

## Task complete

Ready for Task 5 (`appendHop` + tests for REQ-d00115-A, B).
