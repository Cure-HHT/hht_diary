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
