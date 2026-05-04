# PHASE 4 TASK 5 — DestinationRegistry

## What landed

`DestinationRegistry` — a process-wide singleton with boot-time registration and post-freeze immutability (REQ-d00122-G).

Public API:

- `DestinationRegistry.instance` — singleton getter.
- `register(Destination d)` — adds to the list; rejects duplicate ids (`ArgumentError`) or post-freeze calls (`StateError`).
- `all()` — returns an unmodifiable view; freezes the registry on first call.
- `matchingDestinations(StoredEvent event)` — returns only destinations whose filter matches; also freezes on first call.
- `@visibleForTesting reset()` — test-only unfreeze + clear.

Design notes:

- `Destination`s are registered in order; `all()` and `matchingDestinations()` preserve that order.
- Both read methods freeze because either of them could be used as the first runtime read; gating only on `all()` would leave `matchingDestinations()` as a loophole that permits registrations between a first filter-match and a later `all()`.
- Annotation `@visibleForTesting` is consumed by the `flutter_lints` package's `invalid_use_of_visible_for_testing_member` rule, so production callers reaching into `reset()` will flag at lint time.

## Tests (8)

- `register adds a destination and all() returns it`
- `registering two destinations with the same id throws`
- `first all() read freezes the registry; subsequent register() throws`
- `matchingDestinations returns only destinations whose filter matches`
- `matchingDestinations also freezes the registry`
- `all() returns an unmodifiable view`
- `matchingDestinations works on an empty registry (returns empty)`
- `reset() clears registrations and unfreezes`

## Verification

- `flutter test test/destinations/destination_registry_test.dart`: 8 passed.
- `flutter analyze`: No issues found.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart` (new, 82 lines)
- `apps/common-dart/append_only_datastore/test/destinations/destination_registry_test.dart` (new, 8 tests)
