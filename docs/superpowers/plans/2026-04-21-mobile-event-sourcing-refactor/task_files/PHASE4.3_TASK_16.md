# PHASE 4.3 TASK 16 — EntryService.record (REQ-d00133)

## Summary

Pulled the sole widget-facing write API forward from Phase 5 into Phase
4.3 with one revised assertion (D) per design §6.8. `EntryService.record`
now owns the atomic local write — event assembly, hash-chain stamping,
materializer fold, diary_entries upsert, sequence-counter advance — and
kicks `syncCycle` fire-and-forget. Destination FIFO fan-out is
DEFERRED to `fillBatch`, which runs on the next `syncCycle` tick
(REQ-d00133-D revised); the write transaction does NOT call
`destination.transform` or `destination.send`.

Supporting changes:

- `EntryTypeRegistry` shipped here in minimal form
  (`register`/`byId`/`isRegistered`/`all`). Task 17 polishes if needed.
- `StoredEvent.softwareVersion` added as a top-level optional field
  (default empty string) so the migration-bridge assertion REQ-d00133-I
  has somewhere to write without breaking the ~20 existing call sites
  that construct `StoredEvent` without it.
- `DeviceInfo` small value type bundles `deviceId`/`softwareVersion`/
  `userId`.
- `SyncCycleTrigger` type alias (`Future<void> Function()`). Production
  passes `() => syncCycle.call()`; tests pass a spy.

Implements: REQ-d00133-A, REQ-d00133-B, REQ-d00133-C, REQ-d00133-D
(revised), REQ-d00133-E, REQ-d00133-F, REQ-d00133-G, REQ-d00133-H,
REQ-d00133-I.

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **373 / 373 green**.
   `dart analyze` clean.
2. **Red — tests first**: wrote `test/entry_service_test.dart` with
   nine tests — one per REQ-d00133 assertion plus one granularity
   test for REQ-d00133-F. Fixture wires a `SembastBackend`, an
   `EntryTypeRegistry`, a spy `syncCycleTrigger`, and a `DeviceInfo`.
   Two tests construct decorator backends:
   - `_FifoPanicBackend` (REQ-d00133-D): counts every
     `enqueueFifo`/`enqueueFifoTxn` call and throws on any attempt,
     proving record() does NOT fan out to FIFOs.
   - `_ThrowingUpsertBackend` (REQ-d00133-E): throws from
     `upsertEntry`, which runs inside the same transaction as
     `appendEvent`, so the rollback guarantees the append is also
     rolled back.
   A `_DelegatingBackend` base forwards every `StorageBackend` method
   to an inner backend so each decorator overrides just the methods
   it wants to intercept.
3. **Green — implementation**:
   - `lib/src/entry_type_registry.dart`: minimal `EntryTypeRegistry`
     with `register`/`byId`/`isRegistered`/`all`. Duplicate
     registration throws `ArgumentError`.
   - `lib/src/entry_service.dart`: `EntryService.record` validates
     eventType + entryType pre-I/O, reads the aggregate's history
     outside the transaction for content-hash no-op detection, then
     opens one `backend.transaction` that reads the chain tail,
     reserves the sequence number, stamps event_id + provenance +
     migration-bridge fields + event_hash, appends, runs the
     materializer, and upserts the diary_entries row. On return it
     kicks `unawaited(syncCycleTrigger())`. No-op duplicates return
     `null`; successful writes return the appended `StoredEvent`.
   - `lib/src/storage/stored_event.dart`: added
     `softwareVersion` as an optional top-level field with default
     `''`. `fromMap` reads the `software_version` key, rejects
     non-String when present, defaults to `''` when absent.
     `toMap` round-trips.
   - `pubspec.yaml`: added path dep on `../provenance` so
     `ProvenanceEntry` is constructible from `EntryService.record`.
   - `lib/append_only_datastore.dart`: exported `EntryService`,
     `DeviceInfo`, `SyncCycleTrigger`, `EntryTypeRegistry`.
   - `test/lint/materialized_view_writer_lint_test.dart`: added
     `entry_service.dart` to the `_allowlist` for REQ-d00121-I —
     `EntryService.record` is the second legitimate writer of
     `diary_entries` (after `rebuildMaterializedView`).
   Reran entry-service tests — **9 / 9 green**.
4. **Full-suite verify**: `flutter test` — **382 / 382 green** (+9
   vs baseline). `dart analyze` clean.

## Test counts

- Baseline: **373 / 373**.
- Final: **382 / 382**. Delta: **+9**.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found!**
- `flutter analyze` (append_only_datastore): **No issues found!**

## Files touched

### Created

- `apps/common-dart/append_only_datastore/lib/src/entry_service.dart`
- `apps/common-dart/append_only_datastore/lib/src/entry_type_registry.dart`
- `apps/common-dart/append_only_datastore/test/entry_service_test.dart`
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.3_TASK_16.md`
  (this file).

### Modified

- `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`
  - Exported `EntryService`, `DeviceInfo`, `SyncCycleTrigger`, and
    `EntryTypeRegistry`.
- `apps/common-dart/append_only_datastore/lib/src/storage/stored_event.dart`
  - Added top-level `softwareVersion` field (optional, default `''`).
    `fromMap`/`toMap` now round-trip `software_version`.
- `apps/common-dart/append_only_datastore/pubspec.yaml`
  - Added path dependency on `../provenance` for `ProvenanceEntry`.
- `apps/common-dart/append_only_datastore/test/lint/materialized_view_writer_lint_test.dart`
  - Added `entry_service.dart` to REQ-d00121-I allowlist.

## Notes

- **softwareVersion default `''`**: the ~20 existing
  `StoredEvent(...)` construction sites (tests and the legacy
  `EventRepository`) don't pass a `softwareVersion`. Making the
  field optional with `''` default keeps those sites compiling
  unchanged. `EntryService.record` is the first and only path that
  populates it (from `metadata.provenance[0].software_version`).
  The design-doc REQ-d00118-C already calls this out: the
  `software_version` clause only becomes enforceable once
  `EntryService.record` exists — which it now does.
- **No-op content hash shape**: the hash input is
  `(event_type, answers, checkpoint_reason, change_reason)`. That
  tuple is deliberately narrower than the full event record — the
  no-op detector's job is "did the user try to save the same thing
  twice?", not "did any byte differ?". Timestamps, event_id,
  sequence_number, provenance all change on every call, so
  including them would defeat the detector.
- **Aggregate history read outside the transaction**: the
  no-op check walks `findEventsForAggregate` before opening the
  write transaction. This is safe because (a) a duplicate would
  contribute no work inside the transaction anyway, and (b) a
  concurrent writer that slipped in between the read and the
  transaction would be a legitimate new event whose content the
  no-op detector could not have seen — serializing the detector
  inside the transaction would only close a race that produces the
  same outcome (the serialized-second-writer branch still writes
  the event).
- **Materializer `firstEventTimestamp` fallback**: resolved from
  the aggregate's oldest event. When the aggregate is new, that's
  the current event's `clientTimestamp`; on subsequent events,
  it's the earliest prior event's timestamp. This matches the
  rebuild path's semantics.
- **Error routing on trigger**: REQ-d00133-G says `unawaited`, so
  a thrown error from `syncCycleTrigger()` falls into the default
  `Zone` unhandled-error handler. The drain path's per-destination
  try/catch inside `SyncCycle._drainOrSwallow` already ensures a
  single destination failure does not propagate; but if some
  future `syncCycleTrigger` throws before reaching drain, the
  fire-and-forget contract surfaces it at the zone level. That
  matches the existing `clinical_diary` style for background
  work — not a new gap introduced by this task.
- **FIFO fan-out is deferred, not skipped**: `fillBatch` is the
  single consumer of `fill_cursor`. When the next `syncCycle` tick
  runs, it reads the cursor, walks past it, applies each
  destination's filter/batch/transform, and enqueues matching
  events onto that destination's FIFO. Events recorded by
  `record()` are therefore visible to destinations on the next
  tick (plus any `maxAccumulateTime` hold from REQ-d00128-F).
- **StorageBackend decorator pattern in tests**: the
  `_DelegatingBackend` base in `entry_service_test.dart` is
  test-local — it overrides every abstract method but delegates to
  an inner backend. Test-specific decorators (`_FifoPanicBackend`,
  `_ThrowingUpsertBackend`) override just the methods they want to
  intercept. This pattern is local to this test file; it is not
  intended as a reusable test fixture.
- **EntryTypeRegistry surface is intentionally minimal**: Task
  17's `bootstrapAppendOnlyDatastore` will exercise `register` and
  `all()`; the design doesn't need any other method on the
  registry, so none was added here. Detailed registry tests
  (e.g., duplicate-registration, empty-registry iteration) land in
  Task 17.
