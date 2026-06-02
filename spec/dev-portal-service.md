# Portal Service — Implementation Requirements

## DIARY-DEV-participant-site-index: Participant-Site Index Materializer

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-action-inventory

### Overview

The portal authorization policy resolves *Participant*-scoped permissions through a
*Participant*-contained-in-*Site* hierarchy. The `participant_site_index` projection
supplies the containment data: the current RAVE-assigned *Site* for each *Participant*.
It is materialized from RAVE-sourced `participant_synced_from_edc` events
(`<!-- satisfied-by: EVS-PRD-scoped-permissions -->`, the substrate's app-supplied
`ContainmentReference` projection contract). RAVE is authoritative; the portal never
writes the mapping except by folding the edge event.

### Assertions

A. The portal SHALL materialize a `participant_site_index` view keyed by
`participant_id` carrying the current `site_id`, by folding
`participant_synced_from_edc` events; a later sync for the same *Participant* SHALL
overwrite the row (the *Participant*'s *Site* is the latest RAVE-sourced value).

B. The portal SHALL register `participant_site_index` when opening its *Event Store*,
so the authorization policy's containment resolver reads it within the dispatch
transaction.

### Rationale

Participants and sites are RAVE-sourced, first-class facts in the single auditable
event stream, ingested as events. The index is the read model the containment
resolver consults so a *Site*-bound *Role* assignment covers *Participant*-scoped requests
at the *Participant*'s RAVE *Site*, fail-closed when no mapping row exists.

*End* *Participant-Site Index Materializer* | **Hash**: 76e68990

## DIARY-DEV-portal-reaction-server: Portal Reaction Server Shell

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-action-inventory

### Overview

The portal hosts its event-sourced actions and read projections over the `reaction`
server shell (`<!-- satisfied-by: EVS-PRD-reaction-widget-contract -->`). A thin
composition wires `ReactionHandlers` over the portal *Event Store* and dispatcher so a
remote reactive client can subscribe to projections and dispatch actions.

### Assertions

A. The portal SHALL compose `ReactionHandlers` over `openPortalEventStore` and
`buildPortalDispatcher`, exposing `GET /me`, `POST /actions`, and a WebSocket
`/subscriptions` endpoint.

B. A `Principal` SHALL be established per connection and per request via a
`PrincipalAuthValidator`, and every dispatched *Action* SHALL be enforced by the
event-derived authorization policy regardless of the Principal's claimed *Role*.

### Rationale

The reactive transport (subscriptions + *Action* dispatch over WS/HTTP) is the portal's
durable client/server seam; standing it up over the SP1/SP2 enforcement core lets the
real UI subscribe to live projections and dispatch audited, permission-gated actions.
The credential validator is swappable (a dev credential validator now; Identity
Platform later) without changing the enforcement path.

*End* *Portal Reaction Server Shell* | **Hash**: 95ceb3ec

## DIARY-DEV-rave-edc-ingest: RAVE/EDC Ingest as Edge Events

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

### Overview

The portal sources *Site* and *Subject* facts from the RAVE/EDC web service and folds
them into its event-sourced log as edge events, rather than persisting them in a
side table. Each EDC fetch appends typed events under an automation initiator, and a
recorded sync-status projection governs a fail-counter and lockout decision so a
misbehaving or unauthenticated EDC connection cannot wedge the portal silently.

### Assertions

A. The portal SHALL ingest RAVE/EDC *Site* and *Subject* records by fetching them from
the EDC web service and appending one `site_synced_from_edc` event per *Site* (on the
`site` aggregate) and one `participant_synced_from_edc` event per *Subject* (on the
`participant` aggregate, carrying the *Participant* id and its *Site* id), each appended
under an automation initiator, so EDC-sourced facts are first-class auditable events
rather than side-table rows.

B. Re-ingesting unchanged EDC data SHALL append no new events, so the event log records
only genuine changes.

C. A RAVE authentication failure SHALL be recorded as a `rave_auth_failed` event that
advances a consecutive-failure counter, a successful sync SHALL be recorded as an
`edc_sync_succeeded` event that resets that counter, and a transient network failure
SHALL NOT advance the counter.

D. Before fetching, the portal SHALL evaluate a lockout decision — proceed, cooldown,
or locked — from the recorded sync status and a configurable failure threshold and
configurable *Cooldown Window*, and SHALL skip the fetch when the decision is not
"proceed"; reaching the failure threshold SHALL be recorded as a hard-lockout event,
and an operator *Unwedge* SHALL be recorded as a `rave_unwedged` event that clears the
lockout.

### Rationale

RAVE/EDC *Sites* and *Subjects* are external facts the portal does not own, but they
must still be attributable and tamper-evident: folding them as edge events places them
on the same append-only chain as every other portal *Action*, so the audit record stays
complete rather than split across a non-audited side table. The fail-counter and
lockout decision protect the chain from a wedged or hostile EDC connection — repeated
auth failures lock the integration and an operator *Unwedge* is itself an audited event —
while distinguishing genuine auth rejection from transient network noise. The
`participant_synced_from_edc` event is the source the `participant_site_index`
materializer folds for containment-scoped authorization.

*End* *RAVE/EDC Ingest as Edge Events* | **Hash**: e93b0ede

## DIARY-DEV-participant-status-projection: Participant Linking-Status Projection

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

### Overview

The portal materializes a per-*Participant* record from the *Participant*
linking-lifecycle events, deriving each *Participant*'s linking status as a state
machine over the most recent lifecycle event. The transition into a connected status
is gated on a confirmation event that originates from the mobile *Diary* application, so
the portal cannot unilaterally declare a *Participant* connected.

### Assertions

A. The portal SHALL maintain a per-*Participant* record materialized from the
linking-lifecycle events of that *Participant*, carrying the *Participant*'s *Site*
assignment and the classifying type of the most recent lifecycle event.

B. A *Participant*'s linking status SHALL be derived from the most recent lifecycle
event, and the transition to a connected status SHALL require a confirmation event
originating from the mobile *Diary* application, so the portal alone cannot advance
any *Participant* to connected.

### Rationale

A *Participant*'s linking state is an audited, derived fact: rather than storing a
mutable status column, the portal folds the linking-lifecycle events into a per-
*Participant* record and classifies the current status from the latest event, keeping
the status reconstructible from the log alone. The connected transition is a
cross-system handshake — the portal may invite or stage a link, but only a confirmation
event raised by the mobile *Diary* application can advance a *Participant* to connected,
so neither node can fabricate the linked relationship on its own.

*End* *Participant Linking-Status Projection* | **Hash**: aafda27d

## DIARY-DEV-user-account-projection: User account projection

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

### Overview

The portal materializes a per-*User* record from the portal *User* lifecycle events,
carrying each *User*'s email, name, and account status. Account status is recorded as an
explicit fact on each status-transition event so the materialized status survives
interleaved non-status edits, and a *User*'s roles and sites are realized as per-(*User*,
*Role*, scope) assignment tuples that an *Administrator* changes by applying the difference
between the desired and current assignment sets.

### Assertions

A. The portal SHALL materialize a per-*User* record from the portal *User* lifecycle
events, carrying the *User*'s email, name, and account status, and SHALL remove the
record when the account is deleted.

B. Account status SHALL be recorded as an explicit fact on each status-transition
event (account created becomes pending, deactivated becomes revoked, reactivated
becomes pending) and SHALL be preserved across non-status events such as profile and
email changes, so the materialized status reflects the latest transition regardless of
interleaving edits.

C. Creating a *User* SHALL record the account and realize the chosen roles and sites as
per-(*User*, *Role*, scope) assignment tuples, and an *Administrator* SHALL change a *User*'s
roles or sites by applying the difference between the desired and current assignment
sets.

### Rationale

A *User* account is an audited, derived fact: rather than storing mutable account and
*Role*-assignment columns in side tables, the portal folds the *User* lifecycle events into
a per-*User* record so the account, its status, and its assignments stay reconstructible
from the same append-only, tamper-evident chain as every other portal *Action*. Account
status is carried as an explicit fact on each status-transition event because the *User*
lifecycle interleaves non-status events — profile and email changes — and a derived
record must reflect the latest genuine transition regardless of those edits. Roles and
sites are realized as the cartesian product of the chosen roles over the chosen sites,
each captured as a single (*User*, *Role*, scope) assignment tuple; an *Administrator* edits
the set by applying the difference between the desired and current tuples, which the
`portal_actions` user-administration *Actions* and the `users_index` materializer
record and fold respectively.

*End* *User account projection* | **Hash**: ae8627b4

## DIARY-DEV-audit-log-read: Audit log read

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

### Overview

The portal serves the *Audit Trail* by reading the append-only event log directly, in
reverse-chronological order, projecting each stored event into a row that names the
initiator, the entry type, the timestamp, and the recorded details. Access to that
trail is a privileged operation: the server admits the request only for a principal
that holds the audit-view permission, and enforces that check itself rather than
trusting the client.

### Assertions

A. The portal SHALL expose the *Audit Trail* by reading the append-only event log in
reverse-chronological order; each returned entry SHALL surface who performed the
operation (the initiator), what occurred (the entry type), when it occurred (the
timestamp), and the recorded details (the event payload and any change reason).

B. Access to the *Audit Trail* SHALL be restricted to principals holding the audit-view
permission, and that restriction SHALL be enforced on the server independent of the
client.

### Rationale

The event log *is* the *Audit Trail*: every state-changing event is already attributable
to an initiator and stamped with the time it occurred, so reading the log in reverse-
chronological order yields the audit record without a separate audit store. The portal
reads the log directly rather than the event-by-security-context join because the
security context is attached to events later in the pipeline; joining now would return
an empty result, so the direct read is the correct source until that upgrade lands and
a richer `queryAudit` can fold the security context in. Authority to view the trail is
enforced server-side because a privileged read must not depend on client cooperation;
the audit-view permission is the gate, and the presentation requirements
`DIARY-GUI-audit-log-common` and `DIARY-GUI-audit-log-administrator` render the rows
this read produces.

*End* *Audit log read* | **Hash**: 34892437

## DIARY-DEV-portal-durable-event-store: Durable, environment-selected event store

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-reaction-server

### Overview

The reactive portal's *Event Store* is its system of record, so a deployed node persists it to
managed Postgres while local and test runs stay in-memory — the same composition root selects the
backend from the environment. The originating-node identity is fixed so a restarted process keeps
appending under one identity, and one-time seed data is written once rather than re-appended on
every boot.

### Assertions

A. The portal SHALL select its *Event Store* backend by environment — a durable Postgres-backed store with a matching durable idempotency store when *Database* configuration is present, and an in-memory store otherwise — without a code change.

B. The deployed portal SHALL derive a stable originating-node identity from configuration that persists across process restarts, so events appended after a restart retain the same originator identity.

C. Boot-time seeding of authorization, *Role*, and reference data SHALL be idempotent against a populated *Event Store*, so repeated restarts append no duplicate seeded events.

### Rationale

A deployed portal restarts (new revisions, scale-to-zero) and must not lose its users, sessions, or
activations, so the event log lives in the already-attached Cloud SQL instance via the library's
managed-Postgres backend; tests and local runs keep the in-memory store, and the choice is made from
`DB_*` configuration with no code branch so the verified path is the shipped path. A fixed
originating-node identifier keeps the originator stable across restarts (the originator of the first
event is the canonicalization authority). Seeding is gated behind a one-time marker because, unlike
the always-fresh in-memory store, a durable store would otherwise accumulate duplicate grant and
*Role*-assignment events on every restart.

*End* *Durable, environment-selected event store* | **Hash**: cfb9c8c5
