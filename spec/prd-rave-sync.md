# Rave EDC Synchronization Resilience

The *Sponsor Portal* synchronizes **Site** and **Participant** data from the *Sponsor*'s configured EDC (Medidata Rave) on a TTL refresh schedule. The Rave account is shared across non-production environments and locks out after a small number of consecutive credential failures at Medidata, with manual operator recovery required.

These requirements define the defense-in-depth pause and manual-recovery surface that prevents the *Sponsor Portal* from wedging the shared Rave credentials, and the operator UX that lets a *Developer Admin* recover when Rave responds again.

Cooldown Window
: The configurable duration after the most recent Rave authentication failure during which the *Sponsor Portal* will not attempt another Rave call.

Lockout Threshold
: The configurable count of consecutive Rave authentication failures that triggers a hard pause requiring manual operator recovery.

Hard Lockout
: The state in which the *Sponsor Portal* refuses to attempt Rave calls until a *Developer Admin* explicitly invokes the recovery action, regardless of how much time has passed since the last failure.

Unwedge
: The *Developer Admin*-initiated recovery action that clears the **Hard Lockout** state and immediately probes Rave with one synchronization attempt to confirm the credentials have been corrected.

## DIARY-OPS-rave-sync-cooldown: Rave Sync Cooldown After Auth Failure

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The **System** SHALL pause all outbound Rave calls for the configured **Cooldown Window** after any Rave authentication failure (HTTP 401).

B. The **System** SHALL read the **Cooldown Window** duration from the `RAVE_AUTH_COOLDOWN_HOURS` environment variable, defaulting to 24 hours when unset or invalid.

C. The **System** SHALL clear the cooldown immediately upon any successful Rave synchronization, including the **Unwedge** probe.

D. The **System** SHALL serve cached **Site** and **Participant** data from the local *Database* during a cooldown without making any Rave call.

### Rationale

The Rave test account is shared across non-production *Sponsor Portal* environments (dev, qa, uat); each environment's local counter is independent. A 24-hour cooldown after every failed authentication is the primary defense against runaway: even with three environments compounding, three failures spread across three days at Medidata is well below the failure cadence required to trip the upstream lockout. The cooldown duration is configurable per environment so a noisy environment can be tightened without coordinating a code change with the others. The "successful sync clears cooldown" rule preserves the operator's ability to confirm a credential fix without waiting out the window; the local store of **Site** and **Participant** data is the *Sponsor Portal*'s system of record for day-to-day operations, so serving cached data during a cooldown imposes no functional restriction on the *Investigator* or *Administrator* workflows.

*End* *Rave Sync Cooldown After Auth Failure* | **Hash**: 2d1cf77c

## DIARY-OPS-rave-sync-hard-lockout: Rave Sync Hard Lockout After Repeated Failures

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The **System** SHALL set a **Hard Lockout** when the count of consecutive Rave authentication failures reaches the configured **Lockout Threshold**.

B. The **System** SHALL block all outbound Rave calls while a **Hard Lockout** is in effect and serve cached **Site** and **Participant** data from the local *Database* in place of fresh fetches.

C. The **System** SHALL clear the **Hard Lockout** state only via the **Unwedge** *Action*; no automatic recovery path SHALL clear it.

D. Each deployment environment SHALL maintain its **Lockout Threshold** state independently, with no cross-environment coordination.

### Rationale

The **Hard Lockout** is the last line of defense behind the **Cooldown Window**. Hitting it requires the configured **Lockout Threshold** of consecutive failures with no successful synchronization between them, which under the default 24-hour cooldown translates to multiple days of unattended failures — a state in which the *Operator* alerts have clearly gone unanswered. At that point an automatic retry adds no value; the system needs human review of the credentials before another attempt is made. The per-environment independence rule keeps each *Sponsor Portal* deployment recoverable on its own and avoids any temptation to share lockout state across environments (which would couple their availability and contradict the *Sponsor Portal*'s isolation model).

*End* *Rave Sync Hard Lockout After Repeated Failures* | **Hash**: 5c2f7d7c

## DIARY-OPS-rave-unwedge-authz: Rave Unwedge Endpoint Authorization

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The **System** SHALL restrict the **Unwedge** endpoint to the *Developer Admin* *Role*; calls from any other *Role* SHALL return HTTP 403.

B. The **System** SHALL write an audit record of every **Unwedge** *Action* to the EDC synchronization log, including the *User* identity, timestamp, and probe outcome.

### Rationale

The **Unwedge** *Action* restores outbound Rave calls and immediately probes the Rave endpoint, so the *Action* is both privileged (can re-trigger the upstream lockout if the credentials are still incorrect) and operationally significant (the moment recovery is attempted). Restricting it to the *Developer Admin* *Role* keeps the recovery surface narrow and aligns with the existing *Developer Admin* operational toolkit. The audit record is required so the operator team can reconstruct who attempted recovery, when, and whether the probe succeeded — essential for incident review and for *FDA 21 CFR Part 11* attribution of operational actions on regulated data flows.

*End* *Rave Unwedge Endpoint Authorization* | **Hash**: 7c99b2b8

## DIARY-OPS-rave-alert-notification: Rave Lockout Operator Alerting

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The **System** SHALL send an operator alert on every Rave authentication failure with the environment identifier, current consecutive-failure count, and configured threshold.

B. The **System** SHALL send a distinct operator alert when a **Hard Lockout** is set, separate from the per-failure alert.

C. The **System** SHALL send a confirmation operator alert when an **Unwedge** *Action* completes, including the actor identity and probe outcome.

D. The **System** SHALL include the environment identifier in every operator alert payload.

E. A failure of the operator alert transport SHALL NOT block, retry, or alter the Rave synchronization request path.

### Rationale

The operator alert is the human-in-the-loop signal that lets a *Developer Admin* intervene before the **Cooldown Window** sequence escalates into a **Hard Lockout**. Three distinct alert types (per-failure, lockout-trip, *Unwedge*-confirmation) carry different escalation semantics and are queryable separately by the operator team. The environment tag is required because the same operator channel receives alerts from all non-production environments. The non-blocking transport rule ensures that an outage in the alert delivery pathway never amplifies a Rave problem — a Slack outage SHALL NOT cause the *Sponsor Portal* to hang on synchronization attempts or surface alert-transport errors to *Investigators* or *Administrators*.

*End* *Rave Lockout Operator Alerting* | **Hash**: 0925f7b5

## DIARY-DEV-rave-auth-failure-classification: Rave Authentication Failure Classification

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The implementation SHALL count only HTTP 401 responses from Rave (signalled by the Rave authentication exception type) toward the consecutive-failure counter that drives the **Cooldown Window** and **Lockout Threshold**.

B. The implementation SHALL NOT count Rave network errors, transport timeouts, or non-401 HTTP responses toward the consecutive-failure counter.

C. The implementation SHALL capture Medidata's `ReasonCode` from the 401 response body when present and persist it with the failure record for operator diagnosis.

### Rationale

Only HTTP 401 advances Medidata's own upstream lockout counter, so only HTTP 401 should advance ours. Counting network errors or transport timeouts would couple the *Sponsor Portal*'s pause behavior to unrelated infrastructure issues and create false **Hard Lockouts** during transient outages — exactly the wedging behavior these requirements exist to prevent. The Medidata `ReasonCode` is a vendor-specific signal (e.g. distinguishing "bad *Password*" from "account locked at Medidata") that gives the operator immediate diagnosis without inspecting Medidata's response body manually.

*End* *Rave Authentication Failure Classification* | **Hash**: f2732c70

## DIARY-GUI-rave-sync-paused-banner: Sites and Participants Pages Paused Banner

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The *Sponsor Portal* SHALL display a non-dismissible banner above the data table on the Sites and Participants pages whenever Rave synchronization is paused (in **Cooldown Window** or **Hard Lockout**).

B. The banner copy SHALL identify the pause reason: a cooldown banner SHALL state the auto-resume time; a **Hard Lockout** banner SHALL direct the *User* to contact a *Developer Admin*.

C. The banner SHALL NOT expose diagnostic detail (failure counter, reason code, last *Unwedge* identity) to non-*Developer Admin* users.

### Rationale

The banner is the visible signal to *Investigators* and *Administrators* that the data they are viewing reflects the last known synchronization, not a fresh fetch. The non-dismissible behavior prevents a *User* from inadvertently working against stale data without context. The auto-resume time on the cooldown variant is actionable for non-admin users (they know when to recheck); the *Developer Admin* contact prompt on the **Hard Lockout** variant is actionable because only the *Developer Admin* can clear it. Diagnostic detail is privileged because the failure-counter value and Medidata `ReasonCode` provide attack signal in addition to operational signal; restricting them to the *Developer Admin* surface limits inadvertent disclosure.

*End* *Sites and Participants Pages Paused Banner* | **Hash**: 75bc47b3

## DIARY-GUI-dev-admin-rave-sync-card: Developer Admin Dashboard Rave Sync Card

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

### Assertions

A. The *Developer Admin* dashboard SHALL render a card that displays the current Rave synchronization state, the consecutive-failure counter, last-failure metadata, and last-**Unwedge** metadata.

B. The card SHALL provide an **Unwedge** *Action* button that is always enabled for the *Developer Admin*, regardless of current state (the *Action* is idempotent — clicking it while not locked simply runs a probe).

C. The card SHALL display a warning above the **Unwedge** *Action* that the operator must confirm both that credentials are correct in the secret manager AND that the *Sponsor Portal* service has been redeployed since any credential rotation, before invoking **Unwedge**.

### Rationale

The card concentrates all *Developer Admin*-relevant Rave synchronization observability in one surface so the operator can diagnose without inspecting logs or running ad-hoc *Database* queries. The always-enabled *Action* lets the operator probe Rave from an `ok` state to verify credentials proactively (e.g. immediately after a Doppler rotation). The pre-*Action* warning addresses a real operational risk: the *Sponsor Portal* reads Rave credentials from process environment variables, which are populated at deployment time; rotating the credentials in the secret manager does not propagate into a running process. An operator who unwedges before redeploying will probe with the old (and still incorrect) credentials and immediately re-trigger the **Cooldown Window**. The warning text is mandatory because the failure mode is non-obvious and recoverable only by another full deployment *Cycle*.

*End* *Developer Admin Dashboard Rave Sync Card* | **Hash**: 19da0ac2
