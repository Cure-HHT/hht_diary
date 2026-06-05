# Portal Settings Store — Implementation Requirements

## DIARY-DEV-portal-settings-store: Event-sourced portal configuration

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-reaction-server

### Overview

The portal records its own configuration as events on the same append-only, tamper-evident log as every other portal *Action*, rather than reading mutable values from a side table or an unaudited environment flag at request time. A `portal_setting_changed` event records the value of a single setting key, a `portal_settings` projection materializes the current value per key by folding the latest event, and initial values are seeded idempotently at boot from deployment configuration when the key has no recorded value. This is the first realization of the configuration-as-events pattern; later operator-facing settings reuse the same store.

### Assertions

A. The portal SHALL record a setting value as a `portal_setting_changed` event on the `portal_setting` aggregate keyed by the setting key (`aggregateId` = key); the latest event for a given key SHALL be authoritative for that setting.

B. The portal SHALL materialize a `portal_settings` projection that folds the latest `portal_setting_changed` value per key into the current value, and SHALL register it when opening its *Event Store* so reads resolve a setting within the dispatch transaction.

C. When a setting key has no materialized value, the portal SHALL seed an initial value idempotently at boot from deployment configuration — emitting a `portal_setting_changed` event only when the projection holds no value for that key — so a configured initial value takes effect on first boot and is not re-appended on subsequent restarts.

### Rationale

Treating portal configuration as events keeps every setting change attributable and reconstructible from the same tamper-evident chain as the rest of the portal's state, rather than splitting authoritative configuration into an unaudited table or a process environment flag that leaves no record of who changed it or when. Latest-event-per-key is the minimal authoritative fold: a setting's current value is simply its most recent recorded change, so the projection needs no schema beyond key and value. Registering the projection at *Event Store* open time lets a setting be read inside the same transaction that dispatches an *Action*, so an *Action* that depends on a setting sees a consistent value. Seeding from deployment configuration solves the pre-login bootstrap — a setting that gates the login flow must have a value before anyone has logged in to set one — while the idempotent gate (seed only when no value is recorded) keeps a durable store from accumulating a duplicate seed event on every restart and lets an in-environment change made later stand rather than being overwritten by the boot seed.

*End* *Event-sourced portal configuration* | **Hash**: 3ae46122

---

## DIARY-DEV-portal-test-account-provisioning: Dev/test seed-account self-provisioning

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-settings-store

### Overview

When a deployment sets `PORTAL_DEV_SEED_PASSWORD`, the portal boot sequence idempotently provisions an Identity Platform account for each seed-user email and stamps an active `users_index` row carrying the resulting `firebase_uid`. This makes seed accounts immediately login-capable under real session authentication without requiring an activation magic-link — a link that cannot be redeemed on dev because it is normally sent to a real inbox. The step is purely additive: it emits the same `user_created`/`user_activated` events that the normal activation flow would emit, so the rest of the system sees no difference. The env guard ensures non-dev/prod deployments are unaffected even if the code path is always compiled in.

### Assertions

A. When `PORTAL_DEV_SEED_PASSWORD` is set at boot, the portal SHALL idempotently provision an Identity Platform account (via `IdentityAdmin.lookupOrProvisionByEmail`) for each seed-user entry whose `userId` is a valid email address, and SHALL emit a `user_activated` event carrying the resulting `firebase_uid` so the `users_index` projection marks the account `status: active` — making the account login-capable without a magic-link activation. A provisioning failure for one email SHALL be logged to stderr and SHALL NOT abort boot or affect other emails.

B. The provisioning step SHALL be guarded by the `PORTAL_DEV_SEED_PASSWORD` environment variable: when the variable is absent or empty the step SHALL be a no-op so non-dev/production deployments that never set this variable are unaffected. Entries whose `userId` does not contain `@` SHALL be silently skipped.

### Rationale

Dev deployments that use real Identity Platform *Session* auth (PORTAL_AUTH_MODE=*Session*) require seed accounts to have both an IdP record and an active portal *User* row before anyone can log in. The normal flow — admin creates *User*, system emails an activation link, *User* clicks it and sets a *Password* — requires a live inbox the dev environment does not have. Provisioning declaratively at boot, guarded by a dev-only env variable, collapses the three-step flow to a single deployment config, leaves the activation path intact for all other environments, and keeps the code path always compiled in (so it is exercised by CI) while remaining inert in production.

*End* *Dev/test seed-account self-provisioning* | **Hash**: 05b08471
