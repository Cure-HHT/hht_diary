# DIARY-OPS-build-deploy-primitives: Build and deploy are orthogonal operations

**Level**: OPS | **Status**: Draft | **Implements**: -

## Assertions

A. `build` SHALL map a single source commit (git SHA) to a single image; the
   resulting image SHALL NOT encode environment or *Sponsor* identity.

B. `deploy` SHALL send an already-built image to a target GCP project and SHALL NOT
   rebuild from, or otherwise mutate, source.

## Rationale

Refines `DIARY-OPS-single-promotable-artifact`. Separating the act that consumes
source (`build`) from the act that places an artifact (`deploy`) is what lets a
hotfix rebuild a *recovered* source state without entangling environment identity.
Image promotion (copy-image + config tweak across envs) is a third primitive,
deferred; it is intentionally NOT asserted here.

*End* *Build and deploy are orthogonal operations* | **Hash**: 1946fd49

---

# DIARY-OPS-environment-as-deployment: An environment is a deployment target

**Level**: OPS | **Status**: Draft | **Implements**: -

## Assertions

A. Source and built images SHALL NOT encode environment or *Sponsor* identity; the
   environment an artifact runs in SHALL be determined at deploy/runtime only.

## Rationale

An environment is distinguished only by *where* an artifact is placed and *who*
authorizes that placement, never by a property baked into source or image. The
deploy-authority dimension (who may place what) is deferred to Phase 2; Phase 1
asserts only the no-identity-in-artifact invariant.

*End* *An environment is a deployment target* | **Hash**: 5339fe94

---

# DIARY-OPS-hotfix-source-recovery: A hotfix builds from the recovered per-env source

**Level**: OPS | **Status**: Draft | **Implements**: -

## Assertions

A. The build source for a hotfix SHALL be the source commit recorded for the target
   environment (the per-env source pointer), not a release tip or `main`.

B. Unreleased `main` commits SHALL NOT enter a hotfix build.

C. A hotfix fix SHALL be forward-ported to `main` and to its baseline branch.

## Rationale

A targeted fix to a deployed environment must build the exact source that produced
that environment's running artifact plus the fix only. The per-env pointer lives in
the sponsor's private repo (core stays sponsor-neutral). Forward-port discipline
prevents the fix from regressing on the next normal build.

*End* *A hotfix builds from the recovered per-env source* | **Hash**: 6bc656c0

---

# DIARY-OPS-neutral-baseline-branch: Sponsor-neutral, version-keyed baseline branches

**Level**: OPS | **Status**: Draft | **Implements**: -

## Assertions

A. Baseline branches SHALL be keyed by version/date (e.g. `baseline/2026-06`) and
   SHALL NOT contain any *Sponsor* name or sponsor-specific identifier.

B. A hotfix SHALL branch from a baseline commit and merge/forward-port back to that
   same baseline branch.

## Rationale

Baseline branches are the long-lived, sponsor-neutral lines that accumulate hotfixes
for whoever froze at that rollout point and provide a stable forward-port reference.
Keying them by date/version (never by *Sponsor*) preserves core sponsor-neutrality.

*End* *Sponsor-neutral, version-keyed baseline branches* | **Hash**: 26c7247f
