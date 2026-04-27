# TODO Phase 4.4 — Events lib extensions for portal-side use

> **Source spec:** Sub-project E of `docs/superpowers/specs/2026-04-22-portal-events-and-actions-libs-design.md` (committed in the `portal-event-sourcing` worktree, on branch `portal-event-sourcing` at commit `eec2be12`). Cross-referenced ticket: **CUR-1159**.
>
> **Parent plan:** Slots between `PLAN_PHASE4.3_library.md` (library additions) and `PLAN_PHASE4.6_demo.md` (demo app). Naming convention `PLAN_PHASE4.4_*.md` would fit; user to choose final location/name when this becomes a formal plan.
>
> **Status:** Spec only. Not a full TDD task plan yet — write a `PLAN_PHASE4.4_*.md` via `superpowers:writing-plans` when ready to implement.
>
> **Greenfield context:** Both mobile and portal are greenfield (never deployed). Field renames (e.g. `StoredEvent.userId` → `StoredEvent.initiator`) and required-field additions are fine. No backwards-compatibility shims, no null-defaults-for-back-compat. Update mobile call sites in the same PR.

## Why this exists

The portal-side counterpart to CUR-1154 (this refactor) is being designed in the `portal-event-sourcing` worktree as CUR-1159. CUR-1159 splits into two sub-projects:

- **Sub-project E** — additive changes to `apps/common-dart/append_only_datastore/`. Belongs in this (mobile) worktree because the lib's single source of truth lives here and the same envelope serves both sides. **This TODO covers Sub-project E.**
- **Sub-project A** — new package `apps/common-dart/portal_actions/`, implemented in the portal worktree after this Sub-project E lands on `main`.

The PIN-login screen mentioned for the diary mobile UI also benefits directly from `Initiator.Anonymous` and `EventSecurityContext`, so these additions are not portal-only.

## Scope

Three additive changes to the events library, plus one documented invariant.

### 1. `Initiator` polymorphic actor type

Replace `StoredEvent.userId: String` with `StoredEvent.initiator: Initiator`. Sealed class with three variants:

```text
sealed class Initiator
  toJson() : Map<String, dynamic>
  static Initiator fromJson(Map<String, dynamic>)

class UserInitiator extends Initiator
  final String userId

class AutomationInitiator extends Initiator
  final String service                 e.g. 'email-service', 'mobile-bg-sync'
  final String? triggeringEventId      cascade audit link; null for free-running
                                        automation (cron, scheduled job, observed
                                        external fact)

class AnonymousInitiator extends Initiator
  final String? ipAddress              best-known identifier; may be null
                                        (use case: pre-auth UI flows like the
                                        upcoming PIN-login screen)
```

JSON shape on disk uses a discriminator field:

```text
"initiator": {
  "type": "user",        |  "type": "automation",            |  "type": "anonymous",
  "user_id": "..."          "service": "...",                   "ip_address": "..."
                            "triggering_event_id": "..."?
}
```

**Why no separate `caused_by_event_id` field:** causation is a property of the actor's invocation, not a free-floating field callers might forget to populate. Users don't have an upstream event (the user IS the cause); only automation does, and it carries `triggeringEventId` in its `Initiator` variant.

**Mobile call-site migration:**
- `userId: uid` → `initiator: UserInitiator(uid)` everywhere.
- Background queue drains and similar use `AutomationInitiator(service: 'mobile-bg-sync')`.
- Pre-auth flows (PIN-login screen) use `AnonymousInitiator(ipAddress: null)` until auth succeeds, then transition to `UserInitiator`.

### 2. `flowToken` correlation field

`StoredEvent` gains a nullable field: `flowToken: String?`. `EventDraft` (the value type callers construct to pass to `appendWithSecurity`) carries the same field.

Format convention (documented, not enforced): `'<aggregate-or-flow-name>:<id>'`, e.g. `'invite:ABC123'`, `'password-reset:XYZ'`, `'patient-enrollment:P-007'`.

Storage backends are responsible for indexing the column / JSONB key for efficient lookup. Sembast: index. PostgreSQL (post-port-ticket): GIN index on the JSONB key, or dedicated indexed column.

**Use case:** multi-step business flows that span aggregates and user sessions are queryable as a single audit story by SELECTing on `flowToken`. Concrete example: invitation lifecycle:

```text
1. invite_created event       flow_token = 'invite:ABC123'
2. invite_email_sent event    flow_token = 'invite:ABC123'   (cascade automation)
3. invite_activated event     flow_token = 'invite:ABC123'   (user clicked link)
```

Audit query "what happened to invite ABC123" becomes one SELECT, no graph walk.

### 2b. `EventDraft` shape (consumed by `appendWithSecurity`)

The portal actions library (CUR-1159 Sub-project A) expects `EventDraft` to be a public value type with at least these fields and methods:

```text
class EventDraft
  final String aggregateId
  final String aggregateType
  final String entryType
  final String eventType
  final Map<String, dynamic> data
  final String? flowToken
  final Map<String, dynamic>? metadata
  final Initiator? initiator                 nullable; dispatcher fills if absent

  EventDraft({
    required aggregateId, aggregateType, entryType, eventType, data,
    flowToken, metadata, initiator,
  })

  /// Returns a new EventDraft with the supplied fields overridden.
  /// Used by the actions-lib dispatcher to stamp initiator, flowToken,
  /// and merged metadata onto drafts produced by an action's execute().
  EventDraft copyWith({
    String? aggregateId,
    String? aggregateType,
    String? entryType,
    String? eventType,
    Map<String, dynamic>? data,
    String? flowToken,
    Map<String, dynamic>? metadata,
    Initiator? initiator,
  })
```

Hash chain fields (`event_hash`, `previous_event_hash`, `sequence_number`) are NOT on `EventDraft`; the events lib computes those at append time and writes them onto the resulting `StoredEvent`. `appendWithSecurity` returns the persisted `StoredEvent`; the actions-lib dispatcher reads `stored.eventId` to populate idempotency-record bookkeeping.

For test-fixture convenience, the events lib SHOULD also provide a `StoredEvent.synthetic({...})` factory that constructs a StoredEvent with caller-supplied fields (no real hashing) — this lets downstream packages write in-memory `StorageBackend` doubles without re-implementing the hash chain. Mark it `@visibleForTesting`.

### 3. `EventSecurityContext` sibling store

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

API additions on the events lib (likely on `EventRepository` or `EntryService`; finalize at impl time):

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
  intended to be invoked by an external scheduler / cron (caller's
  responsibility — this lib does not own the schedule)

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

clearSecurityContextOlderThan(Duration age,
                              {required String reason,
                               required Initiator redactedBy})
  bulk variant; emits ONE summary security_context_bulk_redacted event
  with { count: N, reason: '...', max_age_seconds: ... }
```

**Why a sibling store, not envelope fields:** the event log is the legal record (FDA / ALCOA+ satisfied by `Initiator` alone); IP/UA/session is supplementary security telemetry with its own GDPR-driven lifecycle. Putting it in the envelope would force one of: (a) keep IP forever (GDPR risk), or (b) mutate "immutable" rows to redact (breaks integrity model). The sidecar avoids the bind.

**FK direction:** security context references event (`security.event_id` → `event_log.event_id`). The event row holds **no reference back** to security. This means redacting security never touches the event row, and the event log can be exported / replicated without security details.

**Atomic write:** `appendWithSecurity` MUST commit both the event row and the security row in one backend transaction, or commit neither. In sembast that's `db.transaction((txn) async { ... })`. In future PostgreSQL: a single SQL transaction with two INSERTs.

**The act of redaction is auditable:** `clearSecurityContext` writes a `security_context_redacted` event into the immutable event log with the supplied `Initiator` and `reason`. So even though the redacted data is gone, the action of redaction is permanently recorded. This is essential for the GDPR-erasure / FDA-audit reconciliation: data gone, but action recorded.

### 4. No-secrets invariant (documented contract, not runtime-enforced)

Add to `spec/dev-event-sourcing-mobile.md` as `REQ-EVENTS-NO-SECRETS`:

> Event `data` and `flowToken` fields SHALL NOT contain unhashed credentials, OTPs, recovery tokens, session tokens, or any other value whose mere knowledge confers authority. Hashes (sha256 or stronger, with sufficient entropy in the input to resist precomputation) MAY appear in event `data` when needed for later verification correlation. Secrets are owned by separate short-lived verification tables, not the event log. The library does not enforce this at runtime; callers are responsible.

**Rationale:** read-only access to the event log is a routine, broad attack surface — SIEM pipelines, audit backups, read replicas, compliance exports, human auditors with SELECT privileges. Defense-in-depth requires keeping secrets out of the log even when full-DB-compromise would dwarf the immediate threat. The actions lib (CUR-1159 Sub-project A) and any direct-write automation handlers are the parties responsible for honoring this.

## File plan

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

spec/dev-event-sourcing-mobile.md                    EDIT (new REQ topics — see below)
spec/INDEX.md                                        EDIT (new REQs registered)

Mobile call-site migrations across:
  apps/common-dart/                                  any current consumers of
  apps/daily-diary/                                  StoredEvent.userId or
  any other current consumers                        EntryService.record's
                                                     userId param: replace bare
                                                     userId with UserInitiator(uid).
                                                     Greenfield; no shims.
```

## REQ topics to claim

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

## Testing strategy

```text
Initiator
  - sealed pattern matching exhaustiveness compiles
  - equality / hashCode for each variant
  - JSON roundtrip per variant; discriminator field present
  - rejects unknown discriminator on fromJson

StoredEvent with initiator + flowToken
  - userId migration: existing mobile call sites compile after replacement
  - flowToken nullable; round-trips through sembast
  - sembast index on flowToken accelerates lookup (timing-tolerant test
    asserting count returned)

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

## Out of scope for Phase 4.4

1. PostgreSQL `StorageBackend` implementation — separate "port to portal" ticket.
2. Periodic retention CRON wiring (the cron infrastructure that calls `applyRetentionPolicy`) — ops ticket; this phase only specifies the API.
3. The portal actions library itself (Sub-project A of CUR-1159) — implemented separately in the portal worktree after this lands.
4. Diary-sync mobile→portal ingestion endpoint — its own ticket.
5. OpenTelemetry stamping of events with trace/span context — future enhancement; metadata-only addition.
6. Encryption-at-rest of the security context (currently plain in sembast) — separate ticket if needed.

## Sequencing

This phase depends on Phase 4.3 being complete (so the existing `EntryService.record` and `StorageBackend` are in their post-4.3 shape that this phase modifies). It can land before or after Phase 4.6 (the demo) — the demo would benefit from being able to exercise security context and PIN-login if Phase 4.4 lands first, but the demo is not a hard prerequisite. User chooses ordering.

After Phase 4.4 lands on `main`, the portal worktree's CUR-1159 Sub-project A becomes unblocked.

## Acceptance

This TODO is complete when a corresponding `PLAN_PHASE4.4_*.md` (or whatever name fits the worktree's plan layout) has been written via `superpowers:writing-plans`, the implementation has been TDD'd through, all new REQ assertions pass their tests, mobile call sites have been migrated to `UserInitiator`, and the PR has been merged to `main`.
