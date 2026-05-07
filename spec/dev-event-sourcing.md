# Event Sourcing Library Specification

**Version**: 1.1
**Audience**: Development
**Last Updated**: 2026-05-07
**Status**: Draft

> **See**: docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md for the actions module design (Sub-project A).
> **See**: docs/superpowers/specs/2026-04-23-action-permissions-design.md for the permissions module design.
> **See**: prd-security-RBAC.md for the role-based access model underlying authorization (REQ-p00005, REQ-p00014).
> **See**: prd-event-sourcing-system.md for event-store contracts the dispatcher consumes.

---

## Executive Summary

The `apps/common-dart/event_sourcing/` package provides the full event-sourcing stack:

- **Actions module** (`lib/src/actions/`): the trusted-boundary gatekeeper for audited user actions. Every state-change reaching the host from an untrusted caller flows through its `ActionDispatcher`, which authenticates, authorizes, validates, executes, and records the outcome. Successful actions emit one or more typed events through the event store (`appendWithSecurity`); denied attempts at any pipeline stage emit typed denial events into the same log.

- **Permissions module** (`lib/src/permissions/`): the role-permission matrix mapping layer. The matrix is event-sourced — `permission_granted` and `permission_revoked` events drive a `RolePermissionGrantsMaterializer` that maintains the `role_permission_grants` view. Authorization policy queries are answered by a `TableBackedAuthorizationPolicy` backed by a `RoleMatrixReader`.

This specification defines the contracts both modules expose and the dispatcher's 10-stage pipeline.

---

## Section 1: Action Interface

# REQ-d00166: Action Interface Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00005

## Rationale

`Action<TInput, TResult>` is the unit of work through which every audited state-change flows. Separating the interface from the dispatcher ensures each action declares its own permission surface, input type, validation, and execution, while authorization is centralized in a pluggable policy. Pure methods (`parseInput`, `validate`) enable safe, side-effect-free rejection before any execution-stage work runs.

## Assertions

A. The system SHALL define `Action<TInput, TResult>` as an abstract class with the following members: `name: String`, `description: String`, `permissions: Set<Permission>`, `idempotency: Idempotency`, and four methods: `parseInput(Map<String, dynamic>) -> TInput`, `validate(TInput) -> void`, `execute(TInput, ActionContext) -> Future<ExecutionResult<TResult>>`.

B. Authorization SHALL NOT be a method on `Action`; the dispatcher SHALL evaluate `action.permissions` against an injected `AuthorizationPolicy`.

C. `Action.parseInput` SHALL be pure: no I/O, no mutation of global state. It SHALL throw a subtype of `Exception` (conventionally `ParseError`) on malformed input.

D. `Action.validate` SHALL be pure: no I/O. It SHALL throw `ValidationError` on invalid input. It MAY use `ActionContext.read` for synchronous cross-field validation only when the relevant materialized view is synchronously accessible; otherwise validation SHALL be performed inside `execute`.

E. `Action.execute` SHALL return `ExecutionResult<TResult> { result: TResult, events: List<EventDraft>, securityDetailsOverride: SecurityDetails? }`. The `events` list SHALL be empty or contain one or more `EventDraft` instances; the dispatcher persists them atomically.

F. `Action.idempotency` SHALL declare exactly one of `Idempotency.none`, `Idempotency.optional`, `Idempotency.required`. The dispatcher SHALL reject calls that violate the policy (e.g. `required` without a key SHALL return `DispatchResult.parseDenied(MissingIdempotencyKeyError)`).

*End* *Action Interface Contract* | **Hash**: ae3f6e96

---

## Section 2: Action Registry and Bootstrap

# REQ-d00167: ActionRegistry and Bootstrap

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00005

## Rationale

A single registry of all known actions enables (a) name-based lookup by the dispatcher, (b) permission discovery for the role-permission matrix migration tool, and (c) collision detection at bootstrap time rather than at first call. The bootstrap helper is the deploying app's one-call entry point; it composes all dependencies and returns a ready dispatcher.

## Assertions

A. `ActionRegistry.register<TI, TR>(Action<TI, TR> action)` SHALL throw `ArgumentError` if `action.name` collides with an already-registered action.

B. `ActionRegistry.lookup(String name)` SHALL return the registered `Action` or `null` if none is registered under that name.

C. `ActionRegistry.allDeclaredPermissions: Set<Permission> get` SHALL return the union of `permissions` across all registered actions.

D. `bootstrapAuditedActions({events, authorization, idempotency, actions})` SHALL register every supplied action (rejecting collisions per A) and SHALL return a ready `ActionDispatcher`.

*End* *ActionRegistry and Bootstrap* | **Hash**: 0f53c3bd

---

## Section 3: Dispatcher Pipeline

# REQ-d00168: Dispatcher Pipeline

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00005, REQ-p00013

## Rationale

The dispatcher pipeline is the single path through which untrusted input reaches the event store. Each stage is explicit and ordered so that failure modes are uniformly recorded as typed denial events (correlated by `action_invocation_id`), atomic persistence is guaranteed, and idempotency is enforced without ambiguity.

## Assertions

A. `ActionDispatcher.dispatch(actionName, rawInput, ctx, {idempotencyKey?, flowToken?})` SHALL execute the following pipeline. Each stage that fails SHALL emit a typed denial event into the events lib (per REQ-d00171) and SHALL return the corresponding `DispatchResult` variant; subsequent stages SHALL NOT run.

B. Stage 1 (lookup): if `actionName` is unknown, the dispatcher SHALL emit an `unknown_action` denial and SHALL return `DispatchResult.unknownAction(name)`.

C. Stage 2 (invocation_id): the dispatcher SHALL generate a v4 UUID and SHALL stamp every emitted event's `metadata['action_invocation_id']` with this id (denial events included).

D. Stage 3 (parse): the dispatcher SHALL call `action.parseInput(rawInput)`; on throw, it SHALL emit `parse_denied` and SHALL return `DispatchResult.parseDenied(error)`.

E. Stage 4 (idempotency check): if `action.idempotency != none` and `idempotencyKey != null`, the dispatcher SHALL look up `(action.name, principal.id, idempotencyKey)` in the `IdempotencyStore`. On a non-expired hit, it SHALL short-circuit and SHALL return `DispatchResult.idempotencyHit(prior)` without emitting any new event.

F. Stage 5 (validate): the dispatcher SHALL call `action.validate(input)`; on throw, it SHALL emit `validation_denied` and SHALL return `DispatchResult.validationDenied(error)`.

G. Stage 6 (authorize): for each `Permission p` in `action.permissions`, the dispatcher SHALL await `authorization.isPermitted(principal, p, ctx)`. On the first `false`, it SHALL emit `authorization_denied(p)` and SHALL return `DispatchResult.authorizationDenied(p)`.

H. Stage 7 (execute): the dispatcher SHALL call `action.execute(input, ctx)`; on throw, it SHALL emit `execution_failed` and SHALL return `DispatchResult.executionFailed(error)`.

I. Stage 8 (persist): inside one `events.transaction` block, the dispatcher SHALL, for each `EventDraft d` in `result.events`, stamp `d.initiator = ctx.principal.toInitiator()`, `d.metadata['action_invocation_id'] = invocation_id`, `d.metadata['action_name'] = action.name`, and `d.flowToken = d.flowToken ?? flowToken`; then it SHALL call `txn.appendWithSecurity(d, security: result.securityDetailsOverride ?? ctx.security)`. If any append throws, the entire transaction SHALL roll back; the dispatcher SHALL emit `execution_failed` and SHALL return `DispatchResult.executionFailed(error)`.

J. Stage 9 (record idempotency): if `action.idempotency != none` and `idempotencyKey != null`, the dispatcher SHALL store `(action.name, principal.id, idempotencyKey, resultJson, emittedEventIds, expiresAt)` via the `IdempotencyStore`.

K. Stage 10 (return): the dispatcher SHALL return `DispatchResult.success(result, emittedEventIds)`.

*End* *Dispatcher Pipeline* | **Hash**: 6b65ebee

---

## Section 4: Idempotency Contract

# REQ-d00170: Idempotency Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01002

## Rationale

Replay protection is essential for networked client actions (browsers retrying on timeout, mobile-portal API retries). The `Idempotency` enum lets each action declare whether a key is ignored, optional, or required; the store is keyed per-(action, principal, key) so different principals cannot collide. A default 24-hour TTL is sufficient for user-facing retry windows and bounds store growth.

## Assertions

A. When `action.idempotency == Idempotency.none`, the dispatcher SHALL ignore any `idempotencyKey` parameter (no lookup, no record).

B. When `action.idempotency == Idempotency.required` and the caller does not supply `idempotencyKey`, the dispatcher SHALL emit `parse_denied(MissingIdempotencyKeyError)` and SHALL return `DispatchResult.parseDenied(...)` before running `parseInput`.

C. When `action.idempotency == Idempotency.optional` and the caller does not supply `idempotencyKey`, the dispatcher SHALL skip both lookup and record stages but SHALL otherwise proceed normally.

D. An idempotency lookup hit SHALL return the cached `resultJson` and `emittedEventIds`; the dispatcher SHALL NOT re-run the action and SHALL NOT emit any new event (success or denial).

E. `IdempotencyStore.sweepExpired({DateTime? before})` SHALL delete entries whose `expiresAt` is at or before `before` (default `DateTime.now()`); it SHALL return the count deleted.

F. The default TTL SHALL be 24 hours; an action MAY override via an `idempotencyTtl: Duration` getter whose default returns `Duration(hours: 24)`.

*End* *Idempotency Contract* | **Hash**: afd86f83

---

## Section 5: Denial Events

# REQ-d00171: Denial Events

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00013

## Rationale

Every denied attempt is an auditable event of equal weight to a success. Persisting denials through the same event store (correlated by `action_invocation_id`) enables audit queries that reconstruct the full history of any attempted action without cross-system joins. Sanitization protects the audit trail from leaking caller-supplied payloads that could expose PII or secrets.

## Assertions

A. Every denial event SHALL be an `EventDraft` with `aggregateType: 'action_attempt'`, `aggregateId: <action_invocation_id>`, and `entryType: 'action_denial'`. The `eventType` SHALL be one of: `unknown_action`, `parse_denied`, `validation_denied`, `authorization_denied`, `execution_failed`.

B. Denial event `data` SHALL contain at minimum `error_class: String` and `error_message_sanitized: String`. An `authorization_denied` event SHALL additionally contain `permission_denied: String` and (when available) `principal_active_role: String`. An `unknown_action` event SHALL contain `requested_name: String`.

C. Sanitization SHALL strip stack traces, file paths, and any value that may echo caller-supplied input (including the raw input map). The unsanitized error SHALL be logged separately via `package:logging` for operational debugging.

D. Denial events SHALL be persisted via the same `events.appendWithSecurity` path as success events, including the supplied `SecurityDetails` from `ctx.security`.

E. Every denial event SHALL share the same `action_invocation_id` as the dispatch attempt (in `metadata`), enabling audit queries to correlate the entire attempt's history.

*End* *Denial Events* | **Hash**: 31533023

---

## Section 6: Permission Scope Class

# REQ-d00172: REQ-PERM-SCOPE — Permission scope class enumeration

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-d00168

## Assertions

A. The system SHALL define a closed enumeration `ScopeClass` with three values: `global`, `site`, `self`.

B. The system SHALL require every `Permission` to declare a `scope` of type `ScopeClass`.

C. The system SHALL reject at boot, via the `ActionRegistry`, any two registered permissions with the same `name` but differing `scope` values.

## Rationale

A closed scope enumeration is the shared vocabulary between the actions module (where permissions are declared by Actions) and the permissions module (where they are evaluated against the matrix). Keeping the set closed and small makes authorization decisions statically reasonable: an auditor can list every permission a role holds and inspect each one's scope without reading code. Rejecting same-name-different-scope at boot prevents silent divergence between Actions that declare the same permission identifier.

*End* *REQ-PERM-SCOPE — Permission scope class enumeration* | **Hash**: 57b8525d

---

## Section 7: Authorization Policy Interface Shape

# REQ-d00173: REQ-PERM-POLICY — AuthorizationPolicy interface shape

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

## Section 8: Event-Sourced Matrix and Materialized View

# REQ-d00174: REQ-PERM-MATRIX — Event-sourced matrix and materialized view

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-p00005

## Assertions

A. The system SHALL define two event types persisted via the event store: `permission_granted` (payload `{role, permissionName, scope}`) and `permission_revoked` (payload `{role, permissionName}`). Both events use `aggregateType: 'role_permission_grant'` and `aggregateId: '<role>:<permissionName>'`.

B. The system SHALL define a `RolePermissionGrantsMaterializer` extending the library's `Materializer`, with `viewName: 'role_permission_grants'`, that folds matching events into the view: `permission_granted` SHALL upsert a row keyed by `aggregateId` with payload `{role, permissionName, scope}`; `permission_revoked` SHALL delete the row keyed by `aggregateId`.

C. A grant SHALL be represented by the presence of a view row produced by the materializer; absence of a row SHALL mean no grant, regardless of whether the row was never written or was removed by a `permission_revoked` event.

D. The materializer SHALL run inside the same backend transaction as the appending event; a thrown error in `applyInTxn` SHALL roll back the entire append.

E. The system SHALL provide a `MaterializedViewRoleMatrixReader` implementing `RoleMatrixReader` that answers `isGranted` via a single view-row read keyed by `'<role>:<permissionName>'`, and answers `grantsForRole` via a view scan filtered to rows whose `role` field matches.

F. The system SHALL reject role names and permission names containing the `:` character at validation time, since `:` is the composite-aggregateId delimiter.

G. The matrix SHALL NOT carry sponsor identity: deployments are single-tenant per sponsor.

## Rationale

Event-sourcing the matrix unifies its persistence with the rest of the platform's audit story: every grant and revocation is a permanent, attributable event. Per-pair aggregates keep the materializer's fold step a pure upsert or delete with no read-modify-write inside the transaction, so concurrent grants of different pairs cannot conflict. The view-scan for `grantsForRole` is acceptable because the matrix is small (tens of roles, hundreds of permissions). Forbidding `:` in names protects the composite-aggregateId encoding from ambiguity.

*End* *REQ-PERM-MATRIX — Event-sourced matrix and materialized view* | **Hash**: 9e1051ed

---

## Section 9: YAML Seed, Validation, and Event-Emitting Applier

# REQ-d00175: REQ-PERM-SEED — YAML seed, validation, and event-emitting applier

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

## Section 10: Evaluation Algorithm

# REQ-d00176: REQ-PERM-EVAL — Evaluation algorithm

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

## Section 11: Client-Side Snapshot

# REQ-d00177: REQ-PERM-SNAPSHOT — Client-side snapshot

**Level**: dev | **Status**: Draft | **Implements**: -

## Assertions

A. The system SHALL define a `PermissionSnapshot` type carrying a role, a set of granted permissions (each with its scope), and an `issuedAt` timestamp.

B. `PermissionSnapshot` SHALL be JSON-serializable for wire delivery from a server to clients.

C. The system SHALL provide `SnapshotRoleMatrixReader`, a `RoleMatrixReader` implementation backed by a single `PermissionSnapshot`.

D. `SnapshotRoleMatrixReader` SHALL return `false` from `isGranted` and the empty set from `grantsForRole` for any role other than the snapshot's role.

E. Clients SHALL construct `TableBackedAuthorizationPolicy` with a `SnapshotRoleMatrixReader` to evaluate permissions locally, using the same `AuthorizationPolicy` interface used server-side.

F. Matrix events SHALL NOT be synchronized to client event store instances by this library; clients receive only the principal-scoped `PermissionSnapshot`.

## Rationale

Local evaluation without round-trips is required for widget-enablement in the portal UI and for offline use in the mobile diary. A principal-scoped snapshot keeps client state minimal and avoids exposing other roles' grant information to clients. Restricting matrix events to server-side stores keeps admin grant data off patient devices.

*End* *REQ-PERM-SNAPSHOT — Client-side snapshot* | **Hash**: 01f857d7

---

## Section 12: Fail-Safe Bootstrap

# REQ-d00178: REQ-PERM-FAILSAFE — Fail-safe bootstrap

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

---

## Related Specifications

- **Actions Design Document**: docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md
- **Permissions Design Document**: docs/superpowers/specs/2026-04-23-action-permissions-design.md
- **Event Sourcing**: prd-event-sourcing-system.md (REQ-p01000-p01019)
- **RBAC Model**: prd-security-RBAC.md (REQ-p00005, REQ-p00014)
- **Audit Trail**: prd-database.md (REQ-p00004, REQ-p00013)

---

## Revision History

| Version | Date       | Changes                                                              | Ticket   |
| ------- | ---------- | -------------------------------------------------------------------- | -------- |
| 1.0     | 2026-04-22 | Initial Audited Actions Library specification (REQ-d00166-d00171)    | CUR-1159 |
| 1.0     | 2026-04-23 | Action Permissions specification (REQ-d00172-d00178)                 | CUR-1192 |
| 1.1     | 2026-05-07 | Merged into single spec for consolidated event_sourcing package      | CUR-1192 |

---

**Document Classification**: Internal Use - Development Specification
**Review Frequency**: Quarterly or when modifying the event sourcing action/permissions pipeline
**Owner**: Development Team
