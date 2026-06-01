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
