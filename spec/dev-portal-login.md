# Portal Login + *Second Factor* + *Session* — Implementation Requirements

## DIARY-DEV-portal-login-identity-verification: Login identity verification

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-two-factor-authentication

### Overview

The portal authenticates the first login factor by verifying an Identity Platform ID token that the client obtains and presents. The client-obtains-token model keeps the interactive identity step (*Password* today, federated sign-in later) on the client while the portal uniformly verifies the resulting token. Verification selects an emulator path in non-production and a production path that checks the token signature against the issuer's published keys, then resolves the verified token to a portal *User Account* by the recorded Identity Platform identifier.

### Assertions

A. The portal SHALL authenticate the first factor by verifying an Identity Platform ID token supplied by the client, selecting the emulator or production verification path by environment.

B. The portal SHALL resolve the verified token to a portal *User Account* by the recorded Identity Platform identifier, and SHALL reject a token that resolves to no active *User Account*.

### Rationale

Verifying a client-supplied ID token rather than accepting a *Password* over a bespoke endpoint is what keeps the design open to federated sign-in: every method the Identity Platform supports reduces to the same token the portal already knows how to verify. Selecting the verification path by environment lets development run against the emulator while production checks real signatures, so the path exercised in test is the path that ships. Resolving by the immutable Identity Platform identifier — recorded once at activation — rather than by a mutable address closes the account-takeover vector that a re-bindable email key would open, and rejecting a token that maps to no active account keeps a verified-but-unknown identity from gaining any foothold.

*End* *Login identity verification* | **Hash**: 4b3d6032

## DIARY-DEV-portal-login-second-factor: Login second factor

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-two-factor-authentication

### Overview

After the first factor is verified the portal runs a *Second Factor* before granting access. For *Password* sign-in the portal issues a single-use, time-limited email *Verification Code*, held only as a one-way hash in an ephemeral store and never in the event log. The second-factor mechanism is selected per sign-in method so a federated sign-in can carry its own factor instead of the portal's email code.

### Assertions

A. After first-factor verification the portal SHALL issue a single-use, time-limited *Verification Code* to the email of the *User Account*, held only as a one-way hash in an ephemeral store and never written to the append-only event log.

B. The portal SHALL grant access only after the *Verification Code* is validated, and SHALL reject the code once it is used, once it is expired, or after a bounded number of failed attempts, requiring the login to restart.

C. The portal SHALL select the second-factor mechanism per sign-in method, so a federated sign-in can carry its own factor instead of the portal's email code.

### Rationale

The *Second Factor* breaks the single-credential failure mode: a leaked or phished *Password* is not enough without possession of the registered email. The *Verification Code* is single-use and time-limited because a code that survived either property would inherit the replay weakness the *Second Factor* exists to remove, and the attempt cap bounds online guessing. The code is a transient secret with no audit value once spent, so it lives in an ephemeral side store, never the tamper-evident log. Selecting the mechanism per method keeps the portal's email code from being hardwired onto sign-in methods that already carry a stronger factor of their own.

*End* *Login second factor* | **Hash**: 9c1195e5

## DIARY-DEV-portal-second-factor-toggle: Conditional second factor

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-login-second-factor

### Overview

Whether the *Second Factor* runs is governed by the `require_second_factor` portal setting, read from the event-sourced setting store at sign-in. When the setting is explicitly disabled the portal completes a verified first-factor login by minting a *Session* token directly, issuing no email *Verification Code*; when the setting is absent or enabled the email *Second Factor* runs unchanged. Disabling is fail-safe by construction — only an explicit `false` skips the factor — and a skipped factor is recorded as an attributable *Audit Trail* event so the bypass is never silent.

### Assertions

A. When `require_second_factor` is disabled, a verified first-factor login SHALL mint a *Session* token directly and return it, issuing no email *Verification Code* and requiring no second-factor validation step.

B. When `require_second_factor` is absent or enabled, the portal SHALL require the email *Second Factor*, so an environment that has not explicitly disabled the factor always enforces it (fail-safe default).

C. The login interface SHALL complete sign-in without presenting the *Verification Code* entry screen when the server returns a *Session* token directly in response to the first-factor step.

D. A login that skips the *Second Factor* under a disabled setting SHALL be recorded as an attributable *Audit Trail* event, so the bypass is auditable per affected *User Account*.

### Rationale

Making the *Second Factor* conditional on a recorded setting is what lets a non-production environment run automated tests against the real email/*Password* login without the email round-trip, while production keeps the factor. The default is fail-safe — absent or enabled both require the factor — so the factor can only be skipped by an explicit, recorded `false`, and no missing-configuration path can silently weaken authentication. Minting the *Session* token directly on the verified first factor (rather than short-circuiting the validation of an unissued code) keeps the disabled path a clean omission of the second step rather than a forged success of it. The login interface mirrors the server decision by routing past the *Verification Code* screen only when a token is already returned, so the two ends agree on whether a factor is pending. Recording the skip as an attributable audit event keeps the weakened path visible in the same tamper-evident log as every other login, so a disabled factor is an auditable operational choice rather than an invisible gap.

*End* *Conditional second factor* | **Hash**: d4b853aa

## DIARY-DEV-portal-emulator-bootstrap: Portal client emulator bootstrap

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-runtime-environment-resolution

### Overview

The portal client wires the Identity Platform *Auth* emulator from the runtime identity configuration the server provides over the same origin, before any login surface is presented. On a deployment that reports an emulator host the client first deletes its persisted *Auth* state, then initializes the *Auth* SDK, then connects the emulator — so the SDK has no stored *User* to auto-restore and the emulator connection is never silently dropped. A deployment that reports no emulator host (production) leaves persisted *Auth* state intact and connects no emulator.

### Assertions

A. On a deployment whose runtime identity configuration reports an *Auth* emulator host, the portal client SHALL delete its persisted *Auth* state before initializing the *Auth* SDK and then connect the reported emulator, so the SDK auto-restores no *User* and the emulator connection applies rather than being silently dropped.

B. On a deployment whose runtime identity configuration reports no emulator host, the portal client SHALL NOT delete persisted *Auth* state, leaving a restorable *Session* intact.

C. The portal client SHALL present the login surface only after *Auth* initialization — including the emulator connection when one is reported — completes, and SHALL surface an explicit failure rather than a login that would authenticate against production when initialization fails.

### Rationale

On the web the *Auth* SDK auto-restores any persisted *User* during initialization, which uses the *Auth* instance before the emulator can be connected; the connect is then rejected and silently swallowed, leaving the client pointed at production so every sign-in fails against the non-production dummy key (the intermittent local login that "a reload fixes"). Deleting persisted *Auth* state before initialization removes the *User* there is to restore, so the emulator connects deterministically on every load. The delete is gated on a reported emulator host so a production deployment never wipes a real restorable *Session* — there the server's request rejection remains the staleness gate. Gating the login surface on completed initialization, and failing explicitly rather than falling through, keeps a misconfigured or unreachable emulator from masquerading as a production-pointed login.

*End* *Portal client emulator bootstrap* | **Hash**: 8ce0878f

## DIARY-DEV-portal-session-token: Portal session token

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-session-management

### Overview

On second-factor success the portal establishes a *Session* by appending a *Session*-started event and minting a tamper-evident *Session* token. The token is the portal's own credential: it binds a *Session* identifier to the portal *User Account* and is verified on every request and connection. Its validity is governed by the portal's *Session* state rather than by the lifetime of the Identity Platform token that bootstrapped the login.

### Assertions

A. On second-factor success the portal SHALL establish a *Session* by appending a *Session*-started event and minting a tamper-evident *Session* token that binds a *Session* identifier to the portal *User Account*.

B. The *Session* token SHALL be the portal's own credential whose validity is independent of the Identity Platform token lifetime, and the request validator SHALL verify it on every request and connection.

### Rationale

The portal mints its own *Session* credential because the controls the *Session* requires — *Idle Timeout* and immediate cascade revocation — cannot be imposed on a self-contained Identity Platform token whose lifetime the identity provider owns. Binding only the *Session* identifier and the *User Account* into the token, and resolving everything else from *Session* state, keeps the token a stable proof of identity while authorization and active *Role* stay mutable server-side. Verifying it on every request and connection makes the validator the single point at which a no-longer-valid *Session* is refused.

*End* *Portal session token* | **Hash**: 37177d93

## DIARY-DEV-portal-session-lifecycle: Portal session lifecycle

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-session-management

### Overview

The portal ends a *Session* on *Idle Timeout*, on explicit logout, and on the authorization changes that must take effect at once: *Deactivation* of the *User Account* and changes to its *Role* or *Site* assignments. Enforcement is server-side at the request validator, so a terminated or idle-expired *Session* is refused regardless of whether the bearer still holds a token.

### Assertions

A. The portal SHALL terminate a *Session* after a configurable idle period and on explicit logout.

B. When a *User Account* is deactivated, or its *Role* or *Site* assignment is changed, the portal SHALL terminate the active *Sessions* of that *User Account*.

C. The portal SHALL enforce *Session* validity server-side on every request, denying a terminated or idle-expired *Session* regardless of token possession.

D. The portal SHALL expose the effective *Session* *Idle Timeout* and *Timeout Warning Threshold* to the client at *Session* establishment.

E. The portal SHALL treat a keep-alive request as *Session* activity, resetting elapsed inactivity server-side.

### Rationale

Capping idle time bounds the window in which an unattended authenticated workstation can be abused, and explicit logout lets an *Account Owner* end that window deliberately. The cascade on *Deactivation* and on *Role* or *Site* change makes authorization changes take effect synchronously rather than waiting for a *Session* to time out, so a *User* who has lost access for cause cannot keep acting under the stale grant. Enforcing all of this at the validator — rather than trusting the client to stop using a token — is what makes possession of a token insufficient once the *Session* behind it is gone. Exposing the effective idle and warning values lets the client run a faithful soft-timer that mirrors — never overrides — the server's authoritative window, and treating a keep-alive as activity lets an operator who is actively reading (producing interface activity but no data requests) extend the *Session* through the same validator path every other request takes.

*End* *Portal session lifecycle* | **Hash**: a7e8ed40

## DIARY-DEV-portal-session-config: Portal session configuration sourcing

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-session-management

### Overview

The portal sources the *Session* *Idle Timeout* and *Timeout Warning Threshold* from event-sourced settings, seeded idempotently at boot from deployment configuration, so the durations are per-deployment without a code change.

### Assertions

A. The portal SHALL source the *Session* *Idle Timeout* and *Timeout Warning Threshold* from the `portal_settings` store keys `session_idle_minutes` and `session_warning_seconds`, seeded idempotently at boot from deployment configuration and clamped to the supported ranges (idle 1–30 minutes; warning 10 seconds to the idle window), falling back to the legacy idle environment value and then the platform defaults.

### Rationale

Reusing the event-sourced `portal_settings` mechanism (the same one the second-factor toggle and *Sponsor* configuration use) makes the timeout durations auditable, replayable, and idempotent across boots, while clamping at both seed and read time means a misconfigured deployment cannot persist or serve an out-of-range value. A single authoritative reader feeds both the request validator and the value surfaced to the client, so the two ends cannot disagree.

*End* *Portal session configuration sourcing* | **Hash**: e0054d77

## DIARY-DEV-portal-active-role-switch: In-session active role switch

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

### Overview

A *User* assigned more than one *Role* acts under one acting *Role* at a time and may change it during a *Session* without re-authenticating. The acting *Role* is a per-request claim the client supplies alongside the *Session* credential, which carries identity rather than a fixed *Role*. The portal verifies the claimed *Role* against the *User*'s current assignments on every request and defaults to the highest-priority assigned *Role* when no claim is supplied. Because the *Role* travels with each request, switching is a client-side change that needs no new token and does not end the *Session*.

### Assertions

A. The portal SHALL resolve the acting *Role* for each request from a *Role* claim the client supplies with the *Session* credential, defaulting to the highest-priority assigned *Role* of the *User* when no claim is supplied.

B. The portal SHALL authorize each request only under a *Role* the *User* is verified to currently hold, granting no permissions for a claimed *Role* the *User* does not hold.

C. The portal SHALL allow a *User* holding more than one *Role* to change the acting *Role* without re-authenticating or terminating the *Session*, with the change taking effect on subsequent requests.

### Rationale

Staff who legitimately hold more than one *Role* need to act in different capacities under a single accountable identity, so the acting *Role* must be switchable within a *Session* rather than requiring separate accounts or a fresh login per capacity. Carrying the *Role* as a per-request claim — verified against the *User*'s current assignments — keeps switching a cheap client-side change while the server stays authoritative over which permissions each *Role* confers and over whether the *User* may act under it at all. Refusing permissions for an unheld claimed *Role* keeps *Role* selection from becoming a privilege-escalation path, and re-deriving membership from the event log on every request means a concurrent revocation takes effect immediately.

*End* *In-session active role switch* | **Hash**: 3d941dbc
