# PHASE 4.3 TASK 2 — Parent plan file updates

## Edits applied

### `README.md` (parent plan index)

Phase table updated:

- Phase 4 description appended with "(batch-FIFO + skip-exhausted per 2026-04-22 design)" to flag the in-phase revisions already made.
- New row 4.3 added: "Dynamic destinations, batch-FIFO migration, unjam/rehabilitate, `EntryService`/`EntryTypeRegistry`/`bootstrap` pulled forward" — risk: Medium.
- New row 4.6 added: "Flutter Linux-desktop demo app at `append_only_datastore/example/`" — risk: Low.
- Phase 5 scope text revised to call out the shrink: "shrunk: EntryService/Registry/bootstrap moved to 4.3".

### `PLAN_PHASE5_cutover.md` (cutover plan)

- Prepended a `> **Note (2026-04-22):** ...` block after the metadata header listing the three tasks that moved to Phase 4.3:
  - Task 3 (`EntryTypeRegistry`) → Phase 4.3 Task 17.
  - Task 5 (`EntryService`) → Phase 4.3 Task 16, with REQ-ENTRY-D revised per design §6.8.
  - Task 6 (`bootstrap`) → Phase 4.3 Task 18.
- Inline `> Moved to Phase 4.3 (2026-04-22)` prefix added under each of Tasks 3, 5, 6 headings.

## Plan-text discrepancy

The PLAN_PHASE4.3 Task-2 spec says "Tasks 3, 4, 5 inside PLAN_PHASE5 get an inline `> Moved to Phase 4.3 (2026-04-22)` prefix." The bullet list immediately above that instruction names the three moved items as "EntryService creation, EntryTypeRegistry creation, bootstrap creation", which in the actual PLAN_PHASE5 heading numbering are **Tasks 3, 5, 6** (Task 4 is "Bundled EntryTypeDefinition assets" and stays in Phase 5 — Phase 4.3 Task 17 creates only the `EntryTypeRegistry` class, not the JSON assets). Annotated Tasks 3, 5, 6 per the bullet-list intent.

## Dev-spec path check

`spec/dev-event-sourcing-mobile.md` exists (Phase 1 created it). No action needed.

## Files modified

- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md`
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE5_cutover.md`
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.3_TASK_2.md` (this file)

No code touched. Baseline tests not re-run (doc-only change).

Ready for Phase 4.3 Task 3.
