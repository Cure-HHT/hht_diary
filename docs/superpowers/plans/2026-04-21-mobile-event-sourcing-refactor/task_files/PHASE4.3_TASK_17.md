# PHASE 4.3 TASK 17 — EntryTypeRegistry

## Status

`EntryTypeRegistry` was pulled forward from Phase 5 Task 3 during Phase 4.3 Task 16 so `EntryService.record`'s REQ-d00133-H validation had something to call into. The class itself landed then; this task adds its dedicated behavioral test file.

## Surface

`EntryTypeRegistry` in `lib/src/entry_type_registry.dart`:

- `register(EntryTypeDefinition defn)` — duplicate id throws `ArgumentError`.
- `byId(String id): EntryTypeDefinition?` — returns null for unknown ids.
- `isRegistered(String id): bool` — convenience wrapper over `byId != null`.
- `all(): List<EntryTypeDefinition>` — unmodifiable view in registration order.

## Tests

New file: `test/entry_type_registry_test.dart`. Seven behavioral tests:

- register + byId round-trip
- byId returns null for unknown id
- duplicate-id register throws ArgumentError
- isRegistered matches byId presence
- all() returns definitions in registration order
- all() is unmodifiable
- empty registry reports zero registrations

## Test counts

Before: 382. After: 389 (+7).

## Analyze

`dart analyze` clean.

## Phase 5 plan alignment

The `> Moved to Phase 4.3 (2026-04-22)` prefix on PLAN_PHASE5 Task 3 now points at a fully-implemented + tested class. Phase 5 consumes it (registers concrete EntryTypeDefinitions) rather than creating it.
