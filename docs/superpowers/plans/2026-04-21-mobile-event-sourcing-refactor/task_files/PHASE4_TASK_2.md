# PHASE 4 TASK 2 — Spec additions: REQ-d00122 through REQ-d00125

## REQs claimed

| New REQ     | Title                                           | Assertions | Hash     |
| ----------- | ----------------------------------------------- | ---------- | -------- |
| REQ-d00122  | Destination Contract for Per-Destination Sync   | A..G       | be13f13e |
| REQ-d00123  | SyncPolicy Retry Backoff Curve                  | A..F       | 1be73b3e |
| REQ-d00124  | Per-Destination FIFO Drain Loop                 | A..H       | 817fc56b |
| REQ-d00125  | sync_cycle() Orchestrator and Trigger Contract  | A..E       | 03bfd328 |

Claimed after REQ-d00121 (the highest existing d-level REQ at Phase 3 completion) via direct file edit. Hashes stamped by `elspais fix <id>`.

## Discovery queries

- `discover_requirements("sync queue destination FIFO retry backoff", scope_id=REQ-p01001)` returned 0 descendants — the dev-level work Phase 4 specifies does not yet exist in the graph. Existing REQ-p01001 assertions A..N map as follows:

| REQ-p01001 assertion | Phase-4 coverage |
| --- | --- |
| A (queue locally) | covered by REQ-d00119 (Phase 2 prior work) |
| B (auto-sync on connectivity) | trigger in Phase 5; orchestrator in REQ-d00125-D |
| C (persistent storage) | REQ-d00119 (Phase 2) |
| D (FIFO delivery) | REQ-d00124-A+G+H |
| E (exponential backoff) | REQ-d00123-A..E + REQ-d00124-B+F |
| F (idempotency keys) | out of Phase 4 scope — handled by `entry_id` uniqueness (deferred) |
| G (preserve queue across restarts) | REQ-d00119 (Phase 2) |
| H (user visibility) | REQ-d00124-D (wedge is a surfaced state, not silent) |
| I (save immediately) | Phase 5 (EntryService) |
| J (auto-sync trigger) | REQ-d00125-D |
| K (manual sync trigger) | REQ-d00125-D |
| L (sync status UI) | Phase 5 (UI) |
| M (log failed sync) | REQ-d00124-G |
| N (no data loss on force-close) | REQ-d00119-D + REQ-d00124-G |

## Rejected alternatives considered

- Folding the new assertions into REQ-d00119 as additions: rejected because REQ-d00119 fixed the FIFO entry *shape* and three `final_status` values, and its rationale explicitly says the operational semantics "are refined in a later phase." Keeping shape (d00119) separate from behavior (d00122-125) avoids widening an already-frozen requirement.
- Combining REQ-d00124 (drain) and REQ-d00125 (sync_cycle) into one REQ: rejected because their triggers, testing surfaces, and future independent evolution (e.g., a new trigger source added without touching drain semantics) benefit from separation.
- Using `mutate_add_requirement` + `mutate_add_assertion` MCP tools: rejected because the direct-file-edit workflow matches Phases 1-3 and allows embedding rationale prose, which the mutate tools do not accept.

## Commands run

```
elspais fix REQ-d00122  # hash stamp
elspais fix REQ-d00123  # hash stamp
elspais fix REQ-d00124  # hash stamp
elspais fix REQ-d00125  # hash stamp
elspais fix             # regenerate INDEX.md
elspais checks          # HEALTHY: 31/31 checks passed
```

## Files modified

- `spec/dev-event-sourcing-mobile.md` — 4 REQs appended (approx. 120 new lines).
- `spec/INDEX.md` — 4 new rows added by `elspais fix` regeneration.

## Notes for later tasks

- Destination contract (REQ-d00122) carries assertions the concrete Phase-5 `PrimaryDiaryServerDestination` must satisfy. Phase-5 implementers: cite REQ-d00122-C+D on the transform method and REQ-d00122-E on the send method.
- REQ-d00124-G ("every send call appends an attempt") applies uniformly — there is no skip-appendAttempt path. Any future optimization that batches attempt records has to preserve per-send traceability.
- REQ-d00125-D enumerates the five triggers by name. Phase-5 trigger wiring should cite these assertion IDs per trigger so coverage is traceable.
