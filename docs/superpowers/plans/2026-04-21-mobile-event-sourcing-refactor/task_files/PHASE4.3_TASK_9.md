# PHASE 4.3 TASK 9 — Destination interface widened for batching

## Summary

Widened the abstract `Destination` contract to carry the batch-FIFO
shape introduced in Phase 4.3 Tasks 6/8. The surface gained three new
members and one signature change:

- `Duration get maxAccumulateTime;` (REQ-d00128-F) — upper bound on
  how long `fillBatch` may hold a single-event batch.
- `bool get allowHardDelete => false;` (REQ-d00129-B) — defaulted to
  `false` in the abstract class so legacy destinations don't have to
  override; concrete destinations that permit hard deletion opt in
  explicitly.
- `bool canAddToBatch(List<StoredEvent>, StoredEvent);` (REQ-d00128-E)
  — destination-owned batch admission predicate.
- `WirePayload transform(StoredEvent)` → `Future<WirePayload>
  transform(List<StoredEvent> batch)` (REQ-d00128-D, REQ-d00122-D) —
  async so real destinations can do per-batch async work (signing,
  key-store lookup); empty batch is a precondition violation.

Also refreshed REQ-d00122-D in `spec/dev-event-sourcing-mobile.md` to
describe the batch-aware signature. `elspais fix` refreshed
REQ-d00122's content hash (and routine index/changelog maintenance
on unrelated PRDs).

Implements: REQ-d00128-D, REQ-d00128-E, REQ-d00128-F, REQ-d00129-B,
REQ-d00122-D (revised).

## New contract (abstract Destination surface)

```text
abstract class Destination {
  String get id;                    // REQ-d00122-A
  SubscriptionFilter get filter;    // REQ-d00122-B
  String get wireFormat;            // REQ-d00122-C

  Duration get maxAccumulateTime;   // REQ-d00128-F
  bool get allowHardDelete => false;// REQ-d00129-B (default false)

  bool canAddToBatch(              // REQ-d00128-E
    List<StoredEvent> currentBatch,
    StoredEvent candidate,
  );

  Future<WirePayload> transform(   // REQ-d00128-D / REQ-d00122-D
    List<StoredEvent> batch,
  );                                // batch SHALL be non-empty

  Future<SendResult> send(WirePayload payload); // REQ-d00122-E
}
```

The batch-aware `transform` returns one `WirePayload` covering the
whole batch; subclasses MAY throw `ArgumentError` on the empty-batch
precondition violation.

## TDD sequence

1. **Baseline**: `flutter test` — **327 / 327 green**. `dart analyze`
   clean.
2. **Red**: Appended five REQ-d00128 / REQ-d00129-B tests to
   `test/destinations/destination_test.dart` and rewrote the existing
   REQ-d00122-D+E tests to the new batch-aware signature:
   - `REQ-d00128-D: Destination.transform(List<Event>) produces one
     WirePayload covering the whole batch`.
   - `REQ-d00128-D: Destination.transform rejects empty batch with
     ArgumentError`.
   - `REQ-d00128-E: canAddToBatch returns true when batch is empty
     and false once capacity is reached`.
   - `REQ-d00128-F: Destination.maxAccumulateTime is declared on the
     destination surface`.
   - `REQ-d00129-B: Destination.allowHardDelete defaults to false in
     the abstract contract` (uses a `_DefaultDestination` fixture
     that relies on the abstract-class default).
   The test file did not compile under the old single-event signature
   ("The return type of the method '_DefaultDestination.transform' is
   'Future<WirePayload>', which does not match the return type,
   'WirePayload'").
3. **Green**: Widened the abstract `Destination` class with the new
   four members (`maxAccumulateTime`, `allowHardDelete` defaulted,
   `canAddToBatch`, batch-aware async `transform`). Updated the
   `FakeDestination` test double with `batchCapacity`,
   `maxAccumulateTime`, `allowHardDelete` fields and the batch-aware
   transform. Updated `_StubDestination` in
   `destination_registry_test.dart` to the new signature.
4. **Analyze fix**: `dart analyze` surfaced a `prefer_is_empty` lint
   on the echo-fixture's `canAddToBatch` (`currentBatch.length < 1`);
   rewrote to `currentBatch.isEmpty` with a comment explaining why
   the echo fixture caps at one event per batch.
5. **Verify**: `flutter test` — **332 / 332 green** (+5). `dart
   analyze` — **No issues found!** `flutter analyze` on
   `apps/daily-diary/clinical_diary` — **No issues found!** (no code
   there is affected).

## Test counts

- Baseline: **327 / 327**.
- Final: **332 / 332**. Delta: **+5** (five new REQ-d00128 /
  REQ-d00129-B tests in `destination_test.dart`; two pre-existing
  REQ-d00122-D/E tests rewritten in-place for the batch signature).

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found.**

## Files touched

- `apps/common-dart/append_only_datastore/lib/src/destinations/destination.dart`
  — widened abstract surface: added `maxAccumulateTime` (REQ-d00128-F),
  `allowHardDelete` defaulted to `false` (REQ-d00129-B), `canAddToBatch`
  (REQ-d00128-E); changed `transform(StoredEvent)` to async
  `transform(List<StoredEvent> batch)` (REQ-d00128-D, REQ-d00122-D).
  Doc comments and `Implements:` citations refreshed.
- `apps/common-dart/append_only_datastore/lib/src/destinations/wire_payload.dart`
  — doc comment updated to reference `Destination.transform(List<StoredEvent>
  batch)` instead of the old single-event signature; `Implements:`
  comment revised to match.
- `apps/common-dart/append_only_datastore/test/test_support/fake_destination.dart`
  — added `batchCapacity` (default `1`), `maxAccumulateTime` (default
  `Duration.zero`), `allowHardDelete` (default `false`) constructor
  params; implemented `canAddToBatch` returning
  `currentBatch.length < batchCapacity`; rewrote `transform` as
  `Future<WirePayload> transform(List<StoredEvent>)` with
  `ArgumentError` on empty batch. The JSON payload now covers the
  whole batch (`event_ids`, `data`).
- `apps/common-dart/append_only_datastore/test/destinations/destination_test.dart`
  — added a second `_DefaultDestination` fixture (for REQ-d00129-B's
  abstract-default assertion); rewrote `_EchoDestination` to the new
  signature; added five REQ-d00128 / REQ-d00129-B tests and updated
  the pre-existing REQ-d00122-D/E tests to use the batch signature.
- `apps/common-dart/append_only_datastore/test/destinations/destination_registry_test.dart`
  — updated `_StubDestination` to the new signature
  (`maxAccumulateTime`, `canAddToBatch`, async
  `transform(List<StoredEvent>)`).
- `spec/dev-event-sourcing-mobile.md` — REQ-d00122-D rewritten:
  "`Destination.transform(List<StoredEvent> batch)` SHALL return a
  `WirePayload` covering the entire batch, with fields `bytes`,
  `content_type`, and `transform_version`; `transform_version` SHALL
  be recorded on the resulting `FifoEntry` and appended to
  `ProvenanceEntry.transform_version` on the receiver side. The batch
  SHALL be non-empty (REQ-d00128-D)." `elspais fix` refreshed
  REQ-d00122's content hash and performed routine index / changelog
  maintenance on unrelated PRDs.

## Notes

- No production caller's contract changed: `drain.dart` reads
  `head.wirePayload` from the stored FIFO row, not from
  `destination.transform`, so the drain path is unaffected by the
  signature change. `fillBatch` (Task 11) is what will invoke
  `transform(batch)` on the enqueue side; Task 9 prepares the
  surface Task 11 will call.
- The `FakeDestination` `batchCapacity` default of `1` preserves the
  legacy single-event behavior for every pre-existing drain-/sync-
  cycle test — none of them needed batch-aware assertions and none
  needed the param passed explicitly. Batch-aware tests in Task 11
  will opt in with `batchCapacity: N`.
- REQ-d00122-D's spec text is now a strict superset of the old text:
  the three fields (`bytes`, `content_type`, `transform_version`)
  and the provenance-stamping requirement are unchanged; only the
  signature and the empty-batch precondition are new (the latter
  cross-referencing REQ-d00128-D).
- `allowHardDelete` is defaulted in the abstract class (not marked
  `abstract`) so existing destinations that have not yet been
  migrated to Phase 4.3 don't have to override it. Concrete
  destinations that permit hard deletion will opt in by overriding
  the getter to `true` in Phase 4.3 Task 10.
