# Portal Web Client Lifecycle — Implementation Requirements

## DIARY-DEV-portal-legacy-sw-eviction: Legacy service-worker eviction + reload-loop guard

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-portal-stale-client-reload

### Overview

The portal web build ships no service worker (`--pwa-strategy=none`), and nginx serves the entry bundle with `no-cache` revalidation so a normal reload suffices to pick up a deploy. A service worker registered by an *earlier* build generation, however, persists in the browser and keeps intercepting fetches from its own precache — bypassing nginx — until it is explicitly removed. This is the root cause of the "must hard-reset to pick up a deploy" symptom, and it also means an automatic reload could return a still-stale bundle.

### Assertions

A. On web application start, the portal SHALL enumerate and unregister all registered service workers, guarded so a browser without service-worker support is a no-op and a browser with none registered is a no-op.

B. The portal SHALL attempt an automatic reload at most once per browser *Session* for a persistent version mismatch, falling back to the non-blocking reload banner if the reloaded bundle is still stale.

### Rationale

Unregistering on every boot is idempotent and cheap, and removes the interceptor at its root so subsequent deploys need only a normal reload. The once-per-*Session* guard exists because automatic reload (the login-screen path of `DIARY-BASE-portal-stale-client-reload`) could otherwise loop forever in the exact scenario this requirement addresses: a legacy worker that survives the reload would keep serving the old bundle while the network reports a new one. Bounding the automatic attempt and degrading to the manual banner converts an unusable reload loop into a single recoverable prompt.

*End* *Legacy service-worker eviction + reload-loop guard* | **Hash**: bb48c254
