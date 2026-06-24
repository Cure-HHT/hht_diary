# Runbook: Hotfix build + deploy (Phase 1)

Targeted fix to one deployed environment, built from the *recovered* source that
produced that environment's running image — never from `main`. Ungated (Phase 1);
an expedited approval gate wraps the deploy step in Phase 2.

## Preconditions

- The target env's per-env source pointer exists in the sponsor repo
  (`deployment/deployed-source/<env>.json`) and records the core source SHA + image
  digests currently deployed.
- A `baseline/<version>` branch exists in core at (or covering) that source SHA. If
  not, cut one: `tools/release/cut-baseline.sh <version> <recovered-sha> --push`.

## Steps

1. **Recover source.** Read the core SHA from the sponsor pointer:
   `deployment/scripts/source-pointer.sh get <env> core_source_sha`.
2. **Branch + fix (core).** From `baseline/<version>`, create
   `CUR-XXXX-hotfix-<slug>`, commit the targeted fix ONLY (no `main` commits).
3. **Build core image.** Dispatch `build-sponsor-ci.yml` on the hotfix branch
   (`source_ref` = the branch). It publishes `sponsor-ci:sha-<short>` (immutable).
4. **Build + deploy (sponsor).** Run the sponsor `hotfix-deploy.yml` with the target
   env + the `sponsor-ci` digest. It builds `portal-final`, deploys to the env's GCP
   project via `deploy-cloud-run-service-callisto.yml`, and bumps the pointer.
5. **Forward-port.** Run `tools/release/forward-port-notice.sh <fix-sha>
   baseline/<version> --linear` to record the obligation (it prints the exact
   cherry-pick commands and files a Linear ticket). Then YOU do the cherry-picks in a
   fresh worktree and open the two SEPARATE PRs (onto `main` and onto the baseline).
   The script never cherry-picks for you. Definition-of-done (Constraint C3).

## Notes

- Resolver + mobile are global artifacts; this runbook covers the per-sponsor
  portal/backend only.
- Phase 1 has no approval gate — deploy is operator-invoked. Do not skip the
  forward-port (Constraint C3).
