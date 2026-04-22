# Mobile Event-Sourcing Refactor — Design

**Date:** 2026-04-21
**Status:** Approved (design); implementation plan pending
**Branch:** `feature/event-sourcing-refactor-design`
**Scope:** Mobile diary app only; shared Dart package designed for portal reuse in a later phase

## 1. Summary

Refactor the mobile diary app so that every patient-originated data entry flows through a single local-first, event-sourced pipeline. Close the gap where questionnaire submissions currently bypass the on-device event store. Treat nosebleed as one entry type among many; make adding new entry types (medication, meals, custom PROs) a data-plus-widget change with no plumbing modifications. Design the underlying package so the same code — with a different storage backend — can be reused on the portal server in a future phase.

## 2. Background

Two prior investigations (2026-04-20) established the current state of mobile and portal:

- **Mobile (`apps/daily-diary/clinical_diary/`)**: nosebleed events are correctly written to an append-only Sembast event store (`apps/common-dart/append_only_datastore/`) with hash-chained tamper evidence. Questionnaire submissions bypass the event store entirely — they POST directly to the diary server and lose offline support. Only one entry type (nosebleed) is covered. Several other regressions: `aggregate_id` is used as a date bucket rather than an entry identifier; `server_timestamp` is set to the device clock (not a server) and is unreferenced anywhere outside the writer; no background sync; no per-destination sync state.

- **Portal server** (noted for context; out of scope for this plan): audits are split across multiple specialized tables, only patient diary data goes through an event-sourced store, and several user-action categories are unlogged.

The system is greenfield — no in-field data exists, so there are no backward-compatibility or migration constraints on the mobile side.

## 3. Goals

1. All patient-originated data entries (nosebleeds, survey questionnaires, future entry types) write to a single on-device append-only event log before any network I/O.
2. Nosebleed becomes an entry type like any other; UI uniqueness only (bespoke widget, prominent homescreen button).
3. Adding a new entry type requires (a) a JSON definition and (b) an optional widget registration — no plumbing changes.
4. Outbound sync is multi-destination. Each destination has its own FIFO which is both an outbound queue and a permanent audit log of what was sent, including the transformed wire payload.
5. The event-sourcing package is pure Dart with no Flutter dependency, so the portal server can reuse it unchanged by implementing the `StorageBackend` interface over PostgreSQL.
6. Foreground-only sync on explicit triggers. No new background-worker machinery.

## 4. Non-goals (explicit out-of-scope — deferred)

Each of these will become its own design/plan when taken up:

1. Portal server ingestion of mobile events.
2. Unified server-side event store for portal user actions (admin actions, authentication, email audit, etc.).
3. Server-side schema changes to `record_audit` / `record_state`.
4. Background / silent-push sync (iOS BGTaskScheduler, Android WorkManager).
5. At-rest encryption of the mobile event store (REQ-p01009 remains open).
6. UI banner for "data not syncing — please update" (state will be queryable; UX is a separate task).
7. Multi-device conflict resolution / multi-source editing (REQ-p01002). Current design is last-writer-wins via whole-answer-replacement; appropriate for single-source editing only.
8. Event-schema migration and rollback (chain-of-promoters pattern at read time; see `memory/project_event_schema_migration_strategy.md`).
9. Protocol-level mitigation of the FIFO-wedge risk (§12): have the portal ingest API accept all well-formed envelopes unconditionally and defer content validation.

## 5. Design decisions (with rationale)

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | **Universal `DiaryEntry` aggregate** with per-entry UUID `aggregate_id`. Drop the vestigial `'diary-YYYY-M-D'` date-bucket pattern. | Aggregate is one entry's lifecycle (potentially multiple events); date-bucket grouping conflated two concerns. Calendar date-grouping is a read-model concern handled by the materialized view's `effective_date` column. |
| 2 | **First-class `entry_type` field** on events; `event_type` reserved for user-intent lifecycle (`finalized` \| `checkpoint` \| `tombstone`). | Separates "what kind of entry is this" from "what happened to it." New entry types add no new event_type values. |
| 3 | **`EntryTypeDefinition` carries `widget_id`** as a first-class pointer into a Flutter widget registry. | Each entry type can have its own bespoke widget for optimal UX. Two entry types *may* share a widget (survey_renderer_v1) but sharing is a UX coincidence, not structural. |
| 4 | **Materialized view `diary_entries`** is a persisted, incrementally-maintained store separate from the event log. Rebuildable from the log at any time. | Calendar and homescreen need fast queries by date/completion. The current on-demand `_materializeRecords()` is O(N) per query and nosebleed-specific. CQRS-clean. |
| 5 | **`effective_date` lives on the view, not on the event.** | Keeps the event schema pure; non-diary events (e.g. settings changes) never need to carry an effective_date. |
| 6 | **Per-destination FIFO** stores serve as both outbound queue and permanent send log. Wire payload (transformed bytes) and per-attempt log are preserved; entries are marked `sent`/`exhausted` but never deleted. | FDA/ALCOA: every sync attempt is audit-worthy, and transformed payloads sent to regulated destinations (CROs, EDC) must be reconcilable with the receiver's records. |
| 7 | **Pub-sub destination routing** via `SubscriptionFilter` on each `Destination`. | Adding a destination doesn't require editing questionnaire definitions or a central routing table. Sponsor-specific destinations register themselves at boot. |
| 8 | **Strict FIFO ordering; no `abandoned` state.** On `exhausted` head, the FIFO wedges until human intervention (typically a shipped app update). | User-confirmed requirement. The only recovery path for the mobile is an app update, so wedges must be visible to operations ASAP. |
| 9 | **Chain-of-custody via `metadata.provenance`** — an append-only list of hops. Each hop (device, diary-server, portal, EDC) adds one entry on receipt. | Natural audit trail for cross-system data flow. Uniform entry shape; no first-entry-is-special logic. |
| 10 | **`provenance` is its own package** (`apps/common-dart/provenance/`). Top-level `device_id` / `software_version` / `client_timestamp` remain as duplicates of `provenance[0]` as a migration bridge; removed when portal is updated to read provenance. | Shared package needed by mobile now, portal/server later. Redundancy defers the server-side change. |
| 11 | **Foreground-only sync** with specific triggers: app launch/resume, 15-minute periodic timer while foreground, new-entry-appended, connectivity-restored while foreground, FCM message received. No background isolates. | iOS/Android battery + platform constraints; leverages existing FCM implementation as the "background wake" mechanism. |
| 12 | **`server_timestamp` removed from mobile event schema.** | Currently misnamed (device clock, not server clock). Unreferenced by any mobile consumer. Server does not read it from the wire (stamps its own `DEFAULT now()` on ingest). Zero cost to remove; eliminates a misleading field. |

## 6. Core data model

### 6.1 Event schema (the append-only row)

```text
event_id              UUID v4
aggregate_id          UUID                 — one per DiaryEntry (spans all lifecycle events)
aggregate_type        string               — "DiaryEntry" for this plan; open discriminator for future
                                            non-diary aggregates (e.g. "DeviceState", "UserSetting")
entry_type            string               — "nose_hht" | "hht_qol" | "med_dose" | ...
event_type            string               — "finalized" | "checkpoint" | "tombstone"
sequence_number       int, monotonic (per-device event log)
user_id               string
device_id             string               — mirror of provenance[0].identifier (migration bridge)
software_version      string               — mirror of provenance[0].software_version (migration bridge)
client_timestamp      ISO 8601 w/ tz       — mirror of provenance[0].received_at (migration bridge)
event_hash            SHA-256 over canonical contents including previous_event_hash
previous_event_hash   SHA-256 of immediately-prior event (null for first event on device)
data                  JSONB                — entry-type-specific; user answers + optional
                                            data.checkpoint_reason for event_type="checkpoint"
metadata              JSONB {
  change_reason:      string               — required (server expects this field)
  provenance:         [ProvenanceEntry]    — chain-of-custody, grows on each hop
  ...open-ended
}
```

Immutability: once appended, **no field on an event is ever mutated**, including sync state. (Sync tracking lives in per-destination FIFOs, not on the event.)

### 6.2 Event types (user intent)

| event_type | Meaning | Materializer effect on diary_entries row |
| --- | --- | --- |
| `finalized` | User pressed submit (first time or after editing a previously-finalized entry — same intent either way). | `is_complete = true`; replace `current_answers`; update `effective_date`, `latest_event_id`, `updated_at`. |
| `checkpoint` | System preserved in-progress user data without user submit intent. `data.checkpoint_reason` carries the detail (e.g. `"nosebleed-started"`, `"app-suspending"`). | `is_complete = false`; replace `current_answers`; update `latest_event_id`, `updated_at`. Effective_date only if present in current answers per `effective_date_path`. |
| `tombstone` | User explicitly deleted the entry. Empty `data`; the intent is the record. | `is_deleted = true`; row stays visible in audit, filtered from active UI. |

### 6.3 Aggregate model

One `aggregate_id` per diary entry. A fresh UUID v7 is minted when the widget first calls `EntryService.record()` for a new entry. All subsequent events on that entry share the same `aggregate_id` and accrete on the log in order:

```text
aggregate-A  (a single nosebleed)
├── event #1  event_type=checkpoint  reason="nosebleed-started"  answers={startTime}
├── event #2  event_type=finalized   answers={startTime, endTime, intensity, notes}
└── event #3  event_type=finalized   answers={same with corrected intensity}   change_reason="Corrected intensity"

aggregate-B  (a single QoL survey completion)
└── event #1  event_type=finalized   answers={q1..q10}
```

Answer merging semantics: **whole-replacement, latest-wins**. The widget passes the full answer set on each `record()` call. No field-by-field merge.

### 6.4 `EntryTypeDefinition`

Lives in `apps/common-dart/trial_data_types/`. Pure data; no storage or Flutter dependencies.

```text
EntryTypeDefinition {
  id                    string         — same value as event.entry_type
  version               string         — same value embedded in event.data.questionnaire_version
  name                  string         — display
  effective_date_path   string?        — JSON path into data.answers; null ⇒ fall back to first
                                         event's client_timestamp for this aggregate
  widget_id             string         — key into the Flutter widget registry
  widget_config         JSON           — widget-specific payload; for widget_id="survey_renderer_v1"
                                         this carries the existing QuestionnaireDefinition shape
  destination_tags      [string]?      — optional; destinations may match on these in SubscriptionFilter
}
```

The existing `QuestionnaireDefinition` class remains — it becomes the concrete shape of `widget_config` when `widget_id == "survey_renderer_v1"`. No changes to `QuestionnaireDefinition` internals in this plan.

### 6.5 `ProvenanceEntry`

Lives in `apps/common-dart/provenance/`. Pure data + a helper to append a new hop.

```text
ProvenanceEntry {
  hop                   string         — "mobile-device" | "diary-server" | "portal-server" | "edc-rave" | ...
  received_at           ISO 8601 w/ tz
  identifier            string         — device_id for mobile; server instance id for servers
  software_version      string         — "clinical-diary@1.2.3+45", "diary-functions@0.5.0", ...
  transform_version     string?        — non-null if this hop's incoming wire payload was produced
                                         by a transform upstream
}
```

Append rule: each hop, on receipt, extends `metadata.provenance` by one entry. Prior entries are never modified. The append happens as data is copied into the receiving hop's storage, which preserves per-store immutability.

## 7. Storage layer

### 7.1 Stores

```text
event_log              append-only, hash-chained, source of truth
                       one row per event; indexed by event_id, aggregate_id, sequence_number

diary_entries          materialized view; rebuildable from event_log
                       one row per aggregate_id
                       columns: entry_id, entry_type, effective_date, current_answers,
                                is_complete, is_deleted, latest_event_id, updated_at
                       indexed by: entry_type, effective_date, is_complete, is_deleted

fifo/{destination_id}  one logical store per registered destination
                       columns: entry_id, event_id, sequence_in_queue, wire_payload,
                                wire_format, transform_version, enqueued_at, attempts[],
                                final_status ("pending" | "sent" | "exhausted"), sent_at

backend_state          key-value, implementation-detail bookkeeping
                       sequence_counter (int), schema_version (int)
```

Note: `backend_state` was previously named `metadata` in the existing code, which collided with the event-level `metadata` field. Renamed to disambiguate.

### 7.2 Write path (single transaction)

When `EntryService.record()` is called:

1. Build the event: assign `event_id`, `sequence_number`, compute `previous_event_hash`, compute `event_hash`, append first `ProvenanceEntry`, populate migration-bridge top-level fields.
2. Append row to `event_log`.
3. Upsert `diary_entries` row for this `aggregate_id` per §6.2 materializer rules.
4. For each `Destination` in `DestinationRegistry` whose filter matches: `await destination.transform(event)` inside the transaction, then insert the resulting payload into `fifo/{destination_id}` with `final_status = "pending"`.
5. Update `backend_state.sequence_counter`.

All five steps happen in one `StorageBackend.transaction()`. Transform failures (step 4) abort the whole write — a broken transform is caught at write time, not on next drain. Once the transaction commits, the user's data is durable.

### 7.3 `StorageBackend` interface

```dart
abstract class StorageBackend {
  Future<T> transaction<T>(Future<T> Function(Txn txn) body);

  Future<AppendResult> appendEvent(Txn txn, Event event);
  Future<List<Event>> findEventsForAggregate(String aggregateId);
  Future<List<Event>> findAllEvents({int? afterSequence, int? limit});

  Future<void> upsertEntry(Txn txn, DiaryEntry entry);
  Future<List<DiaryEntry>> findEntries({
    String? entryType, bool? isComplete, bool? isDeleted,
    DateTime? dateFrom, DateTime? dateTo,
  });

  Future<void> enqueueFifo(Txn txn, String destinationId, FifoEntry entry);
  Future<FifoEntry?> readFifoHead(String destinationId);
  Future<void> appendAttempt(String destinationId, String entryId, AttemptResult attempt);
  Future<void> markFinal(String destinationId, String entryId, FinalStatus status);
  Future<bool> anyFifoExhausted();
  Future<List<ExhaustedFifoSummary>> exhaustedFifos();

  Future<int> nextSequenceNumber(Txn txn);
  Future<int> readSchemaVersion();
  Future<void> writeSchemaVersion(Txn txn, int version);
}
```

Two concrete implementations:
- **`SembastBackend`** — mobile, delivered by this plan.
- **`PostgresBackend`** — portal, future phase. Dropping it in lets the whole package run on the server unchanged.

### 7.4 Rebuild capability

`rebuildMaterializedView()` reads all events in sequence order and replays them into a fresh `diary_entries` store. Not a runtime operation — a disaster-recovery / dev tool. Having it means `diary_entries` is treated as a cache, never as source of truth.

## 8. Sync architecture

### 8.1 `Destination` interface

```dart
abstract class Destination {
  String get id;                        // stable id; used as FIFO store name
  SubscriptionFilter get filter;
  String get wireFormat;                // "json-v1" | "fhir-r4" | "hl7-v2" | ...

  Future<WirePayload> transform(Event event);
  Future<SendResult> send(WirePayload payload);
}

class SubscriptionFilter {
  final List<String>? entryTypes;           // allow-list; null = any
  final List<String>? eventTypes;           // allow-list; null = any
  final bool Function(Event)? predicate;    // escape hatch
  bool matches(Event e);
}

sealed class SendResult {}
class SendOk extends SendResult {}
class SendTransient extends SendResult { final String error; final int? httpStatus; }
class SendPermanent extends SendResult { final String error; }
```

The translation from HTTP responses to `SendResult` is a per-destination judgment. Default categorization: `2xx → SendOk`, `5xx + network → SendTransient`, `4xx → SendPermanent`, with specific destination-level carve-outs (see §11.1).

### 8.2 `DestinationRegistry`

Boot-time wiring. The sponsor entry point (e.g. `hht_diary_callisto`) registers whichever destinations apply; compile-time mode flags gate additional registrations.

```dart
DestinationRegistry.register(PrimaryDiaryServerDestination(...));
// In reverse-proxy mode only:
if (const bool.fromEnvironment('REVERSE_PROXY')) {
  DestinationRegistry.register(MedidataRaveDestination(...));
}
```

The core package has no knowledge of modes.

### 8.3 Drain loop (strict order)

```text
drain(destination):
  loop:
    head = storage.readFifoHead(destination.id)
    if head is None: return
    if backoff_not_elapsed(head): return
    attempt = await destination.send(head.wire_payload)
    storage.appendAttempt(destination.id, head.entry_id, attempt)
    match attempt:
      SendOk:
        storage.markFinal(destination.id, head.entry_id, sent)
        continue
      SendPermanent:
        storage.markFinal(destination.id, head.entry_id, exhausted)
        return                               -- FIFO wedged
      SendTransient:
        if head.attempts.length + 1 >= SyncPolicy.maxAttempts:
          storage.markFinal(destination.id, head.entry_id, exhausted)
          return                             -- FIFO wedged
        return                               -- backoff; next trigger retries
```

Per-destination backoff. One destination's wedge does not affect other destinations. Within a single FIFO, the head gates all subsequent entries (strict ordering by design).

### 8.4 `SyncPolicy` constants

All in `append_only_datastore/lib/src/sync/sync_policy.dart`. Not constructor-injected; named `static const` values in one file:

```dart
class SyncPolicy {
  static const Duration initialBackoff    = Duration(seconds: 60);
  static const Duration maxBackoff        = Duration(hours: 2);
  static const double   backoffMultiplier = 5.0;
  static const double   jitterFraction    = 0.1;
  static const int      maxAttempts       = 20;
  static const Duration periodicInterval  = Duration(minutes: 15);

  static Duration backoffFor(int attemptCount) { ... }
}
```

Backoff curve: 60s -> 5m -> 25m -> 2h (capped). With jitter: ±10%. maxAttempts over this curve is roughly a week before exhaustion.

### 8.5 `sync_cycle()` orchestrator

One function, called by every trigger. Does outbound drain + inbound poll:

```dart
Future<void> syncCycle() async {
  if (_inFlight) return;                     // reentrancy guard
  _inFlight = true;
  try {
    await Future.wait(DestinationRegistry.all().map(drain));
    await portalInboundPoll();
  } finally {
    _inFlight = false;
  }
}
```

Single-isolate Dart; a boolean flag suffices for reentrancy.

### 8.6 Trigger wiring (lives in `clinical_diary`, not the shared package)

- `AppLifecycleState.resumed` → `syncCycle()`
- `Timer.periodic(SyncPolicy.periodicInterval)` while foreground → `syncCycle()`
- `EntryService.record()` completion → `syncCycle()` (fire-and-forget)
- `connectivity_plus` offline→online while foreground → `syncCycle()`
- `FirebaseMessaging.onMessage` and `onMessageOpenedApp` → `syncCycle()`

No background isolate. No WorkManager. No BGTaskScheduler.

## 9. Questionnaire-to-event flow

### 9.1 Single write API

```dart
class EntryService {
  Future<void> record({
    required String entryType,
    required String aggregateId,             // fresh UUID for new entries; existing id for edits
    required EventType eventType,            // finalized | checkpoint | tombstone
    required Map<String, dynamic> answers,
    String? checkpointReason,
    String? changeReason,
  });
}
```

All widgets in `entry_widgets/` call `record()`. The service handles event assembly, provenance, hashing, the atomic transaction, and kicking `syncCycle()`.

### 9.2 No-op detection

Before appending: compute a content hash of `(event_type, canonical-answers, checkpoint_reason, change_reason)`. If identical to the hash of the most recent event on this aggregate, skip the write. The `event_type` being part of the hash means legitimate transitions (checkpoint → finalized with same answers) are still recorded.

### 9.3 Validation boundary

| Layer | Responsibility |
| --- | --- |
| Widget (`clinical_diary/entry_widgets/`) | UX validation — required fields, date ranges, value constraints. Decides *whether* to call `record()` and with what `eventType`. |
| `EntryService` | Structural validation — `entry_type` is registered, `aggregate_id` format is valid, answers is JSON-serializable. Does not validate answer content. |
| Server (future) | Free to reject or flag events; a rejection surfaces as `SendPermanent` from the destination. |

## 10. Package organization and code impact

### 10.1 Target layout

```text
apps/common-dart/
├── provenance/                                 [NEW]
├── trial_data_types/                           (existing; + entry_type_definition.dart)
└── append_only_datastore/                      (existing; major expansion)
    └── lib/src/
        ├── core/                               (existing)
        ├── event/                              (refactored from existing)
        ├── storage/                            [NEW — backend interface + SembastBackend]
        ├── materialization/                    [NEW]
        ├── destinations/                       [NEW]
        ├── fifo/                               [NEW]
        ├── sync/                               [NEW]
        ├── entry_service.dart                  [NEW]
        └── entry_type_registry.dart            [NEW]

apps/daily-diary/clinical_diary/
└── lib/
    ├── entry_widgets/                          [NEW]
    │   ├── registry.dart
    │   ├── nosebleed_form_widget.dart          (logic moved from NosebleedService)
    │   └── survey_renderer_widget.dart         (consumes QuestionnaireDefinition)
    ├── services/
    │   ├── entry_service_bootstrap.dart        [NEW — DI wiring]
    │   ├── triggers.dart                       [NEW — lifecycle/connectivity/timer wiring]
    │   └── ...existing (enrollment, notification, task)
    └── screens/                                (updated to read from diary_entries)
```

### 10.2 Code removed

- `NosebleedService` (split across `EntryService`, `diary_entries` materializer, and `PrimaryDiaryServerDestination`).
- `QuestionnaireService` (definitions load via `EntryTypeRegistry`; submission via `EntryService.record()`).
- Direct HTTP sync code inside services.
- `aggregate_id` as `'diary-YYYY-M-D'` date bucket.
- `parentRecordId` inside nosebleed payload (superseded by shared `aggregate_id`).
- `server_timestamp` field on the event.

### 10.3 Code kept and adapted

- `EventRepository` — refactored to delegate persistence to `StorageBackend` rather than calling Sembast directly. Hash-chain and append logic stays.
- `QuestionnaireDefinition` and bundled `questionnaires.json` — unchanged. Becomes the shape of `widget_config` under `widget_id="survey_renderer_v1"`.
- `NosebleedRecord` domain type — kept as an in-widget convenience; never enters the event store.
- `MobileNotificationService` — unchanged; existing message callbacks now invoke `syncCycle()`.

### 10.4 Boot-time wiring

```dart
// clinical_diary/main.dart
await bootstrapAppendOnlyDatastore(
  backend: SembastBackend(path: ...),
  entryTypes: await loadEntryTypeDefinitionsFromAssets(),
  destinations: [
    PrimaryDiaryServerDestination(enrollmentService: ...),
    // Additional destinations added under compile-time flags in sponsor-repo
    // entry points (e.g. hht_diary_callisto).
  ],
);
```

## 11. Cross-cutting concerns

### 11.1 REQ-d00113 (Deleted Questionnaire Submission Handling)

The existing server behavior (`409 questionnaire_deleted`) and the existing mobile UX (surface a "withdrawn" error at submit time) are being replaced by a cleaner model:

- `PrimaryDiaryServerDestination.send()` translates `409 questionnaire_deleted` → `SendOk`. The mobile submission is recorded locally and "accepted" from the FIFO's perspective.
- The event stays in the event_log as the honest audit fact: the user submitted answers to a questionnaire that was subsequently withdrawn.
- The portal's independent inbound-message path (polled during `syncCycle()`) delivers a "tombstone entry X" instruction. Mobile handles that via `EntryService.record(..., eventType=tombstone, ...)`.
- Both sides converge on a tombstoned aggregate. Ingestion is idempotent at `event_uuid`, so duplicate tombstones are not a concern.
- UX: the user discovers the withdrawal via the entry's tombstoned state (shown on the aggregate) rather than via a submit-time error.

This pattern generalizes: any 4xx response is categorized by the destination's `send()` implementation, keeping protocol quirks local.

### 11.2 Chain-of-custody field duplication

As a migration bridge, the top-level event fields `client_timestamp`, `device_id`, and `software_version` duplicate values in `metadata.provenance[0]`. This duplication exists solely so the existing server ingestion code (which reads these fields off the wire) does not have to change in this plan.

**Trigger for removal:** when the portal ingestion is updated to read `metadata.provenance[0].*` instead of the top-level fields (deferred work, §4 item 1), these top-level fields will be removed from the mobile schema. Marked in the code with a `TODO(CUR-xxx)` referencing the portal-ingestion ticket when it exists.

### 11.3 Materializer fallbacks

- **`effective_date` fallback.** If the `EntryTypeDefinition.effective_date_path` is null, or if the JSON path doesn't resolve in current answers (e.g. the entry is still at a checkpoint stage with `data.startTime` not yet present), fall back to the `client_timestamp` of the *first* event on this aggregate. This gives the calendar a stable date for incomplete entries.
- **Answer merging.** Whole-replacement, latest-wins. The widget is responsible for passing the full answer set on each `record()` call.

## 12. Known risks

### 12.1 FIFO wedge on `SendPermanent`

Strict ordering + "recovery = app update" together produce a real failure mode: any destination returning a permanent content-rejection wedges that destination's FIFO until an app update is shipped. Subsequent events pile up behind the exhausted head.

Triggers include: client bug producing malformed events, client/server schema skew during rollout, destination-side config drift.

**Mitigation for this plan:** the UI makes this state visible. `anyFifoExhausted()` is exposed on the storage backend; the mobile UI can use it to surface a "data not syncing — please update" banner (the banner UX itself is deferred work).

**Mitigation for a future phase:** the portal ingest API can be designed to never return `SendPermanent`. Accept all well-formed envelopes unconditionally, defer content validation to an asynchronous server-side review. Regulated clinical systems commonly take this approach. Noted in `memory/project_event_sourcing_refactor_out_of_scope.md`.

### 12.2 Single-source editing only

The materializer uses whole-answer-replacement with latest-wins merging. This is correct for a single patient editing their own entries on one device at a time. It is **not** correct for:

- Patient editing the same entry on two devices concurrently (no multi-device conflict resolution).
- Portal users editing patient entries (not supported in this plan).

Full multi-source editing requires per-field vector clocks or CRDTs, conflict-resolution UI, and significant spec work. Deferred as a major future feature (§4 item 7).

## 13. Existing REQs covered

| REQ ID | Title | Source spec | Coverage |
| --- | --- | --- | --- |
| REQ-p00004 | Immutable Audit Trail via Event Sourcing | `spec/prd-database.md` | Fully, on mobile. Server-side is separate work. |
| REQ-p00006 | Offline-First Data Entry | `spec/prd-diary-app.md` | Now covers questionnaires in addition to nosebleeds. |
| REQ-p00013 | Complete Data Change History | `spec/prd-database.md` | Aggregate + append-only + tombstone events. |
| REQ-p01001 | Offline Event Queue with Automatic Synchronization | `spec/prd-event-sourcing-system.md` | Per-destination FIFOs + `sync_cycle()`. Background sync remains future work. |
| REQ-p01067 | NOSE HHT Questionnaire | `spec/prd-questionnaire-nose-hht.md` | Unchanged; definition flows through the new pipeline. |
| REQ-p01068 | HHT Quality of Life Questionnaire | `spec/prd-questionnaire-qol.md` | Unchanged; definition flows through the new pipeline. |
| REQ-p00049 | Ancillary Platform Services (push notifications) | `spec/prd-services.md` | Unchanged; FCM triggers `syncCycle()`. |
| REQ-d00004 | Local-First Data Entry Implementation | `spec/dev-app.md` | Refactored to the new shape. |
| REQ-d00113 | Deleted Questionnaire Submission Handling | `spec/dev-questionnaire.md` | Behavior modified per §11.1. |
| REQ-CAL-p00047 | Hard-Coded Questionnaires | (referenced in code headers) | Remains bundled JSON; augmented by `EntryTypeDefinition`. |

## 14. Likely spec gaps (DEV/OPS level — follow-up tickets)

Items this design implies that do not appear to have corresponding specs today. To be verified against `spec/INDEX.md` and filled in as DEV or OPS specs (not PRD) in follow-up tickets:

- Per-destination FIFO semantics (strict-order drain, exhausted state, backoff curve, `SyncPolicy` values).
- Chain-of-custody provenance structure (entry shape, append rules, `transform_version` semantics).
- `EntryTypeDefinition` schema (required fields, `effective_date_path` JSON-path dialect, `widget_id` registration contract).
- `sync_cycle()` trigger contract (foreground-only, specific triggers, reentrancy guard).
- Mobile materialized view `diary_entries` (schema, rebuild semantics, effective_date fallback).
- Compile-time sponsor-repo destination registration (registration ABI; EDC vs reverse-proxy selection).

## 15. Implementation pointers (for the writing-plans phase)

Key build order, roughly:

1. `provenance` package — data types and `appendHop` helper.
2. `trial_data_types` — add `EntryTypeDefinition`.
3. `append_only_datastore` — `StorageBackend` abstract + `SembastBackend` concrete; refactor existing event code to use it.
4. Materialization (`DiaryEntry`, materializer, rebuild).
5. `Destination` interface, `DestinationRegistry`, `SubscriptionFilter`, `WirePayload`.
6. `FifoEntry` + FIFO storage methods on `StorageBackend`.
7. `SyncPolicy`, drain loop, `sync_cycle()`.
8. `EntryService` + no-op detection + `EntryTypeRegistry`.
9. `PrimaryDiaryServerDestination` with the REQ-d00113 response translation.
10. `clinical_diary` widget registry + `NosebleedFormWidget` + `SurveyRendererWidget`.
11. `clinical_diary` triggers (`AppLifecycleState`, connectivity, timer, FCM handlers).
12. Screen updates (home, calendar, edit-existing) to read from `diary_entries`.
13. Removal of the old `NosebleedService` and `QuestionnaireService`.
14. Bundled asset updates: add `EntryTypeDefinition` entries for `nose_hht`, `hht_qol`, `eq` (entry_type IDs per existing `QuestionnaireType` mapping).

Test coverage should include: append-only integrity under interrupt, materializer correctness across the three `event_type` values, FIFO strict-ordering with mixed transient/permanent failures, `sync_cycle` reentrancy, multi-destination fan-out with filter matching, transform provenance, and `rebuildMaterializedView()`.

## 16. References

- Prior investigations (2026-04-20): mobile local-first architecture audit and portal audit logging audit.
- Existing code: `apps/common-dart/append_only_datastore/lib/src/infrastructure/repositories/event_repository.dart`, `apps/daily-diary/clinical_diary/lib/services/nosebleed_service.dart`, `apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart`, `apps/daily-diary/clinical_diary/lib/services/notification_service.dart`, `apps/daily-diary/diary_functions/lib/src/user.dart` (existing sync handler).
- Existing specs: `spec/prd-event-sourcing-system.md`, `spec/prd-diary-app.md`, `spec/prd-database.md`, `spec/dev-app.md`, `spec/dev-questionnaire.md`.
- Memory: `project_event_sourcing_refactor_out_of_scope.md`, `project_event_schema_migration_strategy.md`, `project_greenfield_status.md`.

---

## Changelog

Entries added here as this design's scope is extended by follow-on work. The body of the design above is preserved as-of its 2026-04-21 review and is NOT edited in place. Follow-on designs land in their own dated documents and record their changes here.

### 2026-04-22 — Dynamic destinations + demo app (Phase 4.3 + 4.6 inserted)

Follow-on design: `docs/superpowers/2026-04-22-dynamic-destinations-and-demo-design.md`.

Two new phases inserted into the rebase-merge sequence between Phase 4 and Phase 5:
- **Phase 4.3** — library additions: dynamic destination lifecycle (add/remove, schedule, historical replay on startDate, graceful and hard deactivation), batch FIFO model, unjam/rehabilitate ops; plus `EntryService` / `EntryTypeRegistry` / `bootstrapAppendOnlyDatastore` pulled forward from Phase 5.
- **Phase 4.6** — demo app at `apps/common-dart/append_only_datastore/example/` exercising the full surface; acceptance via nine `USER_JOURNEYS.md` scenarios.

Two decisions in the 2026-04-21 design are **inverted** by the 2026-04-22 follow-on:

1. **§5 decision #8 (strict FIFO ordering; wedge on exhausted head) is inverted.** Exhausted rows become skip-on-read: `readFifoHead` returns the first `pending` row, past any exhausted ones. Drain continues past exhausted rows rather than wedging behind them. A permanent-rejection is an audit-logged batch loss, not an outage for the destination. Rationale: under the batch-FIFO model (one row = one wire transaction = up to N events), wedging on a single bad batch would block an unbounded number of events for an app update; skip-and-continue gives ops a visible signal (`anyFifoExhausted` flips true) without blocking delivery. See follow-on §5 decision #4 and §6.5.

2. **§12.1 (FIFO wedge risk) is substantially reduced.** With skip-on-exhausted drain, the wedge failure mode described in this section largely disappears. The remaining wedge-equivalent is "every batch exhausts" — a systemic problem meriting a different response than the single-batch wedge. The deferred mitigation noted in this section (protocol-level "never return SendPermanent") is still valuable but no longer urgent.

Several additions that cascade from the follow-on:
- **FIFO row shape changes from one-event-per-row to one-batch-per-row.** `FifoEntry.event_ids` is a list; `wire_payload` covers the whole batch. Locked in Phase 4.3; `PLAN_PHASE4_sync.md` revised in parallel so Phase 4 implementation produces batch-FIFOs from the start. `Destination.transform` becomes `transform(List<Event>)`.
- **`fill_cursor` per destination in `backend_state`.** Durable watermark recording the last `sequence_number` promoted into any FIFO row for this destination. Enables app-interrupt recovery of batch-assembly.
- **`SyncPolicy` refactored to a value object** with optional override on `drain`/`syncCycle`. Small, strictly additive retrofit.
- **Concurrency model documented:** Dart single-isolate + sembast transaction serialization + `syncCycle` reentrancy guard + one new guard (`markFinal` and `appendAttempt` tolerate missing row/store for the drain-mid-flight race).
- **Phase 5 shrinks:** `EntryService`, `EntryTypeRegistry`, `bootstrapAppendOnlyDatastore` move out of Phase 5 into Phase 4.3. Phase 5 keeps the cutover work only (PrimaryDiaryServerDestination, portalInboundPoll, widget registry, triggers, screen updates, deletions, REQ-d00113 behavior update).
