# DIARY-DEV-runtime-environment-resolution: Runtime Environment Resolution

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-OPS-single-promotable-artifact

## Assertions

A. The mobile and portal applications SHALL resolve the active environment at runtime rather than from a compile-time constant: the *Mobile Application* from a bundled environment pointer asset, and the portal from configuration the server provides over the same origin.

B. When the active environment cannot be determined — the mobile environment pointer is absent or unreadable, or the server provides no environment value — the application SHALL resolve to the dev environment.

C. Backend endpoint, application title, environment banner, developer-tools availability, and reset-data availability SHALL be derived from the resolved environment at runtime.

D. In the prod environment, the application SHALL disable developer tools, the reset-all-data affordance, the environment banner, and any affordance that fabricates, bulk-injects, or exports *Diary* records.

E. The mobile environment pointer SHALL be carried such that changing it does not invalidate the application's compiled output.

## Rationale

Moving the environment from a compile-time constant to a runtime-resolved bundled pointer is what allows one compilation to serve every environment (E) and lets all environment-dependent behavior follow a single source of truth (A, C). The dev default (B) makes any unspecified build safe. The prod gate (D) replaces flavor-based compile-time exclusion with one small, validatable runtime control.

*End* *Runtime Environment Resolution* | **Hash**: b0c74776
