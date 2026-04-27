# Phase 1 Task 5: appendHop helper + tests

**Date:** 2026-04-21
**Status:** COMPLETE

## Files

- Created: `apps/common-dart/provenance/lib/src/append_hop.dart` — single pure function.
- Created: `apps/common-dart/provenance/test/append_hop_test.dart` — 8 test cases.
- Modified: `apps/common-dart/provenance/lib/provenance.dart` — added `export 'src/append_hop.dart';`.

## Assertions covered

| Assertion | Coverage |
| --- | --- |
| REQ-d00115-A | Empty-chain append yields length 1; non-empty chain grows by exactly 1; new entry sits at tail; returns a new List instance; no deduplication of equal entries |
| REQ-d00115-B | Input chain unchanged after call; returned list rejects `add`, `removeLast`, and index-set (throws `UnsupportedError` per `List.unmodifiable`); prior entries remain equal to their original values across repeated appends |

With Task 4 covering -C through -F, all six assertions of REQ-d00115 now have tests.

## Implementation

```dart
List<ProvenanceEntry> appendHop(
  List<ProvenanceEntry> chain,
  ProvenanceEntry entry,
) =>
    List<ProvenanceEntry>.unmodifiable(<ProvenanceEntry>[...chain, entry]);
```

Choices:
- `List.unmodifiable` (not just a new mutable list) — downstream callers cannot introduce mutation bugs that break REQ-d00115-B.
- Spread into a fresh list literal — copies the input's contents; the input itself is never handed to `List.unmodifiable`.
- No deduplication — each hop's append is recorded as a distinct position even if the hop happens to send identical attribution twice (should not occur in practice, but the helper does not enforce uniqueness).

## TDD flow

1. Wrote 8 failing tests.
2. `dart test` — failures "Method not found: 'appendHop'" (expected).
3. Implemented `appendHop` as a one-liner; added export to the library barrel.
4. `dart test` — 27 pass (19 + 8). `dart analyze` — 2 info-level lints:
   - `always_use_package_imports` in `append_hop.dart` (used relative `import 'provenance_entry.dart';`). Fixed to `import 'package:provenance/src/provenance_entry.dart';`.
   - `unnecessary_lambdas` in `append_hop_test.dart` line 77 (`() => chain.removeLast()` → `chain.removeLast` tearoff). Fixed.
5. Re-ran: 27 pass, analyze clean.

## Task complete

All of REQ-d00115 (6 assertions) now covered by tests and implementation. Ready for Task 6 (`EntryTypeDefinition` in trial_data_types for REQ-d00116).
