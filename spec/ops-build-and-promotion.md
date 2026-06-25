# DIARY-OPS-single-promotable-artifact: Single Promotable Artifact

**Level**: OPS | **Status**: Draft | **Implements**: -

## Assertions

A. Server components SHALL be built as a single container image whose environment-specific behavior derives exclusively from runtime environment variables, with no environment identity baked into the image.

B. The portal web UI SHALL be built as a single artifact whose environment-specific configuration is obtained at runtime, with no environment identity compiled into the bundle.

C. The *Mobile Application* SHALL be produced from a single, environment-independent compilation; per-environment mobile packages SHALL differ only by the bundled environment pointer, the application/bundle identifier, the code-signing identity, per-environment native service configuration (e.g. `google-services.json`), and platform launcher metadata (e.g. app name resource).

D. Before release, the set of differences between any two mobile environment packages SHALL be recorded in a controlled delta record that enumerates each difference and asserts no others exist.

## Rationale

The platform validates artifacts. A single promoted artifact gives one traceable identity from test evidence to release. Servers and the web portal achieve this literally (environment at runtime). Mobile cannot, because the app stores re-sign and re-wrap every upload and the environment pointer is bundled at packaging; the proportionate substitute is a single environment-independent compilation whose per-package delta is small, enumerable, and risk-assessed (D).

### Risks

- **R1 — uat/prod packages not byte-identical.** Validation transfers by documented delta, not artifact identity. Mitigation: the delta is restricted to {env pointer, bundle id, signing, native service config (e.g. `google-services.json`), launcher metadata} (assertion C) and holds by construction because both come from one compilation; the controlled delta record (assertion D) is reviewed each release.
- **R2 — store re-signing/re-wrapping.** Play App Signing and Apple FairPlay mean installed bytes differ from the uploaded artifact regardless. Mitigation: documented as platform behavior; integrity assured by the store signing chain and the server's zero-trust boundary.
- **R3 — prod package repointed to a non-prod backend.** Mitigation: the env pointer is bundled inside the signed package; changing it requires re-signing (tampering), outside validation scope; server authorization independently rejects cross-environment credentials.
- **R4 — prod binary contains gated dev/dangerous code paths.** Mitigation: runtime gate (`DIARY-DEV-runtime-environment-resolution` assertion D), validated once; reaching disabled affordances requires tampering; a tampered client can do nothing the server does not authorize.

*End* *Single Promotable Artifact* | **Hash**: cbc3c5c0

# DIARY-OPS-deploy-traffic-gating: Canary Traffic-Gating for Deploys

**Level**: OPS | **Status**: Draft | **Implements**: -

## Assertions

A. The deploy workflow SHALL publish each new revision with no live traffic and a revision tag, so the revision is reachable for verification while the prior revision continues to serve all traffic.

B. The deploy workflow SHALL run its post-deploy verification checks against the no-traffic tagged revision before any traffic is shifted to it.

C. The deploy workflow SHALL migrate all traffic to the new revision only after every verification check passes.

D. When a verification check fails, the deploy workflow SHALL terminate the run with the prior revision still receiving all traffic.

E. The deploy workflow SHALL reject any image reference that is not pinned to an immutable content digest (an `@sha256:` digest), accepting digest-pinned references only and rejecting mutable tags.

## Rationale

A container platform's default startup probe confirms only that the container accepts connections on its port, so a revision that starts but is functionally broken — for example one whose runtime secret injection failed, returning an error on login while a shallow health endpoint still returns success — can receive all traffic before any functional check runs. Publishing the revision with no traffic, verifying it at its tagged address, and shifting traffic only after verification passes closes that window without a reactive revert: traffic never reaches an unverified revision, so a failed verification leaves the prior revision serving. Reverting a revision is therefore an ordinary redeploy of the prior immutable image through the same gate; recovery of the underlying datastore is a separate concern owned by the platform's data backup and archival requirement.

*End* *Canary Traffic-Gating for Deploys* | **Hash**: e510bb08
