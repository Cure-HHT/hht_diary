# Portal Activation — Implementation Requirements

## DIARY-DEV-portal-activation-code-lifecycle: Activation code lifecycle

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-activation-workflow

### Overview

Account activation turns an *Administrator*-created *User Account* into a credentialed
account. The portal mints a single-use, time-limited activation code, delivers it as a
*Verification Link*, and consumes it when the *Account Owner* sets a *Password*. The code is
a transient secret: the portal holds only a one-way hash of it in an ephemeral
server-side store, never in the append-only event log, and the cleartext exists solely in
the delivered link.

### Assertions

A. The portal SHALL generate each activation code from a cryptographically secure random
source and SHALL persist only a one-way hash of it, so the cleartext code exists solely
in the delivered *Verification Link*.

B. The portal SHALL treat an activation code as single-use: once consumed it SHALL be
invalidated and SHALL NOT be accepted again.

C. The portal SHALL reject an activation code once its issuance expiry has passed.

D. When a new activation code is issued for a *User Account*, the portal SHALL invalidate
any previously issued unused code for that *User Account*.

E. The portal SHALL hold activation codes and their state in an ephemeral server-side
store and SHALL NOT write them to the append-only event log.

### Rationale

The activation code is the proof that the recipient controls the registered email, so it
must be unguessable (a cryptographically secure source), unreplayable (single-use,
invalidated on consumption), and bounded in time (rejected after expiry). Issuing a fresh
code invalidates the prior one so a resend never leaves two valid paths open at once. The
code is a short-lived secret with no audit value once spent, so it is held in an ephemeral
side store rather than the tamper-evident event log, which records only the durable
lifecycle facts: that a code was issued, and that the account was activated.

*End* *Activation code lifecycle* | **Hash**: ec270b2e

## DIARY-DEV-portal-identity-provisioning: Identity Platform provisioning

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-activation-workflow

### Overview

When the *Account Owner* completes activation by setting a *Password*, the portal provisions
the corresponding Identity Platform account. The provisioning step is keyed by the email
address and is idempotent, so a retried activation converges on the same account
identifier rather than failing or creating a duplicate. The Identity Platform target is
environment-selected so non-production deployments exercise the same code path against the
emulator.

### Assertions

A. On activation the portal SHALL perform an idempotent lookup-or-provision against
Identity Platform keyed by the *Email Address* of the *User Account*, obtaining a stable
account identifier.

B. The portal SHALL select the Identity Platform target by environment so a non-production
deployment uses the emulator without a code change.

### Rationale

Activation is the boundary at which a candidate account becomes able to authenticate, so
it is where the Identity Platform record is created with the *Account Owner*'s chosen
*Password*. Keying on the *Email Address* and making the call idempotent means a duplicated or
retried request — a double submit, a network retry — converges on one account rather than
failing or forking identity. Selecting the target by environment lets the same code run
against the emulator in development and the live project in production without a branch, so
the path verified in test is the path that ships.

*End* *Identity Platform provisioning* | **Hash**: 0e3eb2b5

## DIARY-DEV-portal-activation-email-delivery: Activation email delivery

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-activation-workflow

### Overview

The portal delivers the *Verification Link* to the *Account Owner*'s registered email
address over Gmail using workload-identity federation, with a console-output fallback so
non-production deployments need no mail credentials. Activation responses are
enumeration-resistant: they reveal at most a masked *Email Address* and never disclose
whether an account exists, and an unusable link returns a single fixed rejection message.

### Assertions

A. The portal SHALL deliver the *Verification Link* to the *User Account*'s registered email
address via Gmail using workload-identity federation, with a console-output fallback for
non-production.

B. The portal SHALL reveal at most a masked *Email Address* in activation responses and
SHALL NOT disclose whether an account exists; an invalid, expired, or used link SHALL
return the single fixed rejection message.

### Rationale

Delivering the link to the registered address is what binds activation to control of that
address; doing it over workload-identity federation keeps the sending credential out of
the code and configuration, and the console fallback lets developers exercise the flow
without provisioning mail access. The responses are deliberately uninformative — a masked
address, one fixed rejection string — so an unauthenticated caller probing the activation
endpoints cannot enumerate which accounts exist or distinguish an expired link from an
unknown one.

*End* *Activation email delivery* | **Hash**: 8357a727

## DIARY-DEV-portal-user-activated-binding: User-activated binding

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-account-activation-workflow

### Overview

On successful activation the portal appends a system-initiated `user_activated` event that
binds the portal *User Account* to its Identity Platform account. The event records the
immutable Identity Platform identifier alongside the *Email Address*, which folds onto the
*User Account*'s index row so a later verified token can be resolved back to the portal
*User Account*, and it carries the account's transition to active status.

### Assertions

A. On successful activation the portal SHALL append a system-initiated `user_activated`
event that records the immutable Identity Platform identifier and the *Email Address* of the
portal *User Account*.

B. The portal SHALL record the Identity Platform identifier on the *User Account*'s index
row so a verified token can later be resolved to the portal *User Account*.

C. After `user_activated`, the portal SHALL reflect the *User Account*'s account status as
active.

### Rationale

The binding between the portal *User Account* and its Identity Platform account is a durable
fact with audit value, so it is recorded as an event rather than held only in the transient
activation store. The event is system-initiated because no authenticated *User* exists at
the moment of activation — the *Account Owner* is establishing their credential, not acting
under a *Session*. Recording the Identity Platform identifier on the *User Account* index row
is what lets a later login resolve a verified token to the portal *User Account* without a
separate identity table, and carrying the active-status transition on the same event keeps
the account's status reconstructible from the one append-only chain.

*End* *User-activated binding* | **Hash**: 25fda53b
