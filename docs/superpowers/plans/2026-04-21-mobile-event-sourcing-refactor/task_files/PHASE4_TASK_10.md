# PHASE 4 TASK 10 — Version bump + CHANGELOG

## What landed

- `apps/common-dart/append_only_datastore/pubspec.yaml`: version `0.2.0+3` → `0.3.0+4`.
- `apps/common-dart/append_only_datastore/CHANGELOG.md`: new top entry covering the Phase-4 public surface and the Phase-2 contract clarifications folded into this phase.

Version bump rationale: minor-bump (0.2 → 0.3) because Phase 4 ships new public types (`Destination`, `SubscriptionFilter`, `WirePayload`, `DestinationRegistry`, `SyncPolicy`, `drain`, `SyncCycle`) AND changes the behavior of two `StorageBackend` methods (`nextSequenceNumber`, `SembastBackend.enqueueFifo`). Both are observable changes to existing callers — minor-version signals the breaking-but-compatible semantic shift.

## Verification

- `flutter test` in `append_only_datastore`: 298 passed.
- `flutter analyze` in `append_only_datastore`: No issues found.
- `flutter analyze` in `clinical_diary`: No issues found (path-dependent on `append_only_datastore`; confirms the Phase-2 contract changes do not break the dependent tree).

## Files changed

- `apps/common-dart/append_only_datastore/pubspec.yaml` (version bump)
- `apps/common-dart/append_only_datastore/CHANGELOG.md` (new 0.3.0 entry)
