# Phase 4.4 — Events lib extensions for portal use

**Date**: 2026-04-22
**Branch**: `mobile-event-sourcing-refactor`
**Linear ticket**: CUR-1154 (parent), CUR-1159 (portal-side counterpart Sub-project E)
**Status**: Design — pending implementation plan

---

## 1. Motivation

The portal-server side of the event-sourcing system (CUR-1159) is being designed in a separate worktree and needs the events library to grow universal extensions before the portal actions library is built. The same extensions also unblock the mobile PIN-login flow (`AnonymousInitiator`) and close a long-standing tamper-evidence gap on event metadata.

Phase 4.4's job is to ship those events-lib changes — identity, correlation, security context, multi-materialized-view support — without disturbing the in-flight Phase 4.3 deliverables and without touching the `clinical_diary` app (Phase 5's job is to wire the renamed `EventStore` into widgets and remove the legacy `EventRepository`/`NosebleedService` path).

The design source is `TODO4.4.md` at the worktree root, which captured the spec from the portal worktree (`docs/superpowers/specs/2026-04-22-portal-events-and-actions-libs-design.md` Sub-project E, committed in `portal-event-sourcing` at `eec2be12`). Multi-materializer support and storage-failure handling were surfaced during this brainstorm; multi-materializer is folded into Phase 4.4, storage failure is split into Phase 4.5 (its own design doc at `docs/superpowers/2026-04-22-storage-failure-handling-design.md` already exists).

## 2. Scope

| In Phase 4.4 | Deferred to Phase 4.5 | Deferred to Phase 4.6 |
| --- | --- | --- |
| `Initiator` polymorphic actor type | `StorageException` taxonomy + classifier | Phase 4.6 demo app |
| `flow_token` correlation field | Storage Health query / stream surface | Multi-materializer worked example (red/green/blue button toggle as second view) |
| `EventSecurityContext` sidecar store | Storage Failure Audit log | |
| `EventStore` (rename from `EntryService`) with universal `append` API | `FailureInjector` test seam | |
| `Source` (rename from `DeviceInfo`) | `EntryService.record` failure-classification wrap | |
| `bootstrapAppendOnlyDatastore` returns `AppendOnlyDatastore` facade | `MaterializedView` recovery on read corruption | |
| Multi-materializer support (`Materializer` becomes pluggable; `def.materialize` flag) | | |
| Generic view storage on `StorageBackend` | | |
| 3 reserved system entry types (security context audit) | | |
| Hash spec change (REQ-d00120-B updates) | | |
| `REQ-EVENTS-NO-SECRETS` documented invariant | | |

**Mobile call-site migration scope (Phase 4.4):** events lib + `EventStore` only. The legacy `EventRepository.append` gets a 1-line drive-by patch (`userId: String` param wraps internally as `UserInitiator(userId)`) so it keeps compiling. `clinical_diary`/`NosebleedService` stay untouched until Phase 5 deletes them.

## 3. Architecture

```text
                       AFTER PHASE 4.4 (CONSOLIDATED VIEW)

  +----------------------------------------------------------------+
  |    bootstrapAppendOnlyDatastore({                              |
  |      backend, source, entryTypes, destinations,                |
  |      materializers, syncCycleTrigger?,                         |
  |    }) -> Future<AppendOnlyDatastore>                           |
  |                                                                |
  |    Auto-registers 3 system entry types (security_context_*)    |
  +-------------------------------+--------------------------------+
                                  |
                                  v
  +----------------------------------------------------------------+
  |    AppendOnlyDatastore  (facade returned by bootstrap)         |
  |    -------------------------                                   |
  |    + eventStore: EventStore                                    |
  |    + entryTypes: EntryTypeRegistry                             |
  |    + destinations: DestinationRegistry                         |
  |    + securityContexts: SecurityContextStore                    |
  +----+----------------+--------------+--------------+------------+
       |                |              |              |
       v                v              v              v
  +----------+   +----------------+   +-----------+   +----------------+
  | Event    |   | EntryType      |   | Destination|   | SecurityContext|
  | Store    |   | Registry       |   | Registry   |   | Store          |
  | (rename  |   | (Phase 4.4 adds|   | (Phase 4.3)|   | (NEW Phase 4.4)|
  | from     |   | materialize    |   |            |   |                |
  | Entry-   |   | flag)          |   |            |   |                |
  | Service) |   |                |   |            |   |                |
  +----+-----+   +----------------+   +-----------+   +-----+----------+
       |                                                    |
       v                                                    v
  +----------------------------------------------------------------+
  |    StorageBackend (abstract)                                   |
  |    -- existing event/FIFO/schedule methods unchanged           |
  |    -- diary-specific methods DROPPED (greenfield)              |
  |    -- generic view methods ADDED:                              |
  |       readViewRowInTxn / upsertViewRowInTxn /                  |
  |       deleteViewRowInTxn / findViewRows / clearViewInTxn       |
  |                                                                |
  |    impl: SembastBackend  <-- Phase 4.4 adds sembast indexes    |
  |                              on flow_token, ip_address,        |
  |                              recorded_at                       |
  +----------------------------------------------------------------+
```

**Permission-blind invariant:** `EventStore` and `SecurityContextStore` expose unguarded read/write APIs to anything holding a reference. All access control lives in the widget layer (Flutter widgets client-side, request handlers server-side). The lib does not gate by user role, scope, or tenancy.

## 4. Components and types

### 4.1 `Initiator` (sealed)

```text
lib/src/storage/initiator.dart                          [NEW]
  sealed class Initiator
    Map<String, dynamic> toJson();
    static Initiator fromJson(Map<String, dynamic> json);
                  // throws FormatException on unknown discriminator
                  // or missing required field per variant

  class UserInitiator extends Initiator
    final String userId;
                  // JSON: {"type": "user", "user_id": "..."}

  class AutomationInitiator extends Initiator
    final String service;
                  // e.g., 'mobile-bg-sync', 'retention-policy'
    final String? triggeringEventId;
                  // cascade audit link; null for cron / free-running.
                  // JSON: {"type": "automation", "service": "...",
                  //        "triggering_event_id": "..."?}

  class AnonymousInitiator extends Initiator
    final String? ipAddress;
                  // best-known by the actor at action time;
                  // null on mobile pre-auth (PIN-login screen).
                  // JSON: {"type": "anonymous", "ip_address": "..."}
```

`AnonymousInitiator.ipAddress` is distinct from `EventSecurityContext.ipAddress`: the former is "best-known by the actor"; the latter is "as observed by the receiving server." Both can coexist on the same event without contradiction.

### 4.2 `Source` (rename from `DeviceInfo`)

```text
lib/src/storage/source.dart                             [NEW; rename]
  class Source
    final String hopId;            // 'mobile-device' / 'portal-server' / etc.
    final String identifier;       // deviceId / serverHostname
    final String softwareVersion;  // 'package@semver+build'
                                   // matches REQ-d00115-E format
```

`Source` is the constructor-time identity of the writing process; it stamps `provenance[0]` on every event. The portal constructs an `EventStore` with `Source(hopId: 'portal-server', identifier: hostname, ...)`.

### 4.3 `StoredEvent` shape after Phase 4.4

```text
lib/src/storage/stored_event.dart                       [EDIT]
  class StoredEvent
    // identity (in event_hash):
    final String eventId;
    final String aggregateId;
    final String aggregateType;
    final String entryType;
    final String eventType;
    final int sequenceNumber;
    final Map<String, dynamic> data;
    final Initiator initiator;             // NEW (replaces userId)
    final DateTime clientTimestamp;
    final String? previousEventHash;
    final String? flowToken;               // NEW, indexed on backend
    final Map<String, dynamic> metadata;   // includes provenance[0]

    // outputs / non-identity:
    final String eventHash;
    final DateTime? syncedAt;              // legacy, Phase 5 removes

    // DROPPED top-level fields (read from metadata.provenance[0]):
    //   - userId       (replaced by initiator)
    //   - deviceId     (was REQ-d00133-I migration bridge; greenfield)
    //   - softwareVersion  (same)
```

### 4.4 Event hash spec change (updates REQ-d00120-B)

Before: `event_id, aggregate_id, entry_type, event_type, sequence_number, data, user_id, device_id, client_timestamp, previous_event_hash`.

After: `event_id, aggregate_id, entry_type, event_type, sequence_number, data, initiator, flow_token, client_timestamp, previous_event_hash, metadata`.

Additions: `initiator` (full JSON), `flow_token`, `metadata`. Drops: `user_id` (replaced by `initiator`), `device_id` (now lives in `metadata.provenance[0].identifier`, hashed transitively).

**Why metadata is now hashed:** Each hop's hash covers the event as written by that hop, including its own metadata. When system B receives an event from A, B inherits A's hash unchanged (B does not recompute A's hash). B may compute its own per-hop hash over (identity + A's metadata + B's appended provenance entry) and store it inside its own provenance entry. Hashes stack per hop. The chain detects tampering because altering a middle record cleanly requires re-deriving every later hash, and bitcoin-anchored hashes (future) defeat even that. Phase 4.4 only ships the originating-hop hash (single `event_hash` field); per-hop hash stacking is a future-phase concern (lands when downstream hops exist).

### 4.5 `EventStore` (rename from `EntryService`)

```text
lib/src/event_store.dart                                [RENAME from
                                                          entry_service.dart]
  class EventStore
    EventStore({
      required StorageBackend backend,
      required EntryTypeRegistry entryTypes,
      required Source source,
      required SecurityContextStore securityContexts,
      List<Materializer> materializers = const [],
      SyncCycleTrigger? syncCycleTrigger,
      ClockFn? clock,
      Uuid? uuid,
    });

    Future<StoredEvent?> append({
      required String entryType,
      required String aggregateId,
      required String aggregateType,
      required String eventType,
      required Map<String, dynamic> data,
      required Initiator initiator,
      String? flowToken,
      Map<String, dynamic>? metadata,
      SecurityDetails? security,
      String? checkpointReason,
      String? changeReason,
      bool dedupeByContent = false,
    });

    Future<void> clearSecurityContext(
      String eventId, {
      required String reason,
      required Initiator redactedBy,
    });

    Future<RetentionResult> applyRetentionPolicy({
      SecurityRetentionPolicy? policy,
      Initiator? sweepInitiator,
                    // defaults to AutomationInitiator(service: 'retention-policy')
    });
```

One `append` method serves both mobile widgets (typically `dedupeByContent: true`, no security) and portal callers (security details supplied, dedupe off).

### 4.6 `EntryTypeDefinition` gains a flag

```text
apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart  [EDIT]
  class EntryTypeDefinition
    ...
    final bool materialize;    // default true
                               // false skips ALL materializers for events
                               // of this entry type (system events only)
```

### 4.7 Security module

```text
lib/src/security/event_security_context.dart            [NEW]
  class EventSecurityContext
    final String eventId;             // FK to event_log.event_id (one-way)
    final DateTime recordedAt;
    final String? ipAddress;
    final String? userAgent;
    final String? sessionId;
    final String? geoCountry;
    final String? geoRegion;
    final String? requestId;
    final DateTime? redactedAt;
    final String? redactionReason;

lib/src/security/security_details.dart                  [NEW]
  // immutable input passed by callers to EventStore.append
  class SecurityDetails
    final String? ipAddress;
    final String? userAgent;
    final String? sessionId;
    final String? geoCountry;
    final String? geoRegion;
    final String? requestId;

lib/src/security/security_retention_policy.dart         [NEW]
  class SecurityRetentionPolicy
    final Duration fullRetention;            // default 90 days
    final Duration truncatedRetention;       // default 365 days additional
    final bool truncateIpv4LastOctet;        // default true
    final bool truncateIpv6Suffix;           // default true (/48)
    final bool dropUserAgentAfterFull;       // default true
    final bool dropGeoAfterFull;             // default false
    final bool dropAllAfterTruncated;        // default true
    static const SecurityRetentionPolicy defaults;

lib/src/security/security_context_store.dart            [NEW]
  abstract class SecurityContextStore
    Future<EventSecurityContext?> read(String eventId);
    Future<PagedAudit> queryAudit({
      Initiator? initiator,
      String? flowToken,
      String? ipAddress,
      DateTime? from,
      DateTime? to,
      int limit = 50,        // 1 <= limit <= 1000
      String? cursor,        // opaque
    });
    // Mutations are package-private; only EventStore writes/clears
    // security rows so the row mutation and the audit event-log row
    // commit in one transaction.

  class PagedAudit
    final List<AuditRow> rows;
    final String? nextCursor;

  class AuditRow
    final StoredEvent event;
    final EventSecurityContext context;

lib/src/security/sembast_security_context_store.dart    [NEW]
  class SembastSecurityContextStore implements SecurityContextStore
    // sembast store named 'security_context'
    // indexes: event_id (PK), ip_address, recorded_at

lib/src/security/system_entry_types.dart                [NEW]
  // The 3 reserved system entry types bootstrap auto-registers.
  // All three: materialize=false; eventType='finalized'.
  const securityContextRedactedEntryType;     // single redaction
  const securityContextCompactedEntryType;    // bulk truncate sweep
  const securityContextPurgedEntryType;       // bulk delete sweep
```

### 4.8 Multi-materializer

```text
lib/src/materialization/materializer.dart                [REWRITE]
  abstract class Materializer
    String get viewName;
    bool appliesTo(StoredEvent event);
    Future<void> applyInTxn(
      Txn txn,
      StorageBackend backend, {
      required StoredEvent event,
      required EntryTypeDefinition def,
      required List<StoredEvent> aggregateHistory,
    });

lib/src/materialization/diary_entries_materializer.dart  [NEW; replaces
                                                          static Materializer]
  class DiaryEntriesMaterializer extends Materializer
    @override String get viewName => 'diary_entries';
    @override bool appliesTo(StoredEvent event) =>
        event.aggregateType == 'DiaryEntry';
    @override Future<void> applyInTxn(...) async { ... }

lib/src/materialization/rebuild.dart                     [EDIT]
  Future<int> rebuildView(Materializer materializer, StorageBackend backend);
  // (was: rebuildMaterializedView() hardcoded to diary_entries)
```

### 4.9 `StorageBackend` contract changes

```text
DROPPED (greenfield, no external consumers in mobile):
  - readEntryInTxn / upsertEntry / clearEntries / findEntries
    (DiaryEntry value type stays; DiaryEntriesMaterializer uses generic API)

ADDED:
  - readViewRowInTxn(Txn, viewName, key) -> Map<String, dynamic>?
  - upsertViewRowInTxn(Txn, viewName, key, Map<String, dynamic>) -> void
  - deleteViewRowInTxn(Txn, viewName, key) -> void
  - findViewRows(viewName, {limit, offset}) -> List<Map<String, dynamic>>
  - clearViewInTxn(Txn, viewName) -> void

Sembast impl: one StoreRef<String, Map<String, Object?>> per view name,
lazy-created on first write. View-name namespace owned by the lib + caller-
registered materializers; system entry types reserve the 'security_context'
viewName even though they don't materialize anything.

Sembast indexes (Phase 4.4 adds):
  events store:  flow_token (for cross-event correlation queries)
  security_context store:  ip_address, recorded_at (for queryAudit)
```

### 4.10 Bootstrap

```text
lib/src/bootstrap.dart                                  [EDIT]
  Future<AppendOnlyDatastore> bootstrapAppendOnlyDatastore({
    required StorageBackend backend,
    required Source source,
    required List<EntryTypeDefinition> entryTypes,
    required List<Destination> destinations,
    List<Materializer> materializers = const [],
    SyncCycleTrigger? syncCycleTrigger,
  });

  class AppendOnlyDatastore
    final EventStore eventStore;
    final EntryTypeRegistry entryTypes;
    final DestinationRegistry destinations;
    final SecurityContextStore securityContexts;
```

Bootstrap auto-registers the 3 system entry types BEFORE iterating the caller-supplied list. Caller-supplied id collision with a system id throws `ArgumentError` with an explicit "reserved" message.

## 5. Data flow

### 5.1 `EventStore.append(...)`

```text
0. (pre-transaction, pure validation; throws ArgumentError before any I/O)
   - eventType in {finalized, checkpoint, tombstone}
   - entryTypes.isRegistered(entryType)
   - aggregateType non-empty
   - build provenance0 from Source + clock
   - compute candidateContentHash (only if dedupeByContent)

1. begin transaction:
   1a. if dedupeByContent:
         lastEventOnAggregate = backend.findEventsForAggregateInTxn(...).last
         if hash(lastEvent.content) == candidateContentHash:
           return null   // no-op duplicate; tx commits with zero writes

   1b. previousEventHash = backend.readLatestEventHash(txn)
   1c. sequenceNumber   = backend.nextSequenceNumber(txn)
   1d. eventId          = uuid.v4()

   1e. metadata = {
         ...caller metadata,
         'change_reason': changeReason ?? 'initial',
         'provenance': [provenance0.toJson()],
       }

   1f. eventRecord = {
         event_id, aggregate_id, aggregate_type, entry_type, event_type,
         sequence_number, data, initiator: initiator.toJson(),
         client_timestamp, previous_event_hash, flow_token, metadata,
       }
       eventHash = sha256(JCS(eventRecord))
       eventRecord['event_hash'] = eventHash
       event = StoredEvent.fromMap(eventRecord, 0)

   1g. backend.appendEvent(txn, event)

   1h. if security != null:
         row = EventSecurityContext(eventId, recordedAt: clock.now,
                                    ...security fields...)
         securityContexts.writeInTxn(txn, row)        // package-private API

   1i. for m in materializers:
         if m.appliesTo(event) AND def.materialize == true:
           await m.applyInTxn(txn, backend,
                              event: event, def: def,
                              aggregateHistory: aggregateHistory)

2. commit
3. unawaited(syncCycleTrigger?.call())   // fire-and-forget post-commit
4. return event
```

**Atomicity guarantee:** event row + security row + every materialized-view row commit together or not at all. Failure at any step in 1a–1i rolls back everything.

### 5.2 `EventStore.clearSecurityContext(...)`

```text
1. begin transaction:
   1a. row = securityContexts.readInTxn(txn, eventId)
       if row == null: throw ArgumentError('no security context for $eventId')
   1b. securityContexts.deleteInTxn(txn, eventId)
   1c. self.append(                          // recursive same-tx append
         entryType: 'security_context_redacted',
         aggregateId: eventId,
         aggregateType: 'security_context',
         eventType: 'finalized',
         data: {'reason': reason},
         initiator: redactedBy,
         security: null,
       )                                     // materialize=false on the type
                                             // -> no view rows written
2. commit
```

### 5.3 `EventStore.applyRetentionPolicy(...)`

```text
0. policy   = caller-supplied or SecurityRetentionPolicy.defaults
   sweepBy  = caller-supplied or AutomationInitiator('retention-policy')
   now      = clock.now
   compactCutoff = now - policy.fullRetention
   purgeCutoff   = now - policy.fullRetention - policy.truncatedRetention

1. begin transaction:
   1a. compactedRows = securityContexts.findUnredactedOlderThanInTxn(
                          txn, compactCutoff)
       for row in compactedRows:
         truncated = row.applyTruncation(policy)
         securityContexts.upsertInTxn(txn, truncated)

   1b. purgedRows = securityContexts.findOlderThanInTxn(txn, purgeCutoff)
       for row in purgedRows:
         securityContexts.deleteInTxn(txn, row.eventId)

   1c. if compactedRows.isNotEmpty:
         self.append(
           entryType: 'security_context_compacted',
           aggregateId: 'retention-${now.toIso8601String()}',
           aggregateType: 'security_context',
           eventType: 'finalized',
           data: {'count': compactedRows.length,
                  'cutoff': compactCutoff.toIso8601String(),
                  'policy': policy.toJson()},
           initiator: sweepBy,
           security: null,
         )

   1d. if purgedRows.isNotEmpty:
         self.append(
           entryType: 'security_context_purged',
           aggregateId: 'retention-${now.toIso8601String()}',
           aggregateType: 'security_context',
           eventType: 'finalized',
           data: {'count': purgedRows.length,
                  'cutoff': purgeCutoff.toIso8601String()},
           initiator: sweepBy,
           security: null,
         )

2. commit
3. return RetentionResult(compactedCount, purgedCount)
```

Empty sweep emits NO audit event.

### 5.4 `SecurityContextStore.queryAudit(...)`

```text
sembast impl:
  1. fetch security_context rows where:
       (ipAddress filter applied if non-null)
       AND (recordedAt in [from, to])
     -> set S of (eventId, EventSecurityContext)
  2. fetch event_log rows where:
       eventId IN S.keys
       AND (initiator filter applied if non-null)
       AND (flowToken filter applied if non-null)
     -> set E of (eventId, StoredEvent)
  3. innerJoin S, E on eventId
  4. sort by recordedAt desc
  5. paginate with cursor (recordedAt + eventId composite, opaque to caller)
  6. return PagedAudit(rows, nextCursor)

postgres impl (future):
  SELECT e.*, s.*
  FROM event_log e
  JOIN security_context s ON s.event_id = e.event_id
  WHERE (initiator filter) AND (flow_token filter)
        AND (s.ip_address filter) AND (s.recorded_at BETWEEN from AND to)
  ORDER BY s.recorded_at DESC
  LIMIT 50 OFFSET cursor;
```

## 6. Error handling (Phase 4.4 scope)

Storage-failure exceptions, classifier, audit log, and health surface are deferred to Phase 4.5. Phase 4.4 covers only the boundary cases its new code introduces:

- **`EventStore.append` pre-transaction (all throw `ArgumentError` before any I/O):** `eventType` allowlist violation; `entryType` not registered; empty `aggregateType`; missing `initiator` (compile-time enforced).
- **`EventStore.append` in-transaction:** any backend op throws → entire transaction rolls back, no event appended, no security row, no view rows, no sync trigger fired. Phase 4.4 propagates the underlying exception; Phase 4.5 will categorize as `StorageException`.
- **`EventStore.clearSecurityContext`:** `eventId` not found → `ArgumentError` before transaction opens. Cascading redaction-event append uses the same atomic-tx semantics.
- **`EventStore.applyRetentionPolicy`:** empty sweep emits no audit event; non-empty sweep emits one or two audit events; if either append throws, the entire sweep rolls back.
- **`SecurityContextStore.queryAudit`:** opaque cursor; corrupt cursor → `ArgumentError`; `limit <= 0 || limit > 1000` → `ArgumentError`; all filters nullable (null = match all).
- **`Materializer.applyInTxn`:** throws propagate to `EventStore.append`, which propagates to caller after rollback.
- **`bootstrapAppendOnlyDatastore`:** caller-supplied id colliding with a system entry type id → `ArgumentError` with explicit "reserved" message.
- **`Initiator.fromJson`:** unknown discriminator → `FormatException`; missing required field per variant → `FormatException`.

## 7. Testing strategy

```text
Initiator (test/storage/initiator_test.dart)
  - sealed pattern matching exhaustive across {User, Automation, Anonymous}
  - JSON roundtrip per variant; discriminator field present and exact
  - equality / hashCode for each variant
  - fromJson rejects unknown discriminator with FormatException
  - fromJson rejects missing required fields per variant

Source (test/storage/source_test.dart)
  - constructor + value equality
  - JSON roundtrip (used by ProvenanceEntry stamping)

StoredEvent shape migration (test/storage/stored_event_test.dart)
  - top-level userId field is GONE (compile-time check)
  - top-level deviceId / softwareVersion fields are GONE
  - flowToken nullable; round-trips through sembast
  - eventHash inputs include initiator JSON, flow_token, metadata
    (assertion compares hash against a hand-computed reference value)

EventStore.append (test/event_store_append_test.dart)
  - happy path: event row, optional security row, materializer rows all
    committed; sync trigger fired exactly once
  - happy path with security: null - only event + materializer rows
  - dedupeByContent: identical content returns null, no rows written, no
    trigger fired
  - dedupeByContent: differing content writes new event
  - atomicity: force throw mid-transaction - NO rows present;
    sync trigger NOT fired
  - validation throws happen BEFORE any I/O (event_log empty after each)

EventStore.clearSecurityContext
  - happy path: security row deleted, redaction event in event_log with
    correct entryType / aggregateType / initiator / data.reason
  - missing eventId: ArgumentError; no rows touched; no event emitted
  - the redaction event itself materializes nothing (def.materialize=false)
  - sync trigger fires after the redaction event

EventStore.applyRetentionPolicy
  - empty sweep: no events emitted, RetentionResult counts both zero
  - compact-only sweep: 1 audit event with entryType=compacted
  - compact+purge sweep: 2 audit events, each with correct count + cutoff
  - rollback: force throw mid-sweep -> no truncations, deletions, or
    audit events
  - the audit events themselves are unredactable (event_log entries,
    not security rows)

SecurityContextStore.queryAudit
  - returns paged AuditRow with paired (event, context)
  - filter by initiator (each variant); filter by flowToken; filter by
    ipAddress; filter by date range; combinations
  - cursor pagination: nextCursor returns next page; cursor stable
    across new appends to either store
  - empty result returns empty rows + null nextCursor
  - corrupt cursor -> ArgumentError

EventSecurityContext + sembast store
  - write/read round-trip
  - read on missing returns null
  - one-way FK direction: deleting the security row never touches the
    event row
  - sembast indexes on event_id (PK), ip_address, recorded_at exist

Multi-materializer (test/event_store_multi_materializer_test.dart)
  - register 0 materializers: append works, no view writes
  - register 2 materializers: append fires both that match; one that
    appliesTo=false skipped
  - def.materialize == false: NO materializers fire even if appliesTo=true
  - one materializer throws: transaction rolls back, no event appended
  - rebuildView(materializer) replays event_log into one view in
    isolation (other views untouched)

Generic view storage (test/storage/storage_backend_views_test.dart)
  - read missing key returns null
  - upsert + read round-trips Map<String, dynamic>
  - delete removes the row; read after delete returns null
  - findViewRows iterates with limit + offset
  - clearViewInTxn empties one view without touching others
  - viewName isolation: writing to 'a' never affects 'b'

bootstrapAppendOnlyDatastore
  - returns AppendOnlyDatastore with all 4 collaborators non-null
  - auto-registers 3 system entry types; entryTypes.isRegistered(...) true
  - caller-supplied id colliding with a system id throws ArgumentError
  - bootstrap re-run preserves persisted state (REQ-d00134-C carry-over)
```

Sembast indexes verified by timing-tolerant tests asserting "filter by ip returns N rows in <X ms over a corpus of M".

## 8. REQ topics to claim

REQ numbers claimed at implementation time via `discover_requirements("next available REQ-d")`. All land in `spec/dev-event-sourcing-mobile.md`. Numbering follows Phase 4.3 Task 3 pattern (claim sequentially before writing the new entries).

```text
REQ-INITIATOR        sealed actor type with three variants; replaces
                     userId on StoredEvent and EntryService.record's
                     parameter
                     assertions: A (sealed shape), B (JSON roundtrip
                     per variant), C (User migration of mobile call
                     sites), D (Automation.triggeringEventId optional
                     and references existing event when set), E
                     (Anonymous accepts null ipAddress), F (fromJson
                     rejects unknown discriminator)

REQ-FLOWTOKEN        nullable String? on StoredEvent; storage backends
                     MUST index for query
                     assertions: A (nullable), B (format convention
                     documented), C (multi-event flows share one), D
                     (sembast indexed), E (in event_hash inputs)

REQ-SECCTX           EventSecurityContext store and write integration
                     with EventStore.append; atomic write; one-way FK
                     security -> event
                     assertions: A (sidecar separate from event row),
                     B (FK direction), C (atomic write rollback
                     semantics), D (read by event_id), E (write
                     requires extant event_id), F (queryAudit pagination
                     and filter contract)

REQ-RETENTION        SecurityRetentionPolicy value type,
                     applyRetentionPolicy, clearSecurityContext;
                     audit-event emission on every redaction
                     assertions: A (policy value type with defaults),
                     B (compact sweep truncates IP per policy), C
                     (purge sweep deletes past truncated window), D
                     (clearSecurityContext emits security_context_
                     redacted in event_log), E (compact sweep emits
                     security_context_compacted; empty sweep emits
                     none), F (purge sweep emits security_context_
                     purged; empty sweep emits none), G (redaction
                     events are themselves immutable event_log entries)

REQ-EVENTS-NO-SECRETS   data + flowToken contain no cleartext secrets;
                        hashes acceptable; library does not enforce;
                        caller contract documented
                        assertions: A (statement of invariant), B
                        (rationale narrative), C (acceptable hash spec)

REQ-MATERIALIZERS    pluggable materializers; def.materialize flag;
                     generic view storage on StorageBackend
                     assertions: A (Materializer abstract; viewName,
                     appliesTo, applyInTxn), B (EventStore takes
                     List<Materializer>), C (def.materialize=false
                     skips all materializers for that entry type),
                     D (rebuildView is per-view, idempotent), E
                     (one materializer's throw rolls back the whole
                     append transaction), F (StorageBackend exposes
                     readViewRowInTxn / upsertViewRowInTxn /
                     deleteViewRowInTxn / findViewRows / clearViewInTxn
                     for view-generic access)

REQ-EVENTSTORE       EventStore renames EntryService; one append()
                     method on EventStore; permission-blind
                     assertions: A (rename of class and file), B
                     (single append() method takes per-field args
                     plus optional SecurityDetails plus dedupeByContent
                     flag), C (mobile widget call sites pass per-field
                     args directly), D (no permissions check inside
                     EventStore or SecurityContextStore)

REQ-SOURCE           Source value type renames DeviceInfo; carries
                     hopId / identifier / softwareVersion; stamps
                     ProvenanceEntry
                     assertions: A (rename + signature), B (hopId
                     enumerates 'mobile-device' and 'portal-server'
                     as well-known values), C (softwareVersion follows
                     REQ-d00115-E format)

REQ-d00120-update    Update REQ-d00120-B's identity-field enumeration
                     to drop user_id and device_id, add initiator,
                     flow_token, and metadata. (Edit existing REQ
                     in place; not a new claim.)

REQ-d00134-update    Update REQ-d00134 (bootstrap signature) to return
                     AppendOnlyDatastore facade; auto-register 3
                     system entry types; require Source + materializers
                     parameters. (Edit existing REQ in place.)
```

## 9. File plan

```text
apps/common-dart/append_only_datastore/lib/src/
  storage/
    initiator.dart                                   NEW
    source.dart                                      NEW (rename of
                                                          device_info.dart)
    stored_event.dart                                EDIT (drop userId/
                                                            deviceId/
                                                            softwareVersion;
                                                            add initiator,
                                                            flowToken)
    storage_backend.dart                             EDIT (drop diary
                                                           methods; add
                                                           generic view
                                                           methods)
    sembast_backend.dart                             EDIT (impl of new
                                                           view methods;
                                                           add indexes)
  security/                                          NEW directory
    event_security_context.dart                      NEW
    security_context_store.dart                      NEW (abstract +
                                                          PagedAudit +
                                                          AuditRow)
    sembast_security_context_store.dart              NEW
    security_details.dart                            NEW
    security_retention_policy.dart                   NEW
    system_entry_types.dart                          NEW
  materialization/
    materializer.dart                                REWRITE (now
                                                              abstract)
    diary_entries_materializer.dart                  NEW (extracts
                                                          existing logic)
    rebuild.dart                                     EDIT (rebuildView)
  event_store.dart                                   RENAME from
                                                       entry_service.dart
                                                     EDIT to add
                                                       clearSecurityContext,
                                                       applyRetentionPolicy
  bootstrap.dart                                     EDIT (return
                                                           AppendOnlyDatastore;
                                                           auto-register
                                                           system entry
                                                           types)
  infrastructure/repositories/
    event_repository.dart                            EDIT (1-line patch:
                                                           userId param
                                                           wraps as
                                                           UserInitiator(
                                                           userId) for the
                                                           constructed
                                                           StoredEvent)

apps/common-dart/append_only_datastore/test/
  storage/
    initiator_test.dart                              NEW
    source_test.dart                                 NEW
    stored_event_test.dart                           EDIT
    storage_backend_views_test.dart                  NEW
  security/                                          NEW directory
    event_security_context_test.dart                 NEW
    sembast_security_context_store_test.dart         NEW
    retention_policy_test.dart                       NEW
    append_with_security_atomicity_test.dart         NEW
    clear_security_context_emits_event_test.dart     NEW
    apply_retention_emits_events_test.dart           NEW
    query_audit_test.dart                            NEW
  materialization/
    diary_entries_materializer_test.dart             NEW
    multi_materializer_test.dart                     NEW
  event_store_append_test.dart                       RENAME from
                                                       entry_service_test
  event_store_multi_materializer_test.dart           NEW
  bootstrap_test.dart                                EDIT (facade return,
                                                           system types
                                                           registered)

apps/common-dart/trial_data_types/lib/src/
  entry_type_definition.dart                         EDIT (add materialize
                                                           flag)

apps/common-dart/trial_data_types/test/
  entry_type_definition_test.dart                    EDIT (cover materialize
                                                           field round-trip)

spec/dev-event-sourcing-mobile.md                    EDIT (new REQ topics:
                                                           REQ-INITIATOR,
                                                           REQ-FLOWTOKEN,
                                                           REQ-SECCTX,
                                                           REQ-RETENTION,
                                                           REQ-EVENTS-NO-
                                                             SECRETS,
                                                           REQ-MATERIALIZERS,
                                                           REQ-EVENTSTORE,
                                                           REQ-SOURCE,
                                                           updates to
                                                           REQ-d00120,
                                                           REQ-d00134)
spec/INDEX.md                                        EDIT (auto-regenerated
                                                           via elspais fix)

apps/common-dart/append_only_datastore/lib/append_only_datastore.dart
                                                     EDIT (export new
                                                           public surfaces;
                                                           drop deleted
                                                           ones)
```

## 10. Out of scope

Carried forward from `TODO4.4.md` and confirmed during this brainstorm:

1. **PostgreSQL `StorageBackend` implementation** — separate "port to portal" ticket.
2. **Periodic retention CRON wiring** — ops ticket; this phase only specifies the API.
3. **Portal actions library** (Sub-project A of CUR-1159) — implemented separately in the portal worktree after this lands.
4. **Diary-sync mobile→portal ingestion endpoint** — its own ticket.
5. **OpenTelemetry stamping of events with trace/span context** — future enhancement.
6. **Encryption-at-rest of the security context** — separate ticket if needed.
7. **Per-hop hash stacking** for downstream hops (provenance[1..]) — future-phase concern when downstream hops exist.
8. **Storage failure handling** — Phase 4.5, separate design at `docs/superpowers/2026-04-22-storage-failure-handling-design.md`.
9. **Phase 4.6 demo app** — including the worked button-toggle materialized view.
10. **Phase 5 cutover of clinical_diary** — removing `EventRepository` / `NosebleedService`; rewiring widgets onto `EventStore`.

## 11. Sequencing

Phase 4.5 (storage failure handling) follows. 
Phase 4.6 (demo) follows Phase 4.5.

