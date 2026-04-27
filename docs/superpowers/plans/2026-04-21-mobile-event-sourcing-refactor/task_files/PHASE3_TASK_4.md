# Phase 3 Task 4: Materializer.apply() pure fold function

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Applicable assertions

- REQ-d00121-A — pure fold function
- REQ-d00121-B — finalized whole-replaces current_answers, is_complete=true
- REQ-d00121-C — checkpoint whole-replaces current_answers, is_complete=false
- REQ-d00121-D — tombstone preserves fields except is_deleted
- REQ-d00121-E — latest_event_id + updated_at track event identity
- REQ-d00121-F — effective_date resolution with fallback
- Relates to REQ-p00004-E (derived state) and REQ-p00004-L (view updated on new events — wired in Phase 5).

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/materialization/materializer.dart` — new `Materializer` class with private constructor (static-only) and single public static method `apply({required previous, required event, required def, required firstEventTimestamp}) -> DiaryEntry`.
- `apps/common-dart/append_only_datastore/test/materialization/materializer_test.dart` — 11 tests covering all six assertion families and all the test cases the plan listed.

## TDD evidence

1. Wrote test file first. `flutter test` produced compile-error: "Undefined name 'Materializer'" — expected failure.
2. Implemented `Materializer` class with switch on `event.eventType`, `_extractAnswers` helper, `_resolveEffectiveDate` / `_walkDottedPath` helpers.
3. Re-ran: 11/11 passed. Full suite: 197/197 passed.

## Implementation notes

- **Signature**: matches the plan exactly, using `StoredEvent` (the class name in this repo — the plan's abstract `Event` is this type).
- **event.data['answers']**: the materializer treats the `answers` sub-map of `event.data` as `current_answers`. If absent or non-Map, it defaults to an empty unmodifiable map. This matches the test fixture pattern in `value_types_test.dart`.
- **Tombstone preserves `previous.currentAnswers` and `previous.isComplete`**, but `latestEventId` and `updatedAt` advance per REQ-d00121-E. When there is no previous row, tombstone produces an empty row with `isComplete: false, isDeleted: true`.
- **Unknown `event_type`** raises `StateError`. The legal set is `finalized | checkpoint | tombstone`; anything else is a data-integrity bug and should not be silently absorbed.
- **Dotted-path dialect** is minimal: `a.b.c` drills into Maps. No `[i]` array indexing, no filters. Path resolving to a non-String, or to a String that fails `DateTime.tryParse`, falls back to `firstEventTimestamp`. Same fallback for null `def.effectiveDatePath` or an empty string.
- **Unmodifiable maps**: `_extractAnswers` wraps the result with `Map.unmodifiable` so downstream code cannot mutate the answer map on the `DiaryEntry` it produced. `DiaryEntry.fromJson` has the same guarantee — here we enforce it on the in-memory path too.

## Verification

- `flutter test test/materialization/materializer_test.dart` → 11/11 passing.
- `flutter test` (full suite) → 197/197 passing.
- `flutter analyze` → "No issues found."

## Commit

- `[CUR-1154] Implement Materializer.apply`

## Task complete

Materializer in place and unwired. Ready for Task 5 (rebuildMaterializedView helper).
