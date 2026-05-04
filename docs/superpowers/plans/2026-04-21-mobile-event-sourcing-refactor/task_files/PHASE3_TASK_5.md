# Phase 3 Task 5: rebuildMaterializedView() helper

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Applicable assertions

- REQ-d00121-G — rebuild replaces view from event log; prior contents not read as input.
- REQ-d00121-H — returns count of distinct aggregates materialized.
- REQ-d00121-D — tombstone fold preserved during rebuild.
- REQ-p00004-E — derived view reproducible from event log.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` — added abstract `clearEntries(Txn txn)` method. Required for the rebuild to atomically replace the view rather than incrementally overwrite (prior garbage rows whose aggregate_ids don't appear in the event log would otherwise leak through).
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` — concrete `clearEntries` using `StoreRef.delete(txn)` (Sembast API for "delete all records in store").
- `apps/common-dart/append_only_datastore/lib/src/materialization/rebuild.dart` — top-level function `rebuildMaterializedView(StorageBackend backend, EntryTypeDefinitionLookup lookup) -> Future<int>`.
- `apps/common-dart/append_only_datastore/test/materialization/rebuild_test.dart` — 7 tests against a real `SembastBackend` with an in-memory sembast database.
- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart` — added stub for `clearEntries` in the test-only `_InMemoryBackend` class.
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart` — added `clearEntries` delegation in the `_SpyBackend` test double.

## TDD evidence

1. Wrote `rebuild_test.dart` first; `flutter test` produced compile-error: "Method not found: 'rebuildMaterializedView'" — expected.
2. Added `clearEntries` abstract + concrete. Tests in the full suite failed because two test doubles (`_InMemoryBackend`, `_SpyBackend`) now did not implement the new abstract method.
3. Implemented `rebuildMaterializedView` function.
4. Fixed one incorrect test expectation (expected 3 rows pre-rebuild when only 2 garbage rows exist; the event-append path does not populate `diary_entries`).
5. Added `clearEntries` stubs in the two affected test doubles.
6. Re-ran: 7/7 rebuild tests pass; full suite 204/204 pass; `flutter analyze` clean.

## Implementation decisions

- **findAllEvents called outside the transaction**. Sembast's findAllEvents is non-transactional regardless of call-site; the event log is append-only and rebuild is not a runtime operation, so a point-in-time read followed by an atomic clear+upsert is correct. The atomicity that matters is between `clearEntries` and `upsertEntry` — both inside one `transaction`.
- **Unknown entry_type throws StateError**. An event log referencing a type not in the registry is a data integrity failure. Silently skipping would produce an under-complete view and hide the bug; raising surfaces it during any rebuild.
- **Added `clearEntries(Txn)` to the abstract StorageBackend** rather than doing the clear by iteration inside `rebuildMaterializedView`. The iteration approach would still leave orphan rows if there are more aggregate_ids in `diary_entries` than in the event log (which is exactly the "garbage" case the plan tests for). Adding a store-level clear operation is the cleanest solution and is local to the materialization work.
- **`_garbageEntry` test helper**. The test seeds diary_entries with rows whose aggregate_ids don't exist in the event log, then proves the rebuild erases them. Correct per REQ-d00121-G.

## Verification

- `flutter test test/materialization/rebuild_test.dart` → 7/7 passing.
- `flutter test` (full suite) → 204/204 passing.
- `flutter analyze` → "No issues found."

## Commit

- `[CUR-1154] Implement rebuildMaterializedView`

## Task complete

Rebuild helper and the new `clearEntries` contract in place. Ready for Task 6 (public exports).
