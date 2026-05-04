# Phase 3 Task 8: Phase-boundary squash

**Date:** 2026-04-22
**Owner:** Claude (Opus 4.7) on user direction
**Status:** LOCAL SQUASH COMPLETE — awaiting user decision on force-push + phase-review request

## Rebase

`git fetch origin main` → main still at `5f430f7b` (no movement during Phase 3). No rebase needed.

## Pre-squash Phase 3 commits (6 granular)

```
9d5a4b2a [CUR-1154] Bump append_only_datastore for Phase 3
9eb70e30 [CUR-1154] Export materialization public surface
45afac39 [CUR-1154] Implement rebuildMaterializedView
2fa0bec2 [CUR-1154] Implement Materializer.apply
06684a32 [CUR-1154] Add EntryTypeDefinitionLookup interface
434878ef [CUR-1154] Add materializer contract assertions
```

## Squash procedure used

Instead of `git rebase -i origin/main` (which requires an interactive editor session), used `git reset --soft 508df506` (Phase 2's head) followed by a single `git commit` with the curated Phase 3 message. This produces the same result — all Phase 3 working-tree changes are committed as one — without opening an interactive rebase buffer. Phases 1 and 2 squashed commits are preserved unchanged.

## Post-squash state

```
4aa802e8 [CUR-1154] Phase 3: Add materializer and rebuild helper
508df506 [CUR-1154] Phase 2: StorageBackend abstraction and SembastBackend
c9fcb8d1 [CUR-1154] Phase 1: Add provenance package and EntryTypeDefinition
c974495c [CUR-1154] Fix deployment-doctor counters for Linux set -e compat
b202b05c [CUR-1154] Add design doc and 5-phase implementation plan
5f430f7b [CUR-1118] ...  (main)
```

## Full verification post-squash

| Package | Tests | Analyze |
| --- | --- | --- |
| `apps/common-dart/append_only_datastore` | 204/204 PASS | No issues found |
| `apps/daily-diary/clinical_diary` | 1098/1098 PASS (1 skipped, pre-existing) | No issues found |

## Not yet done (awaits user confirmation)

- **`git push --force-with-lease`** — this is a visible, shared-state action that the controller CLAUDE.md policy requires user confirmation for. The branch has diverged from `origin/mobile-event-sourcing-refactor` (2 local squashed commits vs 19 remote pre-squash commits), so a force-push is the expected finalization step. Waiting on user OK.
- **PR comment** — posting "Phase 3 ready for review — commit `<HEAD>`" (use the actual SHA of the Phase 3 squashed commit at push time, from `git log --oneline origin/main..HEAD | grep 'Phase 3'`) to the draft PR. Also user-triggered.

## Review focus for reviewer

1. `Materializer.apply` correctness across the three event types (finalized / checkpoint / tombstone), especially tombstone preserving prior `currentAnswers` and `isComplete` while flipping `isDeleted` and advancing `latestEventId` / `updatedAt`.
2. `effective_date_path` dotted-path resolution and the three fallback paths (null path, unresolved path, unparseable resolved value).
3. `rebuildMaterializedView` idempotence and garbage removal.
4. `clearEntries` addition to the StorageBackend contract — legitimate extension or premature?
5. Unwired materializer — no call site in production code yet; Phase 5 will wire it into `EntryService.record`.

## Phase-completion SHA (Phase 3)

Whatever SHA `git log --oneline origin/main..HEAD` reports for the
`[CUR-1154] Phase 3: Add materializer and rebuild helper` commit at the
time of review. Intentionally not pinned in this doc: every fixup amend
to the phase-squash commit (including folding this task file in) changes
the SHA, so a literal value here would go stale immediately.
