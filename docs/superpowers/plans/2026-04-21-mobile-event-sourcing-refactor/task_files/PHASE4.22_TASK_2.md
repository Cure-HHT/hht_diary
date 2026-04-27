# Phase 4.22 Task 2 — Spec Amendments via elspais MCP

## Goal

Edit the requirements graph so the dev spec describes the Phase 4.22 contract:
materialize-on-ingest, opt-in system events on the wire, install-identity-based
system aggregate_ids, the discrimination API surface
(`StoredEvent.originatorHop`, `EventStore.isLocallyOriginated`,
`StorageBackend.findAllEvents` originator filters), and the
receiver-stays-passive invariant. No application code changes; only
`spec/dev-event-sourcing-mobile.md`, `spec/INDEX.md`, the worklog, and this
task file.

## REQ Claimed

**REQ-d00154 — Cross-Hop Event Discrimination and Bridged System-Event Storage**
(level: dev, status: Draft, implements: REQ-p00004 + REQ-p01001).

Body (rationale): "Phase 4.22 introduces the API surface and storage-level
conventions that let a receiver distinguish locally-originated events from
bridged-from-upstream events without writing provenance navigation by hand,
and that make the dashboard / forensic query patterns ('all events from this
install', 'all events from any install of this hop class') efficient. System
events use `source.identifier` as their `aggregate_id` so two installations'
system streams never collide on the receiver. The receiver-stays-passive
invariant is formalized: bridged audits are informational about the
originator's local state; the receiver's local state is unaffected."

## Mutations Applied

All applied via the elspais MCP and persisted via
`mcp__elspais__save_mutations`. After save, the new requirement was
relocated from `spec/prd-database.md` (where elspais default-placed it
under its primary parent's file) to `spec/dev-event-sourcing-mobile.md`
via `mcp__elspais__move_requirement`. Hashes and `spec/INDEX.md` were
recomputed by `elspais fix`.

### Add: REQ-d00154 (new requirement)

- `mutate_add_requirement(req_id="REQ-d00154", level="DEV", parent_id="REQ-p00004", edge_kind="IMPLEMENTS")`
- `mutate_add_edge(source_id="REQ-d00154", target_id="REQ-p01001", edge_kind="IMPLEMENTS")` (second IMPLEMENTS parent)
- `mutate_add_assertion(REQ-d00154, "A", ...)` — `StoredEvent.originatorHop` getter; throws `StateError` on empty provenance.
- `mutate_add_assertion(REQ-d00154, "B", ...)` — `EventStore.isLocallyOriginated`; identity check on `identifier`, not `hopId`.
- `mutate_add_assertion(REQ-d00154, "C", ...)` — `StorageBackend.findAllEvents` originatorHopId/originatorIdentifier params (AND semantics).
- `mutate_add_assertion(REQ-d00154, "D", ...)` — Reserved system entry types ship with `materialize: false`.
- `mutate_add_assertion(REQ-d00154, "E", ...)` — Ingest paths SHALL NOT call any DestinationRegistry/EntryTypeRegistry/FIFO method.
- `mutate_add_assertion(REQ-d00154, "F", ...)` — `SubscriptionFilter.includeSystemEvents` semantics on system entry types.
- `move_requirement(req_id="REQ-d00154", target_file="spec/dev-event-sourcing-mobile.md")`
- Body text added by direct file edit (no MCP body-mutation tool exists).

### Add: assertions on existing REQs

- `mutate_add_assertion("REQ-d00121", "K", ...)` — Ingest fires materializers per-event with same `def.materialize` and `m.appliesTo(event)` gates as append; rollback on throw per REQ-d00145-A.
- `mutate_add_assertion("REQ-d00128", "J", ...)` — `SubscriptionFilter.includeSystemEvents: bool` (default false); `matches` bypasses `entryTypes` for reserved system entry types when true; `fillBatch` and `historicalReplay` defer to `matches`.
- `mutate_add_assertion("REQ-d00129", "O", ...)` — Ingest paths SHALL NOT mutate DestinationRegistry/EntryTypeRegistry/FIFO state on the receiver.
- `mutate_add_assertion("REQ-d00142", "D", ...)` — `Source.identifier` is the per-installation unique identity (UUIDv4 recommended); library does not validate at runtime.
- `mutate_add_assertion("REQ-d00145", "N", ...)` — Ingest fires materializers per-event in the ingest transaction; cross-references REQ-d00121-K.

### Update: existing assertion text (final-state voice)

- `mutate_update_assertion("REQ-d00129-J", ...)` — `aggregateId` equal to `source.identifier` (was `'destination:<id>'`); clarified `data.id` is the destination identifier readers filter by.
- `mutate_update_assertion("REQ-d00129-K", ...)` — `aggregateId` equal to `source.identifier`.
- `mutate_update_assertion("REQ-d00129-L", ...)` — `aggregateId` equal to `source.identifier`.
- `mutate_update_assertion("REQ-d00129-M", ...)` — `aggregateId` equal to `source.identifier`.
- `mutate_update_assertion("REQ-d00134-E", ...)` — `aggregateId` equal to `source.identifier` (was `'system:entry-type-registry'`).
- `mutate_update_assertion("REQ-d00134-F", ...)` — `dedupeByContent` semantic rewritten in final-state voice: loads events for the aggregate, selects most-recent event whose entry_type equals the candidate's, content-hash compares, no-op on match.
- `mutate_update_assertion("REQ-d00138-D", ...)` — `clearSecurityContext` audit `aggregateId` equal to `source.identifier`; redacted event id moved to `data.subject_event_id`.
- `mutate_update_assertion("REQ-d00138-E", ...)` — `security_context_compacted` `aggregateId` equal to `source.identifier`.
- `mutate_update_assertion("REQ-d00138-F", ...)` — `security_context_purged` `aggregateId` equal to `source.identifier`.
- `mutate_update_assertion("REQ-d00138-H", ...)` — `applyRetentionPolicy` audit `aggregateId` equal to `source.identifier` (was `'security-retention'`).

## Persistence + Refresh

- `mcp__elspais__save_mutations()` — saved 2 files (`spec/dev-event-sourcing-mobile.md`, `spec/prd-database.md`).
- `move_requirement` relocated REQ-d00154 to `spec/dev-event-sourcing-mobile.md`.
- `elspais fix` — validated 328 requirements, regenerated `spec/INDEX.md` (328 requirements, 11 journeys), recomputed all affected hashes.
- `mcp__elspais__refresh_graph(full=True)` — graph reloaded with 43355 nodes; REQ-d00154 confirmed at hash `e0495b4d`.

## Verification

- `elspais checks`: HEALTHY (32/32 passed).
- `flutter analyze` (event_sourcing_datastore lib): No issues found! (no application code changes were made; this is the expected baseline-clean status).
- All new assertion texts use final-state voice — no "previously," "no longer," or "removed" phrasing.
- All 6 REQ-d00154 assertions A-F present.
- All 4 REQ-d00129 assertions J-M updated; new REQ-d00129-O present.
- All 4 REQ-d00138 assertions D, E, F, H updated.
- REQ-d00134-E + F updated (E for aggregate_id, F for dedupe semantic in final-state voice).
- REQ-d00134-G untouched (no aggregate_id literal embedded; describes entryTypeVersion stamping).

## Files Touched

- `spec/dev-event-sourcing-mobile.md` — REQ-d00121, REQ-d00128, REQ-d00129, REQ-d00134, REQ-d00138, REQ-d00142, REQ-d00145, plus new REQ-d00154.
- `spec/prd-database.md` — added then removed REQ-d00154 IMPLEMENTS edge to REQ-p00004 link footer (cleaned up by `move_requirement` follow-through).
- `spec/INDEX.md` — regenerated by `elspais fix`.
- `PHASE_4.22_WORKLOG.md` — Task 2 marked complete; Task 2 details section appended.
- This file (`PHASE4.22_TASK_2.md`).

## Outcome

Spec is ready for Tasks 3-11 (implementation). All assertion targets named in
the design spec's "Per-class and per-test annotations the implementation plan
must enforce" subsection now have stable REQ-id citations: REQ-d00121-K,
REQ-d00128-J, REQ-d00129-J/K/L/M (revised) + O (new), REQ-d00134-E/F (revised),
REQ-d00138-D/E/F/H (revised), REQ-d00142-D, REQ-d00145-N, REQ-d00154-A/B/C/D/E/F.
