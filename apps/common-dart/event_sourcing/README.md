# event_sourcing_datastore

FDA 21 CFR Part 11 aligned, offline-first event sourcing for Flutter.
Storage-backend swappable; ships with a Sembast (file / IndexedDB)
implementation that runs on iOS, Android, macOS, Windows, Linux, and Web.

## Contents

1. [Overview](#1-overview)
2. [Quick Start](#2-quick-start)
3. [Bootstrap and Startup](#3-bootstrap-and-startup)
4. [Event Types](#4-event-types)
5. [Views](#5-views)
6. [Destinations](#6-destinations)
7. [Provenance and Origin](#7-provenance-and-origin)
8. [Migrations](#8-migrations)
9. [Hash Chains and Verification](#9-hash-chains-and-verification)
10. [Failure Modes](#10-failure-modes)

---

## 1. Overview

The library writes a single append-only event log per installation, with
two derived projections:

- **Materialized views** — caller-supplied `Materializer`s fold each
  appended (or ingested) event into one or more named view rows. Views are
  caches: the event log is the source of truth, and any view can be
  rebuilt from it deterministically.
- **Per-destination FIFOs** — caller-supplied `Destination`s declare an
  event-selection filter, a wire format, and a `send()` callback. The
  library batches matching events into per-destination outbound queues,
  drains them on a sync cycle, and tracks send / wedged / tombstoned
  outcomes per row.

The same library serves two roles in one process:

- **Origin role** (mobile device, anywhere events are first authored):
  `EventStore.append(...)` writes new events, fans out to destinations,
  and runs materializers in the same transaction.
- **Receiver role** (any node bridged from upstream): `EventStore
  .ingestBatch(...)` decodes a wire envelope, idempotency-checks each
  event by `event_id`, stamps a receiver provenance entry, runs
  materializers (same path as origin appends), and persists into the same
  unified event log.

Key invariants the library enforces:

- **Append-only.** Events are never modified or deleted. Tombstone
  events are themselves new events.
- **Immutable hash chain.** Every event carries `event_hash` over its
  identity-field set plus `previous_event_hash` linking to the prior
  event in the local log. A second chain stamps cross-hop provenance
  on every receiver hop.
- **Atomic transactions.** A single `backend.transaction(...)` covers
  the event-log write, the sequence-counter advance, the materializer
  fold, the security-context sidecar write, and (on origin) per-
  destination FIFO enqueues. A throw anywhere rolls all of it back.
- **Receiver stays passive.** Ingest writes event-log rows, materializer
  rows, and `ingest-audit:*` system events; it never enqueues to its
  own outbound destinations on behalf of upstream traffic.
- **Permission-blind library.** `EventStore` exposes unguarded
  read/write APIs; access control lives in the widget / request-handler
  layer above the lib.

The library is pure Dart: nothing in the public surface depends on
Flutter, and the `StorageBackend` abstract contract is Dart-pure so a
second concrete backend (e.g. PostgreSQL) can be slotted in without
touching callers.

---

## 2. Quick Start

The smallest possible compile-and-run program: bootstrap, append one
event, materialize it, read it back from the view.

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:sembast/sembast_memory.dart';

const kNoteEntryType = EntryTypeDefinition(
  id: 'note',
  registeredVersion: 1,
  name: 'Note',
  widgetId: 'note_widget_v1',
  widgetConfig: <String, Object?>{},
);

Future<void> main() async {
  final db = await newDatabaseFactoryMemory().openDatabase('demo.db');
  final backend = SembastBackend(database: db);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'install-uuid-v4-here',
      softwareVersion: 'app@1.0.0+1',
    ),
    entryTypes: const <EntryTypeDefinition>[kNoteEntryType],
    destinations: const <Destination>[],
    materializers: const <Materializer>[
      DiaryEntriesMaterializer(promoter: identityPromoter),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      'diary_entries': <String, int>{'note': 1},
    },
  );

  await datastore.eventStore.append(
    entryType: 'note',
    entryTypeVersion: 1,
    aggregateId: 'note-1',
    aggregateType: 'DiaryEntry',
    eventType: 'finalized',
    data: <String, Object?>{
      'answers': <String, Object?>{'title': 'Hello', 'body': 'World'},
    },
    initiator: const UserInitiator('user-42'),
  );

  final entries = await backend.findEntries(entryType: 'note');
  print('view rows: ${entries.length}'); // -> 1
}
```

The four registered system entry types not visible in this example
(security-context, destination-mutation, retention, registry-init audits)
are auto-registered by `bootstrapAppendOnlyDatastore` before the caller-
supplied list. Their event-log rows appear automatically when the
relevant operations happen — no caller action required.

---

## 3. Bootstrap and Startup

Two responsibilities on the caller, separated by lifetime:

**One-time per installation.** Mint and persist a globally-unique
`Source.identifier`. UUIDv4 to disk on first launch, the same value on
every subsequent boot. The library does NOT validate uniqueness at
runtime; it is a caller obligation. Two installations that share an
identifier will collide on any receiver they both bridge to (system
audit aggregates are keyed on `source.identifier`, per
REQ-d00154-D).

**Each boot.** Construct a `SembastBackend` and call
`bootstrapAppendOnlyDatastore`:

```dart
final datastore = await bootstrapAppendOnlyDatastore(
  backend: backend,
  source: Source(
    hopId: 'mobile-device',
    identifier: persistedInstallUuid,
    softwareVersion: 'my-app@1.2.3+45',
  ),
  entryTypes: <EntryTypeDefinition>[...userEntryTypes],
  destinations: <Destination>[primary, secondary, ...],
  materializers: <Materializer>[
    DiaryEntriesMaterializer(promoter: identityPromoter),
    // ... other materializers
  ],
  initialViewTargetVersions: <String, Map<String, int>>{
    'diary_entries': <String, int>{
      for (final defn in userEntryTypes)
        defn.id: defn.registeredVersion,
    },
    // ... map per materializer.viewName
  },
);
```

The returned `AppendOnlyDatastore` exposes four collaborators:

- `eventStore` — the write API (`append`, `ingestEvent`, `ingestBatch`,
  retention, verification).
- `entryTypes` — the `EntryTypeRegistry`, queryable by `byId(...)` and
  `isRegistered(...)`.
- `destinations` — the `DestinationRegistry`, supporting runtime
  add / remove / start-date / end-date / tombstone-and-refill operations.
- `securityContexts` — read-only access to the security-context sidecar
  store.

Plus one runtime helper: `setViewTargetVersion(viewName, entryType,
version)` for adding a new entry type to an already-running view (e.g. a
sponsor configuration update at runtime).

The bootstrap call itself emits one `system.entry_type_registry_initialized`
audit event recording the registry's full id-to-version map. It is
deduped by content, so a same-state reboot is a no-op; bumping any
`registeredVersion` (or adding a type) emits a new audit row on the
next boot.

---

## 4. Event Types

An `EntryTypeDefinition` is a pure value type identifying one user-
facing entry type:

```dart
const EntryTypeDefinition kNote = EntryTypeDefinition(
  id: 'note',
  registeredVersion: 1,
  name: 'Note',
  widgetId: 'note_widget_v1',
  widgetConfig: <String, Object?>{},
  effectiveDatePath: 'date',     // optional dotted path into answers
  destinationTags: ['journal'],  // optional routing hints
  materialize: true,             // default true
);
```

The lib treats the registry as the single authority for "what entry
types this build accepts." On `EventStore.append` the lib validates
`entryType` against the registry. On `EventStore.ingestBatch` it
additionally validates `entryTypeVersion <= registeredVersion`
(REQ-d00145-M) — see [Section 8](#8-migrations).

### Event-type constraints

`EventStore.append` requires `eventType` to be exactly one of
`finalized`, `checkpoint`, or `tombstone`. These three are user-intent
discriminators owned by the lib:

- **`finalized`** — the canonical "this entry is done" terminator. The
  `DiaryEntriesMaterializer` flips `is_complete = true` on the view row.
- **`checkpoint`** — partial / in-progress save. Same merge semantics as
  finalized, but `is_complete = false`.
- **`tombstone`** — soft-delete marker. Sets `is_deleted = true`;
  preserves prior fields.

### System events

Ten reserved entry types are auto-registered before the caller's list
and managed by the lib:

| Entry type id | Emitted by |
| --- | --- |
| `security_context_redacted` | `EventStore.clearSecurityContext` |
| `security_context_compacted` | `EventStore.applyRetentionPolicy` |
| `security_context_purged` | `EventStore.applyRetentionPolicy` |
| `system.destination_registered` | `DestinationRegistry.addDestination` |
| `system.destination_start_date_set` | `DestinationRegistry.setStartDate` |
| `system.destination_end_date_set` | `DestinationRegistry.setEndDate` |
| `system.destination_deleted` | `DestinationRegistry.deleteDestination` |
| `system.destination_wedge_recovered` | `DestinationRegistry.tombstoneAndRefill` |
| `system.retention_policy_applied` | `EventStore.applyRetentionPolicy` |
| `system.entry_type_registry_initialized` | `bootstrapAppendOnlyDatastore` |

All ten ship `materialize: false` so they bypass every materializer.
They land in the event log as immutable audit rows; that is their only
purpose. A caller-supplied id colliding with one of these throws
`ArgumentError` at bootstrap time with an explicit "reserved" message.

System events are excluded from destination FIFOs by default. A
destination that wants forensic visibility into config-change audits
opts in via `SubscriptionFilter(includeSystemEvents: true)`. See
[Section 6](#6-destinations).

---

## 5. Views

A `Materializer` is the lib's pluggable fold contract. One materializer
maintains one named view (`viewName`); the lib runs every materializer
whose `appliesTo(event)` returns true, in registration order, inside
the same transaction as the append (or ingest):

```dart
abstract class Materializer {
  String get viewName;
  bool appliesTo(StoredEvent event);
  EntryPromoter get promoter;
  Future<int> targetVersionFor(Txn txn, StorageBackend backend,
                               String entryType);
  Future<void> applyInTxn(Txn txn, StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  });
}
```

A materializer reads and writes view rows through the generic
`StorageBackend.{read,upsert,delete,find,clear}View*` methods, scoped
by `viewName`. A throw inside `applyInTxn` rolls back the entire
append (or ingest batch).

The library ships one concrete materializer:

- **`DiaryEntriesMaterializer`** — folds events whose
  `aggregateType == 'DiaryEntry'` into the `diary_entries` view. The
  fold logic is exposed as `DiaryEntriesMaterializer.foldPure(...)` so
  callers (e.g. `rebuildView`) can reuse it without going through the
  backend.

### Materialize-on-ingest

The same materializer code path runs on both origin appends and on
ingested events from upstream — no caller wiring required. A receiver
of upstream traffic sees materialized rows appear as ingest commits,
exactly as if the events had been appended locally.

### Reactive read APIs

The `StorageBackend` exposes three broadcast streams:

- **`watchEvents({int? afterSequence})`** — emits replay-then-live of
  the event log. Useful for an "Events" panel or for pipeline glue.
- **`watchFifo(destinationId)`** — emits the destination's FIFO
  snapshot (`List<FifoEntry>`) on subscribe and on every mutation.
- **`watchView(viewName)`** — emits the view's row list on subscribe
  and on every mutation. Cross-view isolated: a mutation in view A
  never wakes a `watchView('B')` subscriber.

These streams are lossy under `pause()` (Dart broadcast contract). To
throttle, do work asynchronously inside `onData` or cancel and
re-subscribe.

### Rebuilding a view

Two helpers replay the event log into a view in one transaction:

```dart
// Single-view rebuild with explicit per-entry-type target versions.
// Strict-superset rule: must cover every entry type already in
// view_target_versions plus any new ones.
final processed = await rebuildView(
  materializer,
  backend,
  entryTypeLookup,
  targetVersionByEntryType: <String, int>{
    'note': 1,
    // ... one entry per entry type the view materializes
  },
);

// Legacy disaster-recovery rebuild for the diary_entries view, identity
// promotion (no version-aware promotion).
final aggregates = await rebuildMaterializedView(backend, entryTypeLookup);
```

Both run inside one `backend.transaction` — a mid-rebuild failure rolls
everything back.

---

## 6. Destinations

A `Destination` is a synchronization target that owns its own FIFO,
batch transform, and send callback:

```dart
abstract class Destination {
  String get id;                   // stable; used as fifo_<id> store
  SubscriptionFilter get filter;   // event-selection predicate
  String get wireFormat;           // e.g. 'json-v1', 'esd/batch@1'
  Duration get maxAccumulateTime;  // single-event-batch hold
  bool get allowHardDelete;        // default false
  bool get serializesNatively;     // default false; see below
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate);
  Future<WirePayload> transform(List<StoredEvent> batch);
  Future<SendResult> send(WirePayload payload);
}
```

### Subscription filters

`SubscriptionFilter` composes four AND-combined constraints:

```dart
const SubscriptionFilter(
  entryTypes: <String>['note', 'survey'],   // null = any user type
  eventTypes: <String>['finalized'],        // null = any event type
  predicate: null,                          // optional escape hatch
  includeSystemEvents: false,               // default; opt-in below
);
```

`null` means "match all"; an empty list means "match nothing." That
distinction is deliberate: a destination that wants ONLY system events
sets `entryTypes: <String>[]` plus `includeSystemEvents: true`.

### User-payload destinations vs native-wire destinations

The library supports two FIFO row shapes:

- **3rd-party wire format** (`serializesNatively: false`, the default).
  The lib invokes `Destination.transform(batch)` and persists the
  resulting `WirePayload` (bytes + `contentType` + `transformVersion`)
  verbatim. Drain hands the same bytes to `Destination.send`.
- **Native canonical format** (`serializesNatively: true`,
  `wireFormat: 'esd/batch@1'`). The lib builds a `BatchEnvelopeMetadata`
  from the local `Source`, persists envelope metadata + null payload on
  the FIFO row, and reconstructs the wire bytes deterministically (RFC
  8785 JCS) on each send attempt. `transform` is not called and SHALL
  throw if invoked.

The native format is what `EventStore.ingestBatch` decodes on the
receiver side, so a native-destination outbound stream is bit-compatible
with the receiver's ingest API — see the example app's `DownstreamBridge`
for the in-memory wiring.

### Drain outcomes

`send(payload)` returns one of three variants:

- **`SendOk`** — accepted; drain marks the FIFO row `sent` and stamps
  `sent_at`.
- **`SendTransient`** — retryable; drain applies backoff per
  `SyncPolicy` (or the supplied policy) and re-attempts on the next
  cycle. After `maxAttempts` the row converges to the same wedged
  terminal state as a permanent rejection.
- **`SendPermanent`** — non-retryable; drain marks the FIFO row
  `wedged` and halts at the head. Recovery is `DestinationRegistry
  .tombstoneAndRefill(...)`, which marks the wedged row tombstoned,
  sweeps the trail of pending rows behind it, and rewinds the fill
  cursor so the next cycle re-batches from a fresh sequence.

### Receiver-role passivity

When a node is acting as a receiver (i.e. accepting ingest from
upstream), `EventStore.ingestBatch` does NOT enqueue to local
destinations on behalf of upstream events. Receiver-side processing
is exactly: idempotency check, persist, materialize. Outbound fan-out
is a property of the originator's local destinations only. A node that
both originates AND bridges further downstream registers its own local
destinations whose filters explicitly opt-in to bridge-relevant traffic.

---

## 7. Provenance and Origin

Every event carries a `metadata.provenance` list. Entry zero is the
originator's hop, recorded at `append` time:

```dart
ProvenanceEntry(
  hop: source.hopId,                 // role-class string
  identifier: source.identifier,     // per-installation UUID
  softwareVersion: source.softwareVersion,
  receivedAt: <append timestamp>,
);
```

Every receiver hop appends one more entry, recording arrival, the
chain-2 cursor (`previousIngestHash`, `ingestSequenceNumber`), and the
batch context if any (`batchContext`).

`Source` carries three fields:

- **`hopId`** — role-class string; well-known values are `mobile-device`
  and `portal-server`. The lib does not enumerate further.
- **`identifier`** — per-installation unique identity. UUIDv4 on first
  install, persisted to disk, the same value on every subsequent boot.
  System audit aggregate ids equal `source.identifier`.
- **`softwareVersion`** — opaque tag the lib does not parse; conventionally
  `package@semver+build`.

### Origin discrimination

To distinguish locally-originated events from bridged-from-upstream
events:

```dart
// Compares provenance[0].identifier against source.identifier (NOT
// hopId — two installs of the same role class are distinct origins).
final isMine = eventStore.isLocallyOriginated(event);

// Convenience accessor on the event itself:
final origin = event.originatorHop;
print(origin.hop);         // e.g. 'mobile-device'
print(origin.identifier);  // origin install UUID
```

`StorageBackend.findAllEvents` accepts `originatorHopId` and
`originatorIdentifier` filters that match against `provenance[0]` for
read-side queries.

---

## 8. Migrations

Two version stamps appear on every event and govern two different
migration concerns:

- **`entry_type_version`** — schema version of the user-payload `data`
  for one entry type. Caller-supplied per `EventStore.append` call;
  preserved verbatim on the wire and on the receiver's persisted row.
- **`lib_format_version`** — storage shape version produced by the
  current lib build. Stamped automatically from
  `StoredEvent.currentLibFormatVersion` on every append.

### Per-entry-type promotion

When a materializer's stored target version differs from an event's
authoring `entry_type_version`, the lib invokes the materializer's
`EntryPromoter` callback before folding:

```dart
typedef EntryPromoter =
    Map<String, Object?> Function({
      required String entryType,
      required int fromVersion,
      required int toVersion,
      required Map<String, Object?> data,
    });
```

The promoter returns a NEW map and SHALL NOT mutate `data` in place.
The lib treats it as opaque: it does not compose chains, inspect the
result, or interpret the version direction. A throw in the promoter
rolls back the transaction.

Use `identityPromoter` when authoring versions always equal target
versions (the most common case). Compose your own when entry-type
schema bumps require runtime promotion of historical events. Persisted
view rows are then upgraded by calling `rebuildView` with the new target
map (strict-superset rule applies).

### Lib format ahead-of-receiver

On `EventStore.ingestBatch`, the lib checks `lib_format_version` on
each incoming event before any other work. If the wire version exceeds
the receiver's `currentLibFormatVersion`, the entire batch is rolled
back with `IngestLibFormatVersionAhead`. Operator action is to upgrade
the receiver build.

The check is asymmetric: receivers MAY accept events whose
`lib_format_version` is less than or equal to their own
`currentLibFormatVersion` (forward-compatible decode), but MAY NOT
accept events ahead of theirs.

---

## 9. Hash Chains and Verification

Two independent hash chains protect different invariants.

### Chain 1 — per-event provenance integrity

Each event stamps `event_hash` over the canonical JSON of its identity
fields (`event_id`, `aggregate_id`, `entry_type`, `event_type`,
`sequence_number`, `data`, `initiator`, `flow_token`,
`client_timestamp`, `previous_event_hash`, `metadata`). Each receiver
hop records the wire-arrival hash on its provenance entry as
`arrival_hash` and recomputes the event hash with its own hop appended.

`EventStore.verifyEventChain(event)` walks the provenance list backward
from tail to origin. For each hop, it recomputes what the prior hop's
`event_hash` should have been (using the right substituted
`sequence_number` per receiver-side reassignment) and compares against
the stored `arrival_hash`. Returns a `ChainVerdict`; non-throwing.

### Chain 2 — per-receiver sequence integrity

On every ingest, the receiver stamps `previousIngestHash` on its own
provenance entry pointing at the prior ingest-stamped event in its
local log. Together with `ingestSequenceNumber`, this forms a hash
chain over the receiver's ingest sequence independent of upstream
chain state.

`EventStore.verifyIngestChain({fromSequenceNumber, toSequenceNumber})`
walks Chain 2 over a slice of the local log; non-throwing; returns a
`ChainVerdict`. Origin-only events in the slice are skipped (they have
no receiver-stamped top entry).

Both verdicts list `ChainFailure` entries with `position`, `kind`
(`arrivalHashMismatch`, `previousIngestHashMismatch`,
`provenanceMissing`), `expectedHash`, and `actualHash` for every broken
link, so a tooling layer can report what failed without re-walking the
chain.

---

## 10. Failure Modes

The library exposes a small, deliberate exception taxonomy so callers
can write retry / escalate / rebuild logic against typed errors rather
than scraping strings.

### Storage exceptions

A sealed `StorageException` hierarchy with three disjoint variants:

- **`StorageTransientException`** — retryable. The classifier today
  maps `dart:async` `TimeoutException` here.
- **`StoragePermanentException`** — non-retryable but data intact.
  `dart:io` `FileSystemException`, `StateError`, `ArgumentError`, and
  most sembast `DatabaseException` lifecycle codes (`errBadParam`,
  `errDatabaseNotFound`, `errDatabaseClosed`) map here. Unrecognized
  errors classify here too — a retry loop on unknown errors is worse
  than failing loudly.
- **`StorageCorruptException`** — data-integrity violated.
  `FormatException` (JSON decode failure, hash-chain break) and
  sembast `errInvalidCodec` map here. Recovery is rebuild from the
  event log or restoration from a clean source.

`classifyStorageException(error, stack)` is a pure function; never
throws, always returns one of the three variants. Use it in
catch-blocks to switch on a typed verdict:

```dart
try {
  await store.append(...);
} catch (e, s) {
  switch (classifyStorageException(e, s)) {
    case StorageTransientException(): /* retry with backoff */
    case StoragePermanentException(): /* surface to operator */
    case StorageCorruptException():   /* rebuild / quarantine  */
  }
}
```

### Ingest exceptions

`EventStore.ingestBatch` and `ingestEvent` throw five typed exceptions
the receiver-side caller (typically a bridge or HTTP handler) should
catch:

| Exception | Cause | Caller action |
| --- | --- | --- |
| `IngestDecodeFailure` | Wire bytes malformed or unsupported `wireFormat` | Quarantine the wire payload |
| `IngestChainBroken` | Chain 1 verdict failed on an incoming event | Quarantine; investigate |
| `IngestIdentityMismatch` | Same `event_id` already stored with a different hash | Quarantine; investigate |
| `IngestLibFormatVersionAhead` | Wire `lib_format_version > receiver currentLibFormatVersion` | Upgrade receiver lib |
| `IngestEntryTypeVersionAhead` | Wire `entry_type_version > registered_version` | Upgrade receiver registry |

All five are atomic at batch granularity: a thrown exception rolls back
the entire `ingestBatch` transaction, so receivers never see partial
batch acceptance. After catch, the caller may invoke
`EventStore.logRejectedBatch(bytes, wireFormat: ..., reason: ...,
failedEventId: ..., errorDetail: ...)` to record one
`ingest.batch_rejected` audit event with the wire bytes preserved for
forensic replay.

Idempotent re-ingest of an already-stored event with a matching arrival
hash returns `IngestOutcome.duplicate` (NOT thrown) and emits one
`ingest.duplicate_received` audit event.
