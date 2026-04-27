# Phase 3 Task 6: Public library exports

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Files changed

- `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart` — added a new "Materialization layer" export section before the existing "Storage layer" section (maintains `directives_ordering` lint's alphabetical-by-path requirement: `src/materialization/...` < `src/storage/...`).

## Exports added

```dart
export 'src/materialization/entry_type_definition_lookup.dart'
    show EntryTypeDefinitionLookup;
export 'src/materialization/materializer.dart' show Materializer;
export 'src/materialization/rebuild.dart' show rebuildMaterializedView;
```

## Exports deliberately NOT added

- `MapEntryTypeDefinitionLookup` (in `test/test_support/`). Test-only double. Apps use the compile-time sponsor-repo registry introduced in Phase 5. Re-exporting the map-backed double from `lib/` would invite apps to use it accidentally.

## Verification

- `flutter analyze` → "No issues found" (no `directives_ordering` regressions).
- `flutter test` → 204/204 passing.

## Commit

- `[CUR-1154] Export materialization public surface`

## Task complete

Public API of `append_only_datastore` now re-exports the three Phase 3 additions. Ready for Task 7 (version bump + CHANGELOG).
