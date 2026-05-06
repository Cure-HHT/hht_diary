# Audited Actions Library Specification

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2026-04-22
**Status**: Draft

> **See**: docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md for the full design (Sub-project A).
> **See**: prd-security-RBAC.md for the role-based access model underlying authorization (REQ-p00005, REQ-p00014).
> **See**: prd-event-sourcing-system.md for event-store contracts the dispatcher consumes.

---

## Executive Summary

The `apps/common-dart/audited_actions/` package defines the trusted-boundary gatekeeper for audited user actions. Every state-change reaching the host from an untrusted caller flows through its `ActionDispatcher`, which authenticates, authorizes, validates, executes, and records the outcome. Successful actions emit one or more typed events through the events lib (`appendWithSecurity`); denied attempts at any pipeline stage emit typed denial events into the same log.

This specification defines the contracts the package exposes (`Action`, `ActionRegistry`, `ActionDispatcher`, `AuthorizationPolicy`, `IdempotencyStore`) and the dispatcher's 10-stage pipeline.

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

## Section 4: Authorization Policy

# REQ-d00169: Authorization Policy

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00005, REQ-p00014

## Rationale

Authorization is pluggable behind an abstract policy so that deployments can choose between table-backed matrix lookups (production) and deny-all defaults (safe bootstrap). A discovery tool converts declared permissions into a SQL migration so the role-permission matrix grows monotonically and auditably.

## Assertions

A. `AuthorizationPolicy` SHALL be an abstract class with one method: `Future<bool> isPermitted(Principal principal, Permission permission, ActionContext ctx)`.

B. `TableBackedAuthorizationPolicy(RoleMatrixReader matrix)` SHALL read `principal.activeRole`, query `matrix.permissionsForRole(role)`, and SHALL return whether `permission.name` is present in the result. If `principal` is anonymous, it SHALL return `false` unconditionally.

C. `DenyAllAuthorizationPolicy` SHALL return `false` from every `isPermitted` call. The default constructor SHALL log a warning on every call (production-mode signal); a `DenyAllAuthorizationPolicy.forTests()` constructor SHALL suppress the warning.

D. The permission discovery tool SHALL emit a SQL migration with `INSERT ... ON CONFLICT DO NOTHING` rows for every permission in `registry.allDeclaredPermissions` not already present in the `role_permission_matrix_permissions` table. Permissions present in the database but absent from the registry SHALL be emitted as SQL comments only and SHALL NOT be auto-deleted.

*End* *Authorization Policy* | **Hash**: 3daddba7

---

## Section 5: Idempotency Contract

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

## Section 6: Denial Events

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

## Related Specifications

- **Design Document**: docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md
- **Event Sourcing**: prd-event-sourcing-system.md (REQ-p01000-p01019)
- **RBAC Model**: prd-security-RBAC.md (REQ-p00005, REQ-p00014)
- **Audit Trail**: prd-database.md (REQ-p00004, REQ-p00013)

---

## Revision History

| Version | Date       | Changes                                                              | Ticket   |
| ------- | ---------- | -------------------------------------------------------------------- | -------- |
| 1.0     | 2026-04-22 | Initial Audited Actions Library specification (REQ-d00166-d00171)    | CUR-1159 |

---

**Document Classification**: Internal Use - Development Specification
**Review Frequency**: Quarterly or when modifying the portal action pipeline
**Owner**: Development Team
