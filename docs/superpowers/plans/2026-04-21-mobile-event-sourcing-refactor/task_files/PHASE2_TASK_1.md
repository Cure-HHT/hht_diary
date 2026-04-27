# Phase 2 Task 1: Baseline verification

**Date:** 2026-04-21
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Branch state

- Worktree: `/home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/`
- Branch: `mobile-event-sourcing-refactor` (no checkout change — shared across all 5 phases)
- Phase 1 completion SHA: `c9fcb8d1 [CUR-1154] Phase 1: Add provenance package and EntryTypeDefinition` (HEAD)
- Additional branch commits ahead of `origin/main`:
  - `c974495c [CUR-1154] Fix deployment-doctor counters for Linux set -e compat`
  - `b202b05c [CUR-1154] Add design doc and 5-phase implementation plan`
- `git fetch origin main && git log --oneline origin/main..HEAD` shows origin/main did NOT move during Phase 1 review; no rebase was required.

## Baseline test results

| Command | Result |
| --- | --- |
| `(cd apps/common-dart/append_only_datastore && flutter test)` | PASS — 90 tests |
| `(cd apps/common-dart/trial_data_types && dart test)` | PASS — 54 tests |
| `(cd apps/common-dart/provenance && dart test)` | PASS — 31 tests |
| `(cd apps/daily-diary/clinical_diary && flutter test)` | PASS — 1098 tests (1 skipped, pre-existing) |
| `(cd apps/daily-diary/clinical_diary && flutter analyze)` | PASS — No issues found |

All test counts match expectations: trial_data_types is +20 over Phase 1's baseline of 34 (17 new EntryTypeDefinition tests plus the 3-test suite expansion noted in the Phase 1 commit). provenance is 31 (Phase 1 output). append_only_datastore and clinical_diary are unchanged from Phase 1 baseline.

## REQ number discovery (for Task 2)

Phase 1 used REQ-d00115 and REQ-d00116. The highest registered REQ-d in elspais is REQ-d00116 (verified via `elspais search "REQ-d00115"` / `"REQ-d00116"`). Candidates for Phase 2:

- `REQ-d00117` — StorageBackend transaction contract (the plan's REQ-SB placeholder)
- `REQ-d00118` — Event schema changes (the plan's REQ-ES placeholder)
- `REQ-d00119` — Per-destination FIFO semantics (the plan's REQ-FIFO placeholder)

All three confirmed unused via `elspais search REQ-d00117/8/9` → "No results."

(The only hit for the pattern `REQ-d0011[7-9]|REQ-d0012[0-5]` in the repo is `REQ-d00123`, which appears twice in `docs/ops-deployment-production-tagging-hotfix.md` as an illustrative commit-message example, not an actual claim. `elspais search REQ-d00123` also returns no results. Safe to use REQ-d00117/118/119 as planned.)

## elspais MCP status

At session start, `/mcp` output showed "Failed to reconnect to elspais." A subsequent `claude mcp list` showed elspais connected. The elspais CLI (`/home/metagamer/.local/bin/elspais`, v0.114.29) is functional; `elspais checks` runs cleanly (31/33 checks passed, 2 warnings, 16 skipped — standard baseline).

The plan's "`discover_requirements` MCP tool" phrasing maps to the elspais CLI's `search` subcommand plus manual number allocation — there is no built-in "next available" command. The pattern used above (search for a probable unused slot, verify no hits) is the workable substitute.

## Deviation from plan note (for Task 4)

The plan's Task 4 claims the `client_timestamp / device_id / software_version = metadata.provenance[0].*` duplication rule (REQ-ES-C) "is checked by the `EventRepository.append` code path in Task 6." That is inconsistent — Task 6 is SembastBackend-level, and `SembastBackend.appendEvent` receives an already-constructed Event. The duplication must happen in `EventRepository.append()` (the caller that constructs the event), which is Task 9. Plan to defer the REQ-ES-C verification test to Task 9 and note this in PHASE2_TASK_4.md.

## Pre-existing working-tree state (unchanged from Phase 1)

Three files remain uncommitted on the worktree (carried over from Phase 1 Task 1 triage):

- `.elspais.toml` (user's MCP debugging, modified)
- `.elspais.toml.old` (v3 config backup)
- `apps/sponsor-portal/tool/deployment-doctor.sh` — wait, this one was actually committed as `c974495c` during Phase 1. Re-checked: `git status` returns `nothing to commit, working tree clean`. The `.elspais.toml` and `.elspais.toml.old` items must have also been resolved during Phase 1 (or they were tracked and committed as part of the deployment-doctor commit). Clean tree confirmed.

## Task complete

All Task 1 verifications green. Ready for Task 2 (spec additions for REQ-d00117, REQ-d00118, REQ-d00119).
