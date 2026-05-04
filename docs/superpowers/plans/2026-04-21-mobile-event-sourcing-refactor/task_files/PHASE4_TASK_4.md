# PHASE 4 TASK 4 — SubscriptionFilter

## What landed

Converted `SubscriptionFilter` from the Task-3 abstract placeholder into a concrete class with three optional constraints composed by AND:

- `entryTypes: List<String>?` — allow-list over `event.entry_type`.
- `eventTypes: List<String>?` — allow-list over `event.event_type`.
- `predicate: bool Function(StoredEvent)?` — escape-hatch, consulted after the allow-lists pass.

Semantics (REQ-d00122-F):

- A `null` list means "match all". An **empty** list means "match none". The distinction is deliberate — a default-constructed `[]` somewhere should not accidentally broadcast every event.
- The predicate is short-circuited: if an allow-list rejects the event, the predicate is not invoked. This matters when the predicate is expensive.
- A default-constructed `SubscriptionFilter()` (no constraints at all) matches every event — this is the convenience case for destinations that want unconditional fan-out.

## Follow-ups from Task 3 cleanup

- `destination_test.dart` previously declared a `_AllowAll extends SubscriptionFilter` subclass because Task 3 shipped `SubscriptionFilter` as abstract. Now that `SubscriptionFilter` is concrete with a null-default of "match all", the subclass is redundant and has been removed; `_EchoDestination.filter` returns `const SubscriptionFilter()`.

## Tests added

- 10 tests in `test/destinations/subscription_filter_test.dart`:
  - null lists match everything
  - `entryTypes` allow-list selects by entry_type
  - `eventTypes` allow-list selects by event_type
  - Intersection: entryTypes AND eventTypes
  - Empty `entryTypes` matches nothing (null/empty distinction)
  - Empty `eventTypes` matches nothing (null/empty distinction)
  - `predicate` escape-hatch filters further
  - `predicate` is not invoked when allow-lists fail (short-circuit)
  - All three constraints compose
  - Default filter matches everything

## Verification

- `flutter test test/destinations/`: 25 tests passed (was 16 after Task 3; +9 new; +1 tweaked in destination_test.dart).
- `flutter analyze`: No issues found.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/destinations/subscription_filter.dart` — rewrote from abstract to concrete class (REQ-d00122-B+F).
- `apps/common-dart/append_only_datastore/test/destinations/destination_test.dart` — dropped `_AllowAll` subclass; use `const SubscriptionFilter()` directly.
- `apps/common-dart/append_only_datastore/test/destinations/subscription_filter_test.dart` (new, 10 tests).
