# PHASE 4.3 TASK 10 — DestinationRegistry dynamic mutation API

## Summary

Replaced the Phase-4 singleton `DestinationRegistry` (freeze on first
read) with an instance-based, `StorageBackend`-bound registry that
supports the REQ-d00129 dynamic lifecycle:

- `addDestination(d)` — registers at any time after bootstrap; duplicate
  id throws `ArgumentError` (REQ-d00129-A).
- `setStartDate(id, date)` — one-shot immutable; a second call throws
  `StateError` (REQ-d00129-C). The matching replay side-effect
  (REQ-d00129-D) is deferred to Task 12, marked by a `TODO(Task 12)` at
  the decision point.
- `setEndDate(id, date)` — returns `SetEndDateResult.{closed, scheduled,
  applied}` per the three-way classification (REQ-d00129-F).
- `deactivateDestination(id)` — shorthand for `setEndDate(id,
  DateTime.now())`; returns `closed` (REQ-d00129-G).
- `deleteDestination(id)` — gated on the destination's
  `allowHardDelete`; when allowed, drops the FIFO store + schedule
  record + fill-cursor atomically in one transaction
  (REQ-d00129-H).

Added a `DestinationSchedule` value type (`startDate`, `endDate`, JSON
round-trip, `isDormant`, `isActiveAt(now)`), a `SetEndDateResult` enum,
and an `UnjamResult` value type (used by Task 14, parked here now to
avoid future import churn). Schedules persist through new
`StorageBackend` methods `readSchedule`, `writeSchedule`,
`writeScheduleTxn`, `deleteScheduleTxn`, and `deleteFifoStoreTxn`.

REQ-d00122-G revised in the spec to describe the new dynamic lifecycle
(registry stays open to runtime `addDestination`; schedule state
controls visibility).

Implements: REQ-d00129-A, REQ-d00129-C, REQ-d00129-F, REQ-d00129-G,
REQ-d00129-H, REQ-d00122-G (revised).

## Deliberately deferred

- REQ-d00129-D (past-start triggers replay) and REQ-d00129-E
  (future-start accumulates without replay) — Task 12. Task 10's
  `setStartDate` leaves a `TODO(Task 12): trigger replay when
  startDate <= now()` at the decision point, and the registry
  currently persists the new schedule without calling replay.
- REQ-d00129-I (fillBatch time-window filter) — Task 11/12.
- Historical-replay orchestrator (REQ-d00130) — Task 12.
- `unjamDestination` (REQ-d00131) — Task 14 will consume
  `UnjamResult` which is parked in `destination_schedule.dart` now.

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **332 / 332 green**.
   `dart analyze` clean.
2. **Red — new value types and backend surface**:
   - Added `lib/src/destinations/destination_schedule.dart` with
     `DestinationSchedule`, `SetEndDateResult`, and `UnjamResult`.
   - Extended `StorageBackend` with `readSchedule`, `writeSchedule`,
     `writeScheduleTxn`, `deleteScheduleTxn`, `deleteFifoStoreTxn`.
   - Implemented the same in `SembastBackend`. `deleteFifoStoreTxn`
     uses sembast's `StoreRef.drop(txn)` so the whole
     `fifo_<destId>` namespace is removed in one atomic step; it
     also drops the fill-cursor record and removes the id from the
     `known_fifo_destinations` list so
     `anyFifoExhausted`/`exhaustedFifos` no longer iterate the
     deleted FIFO.
   - Added no-op forwarders to the two test stubs (`_InMemoryBackend`
     in `storage_backend_contract_test.dart`, `_SpyBackend` in
     `event_repository_test.dart`) so the existing contract tests
     continue to compile.
3. **Red — registry rewrite**:
   - Rewrote `lib/src/destinations/destination_registry.dart` as
     an instance-based class bound to a `StorageBackend` at
     construction. Removed the old singleton (`instance`, `reset`,
     `register`, `matchingDestinations`, `_frozen`). Added
     `addDestination`, `all`, `byId`, `scheduleOf`, `setStartDate`,
     `setEndDate`, `deactivateDestination`, `deleteDestination`.
   - Added `test/destinations/destination_registry_dynamic_test.dart`
     with the REQ-d00129-A/C/F/G/H assertions (12 tests total).
   - Rewrote the existing `test/destinations/destination_registry_test.dart`
     as instance-based smoke tests (addDestination +
     duplicate + "no freeze on first read" + unmodifiable view +
     byId) — 5 tests.
   - Updated `test/sync/sync_cycle_test.dart` to construct a fresh
     `DestinationRegistry(backend: backend)` per test and pass it
     through to `SyncCycle` instead of
     `DestinationRegistry.instance`.
4. **Green**: `flutter test` — **343 / 343 green** (+11).
5. **Analyze**: `dart analyze` surfaced a `sort_constructors_first`
   info on `DestinationSchedule.fromJson` appearing after the named
   constructor; moved the factory ahead of field declarations.
   Final `dart analyze` — **No issues found.**
6. **Spec**: Revised REQ-d00122-G to describe the dynamic
   lifecycle. Refreshed the REQ-d00122 rationale paragraph that
   previously described the freeze. Ran `elspais fix`.
7. **Verify**: `flutter analyze` on
   `apps/daily-diary/clinical_diary` — **No issues found!**

## Test counts

- Baseline: **332 / 332**.
- Final: **343 / 343**. Delta: **+11**:
  - `destination_registry_dynamic_test.dart`: +12 new REQ-d00129
    tests (A x 3, C x 2, F x 3, G x 1, H x 2, plus one defensive
    "delete unknown throws" and one "scheduleOf unknown throws"
    and one "setStartDate/setEndDate unknown id throws").
  - `destination_registry_test.dart`: -9 old singleton/freeze tests,
    +5 new instance-based smoke tests. Net -4.
  - Net: +12 -4 +3 = +11.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found.**

## Files touched

### Created

- `apps/common-dart/append_only_datastore/lib/src/destinations/destination_schedule.dart`
  — `DestinationSchedule` value type (JSON round-trip,
  `isDormant`, `isActiveAt(now)`), `SetEndDateResult` enum,
  `UnjamResult` value type.
- `apps/common-dart/append_only_datastore/test/destinations/destination_registry_dynamic_test.dart`
  — REQ-d00129-A/C/F/G/H tests plus defensive unknown-id coverage.

### Modified (library)

- `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart`
  — full rewrite. Singleton removed. Instance-based, bound to a
  `StorageBackend` at construction. New surface: `addDestination`,
  `all`, `byId`, `scheduleOf`, `setStartDate`, `setEndDate`,
  `deactivateDestination`, `deleteDestination`. In-memory caches
  for destinations and schedules; schedule mutations persist
  through the backend.
- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
  — added `readSchedule`, `writeSchedule`, `writeScheduleTxn`,
  `deleteScheduleTxn`, `deleteFifoStoreTxn` to the abstract
  contract with `Implements:` citations.
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`
  — implemented the five new schedule / FIFO-store methods.
  `deleteFifoStoreTxn` drops the whole `fifo_<destId>` store,
  drops the fill-cursor record, and removes the destination from
  `known_fifo_destinations` — all in one transaction.
- `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`
  — exported `DestinationSchedule`, `SetEndDateResult`,
  `UnjamResult` from the destinations barrel.

### Modified (tests)

- `apps/common-dart/append_only_datastore/test/destinations/destination_registry_test.dart`
  — rewritten as instance-based smoke tests (5 tests: duplicate
  throws, no-freeze-on-first-read, unmodifiable view, byId).
- `apps/common-dart/append_only_datastore/test/sync/sync_cycle_test.dart`
  — constructs a fresh `DestinationRegistry(backend: backend)`
  per test; replaces `DestinationRegistry.instance.register(d)`
  with `await registry.addDestination(d)`.
- `apps/common-dart/append_only_datastore/test/storage/storage_backend_contract_test.dart`
  — `_InMemoryBackend` extended with `UnimplementedError`
  forwarders for the five new methods; added the
  `destination_schedule` import.
- `apps/common-dart/append_only_datastore/test/event_repository_test.dart`
  — `_SpyBackend` extended with delegating forwarders for the
  five new methods.

### Modified (spec)

- `spec/dev-event-sourcing-mobile.md` — REQ-d00122-G rewritten to
  describe the dynamic lifecycle (registry stays open to runtime
  `addDestination`; schedule state governs visibility). Revised
  REQ-d00122 rationale paragraph that previously described the
  freeze. `elspais fix` refreshed REQ-d00122's content hash and
  performed routine index / changelog maintenance on unrelated
  PRDs.

## Notes

- The test-update churn was small because only three files used
  the singleton: `destination_registry_test.dart`,
  `sync_cycle_test.dart`, and (indirectly) any test that
  constructed a `SyncCycle`. `drain_test.dart` does NOT use the
  registry (`drain` takes a `Destination` directly), so none of
  its tests needed updating.
- `FakeDestination` already carried the `allowHardDelete` getter
  from Task 9 (with `false` default), so the REQ-d00129-H
  "throws when allowHardDelete is false" path is exercised against
  the default-false destination, and the "drops everything when
  allowHardDelete is true" path is exercised against
  `FakeDestination(id: 'purgeable', allowHardDelete: true)`.
- `UnjamResult` is parked in `destination_schedule.dart` now
  rather than introduced in Task 14; parking avoids a rename /
  import churn when Task 14 lands. Nothing references it yet.
- Bootstrap wiring (sponsor-repo `main()` constructing a single
  `DestinationRegistry` and passing it into `SyncCycle`) is
  deferred to Task 18. Until Task 18, production code has no
  registry; tests construct one per test.
- The `TODO(Task 12): trigger replay when startDate <= now()` in
  `setStartDate` is the one deliberate deferred branch. When
  Task 12 lands, the body will dispatch into a replay orchestrator
  inside the same transaction that persists the schedule.
