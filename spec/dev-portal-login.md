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

### Rationale

Capping idle time bounds the window in which an unattended authenticated workstation can be abused, and explicit logout lets an *Account Owner* end that window deliberately. The cascade on *Deactivation* and on *Role* or *Site* change makes authorization changes take effect synchronously rather than waiting for a *Session* to time out, so a *User* who has lost access for cause cannot keep acting under the stale grant. Enforcing all of this at the validator — rather than trusting the client to stop using a token — is what makes possession of a token insufficient once the *Session* behind it is gone.

*End* *Portal session lifecycle* | **Hash**: 32f18e2d

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
