# Events Library Extensions and Audited Actions Library — Design

**Date:** 2026-04-22
**Status:** Design awaiting implementation
**Ticket:** TBD (to be claimed at implementation time, one per sub-project)
**Related design:** `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` (mobile worktree)
**Related plan:** `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.3_library.md` (mobile worktree)

## 1. Summary

Two sibling sub-projects, designed coherently in one document, implemented in two different worktrees and shipped as two PRs. Together they lay the foundation for unifying the portal's disparate event/audit stores and CRUD-style state tables behind a single event-sourced log with multiple materialized views — the portal-side counterpart to the mobile event-sourcing refactor.

- **Sub-project E — Events library extensions.** Additive changes to `apps/common-dart/append_only_datastore/`: replace `userId` with a polymorphic `Initiator` (User | Automation | Anonymous, with `triggeringEventId` on Automation for cascade audit), add a `flowToken` field for cross-aggregate / cross-session correlation, and add a sibling `EventSecurityContext` store with a configurable retention policy and a thorough redaction API. Implemented in the **mobile-event-sourcing-refactor** worktree because that lib's single source of truth lives there and the same envelope serves both sides.

- **Sub-project A — Audited actions library.** New package `apps/common-dart/audited_actions/`: an `Action<TInput, TResult>` interface, a dispatcher pipeline that authenticates / authorizes / validates / executes / records, a pluggable `AuthorizationPolicy` interface backed initially by a permissions-matrix table (and later a GUI), an `IdempotencyStore` for replay protection, and an automated permission-discovery tool that surfaces newly-declared permissions for admins to grant. Implemented in **this worktree** *after* Sub-project E lands on `main` (the actions lib consumes E's API surface).

This design produces no implementation in this brainstorm. Its outputs are this design doc and (next session) two implementation plans, one per sub-project.

## 2. Background

The portal's current state, scanned at design time:

```text
Existing portal-side audit/event stores (PostgreSQL):
  record_audit, record_state             diary CQRS (USER/INVESTIGATOR/ADMIN ops)
  auth_audit_log                         IDP authentication outcomes
  portal_user_audit_log                  portal-user lifecycle
  email_audit_log                        outbound email
  admin_action_log                       admin actions
  auditor_export_log                     compliance exports
  break_glass_access_log                 emergency-access usage
  edc_sync_log                           EDC system sync

Existing CRUD-style state tables to eventually become materialized views:
  portal_users, portal_user_roles, portal_user_site_access,
  portal_pending_email_changes, app_users, sites, patients,
  user_site_assignments, investigator_site_assignments,
  analyst_site_assignments, sponsor_role_mapping,
  patient_linking_codes, patient_fcm_tokens,
  email_otp_codes, email_rate_limits, system_config,
  questionnaire_instances, questionnaire_responses,
  investigator_annotations, sync_conflicts
```

The mobile event-sourcing refactor (in flight in PR 511 / branch `mobile-event-sourcing-refactor`) has produced a Dart library, `append_only_datastore`, with the right primitives for an event-sourced store: a typed event envelope (`StoredEvent`), a per-aggregate hash chain, a `StorageBackend` abstraction (sembast on mobile; portal will add a PostgreSQL impl), a destination/FIFO sync system, materializers, and a bootstrap entry point. The library was deliberately designed to be extended for portal use without changes to its core primitives — see `project_event_sourcing_refactor_out_of_scope.md` (deferred items 1, 2, 3, 8, 9).

What the library is missing for portal use, surfaced in this brainstorm:

1. **Actor identity is too narrow.** `StoredEvent.userId` assumes a human caller. Portal events come from many sources: human users in browsers, server-side automation (cron, handlers, mobile-sync ingestion), and unauthenticated callers (failed token verification). The current envelope can't represent these honestly.

2. **No cascade-audit linkage.** When an automation fires in response to an event (admin invites X → email service sends invite), there is no field to record that link. The existing per-aggregate hash chain captures *successive states of one aggregate*, not *one event causing another*.

3. **No cross-flow correlation.** Multi-step business flows (invitation issued → email sent → account activated) span aggregates and user sessions; today there is no first-class correlation field, so audit queries like "tell me everything that happened to invite ABC123" require post-hoc joins on aggregate-specific data fields.

4. **Security telemetry has no home.** IP / user-agent / session / geo are valuable for security investigation and required by regulation in some flows, but they are PII subject to retention limits — they cannot live forever in the immutable event log without GDPR friction. The library has no concept of a separately-retained security sidecar.

The portal also has no general purpose **command/intent** layer. Today, server-side endpoints in `portal_functions/lib/src/` execute their work inline: they verify the IDP token, look up the portal user, check role membership, validate request bodies, do the work, write to one or more of the disparate audit logs. Each endpoint is bespoke. There is no shared place to enforce "every state-change is auditable", no shared notion of a permission, no shared replay-protection, and no path that reliably records *denied* attempts.

The actions library closes both gaps. It is the trusted-boundary gatekeeper between untrusted callers (browsers, future-mobile-portal-API) and the events lib, and it is the single producer of event-shaped audit records on both success and denial paths. Server-side automation that lives inside the trust boundary writes events directly via the events lib — it does not need the actions lib's gatekeeping.

## 3. Goals

**Sub-project E:**

1. The event envelope honestly represents who or what initiated each event: a human user, a server-side automation (with an optional reference to the upstream event that triggered it), or an unauthenticated caller.
2. Multi-step business flows can be queried as a single audit story via a first-class correlation field, without post-hoc joins.
3. Security telemetry (IP / UA / session / geo) is captured atomically with the event it accompanies, persisted in a sibling store with a documented retention lifecycle, and removable on demand without violating the event log's immutability.
4. Library invariants make it harder to accidentally log secrets in events.

**Sub-project A:**

1. Every state-change reaching the host from an untrusted caller flows through one library-defined pipeline that authenticates, authorizes, validates, executes, and records the outcome.
2. Denied attempts (auth, authz, validation) emit denial events into the unified event log with the same primitives as successes, so audit queries see both.
3. Authorization is declarative on each action and pluggable behind an interface, so the future role-permission-matrix-managed-via-GUI can drop in without rewriting actions.
4. Newly-declared permissions are auto-discoverable, so admins are surfaced what's new to grant on each deploy.
5. Actions are testable in isolation: each is a class with pure `parseInput`, pure `validate`, pure `authorize`, and an `execute` that returns event drafts the dispatcher persists.
6. Idempotency is a first-class affordance, so retried HTTP calls don't double-write events.

## 4. Non-goals

1. **PostgreSQL `StorageBackend` implementation.** Lives in a separate "port the events lib to portal" ticket. This design assumes that backend will eventually exist; both sub-projects use the existing `StorageBackend` abstraction.
2. **Mobile-to-portal diary-sync ingestion endpoint.** Its own ticket.
3. **Concrete portal action catalog** (which actions exist, with what input shapes). Each per-area cutover ticket defines its own actions; this design defines the framework only.
4. **CRUD-table-to-materialized-view cutovers.** N future tickets, each scoped to one table or table cluster.
5. **Periodic retention-policy CRON job.** This design specifies the API the job will invoke. The cron infrastructure is an ops ticket.
6. **Role-permission matrix admin GUI.** Initial impl reads the matrix from a Postgres table; the GUI is a later concern.
7. **Scope-aware permissions** (e.g. `patient.read` for "this investigator's site only"). The `AuthorizationPolicy` interface admits future scope-aware impls; the initial impl returns coarse-grained yes/no per (principal, permission).
8. **OpenTelemetry integration.** Future enhancement: stamp each event's metadata with active trace/span context, and use OTel span links at async cross-trace boundaries. Metadata-only addition; no structural impact.
9. **Migration / rollback runbooks for cutover work.** System is greenfield; deferred until first deployment.
10. **Backfilling existing portal data into the unified event log.** No production data exists; cutover work simply removes the old tables and writes events going forward. (Greenfield status confirmed for both mobile and portal.)
11. **Sponsor isolation via `sponsor_id` plumbing or row-level security for tenancy.** Each sponsor gets its own deployment in a dedicated VPC; tenancy is an infrastructure concern, not a schema concern. The unified event log is single-tenant per deployment.
12. **Rate-limiting at the actions lib boundary.** HTTP-edge rate limiting (in front of the portal server) handles garbage-token floods; the actions lib only sees post-edge traffic.

## 5. Design decisions

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | **Two sibling sub-projects, not one.** Events lib extensions ship from the mobile worktree; actions lib ships from the portal worktree once E is on `main`. | Keeps the events lib's single source of truth where it already lives; the actions lib has a stable consumer API to design against; PRs are independently reviewable. |
| 2 | **Trust boundary is the architectural seam.** Actions lib is the gatekeeper for untrusted ingress; trusted in-process automation writes events directly via the events lib. | Forcing automation through an Action class would require fake authorization checks and a "system" pseudo-user. Two paths, honest about their differences, both producing identically-shaped events. |
| 3 | **Polymorphic `Initiator` replaces bare `userId`.** Sealed class with three variants: `User(userId)`, `Automation(service, triggeringEventId?)`, `Anonymous(ipAddress?)`. | The envelope tells the truth about who or what wrote each event. Mobile lib gains the same shape (greenfield; no migration cost). The PIN-login flow on mobile will use `Anonymous` and `User` variants. |
| 4 | **`Initiator.Automation.triggeringEventId` is the cascade audit link, not a separate `caused_by_event_id` field.** | Causation is a property of the actor's invocation, not a free-floating field callers might forget. User-initiated events have no upstream event (the user IS the cause); automation events optionally do. One field, located where it belongs. |
| 5 | **First-class `flowToken: String?` on `StoredEvent` for multi-step business-flow correlation.** | Compliance audit queries like "what happened to invite ABC123" should be a single SELECT, not a graph walk. Conventional metadata key would work but invites inconsistent naming and no guaranteed indexing; a typed field forces uniformity and makes storage backends responsible for indexing it. |
| 6 | **`EventSecurityContext` is a sibling store, not envelope fields.** Mutable, retention-policied, references events one-way. | The event log is the legal record (FDA satisfied by `Initiator` alone); IP/UA/session is supplementary security telemetry with its own GDPR-driven lifecycle. Putting it in the envelope would force one of: (a) keep IP forever (GDPR risk), or (b) mutate "immutable" rows to redact (breaks integrity model). The sidecar avoids the bind. |
| 7 | **Atomic write via `appendWithSecurity(draft, security)`.** Single backend transaction writes the event row and the security-context row together, or neither. | Partial writes would leave orphan security context or unrecordable security-bearing event. The transaction is straightforward in PostgreSQL (single tx with two INSERTs) and in sembast (single-isolate transaction serialization). |
| 8 | **`clearSecurityContext` itself emits an audit event.** The act of redaction is recorded in the immutable event log even though the redacted data is gone. | GDPR erasure requires the data to be gone; FDA audit requires the action to be recorded. The two coexist because the action-of-redaction is metadata about a transaction, not the redacted data itself. |
| 9 | **Retention policy is a value object with static defaults, configurable later.** Initial defaults: 90 days at full granularity, additional 365 days truncated, then drop. | Get the API right in this sub-project; defer "where do operators configure this" to ops tooling. The `applyRetentionPolicy(policy?)` and `clearSecurityContextOlderThan(duration)` calls give ops the levers without baking config-management into the lib. |
| 10 | **No-secrets invariant on event data and `flowToken`.** Cleartext OTPs, recovery tokens, session tokens, and any value whose mere knowledge confers authority MUST NOT appear in events. Hashes MAY. | Read-only access to the event log is a routine, broad attack surface (SIEM, backups, auditors, read replicas). Defense-in-depth requires keeping secrets out of the log even when full-DB-compromise would dwarf the threat. Documented as `REQ-EVENTS-NO-SECRETS`. |
| 11 | **Action is class-based, not function-based.** `class MyAction extends Action<TInput, TResult>` with `parseInput / validate / authorize / execute`. | Idiomatic Dart; testable in isolation; plays well with future codegen. Closures-with-builders work but get awkward when validation/authorization grow real logic. |
| 12 | **Multi-event actions are allowed.** `Action.execute()` returns `ExecutionResult { result, events: List<EventDraft> }`; dispatcher writes them in one transaction with shared `action_invocation_id` in metadata. | "Delete user" needs to emit revocation events across roles + sites + a tombstone; forcing one-event-per-action would create artificial sub-actions. Atomic multi-event keeps the audit story a single transaction. |
| 13 | **Pluggable `AuthorizationPolicy`.** Actions declare permissions; an injected policy resolves principal-x-permission-x-context. Initial impl reads from a Postgres `role_permission_matrix` materialized view. | The future permissions system is a user-definable role × code-derived-permission matrix, manageable via GUI. Decoupling actions from policy lets that future drop in without action rewrites. |
| 14 | **Permission discovery tool emits a SQL migration.** Walks the `ActionRegistry` at deploy time, finds permissions not present in the matrix, emits `INSERT ... ON CONFLICT DO NOTHING` rows in `unassigned` state. | New permissions surface to admins automatically on every deploy; admins explicitly grant them. No silent over-permissioning. |
| 15 | **Idempotency keys are optional per action, with three policies: `None`, `Optional`, `Required`.** Stored in `action_idempotency` keyed by `(action_name, principal_id, key)`. | Most actions are safe to retry without idempotency (they happen to be idempotent by design or have natural unique constraints); a few need it strictly (financial-equivalent operations like sending an invoice email). Per-action declaration matches reality. |
| 16 | **Denied attempts always emit denial events** (refined-A). Each pipeline-stage failure produces a typed denial event written via `events.appendWithSecurity` with the requesting principal's security context. Pre-auth garbage stays at the HTTP edge. | FDA / 21 CFR Part 11 want denied access in audit. Volume risk is low because IDP shields us from credential brute-force (the only category that could flood denial volume), and post-auth denials are real-user behavior at human cadence. |
| 17 | **Action dispatcher generates `action_invocation_id` per call**, stamps every emitted event's metadata with it. | Lets queries find "all events from this single user click" without inferring by timestamp + principal. Co-exists with `flowToken` (cross-flow) and `Initiator.triggeringEventId` (cascade); each handles a different scope. |

## 6. Sub-project E — Events library extensions

Implementation venue: **mobile-event-sourcing-refactor worktree**. Sequencing within that worktree's existing phase plan is the user's call (likely a new phase after current 4.3/4.6/5, or folded into one of them).

### 6.1 `Initiator` polymorphic actor type

New file: `apps/common-dart/append_only_datastore/lib/src/storage/initiator.dart`.

```text
sealed class Initiator
  toJson() : Map<String, dynamic>
  static Initiator fromJson(Map<String, dynamic>)

class UserInitiator extends Initiator
  final String userId

class AutomationInitiator extends Initiator
  final String service                 e.g. 'email-service', 'mobile-bg-sync'
  final String? triggeringEventId      cascade link; null for free-running
                                        automation (cron, scheduled job,
                                        observed external fact)

class AnonymousInitiator extends Initiator
  final String? ipAddress              best-known identifier; may be null
```

`StoredEvent.userId: String` is replaced by `StoredEvent.initiator: Initiator`. JSON shape on disk uses a discriminator field:

```text
"initiator": {
  "type": "user",        |  "type": "automation",            |  "type": "anonymous",
  "user_id": "..."          "service": "...",                   "ip_address": "..."
                            "triggering_event_id": "..."?
}
```

Mobile call-site migration: `userId: uid` → `initiator: UserInitiator(uid)`. Mobile background queue drains and similar use `AutomationInitiator(service: 'mobile-bg-sync')`. Pre-auth UI flows (the upcoming PIN-login screen) use `AnonymousInitiator(ipAddress: null)` until auth succeeds.

### 6.2 `flowToken` correlation field

`StoredEvent` gains a nullable field: `flowToken: String?`. Format convention (documented, not enforced): `'<aggregate-or-flow-name>:<id>'`, e.g. `'invite:ABC123'`, `'password-reset:XYZ'`, `'patient-enrollment:P-007'`. Storage backends are responsible for indexing the column / JSONB key for efficient lookup.

`EventDraft` (new helper type produced by callers, consumed by `appendWithSecurity`) carries `flowToken: String?`. Most events have none. When an action emits multiple events, a single `flowToken` is typically shared across them.

### 6.3 `EventSecurityContext` sibling store

New module: `apps/common-dart/append_only_datastore/lib/src/security/`.

```text
event_security_context.dart
  class EventSecurityContext
    final String eventId             FK to event_log.event_id (one-way)
    final DateTime recordedAt
    final String? ipAddress
    final String? userAgent
    final String? sessionId
    final String? geoCountry
    final String? geoRegion
    final String? requestId
    final DateTime? redactedAt
    final String? redactionReason

security_context_store.dart
  abstract class SecurityContextStore
    Future<void> write(EventSecurityContext)
    Future<EventSecurityContext?> read(String eventId)
    Future<int> applyRetentionPolicy(SecurityRetentionPolicy)
    Future<void> clearOne(String eventId, String reason)
    Future<int> clearOlderThan(Duration age, {String? reason})

sembast_security_context_store.dart
  class SembastSecurityContextStore implements SecurityContextStore
    backed by a sembast store; tests via in-memory backend

security_details.dart
  class SecurityDetails
    immutable input value passed by callers to appendWithSecurity;
    mirrors EventSecurityContext minus eventId/recordedAt/redaction
    fields (those are dispatcher-stamped on write)

security_retention_policy.dart
  class SecurityRetentionPolicy
    final Duration fullRetention            default 90 days
    final Duration truncatedRetention       default 365 days additional
    final bool truncateIpv4LastOctet        default true
    final bool truncateIpv6Suffix           default true   (/48)
    final bool dropUserAgentAfterFull       default true
    final bool dropGeoAfterFull             default false
    final bool dropAllAfterTruncated        default true

    static const SecurityRetentionPolicy defaults = const SecurityRetentionPolicy(...)
```

API additions on the events lib:

```text
appendWithSecurity(EventDraft draft, {SecurityDetails? security}) : Future<StoredEvent>
  single backend transaction:
    1. compute event_hash, sequence_number, etc.
    2. write event row to event_log
    3. if security != null: write EventSecurityContext row referencing
       the new event_id
  returns the persisted StoredEvent
  rollback semantics: failure at any step leaves neither row present

applyRetentionPolicy({SecurityRetentionPolicy? policy}) : Future<RetentionResult>
  policy ?? SecurityRetentionPolicy.defaults
  sweeps EventSecurityContext rows past their windows:
    - rows past fullRetention: truncate per policy flags
    - rows past fullRetention + truncatedRetention: delete or further drop
  returns counts (truncated, deleted)
  intended to be invoked by an external scheduler / cron

clearSecurityContext(String eventId, {required String reason,
                                       required Initiator redactedBy}) : Future<void>
  deletes the EventSecurityContext row for eventId
  emits a security_context_redacted event into the event log:
    aggregateType: 'security_context'
    aggregateId:   eventId
    eventType:     'redacted'
    initiator:     as supplied (UserInitiator(adminId) or
                   AutomationInitiator('retention-policy'))
    data:          { reason: '...' }
  the redaction itself is auditable forever; the redacted security
  data is gone.

clearSecurityContextOlderThan(Duration age, {required String reason,
                                              required Initiator redactedBy})
  bulk variant; emits ONE summary security_context_bulk_redacted event
  with { count: N, reason: '...', max_age_seconds: ... }
```

### 6.4 No-secrets invariant

Documented in `spec/dev-event-sourcing-mobile.md` as `REQ-EVENTS-NO-SECRETS`:

> Event `data` and `flowToken` fields SHALL NOT contain unhashed credentials, OTPs, recovery tokens, session tokens, or any other value whose mere knowledge confers authority. Hashes (sha256 or stronger, with sufficient entropy in the input to resist precomputation) MAY appear in event `data` when needed for later verification correlation. Secrets are owned by separate short-lived verification tables, not the event log. The library does not enforce this at runtime; callers (the actions lib, action implementations, automation handlers) are responsible.

Rationale: read-only access to the event log is a routine, broad attack surface (SIEM pipelines, audit backups, read replicas, compliance exports). Defense-in-depth requires keeping secrets out of the log even when full-DB-compromise would dwarf the immediate threat.

### 6.5 File plan

```text
apps/common-dart/append_only_datastore/lib/src/
  storage/
    initiator.dart                                   NEW
    stored_event.dart                                EDIT (userId -> initiator;
                                                            + flowToken)
    storage_backend.dart                             EDIT (+ appendWithSecurity)
  security/                                          NEW directory
    event_security_context.dart                      NEW
    security_context_store.dart                      NEW (abstract)
    sembast_security_context_store.dart              NEW
    security_details.dart                            NEW
    security_retention_policy.dart                   NEW
  bootstrap.dart                                     EDIT (wires the security store
                                                            via bootstrapAppendOnlyDatastore)

apps/common-dart/append_only_datastore/test/
  storage/
    initiator_test.dart                              NEW
    stored_event_test.dart                           EDIT
  security/
    event_security_context_test.dart                 NEW
    sembast_security_context_store_test.dart         NEW
    retention_policy_test.dart                       NEW
    append_with_security_atomicity_test.dart         NEW
    clear_security_context_emits_event_test.dart     NEW

spec/dev-event-sourcing-mobile.md                    EDIT (new REQ topics)
spec/INDEX.md                                        EDIT (new REQs registered)
```

Mobile call-site migrations across `apps/common-dart/`, `apps/daily-diary/`, and any other current consumers of `StoredEvent.userId` / `EntryService.record`'s userId parameter: replace bare userId with `UserInitiator(uid)`. Greenfield status applies; no compatibility shims needed.

### 6.6 REQ topics

Numbers claimed at implementation time via `discover_requirements("next available REQ-d")`. All land in `spec/dev-event-sourcing-mobile.md`.

```text
REQ-INITIATOR        sealed actor type with three variants; replaces userId on
                     StoredEvent and EntryService.record's parameter
                     assertions: A (sealed shape), B (JSON roundtrip), C (User
                     migration of mobile call sites), D (Automation.
                     triggeringEventId optional and references existing event
                     when set), E (Anonymous accepts null ipAddress)

REQ-FLOWTOKEN        nullable String? on StoredEvent and EventDraft; storage
                     backends MUST index for query
                     assertions: A (nullable), B (format convention documented),
                     C (multi-event actions share one), D (sembast indexed)

REQ-SECCTX           EventSecurityContext store and appendWithSecurity helper;
                     atomic write; one-way FK security -> event
                     assertions: A (sidecar separate from event row), B (FK
                     direction), C (atomic write rollback semantics), D (read
                     by event_id), E (write requires extant event_id)

REQ-RETENTION        SecurityRetentionPolicy value type, applyRetentionPolicy,
                     clearSecurityContext, clearSecurityContextOlderThan
                     assertions: A (policy value type with defaults), B (sweep
                     truncates IP per policy), C (sweep deletes past truncated
                     window), D (clearOne emits security_context_redacted
                     event in event log), E (bulk clear emits one summary
                     event), F (redaction events are themselves immutable)

REQ-EVENTS-NO-SECRETS   data + flowToken contain no cleartext secrets;
                        hashes acceptable; library does not enforce; caller
                        contract documented
                        assertions: A (statement of invariant), B (rationale
                        narrative), C (acceptable hash spec)
```

### 6.7 Testing

```text
Initiator
  - sealed pattern matching exhaustiveness compiles
  - equality / hashCode for each variant
  - JSON roundtrip per variant; discriminator field present
  - rejects unknown discriminator on fromJson

StoredEvent with initiator + flowToken
  - userId migration: existing mobile call sites compile
  - flowToken nullable; round-trips through sembast
  - sembast index on flowToken accelerates lookup (timing-tolerant
    test asserting count returned)

EventSecurityContext + sembast store
  - write then read round-trips
  - read on missing returns null
  - one-way FK direction: the security row references event_id;
    the event row holds no reference back to security
  - clearOne removes the security row without touching the
    referenced event row

appendWithSecurity atomicity
  - happy path: both rows present after commit
  - failure mid-transaction (force throw between writes): neither
    row present; storage state unchanged
  - security: null path: only event row present

Retention policy
  - defaults instance equals expected static
  - applyRetentionPolicy on rows just past fullRetention: IP
    truncated per flags, UA dropped per flag, geo per flag
  - applyRetentionPolicy on rows past full + truncated: rows
    deleted (or further dropped per flag)
  - applyRetentionPolicy is idempotent (second run on already-
    truncated rows: no change)

clearSecurityContext
  - clearOne removes the security context row
  - clearOne emits exactly one security_context_redacted event
    with correct aggregateType, aggregateId, initiator, reason
  - clearOlderThan emits one bulk-redacted event with count
  - the redaction events themselves cannot be deleted (event-log
    immutability invariant from existing tests)

No-secrets
  - documentation tests: spec text present in REQ assertions file
  - no runtime test (caller obligation, not lib enforcement)
```

## 7. Sub-project A — Audited actions library

Implementation venue: **this portal-event-sourcing worktree**, after Sub-project E lands on `main`. New package: `apps/common-dart/audited_actions/`.

### 7.1 Package shape

```text
apps/common-dart/audited_actions/
  pubspec.yaml                     name: audited_actions
                                    depends on: append_only_datastore (post-E),
                                                provenance, canonical_json_jcs,
                                                meta, async
  lib/
    audited_actions.dart            public exports
    src/
      action.dart                  Action<TInput, TResult> abstract;
                                    ExecutionResult<TResult>; EventDraft;
                                    Idempotency enum
      action_context.dart          ActionContext, Principal, SecurityDetails
                                    (re-exported from append_only_datastore)
      action_registry.dart         ActionRegistry
      action_dispatcher.dart       ActionDispatcher pipeline
      authorization_policy.dart    abstract AuthorizationPolicy;
                                    DenyAllAuthorizationPolicy
      table_backed_authorization_policy.dart  reads role_permission_matrix
                                                materialized view
      idempotency_store.dart       abstract IdempotencyStore;
                                    InMemoryIdempotencyStore
      bootstrap.dart               bootstrapAuditedActions()
      denial_events.dart           denial event drafts (UnknownAction,
                                    Parse, Validation, Authorization,
                                    ExecutionFailed)
      permission.dart              Permission value type
  test/
    action_dispatcher_test.dart
    idempotency_test.dart
    authorization_policy_test.dart
    bootstrap_test.dart
    denial_events_test.dart
  tool/
    discover_permissions.dart      CLI; emits SQL migration seeding new
                                    permissions
```

### 7.2 Core types

```text
abstract class Action<TInput, TResult>
  String get name                                      e.g. 'invite_user'
  String get description                               human-readable
  Set<Permission> get permissions                      declared; auto-discovered
  Idempotency get idempotency                          None | Optional | Required

  TInput parseInput(Map<String, dynamic> raw)          throws ParseError
  void validate(TInput input)                          throws ValidationError
  Future<ExecutionResult<TResult>> execute(
    TInput input,
    ActionContext ctx,
  )                                                    throws ExecutionFailedError

class Permission
  final String name                                    convention: <aggregate>.<verb>
                                                        e.g. 'user.invite',
                                                              'patient.enroll'

enum Idempotency
  none, optional, required

class ExecutionResult<TResult>
  final TResult result                                 returned to caller
  final List<EventDraft> events                        persisted atomically by
                                                        the dispatcher
  final SecurityDetails? securityDetailsOverride       rare; otherwise dispatcher
                                                        uses ctx.security

class EventDraft                                       (also defined in events lib;
                                                        actions lib re-exports)
  final String aggregateId
  final String aggregateType
  final String entryType
  final String eventType
  final Map<String, dynamic> data
  final String? flowToken
  final Map<String, dynamic>? metadata
                                                        initiator and
                                                        sequence/hash chain
                                                        filled by dispatcher

class ActionContext
  final Principal principal                            from auth middleware
  final SecurityDetails security                       from request
  final DateTime requestStartedAt
  final Reader read                                    materialized-view reader

sealed class Principal
  Principal.user(String userId, {Set<String> roles, String? activeRole, ...})
  Principal.anonymous({String? ipAddress})
  Initiator toInitiator()                              for stamping events
```

### 7.3 ActionRegistry and bootstrap

```text
class ActionRegistry
  void register<TI, TR>(Action<TI, TR> action)        throws on name collision
  Iterable<Action> get all
  Action? lookup(String name)
  Set<Permission> get allDeclaredPermissions          for matrix-population tool

class ActionDispatcher                                 see 7.4

bootstrapAuditedActions({
  required EventsApi events,                           thin handle on the events
                                                        lib's write surface (post-E:
                                                        appendWithSecurity, plus
                                                        whatever read access actions
                                                        need); concrete type name
                                                        decided in the events lib
                                                        implementation
  required AuthorizationPolicy authorization,
  required IdempotencyStore idempotency,
  required List<Action> actions,
}) : ActionDispatcher
  - validates no duplicate action.name (ArgumentError)
  - registers each action
  - returns ready dispatcher
```

### 7.4 Dispatcher pipeline

```text
class ActionDispatcher
  Future<DispatchResult<TResult>> dispatch<TInput, TResult>(
    String actionName,
    Map<String, dynamic> rawInput,
    ActionContext ctx, {
    String? idempotencyKey,
    String? flowToken,
  })

Pipeline (each stage failure -> denial event written via
events.appendWithSecurity with ctx.security):

  1. Lookup action by name
       miss -> emit UnknownActionDeniedEvent;
                return DispatchResult.unknownAction()

  2. Generate action_invocation_id (UUID per dispatch)

  3. Parse input
       action.parseInput(rawInput)
       throw -> emit ParseDeniedEvent (with action_name and
                                        sanitized error message);
                 return DispatchResult.parseDenied(error)

  4. Idempotency check (if action.idempotency != none and key supplied)
       lookup (action.name, principal.id, key) in IdempotencyStore
       hit -> return cached result (no new events written)

  5. Validate
       action.validate(input)
       throw -> emit ValidationDeniedEvent;
                 return DispatchResult.validationDenied(error)

  6. Authorize
       for each Permission p in action.permissions:
         if NOT await authorization.isPermitted(principal, p, ctx):
           emit AuthorizationDeniedEvent (records first failed permission);
           return DispatchResult.authorizationDenied(p)

  7. Execute
       result = await action.execute(input, ctx)
       throw -> emit ExecutionFailedEvent (with sanitized error);
                 return DispatchResult.executionFailed(error)

  8. Persist (single events-lib transaction):
       for each EventDraft d in result.events:
         d.initiator = ctx.principal.toInitiator()
         d.metadata['action_invocation_id'] = action_invocation_id
         d.metadata['action_name'] = action.name
         d.flowToken = d.flowToken ?? flowToken            (parameter is fallback)
         events.appendWithSecurity(d,
           security: result.securityDetailsOverride ?? ctx.security)

  9. Record idempotency entry (if applicable)
       store result + emitted event_ids; TTL per action policy

  10. Return DispatchResult.success(result, emittedEventIds)

class DispatchResult<TResult>
  sealed; variants: success, unknownAction, parseDenied,
  validationDenied, authorizationDenied, executionFailed,
  idempotencyHit
```

### 7.5 Authorization

```text
abstract class AuthorizationPolicy
  Future<bool> isPermitted(
    Principal principal,
    Permission permission,
    ActionContext ctx,
  )

class TableBackedAuthorizationPolicy implements AuthorizationPolicy
  TableBackedAuthorizationPolicy(this._matrixView)
    where _matrixView is a read-only handle on a materialized
    view derived from role-management events

  isPermitted: principal.activeRole -> permission set from matrix;
               return matrix.has(role: principal.activeRole,
                                  permission: permission.name)

  initial impl is coarse-grained (no scope/site/patient filter).
  ActionContext is in the signature so future scope-aware impls
  can read patient/site fields without breaking the contract.

class DenyAllAuthorizationPolicy implements AuthorizationPolicy
  isPermitted always returns false
  logs an error if used in production (intended for test setups)
```

### 7.6 Idempotency

```text
abstract class IdempotencyStore
  Future<IdempotencyEntry?> lookup(String actionName,
                                    String principalId,
                                    String key)
  Future<void> record(String actionName,
                       String principalId,
                       String key,
                       Map<String, dynamic> resultJson,
                       List<String> emittedEventIds,
                       DateTime expiresAt)
  Future<int> sweepExpired({DateTime? before})

class InMemoryIdempotencyStore implements IdempotencyStore
  Map-backed; for tests and per-process state during early
  development

(PostgreSQL impl arrives in the same later port ticket as the
events-lib backend.)

class IdempotencyEntry
  final Map<String, dynamic> resultJson
  final List<String> emittedEventIds
  final DateTime recordedAt
  final DateTime expiresAt

Default TTL: 24 hours; per-action override possible via Action subclass.

Replay semantics: lookup hit returns the cached result and
emittedEventIds without re-running the action; no new events
written; no idempotency record updated; the caller sees
DispatchResult.idempotencyHit(prior).
```

### 7.7 Permission discovery tool

```text
tool/discover_permissions.dart

Behavior (CLI shape decided at implementation time; here we pin the
contract):

  1. Given access to a populated ActionRegistry (the deploying app
     wires this — possibly via a small adapter script per app, or
     via a build-time codegen step, depending on what fits best
     with Dart's tree-shaking and the portal's deployment shape).
  2. Collects allDeclaredPermissions.
  3. Emits SQL:
       INSERT INTO role_permission_matrix_permissions (name, status)
         VALUES ('user.invite', 'unassigned'),
                ('patient.enroll', 'unassigned')
         ON CONFLICT (name) DO NOTHING;
  4. Optionally lists permissions present in DB but not in code
     (candidates for removal — emitted as comments only; never
     auto-deleted because they may be in active use by past events).

Run as part of CI / pre-deploy; the resulting migration is
committed and reviewed as a normal schema change.
```

### 7.8 Denial events

Each denial-stage emits a typed event into the unified event log:

```text
aggregateType: 'action_attempt'
aggregateId:    action_invocation_id
flowToken:      caller-supplied flowToken if any (preserved)
initiator:      ctx.principal.toInitiator()
metadata:       { action_invocation_id, action_name, denial_stage }

eventType per stage:
  unknown_action      data: { requested_name }
  parse_denied        data: { error_class, error_message_sanitized }
  validation_denied   data: { error_class, error_message_sanitized,
                              field_path? }
  authorization_denied data: { permission_denied,
                                principal_active_role? }
  execution_failed    data: { error_class, error_message_sanitized }
```

Sanitization: error messages are passed through a small allowlist filter (no stack traces, no echoed input values that may contain secrets, no internal paths). The unsanitized error is logged separately to the standard application log for ops debugging.

### 7.9 REQ topics

Numbers claimed at implementation time. All land in `spec/dev-audited-actions.md` (new file).

```text
REQ-ACTION       Action interface contract: parseInput pure;
                 validate pure (no I/O); authorize-via-policy
                 (not on the Action itself); execute returns
                 ExecutionResult atomically applied
                 assertions: A (interface shape), B (parse purity),
                 C (validate purity), D (execute returns
                 List<EventDraft>), E (Idempotency declared per
                 action)

REQ-ACTREG       ActionRegistry + bootstrapAuditedActions:
                 name uniqueness, registry exposure for permission
                 discovery
                 assertions: A (collision throws ArgumentError),
                 B (lookup returns registered action),
                 C (allDeclaredPermissions union)

REQ-DISPATCH     ActionDispatcher pipeline: ten stages, denial
                 event per failed stage, action_invocation_id
                 stamping, atomic event persistence, flowToken
                 propagation
                 assertions: A-J (one per pipeline stage and
                 invariant)

REQ-AUTHZ        AuthorizationPolicy interface, table-backed
                 impl, permission discovery tool
                 assertions: A (interface), B (table-backed
                 reads matrix view), C (deny-all variant logs
                 in production), D (discovery tool emits SQL),
                 E (discovery tool comments out absent perms)

REQ-IDEMPOT      Idempotency contract: per-action policy,
                 hash key, TTL, replay semantics
                 assertions: A (None policy: caller may not
                 supply key), B (Required policy: caller MUST
                 supply key), C (lookup hit short-circuits;
                 cached result returned), D (no events on hit),
                 E (sweepExpired removes past entries)

REQ-DENIAL       Denial events: typed shape per stage, error
                 sanitization, action_attempt aggregate type
                 assertions: A-E (one per denial event type
                 plus sanitization invariant)
```

### 7.10 Testing

```text
Each pipeline stage gets a focused test:
  - lookup miss
  - parse failure
  - idempotency hit (returns cached, emits nothing)
  - validation failure
  - authorization failure (single permission and multi-permission)
  - execution exception
  - successful single-event execute
  - successful multi-event execute (atomic; rollback on partial failure)

Multi-event atomicity:
  - inject failure on the second of three EventDrafts; assert
    all three rolled back; assert no idempotency record stored
  - inject failure on the security context write of the second
    event; assert all three rolled back including security rows

Idempotency:
  - InMemoryIdempotencyStore: lookup-after-record returns equivalent
  - lookup with different key: miss
  - lookup with different principal: miss
  - lookup with different action: miss
  - sweepExpired removes only past-expiry rows
  - record with TTL of 0: never returned by lookup

AuthorizationPolicy:
  - TableBackedAuthorizationPolicy: hits matrix view; respects
    activeRole; multi-permission action requires all
  - DenyAllAuthorizationPolicy: always denies; logs error in
    production-mode

Denial events:
  - one per stage written via appendWithSecurity
  - data shape per spec
  - sanitization: stack traces removed; echoed input redacted
  - action_invocation_id propagates through every emitted event
    in the dispatch (success and denial)

Bootstrap:
  - duplicate action.name throws
  - empty registry boots cleanly
  - registry exposes all declared permissions

Permission discovery:
  - given a fake registry of three actions (5 permissions),
    emits expected SQL with ON CONFLICT DO NOTHING
  - dry-run flag prints SQL to stdout without writing file
```

## 8. Out of scope (stated again, for spec-readers)

1. PostgreSQL `StorageBackend` and `IdempotencyStore` impls.
2. Mobile-to-portal diary-sync ingestion.
3. Concrete actions (per-area cutover tickets).
4. CRUD-table-to-materialized-view cutovers.
5. Periodic retention CRON wiring.
6. Role-permission matrix admin GUI.
7. Scope-aware permissions.
8. OpenTelemetry trace stamping (see §9).
9. Migration / rollback runbooks (greenfield).
10. Backfilling existing portal data.

## 9. Future work

1. **OpenTelemetry stamping.** When integrated, the actions lib's dispatcher captures the active OTel span context and stamps each emitted event's metadata with `trace_id`, `span_id`, `parent_span_id`. Direct events-lib callers (server-side automation outside the actions lib) use a small `otelStampedDraft(draft)` helper. At async cross-trace boundaries (e.g. a queue handler picking up a downstream event), the handler creates an OTel span LINK to the upstream trace; this co-exists with `Initiator.triggeringEventId` (the AUDIT cause) and serves a different audience (the TECHNICAL trace continuation).
2. **Scope-aware authorization.** Extend `AuthorizationPolicy` impls to read patient/site/sponsor scope from materialized views and intersect with principal's site/role assignments, without changing the interface.
3. **Action codegen.** Annotation-based `@Action` declarations auto-register; schema for inputs auto-derived from class fields. Optional ergonomic improvement; not needed for v1.
4. **Idempotency-key derivation helpers.** For HTTP middleware to derive a stable key from `Idempotency-Key` header or from a digest of (path, body) when the client didn't supply one.
5. **Permission sunset workflow.** When the discovery tool reports permissions in DB but absent from code, an ops workflow purges them (with migration showing prior usage).

## 10. Implementation sequencing

```text
Sub-project E (mobile worktree)
  - User decides where it slots in the existing mobile phase plan
    (PHASE4.3, PHASE4.6, PHASE5, or a new PHASE inserted after).
  - One PR; squashed phase commit per worktree convention.
  - Lands on main.

  ↓

Sub-project A (this worktree)
  - Begins after Sub-project E is on main.
  - One ticket; one PR.
  - Lands on main.

  ↓

(later, separate tickets)
  - PostgreSQL StorageBackend + IdempotencyStore impl
  - diary-sync ingestion endpoint + mobile-side destination
  - questionnaires cutover (mobile + portal simultaneously)
  - per-CRUD-table cutovers (one ticket each)
```

## Requirements

This design predates CLAUDE.md rule 7 and is preserved as a historical
reference. Canonical REQ assertions live in the dev-spec files:

- Sub-project E (events lib extensions) — implemented via CUR-1154 work
  on main; see `spec/dev-event-sourcing-datastore.md` for the
  authoritative event-store contracts (REQ-d00115..REQ-d00127 and
  follow-on phase 4.x REQs).
- Sub-project A (audited_actions) — REQ-d00166..REQ-d00171, see
  `spec/dev-audited-actions.md`.
- Sub-project A (action_permissions) — REQ-d00172..REQ-d00178, see
  `spec/dev-action-permissions.md`.

This document is reference-only; new assertions and edits should land in
the dev-spec files above, not here.
