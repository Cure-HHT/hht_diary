# Portal Service — Implementation Requirements

## DIARY-DEV-participant-site-index: Participant-Site Index Materializer

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-action-inventory
**Integrates**: EVS-PRD-scoped-permissions

### Overview

The portal authorization policy resolves *Participant*-scoped permissions through a
*Participant*-contained-in-*Site* hierarchy. The `participant_site_index` projection
supplies the containment data: the current RAVE-assigned *Site* for each *Participant*.
It is materialized from RAVE-sourced `participant_synced_from_edc` events
(via `EVS-PRD-scoped-permissions`, the substrate's app-supplied
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
**Integrates**: EVS-PRD-reaction-widget-contract

### Overview

The portal hosts its event-sourced actions and read projections over the `reaction`
server shell (via `EVS-PRD-reaction-widget-contract`). A thin
composition wires `ReactionHandlers` over the portal *Event Store* and dispatcher so a
remote reactive client can subscribe to projections and dispatch actions.

### Assertions

A. The portal SHALL compose `ReactionHandlers` over `openPortalEventStore` and
`buildPortalDispatcher`, exposing `GET /me`, `POST /actions`, and a WebSocket
`/subscriptions` endpoint.

B. A `Principal` SHALL be established per connection and per request via a
`PrincipalAuthValidator`, and every dispatched *Action* SHALL be enforced by the
event-derived authorization policy regardless of the Principal's claimed *Role*.

C. A subscription to a row-scoped projection SHALL deliver only the rows within the
subscribing *Principal*'s permitted scope. A *Study Coordinator* bound to a *Site* SHALL
receive only the *Participants* at that *Site* and SHALL NOT receive *Participant* records
from other *Sites*.

D. The portal SHALL configure `ReactionHandlers` with a fixed `/subscriptions` WebSocket
keepalive interval (a checked-in operational constant, currently 20 seconds), kept below
the proxy *Idle Timeout* in front of `/subscriptions`, so an idle or half-open subscription
connection is not silently reaped without the reactive client observing a close.

### Rationale

The reactive transport (subscriptions + *Action* dispatch over WS/HTTP) is the portal's
durable client/server seam; standing it up over the SP1/SP2 enforcement core lets the
real UI subscribe to live projections and dispatch audited, permission-gated actions.
The credential validator is swappable (a dev credential validator now; Identity
Platform later) without changing the enforcement path. Row-level read scope (C) mirrors
on the subscription path the same *Site*-to-*Participant* containment the write path enforces
for *Actions*: a view is bound to a scope class and the requesting *Principal*'s scope
assignments are resolved through that containment into the covered rows, so a *Site*-bound
Coordinator's live *Participant* list cannot leak rows from *Sites* they are not assigned
to. A projection with no scope binding stays unscoped at the row level (global/admin
views), gated only by its view-level permission.

Keepalive (D) is set on the portal side rather than baked into the library default because
the library stays transport-policy-neutral; the consumer chooses the interval. Without it,
an idle or half-open WebSocket can be dropped with no close-frame, leaving the reactive
client believing it is still connected so its lifecycle-driven reconnect never fires and
the *User* sees silently stale lists. The interval is a fixed operational constant rather
than per-environment configuration: 20 seconds clears any sane proxy/load-balancer
*Idle Timeout* for the WS route, and its only real constraint — staying below the
`/subscriptions` `proxy_read_timeout` — couples it to another checked-in repo value (the
nginx config), so both live in version control and are reviewed together rather than being
a deployment knob that each environment must set.

*End* *Portal Reaction Server Shell* | **Hash**: 8e038146

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

## DIARY-DEV-portal-seed-config: Config-driven user-role seed

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-durable-event-store

### Overview

The set of seeded *User* accounts and their *Role* assignments is data, not code: a deployed environment supplies it as a *Sponsor*-maintained config file, while local and test runs use an in-code development convenience seed. Because the underlying assignment seed is idempotent against the *Event Store*, the seed is applied on every boot rather than once, so an edited config propagates on redeploy.

### Assertions

A. The portal SHALL apply *User*-*Role*-scope assignments from a declarative seed on every boot, idempotently — emitting an assignment event only for an entry not already present — so an edited seed propagates additions on the next boot; an assignment removed from the seed SHALL be reported as drift and SHALL NOT be auto-unassigned.

B. A deployed portal SHALL load its seed from a *Sponsor*-supplied config file identified by configuration, and when that configuration names a file that is absent the portal SHALL fail to start rather than fall back to the development seed. A run with no seed-file configuration SHALL use the in-code development convenience seed.

C. The deployed seed SHALL contain only *System Operator* accounts; the first *Administrators* are provisioned at runtime by a *System Operator* through the portal, not seeded.

### Rationale

Seeding *User*-*Role* assignments from data keeps the deployed roster out of the shipped binary and lets each *Sponsor* own its operator list without a code change. The assignment seed is idempotent by construction (it diffs the declared set against the materialized assignments and emits only the difference), so — unlike the grant and reference seeding gated behind the one-time marker — it is safe to re-apply on every boot, which is what makes an edited config take effect on redeploy. Drift is reported but never auto-unassigned because removing access is a deliberate, audited *Action*, not a silent consequence of editing a file. Failing closed when a configured seed file is missing prevents a deployed environment from silently falling back to the development convenience seed (which seeds a wildcard *Administrator*). Restricting the deployed seed to *System Operators* — who then provision the first *Administrators* — keeps the deployment bootstrap minimal and routes real account creation through the audited provisioning path.

*End* *Config-driven user-role seed* | **Hash**: 89ccad9f

## DIARY-DEV-role-permissions-seed: File-based role-to-Action authorization seed

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

### Overview

The binding from each *Role* to the *Action* permissions it holds is data, not code: a deployed environment supplies it as a *Sponsor*-maintained `role-permissions.yaml`, loaded as the authorization seed at boot. This is the permission-grant counterpart of the *User*-*Role* roster seed (`DIARY-DEV-portal-seed-config`): the roster declares who holds each *Role*, while this seed declares what each *Role* may do.

### Assertions

A. A *Sponsor*-supplied `role-permissions.yaml`, identified by configuration, SHALL be the authorization seed that binds each *Role* to the *Action* permissions it holds, expressed in *Action* vocabulary only (no `view:<projection>` names).

B. The loader SHALL reject a grant that is not a declared *Action* permission, failing the boot rather than seeding an unknown permission.

C. The loader SHALL validate that the file's *System Operator* grants are a superset of the platform-required minimum (`DIARY-BASE-system-operator-role`).

### Rationale

Expressing policy as *Role* -> *Action* permissions in a single file makes the *Sponsor* binding the single source of truth and keeps it 1:1 with the enforced grants. Rejecting undeclared permissions and validating the *System Operator* minimum makes a malformed or under-provisioned seed a boot failure, not a latent authorization gap.

*End* *File-based role-to-Action authorization seed* | **Hash**: c4e10419

## DIARY-DEV-operator-tier-authz: Operator-Tier Authorization for User Management

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-system-operator-role-D, DIARY-PRD-user-account-edit

### Overview

The **System Operator** is the recovery tier of last resort; letting a regular **Administrator** modify a **System Operator** *User Account* or grant the **System Operator** *Role* is a denial-of-service and privilege-escalation vector. The library's authorization model is actor-permission+scope only — it cannot inspect an *Action*'s target and apps cannot subclass the policy — so target protection is realized as a `tier` scope class with `user → tier` containment, keeping the decision in the substrate and recorded as an auditable event on every enforcement path. The **System Operator** legitimately holds *User*-management permissions because it provisions **Administrator** accounts and other **System Operator** accounts; it holds no *Participant*-facing or clinical permissions (see `DIARY-BASE-system-operator-role/B`).

### Assertions

A. The portal SHALL materialize a `user_tier_index` projection by folding `user_created`, `role_assigned`, and `role_unassigned` events to a `user_id → tier` mapping, where `tier` is `operator` if the *User* currently holds the **System Operator** *Role* and `staff` otherwise.

B. The portal scope registry SHALL declare a `tier` scope class and a `user` scope class contained in `tier` via `user_tier_index`; the target-bearing `portal.user.*` permissions SHALL declare scope class `user`.

C. Each *User*-account *Action* SHALL resolve its authorization scope to the target *User*; the authorization policy SHALL deny the *Action* when the requester's tier coverage does not contain the target *User*'s tier.

D. Assigning a *Role* SHALL additionally require a grant-*Role* permission scoped to the tier of the *Role* being granted; granting the **System Operator** *Role* SHALL require operator-tier coverage.

E. **Administrator** *Role* assignments SHALL carry staff-tier coverage; **System Operator** *Role* assignments SHALL carry coverage spanning all tiers; both SHALL be established at the bootstrap seed and the account-creation paths.

F. Authorization denials on *User*-account *Action* paths SHALL be recorded as audited *Action*-denial events.

### Rationale

The operator-tier containment model keeps the enforcement decision inside the substrate (the authorization policy evaluates it transactionally alongside every *Action*) rather than adding a separate pre-check in each *Action* handler. A `tier` scope class with `user_tier_index` as its containment resolver means an **Administrator**'s staff-tier *Role* assignment naturally fails the containment test against an operator-tier target, and a **System Operator**'s all-tier assignment passes for both tiers. The same mechanism gates *Role*-granting: the grant-*Role* permission is scoped to the tier of the *Role* being granted, so only a principal with operator-tier coverage can issue **System Operator** *Role* assignments. All denials are recorded as audited *Action*-denial events so the *Audit Trail* captures attempted escalations as well as successful operations.

*End* *Operator-Tier Authorization for User Management* | **Hash**: cda9a051
