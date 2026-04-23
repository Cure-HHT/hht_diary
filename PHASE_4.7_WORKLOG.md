# Phase 4.7 Worklog

One section per completed task. Current state only — no diff narration.

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.7_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.

("phase" here denotes each numbered task of Phase 4.7; Phase 4.7 implementation uses independent tasks per the design spec, with consolidated phase-end review once all tasks complete.)

---

## Plan

`docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.7_strict_order_drain.md` — fixes a race condition in `drain()` that can violate strict-order semantics when concurrent `drain` calls on the same destination observe overlapping event windows. Phase 4.7 spans 3 independent tasks:

- **Task 1** (baseline verification + worklog) — confirm green baseline, reserve REQ-d00144 for tombstoneAndRefill, document plan/design anchors
- **Task 2** (fix logic + unit tests) — repair the `drain` algorithm to honor strict-order atomicity, add three new test cases
- **Task 3** (demo scenario + integration) — add a JNY demonstrating the fix's observable effect

## Design spec

`docs/superpowers/specs/2026-04-23-strict-order-drain-fix-design.md` — documents the race, its symptoms, the root cause in the pre-existing `drain()` algorithm, and the proposed fix (tombstoneAndRefill semantics: immediate-write tombstones block concurrent reentrancy; events are refilled atomically post-send).

## REQ-d substitution table

| Plan context | Assigned REQ-d | Title |
| --- | --- | --- |
| tombstoneAndRefill implementation | REQ-d00144 | Strict-order drain via tombstoneAndRefill semaphore |

---

## Task 1: Baseline verification + worklog

### Git state

Phase 4.6 completed on this branch with commit `d8128286` (Phase 4.6 tweak: FIFO slider ranges). Two Phase 4.7 commits already on HEAD:

- `ba9a143e` — [CUR-1154] Design spec: strict-order drain semantics fix
- `b6d62bfb` — [CUR-1154] Phase 4.7 plan: strict-order drain semantics fix

Working tree contains a pre-existing unstaged change to `.githooks/pre-commit` (from Phase 4.6 session). NOT included in this commit.

### Baseline tests (Phase 4.6 post-state)

- `append_only_datastore` (`flutter test`): **472 pass**; `flutter analyze` clean
- REQ-d00144 verification: no matches found in `spec/INDEX.md` or `spec/dev-event-sourcing-mobile.md`

### Plan/design anchors

- **Design doc**: `docs/superpowers/specs/2026-04-23-strict-order-drain-fix-design.md`
- **Plan doc**: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.7_strict_order_drain.md`
- **Applicable REQ**: REQ-d00144 (tombstoneAndRefill drain semantics) — reserved for Task 2

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.7_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.
