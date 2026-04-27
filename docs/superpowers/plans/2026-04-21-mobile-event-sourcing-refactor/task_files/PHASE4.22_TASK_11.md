# Phase 4.22 Task 11 — Final verification + Source doc + worklog close

## Goal

Close Phase 4.22 of CUR-1154. Three things:

1. Update the `Source` class doc comment in `apps/common-dart/event_sourcing_datastore/lib/src/storage/source.dart` to document the install-identity contract introduced by REQ-d00142-D, in final-state voice (no historical "renamed from `DeviceInfo`" framing).
2. Run all test suites + analyze + cleanup greps against the final phase state.
3. Append a final-verification section + the Phase 4.22 commit table to `PHASE_4.22_WORKLOG.md`, mark Task 11's checkbox `[x]`, and stamp the phase complete.

## Implementation

### Step 1 — Source.dart doc update

`apps/common-dart/event_sourcing_datastore/lib/src/storage/source.dart`:

Replaced the historical "Renamed from `DeviceInfo` (Phase 4.4) and narrowed: the old `userId` field moved out to the per-append `Initiator` argument, so one `Source` instance can serve many authenticated users." paragraph with two final-state-voice paragraphs:

- An `identifier` paragraph documenting the per-installation unique identity contract (REQ-d00142-D): production callers MUST persist a globally-unique value (UUIDv4 recommended) on first install and pass the same value on every subsequent bootstrap; the library does NOT validate the format at runtime; the consequence of a shared identifier across two installs is that they collide on the system audit aggregate_id (which equals `source.identifier` per REQ-d00134-E, REQ-d00129-J/K/L/M, REQ-d00138-D/E/F/H) on any receiver they both bridge to.
- A `hopId` paragraph documenting the role-class enumeration (REQ-d00142-B) and clarifying that `EventStore.isLocallyOriginated` (REQ-d00154-B) discriminates on `identifier`, not `hopId`.

Updated the per-class `// Implements:` annotations:

- `REQ-d00142-A` annotation: rewritten in final-state voice — "three fields: hopId, identifier, softwareVersion" (the prior "rename of DeviceInfo" history-of-change wording is gone).
- `REQ-d00142-B`, `REQ-d00142-C`: unchanged.
- `REQ-d00142-D`: new annotation — "identifier is the per-installation unique identity; library does not validate format; caller obligation to persist + reuse across boots."

The class body (`const Source({...})` constructor + `==`/`hashCode`/`toString`) is unchanged.

### Step 2 — Verification commands

```text
$ (cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
00:05 +705: All tests passed!

$ (cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
Analyzing event_sourcing_datastore...
No issues found! (ran in 0.8s)

$ (cd apps/common-dart/provenance && dart test 2>&1 | tail -5)
00:00 +45: All tests passed!

$ (cd apps/common-dart/provenance && dart analyze 2>&1 | tail -3)
Analyzing provenance...
No issues found!

$ (cd apps/common-dart/event_sourcing_datastore/example && flutter test 2>&1 | tail -5)
01:05 +81: All tests passed!

$ (cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
Analyzing example...
No issues found! (ran in 0.6s)
```

Cleanup greps (all expected results confirmed):

- `grep -rnE "aggregateId:\s*'(destination:|system:entry-type-registry|security-retention|system_retention|system_destination|retention-compact|retention-purge)" apps/common-dart/event_sourcing_datastore/lib/` -> 0 hits.
- `grep -nE "kReservedSystemEntryTypeIds.contains" apps/common-dart/event_sourcing_datastore/lib/src/sync/*.dart` -> 0 hits in `fill_batch.dart` and `historical_replay.dart`.
- `grep -rnE "includeSystemEvents|originatorHop|isLocallyOriginated" apps/common-dart/event_sourcing_datastore/lib/` -> rich hits in `subscription_filter.dart`, `stored_event.dart`, `event_store.dart`, `storage_backend.dart`, plus the library re-export in `event_sourcing_datastore.dart`.
- `grep -rnE "'demo-device'|'demo-portal'" apps/common-dart/event_sourcing_datastore/example/` -> 0 hits.

### Step 3 — Worklog close

Appended a "Final verification (Task 11)" section to `PHASE_4.22_WORKLOG.md` covering:

- All test counts (705 / 45 / 81), analyze status, and grep results.
- A summary of the Source.dart doc update (final-state voice; REQ-d00142-A/B/C/D annotations all present).
- Phase 4.22 closure narrative: closes the Phase 4.9 materialize-on-ingest deferral, introduces opt-in system-event bridging via `SubscriptionFilter.includeSystemEvents`, consolidates system audit aggregate_ids onto `source.identifier`, adds the cross-hop discrimination API, and the example app demonstrates end-to-end via per-pane install UUIDs + NativeAudit + hop badge.
- Lib-side bonus: closed a latent `runHistoricalReplay` bug surfaced by Task 10's NativeAudit registration; pinned by 2 regression tests in `historical_replay_test.dart`.
- The Phase 4.22 commit table — one row per task with `<sha>` + commit subject — for the rebase-merge audit trail.
- Phase 4.22 complete stamp.

Flipped `- [ ] Task 11: ...` -> `- [x] Task 11: ...` near the top of the worklog.

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/lib/src/storage/source.dart` — doc comment rewritten in final-state voice; REQ-d00142-D annotation added.

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 11 checkbox flipped; Final verification section + Phase 4.22 commit table appended; phase complete stamp added.
- This file (`PHASE4.22_TASK_11.md`).

## Outcome

Phase 4.22 of CUR-1154 is complete. The library now:

1. Materializes ingested events on the receiver inside the same ingest transaction (REQ-d00121-K, REQ-d00145-N), closing the Phase 4.9 deferral.
2. Discriminates locally-originated vs ingested events at the API surface (REQ-d00154-A: `StoredEvent.originatorHop`; REQ-d00154-B: `EventStore.isLocallyOriginated`; REQ-d00154-C: `StorageBackend.findAllEvents` originator filters).
3. Routes system audits through an explicit `SubscriptionFilter.includeSystemEvents` opt-in (REQ-d00128-J), and bridges them across hops without leaking into receiver runtime configuration (REQ-d00154-D / REQ-d00154-E / REQ-d00129-O receiver-stays-passive invariants).
4. Consolidates system audit aggregate_ids onto `source.identifier` (REQ-d00154-D) so two installs with the same role class still produce disjoint system aggregates on a shared receiver.
5. Refines `dedupeByContent` to match the most-recent prior event of the same `entry_type` within the aggregate (REQ-d00134-F), preventing cross-entry-type false dedupe inside a system aggregate.

The example app demonstrates the cross-hop story end-to-end:

- Per-pane UUIDv4 install identifiers (REQ-d00142-D) persisted to the demo's app-support directory.
- Two parallel native destinations (`NativeUser` and `NativeAudit`) sharing the downstream bridge — `NativeAudit` ships system audits via `includeSystemEvents: true`.
- A `[L]` / `[R]` badge on every `EventStreamPanel` row driven by `EventStore.isLocallyOriginated` (REQ-d00154-B).

CUR-1154 library work is complete. Ready for pre-PR review and rebase-merge.
