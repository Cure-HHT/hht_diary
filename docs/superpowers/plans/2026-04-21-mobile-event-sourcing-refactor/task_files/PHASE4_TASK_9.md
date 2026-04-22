# PHASE 4 TASK 9 — Public library exports

## What landed

Added two new export blocks to `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`:

```dart
// Destinations — per-destination routing contract (Phase 4, CUR-1154).
// FakeDestination lives in test/test_support/ and is intentionally NOT
// exported.
export 'src/destinations/destination.dart' show Destination;
export 'src/destinations/destination_registry.dart' show DestinationRegistry;
export 'src/destinations/subscription_filter.dart'
    show SubscriptionFilter, SubscriptionPredicate;
export 'src/destinations/wire_payload.dart' show WirePayload;

// Sync — backoff curve, drain loop, and top-level orchestrator (Phase 4,
// CUR-1154). Phase 5 wires triggers in clinical_diary that route into
// SyncCycle.call().
export 'src/sync/drain.dart' show ClockFn, drain;
export 'src/sync/sync_cycle.dart' show SyncCycle;
export 'src/sync/sync_policy.dart' show SyncPolicy;
```

`FakeDestination` (test double) lives in `test/test_support/fake_destination.dart` and is **not** exported.

Reordered the overall export blocks so `destinations/` sits between `core/` and `infrastructure/` alphabetically, satisfying the `directives_ordering` lint rule.

## Verification

- `flutter test`: 298 passed.
- `flutter analyze`: No issues found.

## Files changed

- `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart` — two new export blocks + reorder.
