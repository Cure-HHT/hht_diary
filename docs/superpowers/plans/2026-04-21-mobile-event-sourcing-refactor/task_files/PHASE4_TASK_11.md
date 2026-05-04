# PHASE 4 TASK 11 — Phase-boundary squash + request phase review

## What landed

Local squash + force-push + PR comment.

### Phase 4 squashed commit

- SHA: `f81a20f1`
- Subject: `[CUR-1154] Phase 4: Add Destination, FIFO drain, and sync_cycle`
- Body covers the new public surface and the Phase-2 Prereq A+B resolutions folded in.

### Incidental fix on top

- SHA: `340ac8dc`
- Subject: `[CUR-1154] Incidental: pre-push hook unsets ELSPAIS_VERSION before elspais checks`
- Reason: `versions.env` exports `ELSPAIS_VERSION=0.112.13` for the hook's CLI-version-compare step, but elspais's own `ELSPAIS_*` env-var override convention reads it as a `version=4` toml override, causing `elspais checks` to fail with `invalid literal for int(): '0.112.13'`. The hook now unsets `ELSPAIS_VERSION` between the compare step and the checks call.

Kept as a separate "Incidental" commit rather than folding into the Phase-4 squash — it is infrastructure, not Phase-4 scope. Precedent from `00516da2 [CUR-1154] Incidental fixes...` earlier on the same branch.

### Remote branch state (post-push)

```
340ac8dc [CUR-1154] Incidental: pre-push hook unsets ELSPAIS_VERSION before elspais checks
f81a20f1 [CUR-1154] Phase 4: Add Destination, FIFO drain, and sync_cycle
73934aae [CUR-1154] Phase 3: Add materializer and rebuild helper
eb64385b [CUR-1154] Phase 2: StorageBackend abstraction and SembastBackend
5db0dbce [CUR-1154] Phase 1: Add provenance package and EntryTypeDefinition
bc054ff9 [CUR-1154] Add design doc and 5-phase implementation plan
00516da2 [CUR-1154] Incidental fixes: deployment-doctor, .elspais.toml v4, pre-push gh-auth
```

### PR comment

Posted to PR #511: https://github.com/Cure-HHT/hht_diary/pull/511#issuecomment-4299551306

### Verification (pre-push full suite)

- `elspais checks`: HEALTHY 31/31 passed.
- `flutter analyze` in `append_only_datastore`: No issues.
- `flutter analyze` in `clinical_diary`: No issues.
- `flutter test` in `append_only_datastore`: 298 passed.
- `flutter test` in `clinical_diary`: Full suite passed via hook.
- `gitleaks`: No leaks found.
- `markdownlint`: Passed.

### Push blockers encountered

1. **`GITHUB_TOKEN` env var stale** — the keyring has a valid token but `gh` prefers the env var. Worked around by unsetting `GITHUB_TOKEN` in the push subshell. (Same pattern noted in `00516da2`; not yet fixed in the hook itself — the hook diagnostic now fires but the env var is still used.)
2. **`ELSPAIS_VERSION` env var leak** — described above; fixed in `340ac8dc`.

## Awaiting phase review

Record Phase-4 phase-completion SHA here after reviewer sign-off:

- [ ] Phase-4 review completed at SHA: _(fill in after review)_
