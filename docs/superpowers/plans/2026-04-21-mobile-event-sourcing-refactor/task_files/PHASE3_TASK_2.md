# Phase 3 Task 2: Spec additions — REQ-MAT

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## REQ number discovery

- Query: `search("REQ-d00119 OR REQ-d00120 OR REQ-d00121")` → REQ-d00119 (FIFO), REQ-d00120 (Canonical Hashing) exist; REQ-d00121 does not.
- Query: `search("REQ-d00121 OR REQ-d00122 OR REQ-d00123 OR REQ-d00124 OR REQ-d00125")` → no results.
- **Allocated:** `REQ-d00121` (next available after REQ-d00120 from the Canonical Hashing work).

Note: the plan's placeholder "REQ-MAT" was anchored to REQ-d00120 at plan-writing time; the Canonical Hashing REQ landed at REQ-d00120 between plan authoring and Phase 3 execution, so REQ-d00121 is the next free slot.

## Applicable existing assertions

From `discover_assertions("derive current state from event log")`:

- **REQ-p00004-E** — "The system SHALL derive current data state by replaying events from the event store." Directly drives the materializer contract.
- **REQ-p00004-L** — "The system SHALL update the current view automatically when new events are created." Drives the materializer being called in the write path (Phase 5); listed in plan's Task 4 assertion list.
- **REQ-p01006-A, B** — Type-Safe Materialized View Queries. Related but for server-side PG queries, not the mobile materializer. Not bound to REQ-d00121.

`discover_assertions("materialized view CQRS event log projection")` returned 0 — no pre-existing dev-level materializer REQ exists. That's why we are creating one.

## REQ-d00121 content

Title: **`diary_entries Materialization from Event Log`**
Implements: REQ-p00004, REQ-p00013 (both via IMPLEMENTS edges)
Status: Draft
Assertions: A through I (9 assertions), matching the plan's REQ-MAT-A..I verbatim in intent, with prose tightened for SHALL grammar.

Key changes from plan text:
- Plan said "`effective_date` SHALL be computed by resolving `def.effective_date_path` as a JSON path" — kept, but in spec clarified that "parsing as a date" failures also trigger the fallback (not only path-unresolvable), so a checkpoint event with `startTime` set to an unparseable string still gets the first-event-timestamp fallback rather than crashing.
- Plan's assertion I (cache contract) reworded to lean on code review rather than runtime enforcement, matching plan intent.

## Actions taken

1. Wrote REQ-d00121 block into `spec/dev-event-sourcing-mobile.md` with `Hash: TBD` placeholder.
2. `refresh_graph()` → REQ-d00121 registered; 9 assertions and 2 parent edges (REQ-p00004, REQ-p00013) recognized.
3. `elspais fix` → replaced `TBD` with canonical hash `7b9cb4e1`; regenerated `spec/INDEX.md` with REQ-d00121 row added.
4. Reverted cosmetic whitespace changes elspais applied to two unrelated PRD files (`prd-questionnaire-session.md`, `prd-questionnaire-system.md`) to keep the commit focused.

## Verification

- `elspais checks` reports no `REQ-d00121` stale-hash issue post-fix.
- `grep 'REQ-d00121' spec/INDEX.md` shows the row: `| REQ-d00121 | diary_entries Materialization from Event Log | dev-event-sourcing-mobile.md | 7b9cb4e1 |`.
- `get_requirement("REQ-d00121")` returns all 9 assertions and both parent edges resolved.

## Commit

- `[CUR-1154] Add materializer contract assertions`
- Files: `spec/dev-event-sourcing-mobile.md` (+REQ-d00121), `spec/INDEX.md` (+1 row).

## Task complete

REQ-d00121 accepted into the graph. Ready for Task 3 (EntryTypeDefinitionLookup abstract interface).
