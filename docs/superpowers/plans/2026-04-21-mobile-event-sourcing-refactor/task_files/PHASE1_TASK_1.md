# Phase 1 Task 1: Baseline verification, commit planning docs, open draft PR

**Date:** 2026-04-21
**Owner:** Claude (Opus 4.7) on user direction
**Status:** COMPLETE

## Branch state at start

- Worktree: `/home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/`
- Branch: `mobile-event-sourcing-refactor` (was already checked out; no `git checkout -b` needed)
- HEAD at start: `5f430f7b [CUR-1118] Preserve portal session on browser refresh (#488)`

## Pre-existing uncommitted state (triaged)

Before Phase 1 work began, the worktree had four categories of uncommitted changes:

| Path | Status | Disposition |
| --- | --- | --- |
| `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` | untracked | CUR-1154 design doc — committed |
| `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/*` | untracked | CUR-1154 plan directory — committed |
| `.elspais.toml` | modified | elspais MCP schema bump v3→v4 (user's MCP debugging) — LEFT in working tree |
| `.elspais.toml.old` | untracked | 223-line backup of the v3 config — LEFT in working tree |
| `apps/sponsor-portal/tool/deployment-doctor.sh` | modified | bash `((VAR++))` → `: $((VAR+=1))` counter fix (unrelated to CUR-1154) — LEFT in working tree |

Only the two CUR-1154 paths were staged. The three unrelated items remain uncommitted on the working tree.

## Baseline test results (on branch HEAD before planning commit)

| Command | Result |
| --- | --- |
| `(cd apps/common-dart/trial_data_types && dart test)` | PASS — 34 tests |
| `(cd apps/common-dart/append_only_datastore && flutter test)` | PASS — 90 tests |
| `(cd apps/daily-diary/clinical_diary && flutter test)` | PASS — 1098 tests (1 skipped, pre-existing) |
| `(cd apps/daily-diary/clinical_diary && flutter analyze)` | PASS — No issues found |

## Planning commit

- SHA: `b202b05c` on `mobile-event-sourcing-refactor`
- Subject: `[CUR-1154] Add design doc and 5-phase implementation plan`
- 7 files added, 2616 insertions
- Pre-commit hook (markdown lint) passed

## Push result

- Branch pushed to `origin/mobile-event-sourcing-refactor` — new branch on remote.
- Pre-push validation: WARNINGS-ONLY (branch has no open PR, so errors downgrade to warnings). Warnings:
  - elspais config parse error: `Failed to parse config file .elspais.toml: invalid literal for int() with base 10: '0.112.13'`. Source: the working-tree `.elspais.toml` (user's in-progress MCP debugging) — does not affect push of docs changes.
  - Secret detection: clean (1397 commits scanned, no leaks).
  - Markdown lint: pass.
- Remote PR-create URL: https://github.com/Cure-HHT/hht_diary/pull/new/mobile-event-sourcing-refactor

## gh auth resolution

`GITHUB_TOKEN` env var was stale (likely Doppler-injected and expired). Resolved by invoking `gh` with `env -u GITHUB_TOKEN gh ...` so gh falls back to the keyring-stored `faisyrs` account. This pattern is used for all subsequent `gh` calls in this ticket.

## Repo merge settings (captured via `gh repo view`)

```json
{"mergeCommitAllowed":false,"rebaseMergeAllowed":false,"squashMergeAllowed":true}
```

Observation: `rebaseMergeAllowed` is `false`. The user needs to enable it before Phase 5 Task 21's final merge, otherwise the fallback is squash-merge (which collapses the 6 curated commits into 1, losing the per-phase bisect granularity). Flagged in PR body and in Phase 5 Task 21.

## Draft PR

- URL: https://github.com/Cure-HHT/hht_diary/pull/511
- Number: 511
- Title: `[CUR-1154] Mobile event-sourcing refactor`
- Status: draft
- Body: links design doc, the 5 phase plan files, review cadence, merge strategy, test plan
- Warning from `gh pr create`: "4 uncommitted changes" (the unrelated `.elspais.toml`, `.elspais.toml.old`, `deployment-doctor.sh` items that remain in the working tree). Expected.

## Task complete

All Task 1 steps done. Ready for Task 2 (`spec/dev-event-sourcing-mobile.md` with REQ-d00115 and REQ-d00116).
