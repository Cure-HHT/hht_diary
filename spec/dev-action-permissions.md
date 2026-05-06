# Action Permissions — Developer Specification

**Version**: 1.0
**Audience**: Developer
**Last Updated**: 2026-04-23

## Description

The `action_permissions` library implements the `AuthorizationPolicy` interface defined by `audited_actions`. The role x permission matrix is event-sourced via `event_sourcing_datastore`: a registered `Materializer` projects two permission-domain event types (`PermissionGranted`, `PermissionRevoked`) into a `role_permission_grants` view that the policy reads at evaluation time. The library is app-agnostic and runs on whatever `StorageBackend` the host process supplies.

Design rationale and architecture live in `docs/superpowers/specs/2026-04-23-action-permissions-design.md`.

---

## REQ-d00172: REQ-PERM-SCOPE — Permission scope class enumeration

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-d00168, REQ-d00169

## Assertions

A. The system SHALL define a closed enumeration `ScopeClass` with three values: `global`, `site`, `self`.

B. The system SHALL require every `Permission` to declare a `scope` of type `ScopeClass`.

C. The system SHALL reject at boot, via the `ActionRegistry`, any two registered permissions with the same `name` but differing `scope` values.

## Rationale

A closed scope enumeration is the shared vocabulary between `audited_actions` (where permissions are declared by Actions) and `action_permissions` (where they are evaluated against the matrix). Keeping the set closed and small makes authorization decisions statically reasonable: an auditor can list every permission a role holds and inspect each one's scope without reading code. Rejecting same-name-different-scope at boot prevents silent divergence between Actions that declare the same permission identifier.

*End* *REQ-PERM-SCOPE — Permission scope class enumeration* | **Hash**: 57b8525d

---

## REQ-d00173: REQ-PERM-POLICY — AuthorizationPolicy interface shape

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-d00168

## Assertions

A. The `AuthorizationPolicy` interface SHALL expose exactly two public methods: `isPermitted(Principal, Permission)` and `permissionsFor(Principal)`.

B. `isPermitted` SHALL return an `AuthorizationDecision` value — either `Allow` or `Deny`.

C. `Deny` SHALL carry the denied `Permission` and a `DenyReason` enum value.

D. `DenyReason` SHALL be a closed enumeration with three values: `notGranted`, `sessionPreconditionMissing`, `bootstrapFailure`.

E. `permissionsFor` SHALL return the set of `Permission` values exercisable by the given `Principal` under the current session's scope preconditions.

## Rationale

Two methods cover the two hot questions: per-dispatch authorization and session-start snapshot generation. A closed `DenyReason` enum makes denial events queryable and audit-reportable without free-form strings; each reason maps to a distinct operational response (missing grant vs. missing session context vs. system misconfiguration).

*End* *REQ-PERM-POLICY — AuthorizationPolicy interface shape* | **Hash**: a3f79647

---

## REQ-d00174: REQ-PERM-MATRIX — Event-sourced matrix and materialized view

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-p00005

## Assertions

A. The system SHALL define two event types persisted via `event_sourcing_datastore`: `permission_granted` (payload `{role, permissionName, scope}`) and `permission_revoked` (payload `{role, permissionName}`). Both events use `aggregateType: 'role_permission_grant'` and `aggregateId: '<role>:<permissionName>'`.

B. The system SHALL define a `RolePermissionGrantsMaterializer` extending `event_sourcing_datastore`'s `Materializer`, with `viewName: 'role_permission_grants'`, that folds matching events into the view: `permission_granted` SHALL upsert a row keyed by `aggregateId` with payload `{role, permissionName, scope}`; `permission_revoked` SHALL delete the row keyed by `aggregateId`.

C. A grant SHALL be represented by the presence of a view row produced by the materializer; absence of a row SHALL mean no grant, regardless of whether the row was never written or was removed by a `permission_revoked` event.

D. The materializer SHALL run inside the same backend transaction as the appending event; a thrown error in `applyInTxn` SHALL roll back the entire append.

E. The system SHALL provide a `MaterializedViewRoleMatrixReader` implementing `RoleMatrixReader` that answers `isGranted` via a single view-row read keyed by `'<role>:<permissionName>'`, and answers `grantsForRole` via a view scan filtered to rows whose `role` field matches.

F. The system SHALL reject role names and permission names containing the `:` character at validation time, since `:` is the composite-aggregateId delimiter.

G. The matrix SHALL NOT carry sponsor identity: deployments are single-tenant per sponsor.

## Rationale

Event-sourcing the matrix unifies its persistence with the rest of the platform's audit story: every grant and revocation is a permanent, attributable event. Per-pair aggregates keep the materializer's fold step a pure upsert or delete with no read-modify-write inside the transaction, so concurrent grants of different pairs cannot conflict. The view-scan for `grantsForRole` is acceptable because the matrix is small (tens of roles, hundreds of permissions). Forbidding `:` in names protects the composite-aggregateId encoding from ambiguity.

*End* *REQ-PERM-MATRIX — Event-sourced matrix and materialized view* | **Hash**: b3974cac

---

## REQ-d00175: REQ-PERM-SEED — YAML seed, validation, and event-emitting applier

**Level**: dev | **Status**: Draft | **Implements**: -

## Assertions

A. The system SHALL load the matrix seed from `config/action_permissions/base.yaml` at host startup.

B. The YAML schema SHALL contain a `roles` list and a `grants` map from role name to list of permission names.

C. The `SeedValidator` SHALL reject any seed whose grant list contains a permission name absent from the in-memory set of declared permissions supplied by the caller (the `ActionRegistry.allDeclaredPermissions` set at boot).

D. The `SeedValidator` SHALL reject any seed whose `grants` map contains a role key absent from the `roles` list.

E. The `SeedValidator` SHALL reject any seed containing duplicate role names, or duplicate permission names within a single role's grants.

F. The `SeedValidator` SHALL require every role in `roles` to have an entry in `grants`; empty lists are permitted.

G. The `SeedValidator` SHALL reject any seed in which a role name or permission name contains `:`.

H. The `EventSeedApplier` SHALL diff the validated seed against the current `role_permission_grants` view, and SHALL append one `permission_granted` event via `EventStore.append` for each `(role, permissionName)` pair present in the seed and absent from the view.

I. The `EventSeedApplier` SHALL NOT emit `permission_revoked` events for grants present in the view but absent from the seed; it SHALL collect and return such drift in `SeedApplyResult.grantsInViewNotInSeed`.

J. The `EventSeedApplier` SHALL be idempotent across reruns: an unchanged seed yields zero emitted events.

## Rationale

Boot-time strict validation catches typos before they can silently fail open. Computing "discovered permissions" from the live `ActionRegistry` rather than a persisted registry table eliminates a parallel data structure that could drift from reality. The applier emits events rather than writing rows directly so that the materializer maintains the view atomically and the audit trail records every grant. Not emitting `permission_revoked` for view-only grants preserves any grants written by future runtime admin Actions when the YAML happens to lag behind.

*End* *REQ-PERM-SEED — YAML seed, validation, and event-emitting applier* | **Hash**: 5dec8543

---

## REQ-d00176: REQ-PERM-EVAL — Evaluation algorithm

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-d00168, REQ-d00172

## Assertions

A. `isPermitted(principal, permission)` SHALL evaluate the scope precondition before the matrix lookup.

B. The scope precondition SHALL be: `global` is always satisfied; `site` requires `principal.activeSite != null`; `self` requires `principal.userId != null`.

C. A precondition failure SHALL produce `Deny(sessionPreconditionMissing)` without consulting the matrix.

D. A precondition success followed by an absent grant SHALL produce `Deny(notGranted)`.

E. A precondition success followed by a present grant SHALL produce `Allow`.

F. `permissionsFor(principal)` SHALL return the permissions granted to `principal.role` filtered by each permission's scope precondition against the principal.

## Rationale

Precondition-first ordering gives the accurate reason for denial in the audit trail and in any UI response. A principal with no site selected attempting a site-scoped action is told "session precondition missing" (the actionable answer), not "not granted" (which invites a permissions audit when the underlying issue is "select a site first").

*End* *REQ-PERM-EVAL — Evaluation algorithm* | **Hash**: acdfb5d5

---

## REQ-d00177: REQ-PERM-SNAPSHOT — Client-side snapshot

**Level**: dev | **Status**: Draft | **Implements**: -

## Assertions

A. The system SHALL define a `PermissionSnapshot` type carrying a role, a set of granted permissions (each with its scope), and an `issuedAt` timestamp.

B. `PermissionSnapshot` SHALL be JSON-serializable for wire delivery from a server to clients.

C. The system SHALL provide `SnapshotRoleMatrixReader`, a `RoleMatrixReader` implementation backed by a single `PermissionSnapshot`.

D. `SnapshotRoleMatrixReader` SHALL return `false` from `isGranted` and the empty set from `grantsForRole` for any role other than the snapshot's role.

E. Clients SHALL construct `TableBackedAuthorizationPolicy` with a `SnapshotRoleMatrixReader` to evaluate permissions locally, using the same `AuthorizationPolicy` interface used server-side.

F. Matrix events SHALL NOT be synchronized to client `event_sourcing_datastore` instances by this library; clients receive only the principal-scoped `PermissionSnapshot`.

## Rationale

Local evaluation without round-trips is required for widget-enablement in the portal UI and for offline use in the mobile diary. A principal-scoped snapshot keeps client state minimal and avoids exposing other roles' grant information to clients. Restricting matrix events to server-side stores keeps admin grant data off patient devices.

*End* *REQ-PERM-SNAPSHOT — Client-side snapshot* | **Hash**: b8256380

---

## REQ-d00178: REQ-PERM-FAILSAFE — Fail-safe bootstrap

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-d00175

## Assertions

A. The host-facing bootstrap function `bootstrapActionPermissions(...)` SHALL return an `AuthorizationPolicyBootstrap` value; it SHALL NOT throw on seed validation failure.

B. Validation failure SHALL yield a `PolicyFailSafe` result carrying the error list, and SHALL NOT emit any `permission_granted` events.

C. `PolicyFailSafe.policy` SHALL be a `FailSafeAuthorizationPolicy` whose `isPermitted` returns `Deny(bootstrapFailure)` for every call and whose `permissionsFor` returns the empty set.

D. The `isReady` getter SHALL return `true` for `PolicyReady` and `false` for `PolicyFailSafe`.

E. Hosts SHALL wire `isReady` into their readiness signal (e.g. an HTTP `/readyz` endpoint on a server, or a Flutter app-state predicate) so an unhealthy policy prevents traffic or user interaction without crashing the process.

## Rationale

Crash-loop-on-bad-config masks the actual problem and hammers the orchestrator without improving the outcome. A fail-safe bootstrap surfaces the problem through the host's readiness signal while preserving the audit trail of the outage (denial events flow through the dispatcher normally) and allowing healthy revisions or processes to keep operating. Not emitting events on validation failure keeps the event log clean of partial seed runs that would have to be reconciled later.

*End* *REQ-PERM-FAILSAFE — Fail-safe bootstrap* | **Hash**: 075f8212
