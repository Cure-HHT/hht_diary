# Portal *Password* Reset — Implementation Requirements

## DIARY-DEV-portal-reset-code-lifecycle: Password reset code lifecycle

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-password-forgot

### Overview

A *Password* reset is proven by a single-use, time-limited code the portal mints and delivers as a link to the registered email. The portal holds only a one-way hash of the code in an ephemeral server-side store, never the event log; the cleartext exists solely in the delivered link. The code expires 24 hours after issuance or on first use, whichever comes first, and issuing a new code invalidates any prior unused code for the *User*. The request endpoint is enumeration-resistant: it returns the same confirmation whether or not the email matches an account, and mints and emails a code only for an existing active account.

### Assertions

A. The portal SHALL generate each reset code from a cryptographically secure source and SHALL persist only a one-way hash of it in an ephemeral server-side store, never the append-only event log, so the cleartext exists solely in the delivered link.

B. The portal SHALL treat a reset code as single-use and SHALL reject it once consumed or once 24 hours have passed since its issuance, whichever occurs first.

C. When a new reset code is issued for a *User*, the portal SHALL invalidate any previously issued unused code for that *User*.

D. The portal SHALL return the same reset-request confirmation whether or not the email matches an account, and SHALL mint and email a code only for an existing active account.

### Rationale

The reset link is the proof that the requester controls the registered email, so it must be unguessable, single-use, and short-lived. The 24-hour expiry is shorter than the activation link's because a *Password*-reset link has higher attack value. Holding only a hash in an ephemeral store keeps the secret out of the tamper-evident log, which records only the durable facts that a reset was requested and completed. Returning an identical confirmation regardless of account existence denies an attacker the ability to enumerate accounts through the reset form.

*End* *Password reset code lifecycle* | **Hash**: 8bc6a227

## DIARY-DEV-portal-reset-password-update: Password reset credential update

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-password-forgot

### Overview

When a *User* submits a new *Password* against a valid reset code, the portal updates the existing Identity Platform credential for that account. The update never creates an account: a reset is only meaningful for an account that already exists, so a missing account is an error rather than a provisioning trigger. The portal records the durable completion fact only after the credential update succeeds, and surfaces a composition-rule rejection without completing the reset or consuming the code, so the *User* can correct the *Password* and retry on the same link.

### Assertions

A. On a valid reset code the portal SHALL update the Identity Platform *Password* for the account and SHALL NOT create an account when none exists.

B. The portal SHALL append a system-initiated reset-completed event only after the *Password* update succeeds, and SHALL surface a composition-rule rejection without completing the reset or consuming the code.

### Rationale

Reset operates on an established account, so the update path must never fall back to creating one — that would turn a reset endpoint into an unauthenticated account-creation channel. Recording completion only after the credential actually changes keeps the event log honest about what happened. Surfacing a composition rejection without consuming the code lets a *User* who chose too weak a *Password* fix it without restarting the whole reset flow, which the link's single-use property would otherwise force.

*End* *Password reset credential update* | **Hash**: 4972e2a5

## DIARY-DEV-portal-reset-session-termination: Password reset session termination

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-password-forgot

### Overview

A successful *Password* reset terminates every active *Session* of the *User*, closing the window in which a *Session* or second-factor token stolen before the reset could still operate against the now-changed account. The portal does this by recording the *Session*-revocation fact, which the *Session*-cascade machinery already turns into termination of each of the *User*'s live sessions. Because every login requires the *Second Factor*, the next login after a reset necessarily runs two-factor authentication.

### Assertions

A. On a successful *Password* reset the portal SHALL terminate all active sessions of the *User*.

B. Every login SHALL require the *Second Factor*, so a successful reset is necessarily followed by two-factor authentication on the next login.

### Rationale

The value of a reset as a recovery control depends on it also being a containment control: if a pre-reset *Session* or token survived the reset, an attacker who triggered or intercepted the reset could keep operating. Terminating all sessions on reset and requiring the *Second Factor* on the next login closes that window. Reusing the existing *Session*-revocation cascade keeps a single, audited mechanism responsible for ending sessions rather than introducing a second path.

*End* *Password reset session termination* | **Hash**: 7805b6aa
