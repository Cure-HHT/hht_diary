# *Sponsor* Branding — Implementation Requirements

*Sponsor* branding — the *Diary*'s title and logo — is owned by the portal as event-sourced configuration and carried to the *Diary* as a content-addressed asset manifest. These DEV requirements record how the portal sources and serves branding on its tamper-evident log, and how the *Diary* caches the referenced asset bytes durably on-device so the brand survives offline and outlasts participation.

## DIARY-DEV-sponsor-branding-source: Event-sourced sponsor branding source

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-settings-store

### Overview

The portal owns *Sponsor* branding as event-sourced data — a title together with an asset manifest in which each asset is referenced by URI and content hash rather than by its image bytes — recorded on the same append-only, tamper-evident log as the rest of the portal's configuration. Branding is seeded idempotently at boot from the content the *Sponsor* deployment provisions, materialized into a current branding manifest, and served to the *Diary* over a credential-gated asset endpoint. This mirrors the configuration-as-events pattern of its parent so branding is attributable, reconstructible, and ready for future admin-authored edits, while the asset blobs stay outside the log behind hash-and-pointer references.

### Assertions

A. The portal SHALL record *Sponsor* branding metadata (title and asset manifest) as events.

B. The portal SHALL reference each branding asset by URI and content hash, and SHALL NOT store asset image bytes in the event log.

C. The portal SHALL seed *Sponsor* branding at startup from the *Sponsor* deployment's provisioned content.

D. The portal SHALL emit a new branding event at seed only when the provisioned content differs from the materialized branding state.

E. The portal SHALL serve a *Sponsor* branding asset only to a request bearing a valid *Patient* *Session* credential, and SHALL reject an unauthenticated request.

F. The portal SHALL respond not-available when the requested branding asset is absent from the materialized branding manifest.

G. The portal SHALL resolve a branding asset request only against the materialized branding manifest, never against a filesystem path taken from request input.

### Rationale

Recording branding as events rather than reading a file at request time keeps every branding change attributable and reconstructible from the same tamper-evident chain as the rest of the portal's configuration, and positions branding for future admin-authored edits without inventing a second source of truth. Image bytes do not belong in the log: a hash-and-pointer reference keeps the append-only chain small and replayable while still pinning the exact asset content, and the content hash lets a consumer verify the bytes it later fetches. Seeding idempotently at boot — emitting a new event only when the provisioned content differs from the materialized state — lets a deployment's provisioned branding take effect on first boot without re-appending an identical seed on every restart. Gating the asset endpoint on a valid *Patient* *Session* credential keeps the asset API non-public, and resolving every request against the materialized manifest (never a filesystem path drawn from request input) closes the path-traversal surface that a file-serving endpoint would otherwise expose.

*End* *Event-sourced sponsor branding source* | **Hash**: f3651a26

## DIARY-DEV-sponsor-branding-assets: Durable on-device branding assets

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-offline-first

### Overview

The *Diary* keeps branding assets on-device in a content-addressed local cache so the *Sponsor* logo is available offline and retained for posterity after participation ends. Because the asset bytes live outside the event log — the log carries only the URI-and-hash reference — the *Diary* fetches the bytes once per content hash and verifies them against that hash, treating a verification failure as a failed fetch that falls back to the app default brand. While the content hash is unchanged the cached bytes are served without re-fetching, and the branding settings and cached assets are retained after participation ends.

### Assertions

A. The *Diary* SHALL cache branding asset bytes locally keyed by content hash, fetching the bytes at most once per hash.

B. The *Diary* SHALL verify fetched branding bytes against the expected content hash, and SHALL treat a mismatch as a failed fetch that falls back to the app default brand.

C. The *Diary* SHALL serve branding assets from the local cache without re-fetching while the content hash is unchanged.

D. The *Diary* SHALL retain branding settings and cached branding assets after participation ends.

### Rationale

A *Sponsor* logo that had to be re-fetched on every render would be blank whenever the device is offline — exactly the condition the *Offline-First* parent exists to defend against — so the *Diary* caches the bytes on-device and serves them from the cache while the content hash is unchanged. Keying the cache by content hash makes the fetch idempotent (at most once per hash) and gives a natural cache-invalidation signal: a new hash means new bytes, an unchanged hash means the cached bytes still stand. Because the asset bytes travel outside the tamper-evident log, integrity cannot be assumed; verifying fetched bytes against the expected hash and falling back to the app default brand on mismatch keeps a corrupted or substituted asset from ever being displayed. Retaining the branding settings and cached assets after participation ends preserves the brand for posterity, consistent with the *Diary*'s personal-record lifetime that outlasts the clinical *Trial*.

*End* *Durable on-device branding assets* | **Hash**: 5689e3e7
