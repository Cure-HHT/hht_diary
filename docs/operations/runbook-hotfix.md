# Runbook: Hotfix build + deploy (Phase 1)

Targeted fix to one deployed environment, built from the *recovered* source that
produced that environment's running image — never from `main`. Ungated (Phase 1);
an expedited approval gate wraps the deploy step in Phase 2.

## Preconditions

- The target env's per-env source pointer exists in the sponsor repo at
  `deployment/deployed-source/<env>.json` and records the core source SHA + image
  digests currently deployed.
- A `baseline/<version>` branch exists in core at (or covering) that source SHA. If
  not, cut one: `tools/release/cut-baseline.sh <version> <recovered-sha> --push`.

## Steps

Steps 1–3 are shared regardless of which deploy path you take. After building,
choose the **Quick path** (recommended) or the **Manual / break-glass path**.

1. **Recover source.** Read the core SHA from the sponsor repo's source pointer:
   `deployment/scripts/source-pointer.sh get <env> core_source_sha`
   (run this script from the sponsor repo).
2. **Branch + fix (core).** From `baseline/<version>`, create
   `CUR-XXXX-hotfix-<slug>`, commit the targeted fix ONLY (no `main` commits).
3. **Build core images.** Dispatch `build-sponsor-ci.yml` on the hotfix branch
   (`source_ref` = the branch). It runs two phases:
   - **Phase A** publishes `sponsor-ci:sha-<short>` (the immutable source+deps image).
   - **Phase B** builds and pushes the portal-server binary, also tagged
     `portal-server:sha-<short>` and `portal-server:<short>`.

### Quick path (recommended)

**Precondition:** the core build for the ref must exist in GHCR (step 3 above).
The wrapper resolves digests from the published images — it does NOT build; if the
images are absent, the workflow fails immediately with a message to run
`build-sponsor-ci.yml` first.

4. **Deploy via wrapper (sponsor).** In the sponsor repo, run `hotfix.yml` with
   two inputs:

   | Input | Value |
   |---|---|
   | `target-env` | The environment to update (`dev`, `qa`, or `uat`) |
   | `core-ref` | The hotfix branch, tag, or SHA (e.g. `CUR-XXXX-hotfix-<slug>`) |

   The wrapper resolves the ref's HEAD to a short SHA, looks up the published
   `ghcr.io/cure-hht/sponsor-ci:sha-<short>` and
   `ghcr.io/cure-hht/portal-server:sha-<short>` digests, then calls
   `hotfix-deploy.yml` automatically. It builds `portal-final`, deploys to the
   env's GCP project, and bumps the source pointer at
   `deployment/deployed-source/<env>.json` in the sponsor repo.

   Via GitHub Actions UI: **Actions → hotfix → Run workflow**, set the two inputs.
   Via CLI: `gh workflow run hotfix.yml -f target-env=<env> -f core-ref=<ref>`
   (run from the sponsor repo).

5. **Forward-port.** Run `tools/release/forward-port-notice.sh <fix-sha>
   baseline/<version> --linear` to record the obligation (it prints the exact
   cherry-pick commands and files a Linear ticket). Then YOU do the cherry-picks in a
   fresh worktree and open the two SEPARATE PRs (onto `main` and onto the baseline).
   The script never cherry-picks for you. Definition-of-done
   (`DIARY-OPS-hotfix-source-recovery/C`).

### Manual / break-glass path

Use this when you need to pin exact image digests explicitly (e.g. to deploy a
previously-built image that is not the HEAD of the ref, or to bypass digest
resolution when troubleshooting).

After step 3 completes, capture **both** image digests from the run summary or
from the workflow step outputs:

- `sponsor-ci` digest (Phase A "Build and push sponsor-ci image" step output)
- `portal-server` digest (Phase B "Build and push portal-server" step output)

4. **Deploy with explicit digests (sponsor).** In the sponsor repo, run
   `hotfix-deploy.yml` with all five required inputs:

   | Input | Value |
   |---|---|
   | `target-env` | The environment to update (e.g. `dev`, `qa`, `uat`) |
   | `core-source-sha` | Full SHA of the core hotfix commit |
   | `core-source-ref` | The hotfix branch name (e.g. `CUR-XXXX-hotfix-<slug>`) |
   | `sponsor-ci-image` | `ghcr.io/cure-hht/sponsor-ci@sha256:<phase-A-digest>` |
   | `portal-server-image` | `ghcr.io/cure-hht/portal-server@sha256:<phase-B-digest>` |

   The sponsor workflow builds `portal-final`, deploys to the env's GCP project
   via the sponsor's Cloud Run deploy workflow, and bumps the source pointer at
   `deployment/deployed-source/<env>.json` in the sponsor repo.

5. **Forward-port.** Same as Quick path step 5 above.

## Notes

- Resolver + mobile are global artifacts; this runbook covers the per-sponsor
  portal/backend only.
- Phase 1 has no approval gate — deploy is operator-invoked. Do not skip the
  forward-port (`DIARY-OPS-hotfix-source-recovery/C`).
- All paths under `deployment/` referenced above (source pointer, scripts,
  `hotfix-deploy.yml`) live in the **sponsor repo**, not in the core `hht_diary`
  repo.
