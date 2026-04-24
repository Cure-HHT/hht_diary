# Mobile Event-Sourcing Implementation

**Version**: 1.0
**Audience**: Development Specification
**Status**: Draft
**Last Updated**: 2026-04-21

> **See**: prd-database.md for the immutable audit trail principle (REQ-p00004) and complete data change history (REQ-p00013)
> **See**: prd-event-sourcing-system.md for the Event Type Registry (REQ-p01050) and offline event queue (REQ-p01001)
> **See**: docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md for the target architecture
> **See**: docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/ for the phased implementation plan (CUR-1154)

This specification defines the mobile-side implementation of the event-sourcing architecture described in prd-database.md and prd-event-sourcing-system.md. It accumulates DEV-level requirements added across the 5 phases of CUR-1154. Phase 1 introduces the two pure-Dart data types that underpin all subsequent work: `ProvenanceEntry` (chain-of-custody) and `EntryTypeDefinition` (registry entry shape).

---

# REQ-d00115: ProvenanceEntry Schema and Append Rules

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00013

## Rationale

REQ-p00004 (Immutable Audit Trail via Event Sourcing) and REQ-p00013 (Complete Data Change History) require that every data change be attributable to its origin and immutable once recorded. For events that flow across multiple systems (mobile device to diary server to sponsor portal to EDC), a single top-level `device_id` and `client_timestamp` captures only the originating hop. Downstream hops — the diary-server ingestion, portal-server receipt, any transform stages — need to contribute their own attribution without mutating the original record.

A chain-of-custody structure stored in `event.metadata.provenance` solves this: each hop appends one entry on receipt, recording who, when, what software version, and whether a transform was applied. Prior entries are never touched. The resulting chain is a complete, immutable record of the event's journey, directly supporting the ALCOA+ *Attributable* and *Contemporaneous* principles for cross-system data flow.

The top-level `device_id`, `client_timestamp`, and `software_version` event fields remain as duplicates of `provenance[0]` as a migration bridge during the mobile refactor; they are removed once the portal ingestion reads provenance directly (deferred work).

The cross-system provenance chain serves two distinct audit requirements: per-event identity preservation across hops (Chain 1), supported by `arrival_hash`; and per-destination tamper-evidence across events from multiple originators (Chain 2), supported by `previous_ingest_hash` and `ingest_sequence_number`. `batch_context` composes batch-level audit onto per-event records — an event received as part of an `esd/batch@1` batch carries its batch's identity and position, so an auditor can reconstruct the batch from stored events (see REQ-d00145) without duplicating wire bytes into the event store.

## Assertions

A. The system SHALL append exactly one `ProvenanceEntry` to `event.metadata.provenance` on each hop that receives the event, such that the length of the chain equals the number of systems the event has traversed.

B. The system SHALL NOT mutate any `ProvenanceEntry` already present in the chain; subsequent hops SHALL only append.

C. Each `ProvenanceEntry` SHALL carry the fields `hop` (string), `received_at` (ISO 8601 with timezone offset), `identifier` (string), `software_version` (string), and an optional `transform_version` (string).

D. The `identifier` SHALL be a device UUID when the hop represents a patient-facing mobile device; for server hops the `identifier` SHALL be a server instance identifier.

E. The `software_version` SHALL follow the format `"<package-name>@<semver>[+<build>]"`, enabling each hop's software version to be precisely identified from the provenance entry alone.

F. The `transform_version` field SHALL be non-null when and only when this hop's incoming wire payload was produced by a transform at the previous hop; absence SHALL indicate the payload was passed through without transformation.

G. A `ProvenanceEntry` MAY carry a nullable `arrival_hash` string. This field SHALL be `null` on the originator's entry (`provenance[0]` stamped by the originating system). For every entry stamped by a receiver hop on ingest, `arrival_hash` SHALL be non-null and SHALL equal the value of `event.event_hash` as the event appeared on the wire when this hop received it — i.e., the `event_hash` stored by the immediately-preceding hop. The field SHALL NOT be mutated after the entry is appended.

H. A `ProvenanceEntry` MAY carry a nullable `previous_ingest_hash` string. This field SHALL be `null` on the originator's entry and SHALL be `null` on the first-ever provenance entry stamped by a given receiver hop (no destination-local predecessor). For every other receiver-stamped entry, `previous_ingest_hash` SHALL be non-null and SHALL equal the stored `event_hash` of the event immediately preceding this event in the destination's Chain 2 (ingest order). The field SHALL NOT be mutated after the entry is appended.

I. A `ProvenanceEntry` MAY carry a nullable `ingest_sequence_number` integer. This field SHALL be `null` on the originator's entry. For every receiver-stamped entry on a given destination, `ingest_sequence_number` SHALL be non-null, monotonically increasing by 1 across all entries stamped at that destination (across all originators, across all ingestBatch and ingestEvent calls, across receiver-originated audit events — §2.9 of the design spec), and MUST NOT be rewound or reused.

J. A `ProvenanceEntry` MAY carry a nullable `batch_context` record with fields `batch_id` (UUID string), `batch_position` (non-negative integer), `batch_size` (positive integer), `batch_wire_bytes_hash` (SHA-256 hex string), and `batch_wire_format` (string). `batch_context` SHALL be non-null on receiver-stamped entries produced by `EventStore.ingestBatch`, and SHALL be `null` on all other entries (originator entries, process-local `ingestEvent` entries, and entries on receiver-originated audit events emitted outside a batch context).

*End* *ProvenanceEntry Schema and Append Rules* | **Hash**: c90dd968

---

# REQ-d00116: EntryTypeDefinition Schema

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01050

## Rationale

REQ-p01050 (Event Type Registry) establishes that the system maintains a registry of event types and requires metadata on each type for discoverability, versioning, and sponsor eligibility. The mobile implementation needs a concrete data structure to carry that metadata: a pure-Dart value type that describes one entry type's identity, its schema version, the widget used to render it, and optional hints for materializer and destination routing behavior.

`EntryTypeDefinition` is that data structure. It is pure data — no storage, no Flutter dependency — so that the same package can be used on the portal server when server-side entry-type definitions are introduced. The Phase 1 deliverable is the type itself and its JSON round-trip. The registry that consumes these definitions and the widget registry that resolves `widget_id` are downstream phases (3 and 5 respectively) of CUR-1154.

## Assertions

A. An `EntryTypeDefinition` SHALL carry an `id` string that matches the `event.entry_type` value for every event of this entry type.

B. An `EntryTypeDefinition` SHALL carry a `version` string identifying the schema version under which events of this type are written.

C. An `EntryTypeDefinition` SHALL carry a `name` string used for display purposes by the UI and by operational tooling.

D. An `EntryTypeDefinition` SHALL carry a `widget_id` string that serves as a key into the Flutter widget registry, selecting the bespoke or shared widget that renders this entry type.

E. An `EntryTypeDefinition` SHALL carry a `widget_config` JSON payload; the shape of `widget_config` SHALL be determined by the widget corresponding to `widget_id`, not by the EntryTypeDefinition itself.

F. An `EntryTypeDefinition` MAY carry a nullable `effective_date_path` string; when non-null, `effective_date_path` SHALL be a JSON path usable by the materializer to extract the entry's effective date from `event.data.answers`.

G. An `EntryTypeDefinition` MAY carry an optional `destination_tags` list of strings; destinations SHALL be able to match on these tags via `SubscriptionFilter`.

*End* *EntryTypeDefinition Schema* | **Hash**: 0bb2f928

---

# REQ-d00117: StorageBackend Transaction Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

The mobile event-sourcing pipeline composes several independent write streams: the event log, the `diary_entries` materialized view, per-destination FIFO queues, and key-value bookkeeping (sequence counter, schema version). A patient-originated write — for example, recording a nosebleed — touches all of these atomically: the event lands, the materialized view refreshes, every subscribed destination's FIFO grows by one entry, and the sequence counter advances. Any partial failure would corrupt the audit trail and break downstream synchronization.

A single transaction contract wrapping the Sembast database solves this: all writes within a `transaction(body)` call commit or roll back together. The `Txn` handle is lexically scoped so accidental use outside its defining body is detectable and rejected, not silently discarded against a closed transaction. Key-value bookkeeping lives in a Sembast store named `backend_state`, deliberately not named `metadata`, because the event record already carries a top-level field named `metadata` — reusing the name at the store level would make code references ambiguous and invite bugs.

The link to REQ-p01001 (Offline Event Queue with Automatic Synchronization) is indirect but load-bearing: REQ-p01001-D mandates FIFO delivery order per destination, and that ordering guarantee holds only if the enqueue of a FIFO entry and the append of its corresponding event land atomically in the same transaction. Without transactional atomicity a failed write could produce an event with no FIFO entry (undeliverable) or a FIFO entry with no event (dangling reference) — both of which break REQ-p01001-C (persistent storage of queued events) and REQ-p01001-D (FIFO delivery). This requirement (REQ-d00117) is therefore the mobile-side mechanism that makes REQ-p01001's ordering and persistence guarantees implementable, while REQ-p00004 (Immutable Audit Trail) is the direct driver of the append-only and tamper-detection properties.

## Assertions

A. `StorageBackend.transaction(body)` SHALL execute `body` inside a single atomic Sembast transaction such that all `Txn`-bound writes within `body` commit together or roll back together.

B. A `Txn` handle SHALL NOT be valid for use outside the lexical scope of the `transaction()` body that produced it; attempts to use it outside that scope SHALL raise an error.

C. `StorageBackend.appendEvent(txn, event)` SHALL write to the event log and advance the sequence counter within the same `Txn` such that either both writes land or neither does.

D. `StorageBackend.upsertEntry(txn, entry)` SHALL replace the entire `diary_entries` row identified by the entry's identifier, performing a whole-row replace and not a partial field merge.

E. `StorageBackend.enqueueFifo(txn, destination_id, fifo_entry)` SHALL append `fifo_entry` to destination `destination_id`'s FIFO with `final_status` equal to `null` and with an empty `attempts[]` list.

F. Key-value bookkeeping for the backend, including the sequence counter and schema version, SHALL be stored in a Sembast store named `backend_state`; the store name `metadata` SHALL NOT be used for this purpose.

*End* *StorageBackend Transaction Contract* | **Hash**: bb51d314

---

# REQ-d00118: Event Record Schema

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00013

## Rationale

Event records flow from mobile to diary-server to sponsor-portal, and each layer has distinct stamping and identification responsibilities. Historically the mobile record carried a `server_timestamp` populated from the local device clock at record time, which is both misleading — the server has not seen the event yet — and redundant, because the ingestion server stamps its own server-authoritative timestamp on receipt. The shape fixed here removes that device-side `server_timestamp`, promotes `entry_type` to a first-class field rather than burying it in `metadata`, and keeps top-level `client_timestamp`, `device_id`, and `software_version` as exact duplicates of `metadata.provenance[0]` during a migration window that ends when portal ingestion reads provenance directly.

The `aggregate_id` format is allowed to vary during the mobile refactor because two write paths coexist until Phase 5 completes: entries recorded through the new `EntryService.record()` path use UUIDs, while entries still written through the legacy `EventRepository.append()` path retain the original `"diary-YYYY-M-D"` date-bucket identifier. Once the legacy path is deleted, every event carries a UUID `aggregate_id`.

## Assertions

A. Every event record SHALL carry a first-class `entry_type` string field whose value identifies the kind of patient-recorded or administered entry.

B. Event records SHALL NOT carry a `server_timestamp` field; the previously-stored device-clock value SHALL be removed from both the in-memory event type and the persisted Sembast record, and the ingesting server SHALL be the sole authority on server-side timestamps.

C. For any event whose `metadata.provenance` chain is non-empty, the top-level event fields `client_timestamp`, `device_id`, and `software_version` SHALL equal, respectively, `metadata.provenance[0].received_at`, `metadata.provenance[0].identifier`, and `metadata.provenance[0].software_version`. (The `software_version` clause of this assertion becomes active when the `EntryService.record()` path introduces `ProvenanceEntry` stamping in a later phase; the mobile event record at the time this requirement is written carries `client_timestamp` and `device_id` but no top-level `software_version` field, so the `software_version` clause is unenforceable against any write path currently in production and MUST NOT be read as implying existing compliance.)

D. For events written through the `EntryService.record()` path the `aggregate_id` SHALL be a UUID identifying the entry; events written through the legacy `EventRepository.append()` path MAY retain the `"diary-YYYY-M-D"` date-bucket pattern until that legacy path is removed.

*End* *Event Record Schema* | **Hash**: 2937d8bc

---

# REQ-d00119: Per-Destination FIFO Queue Semantics

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

Each synchronization destination — the primary diary server, optional analytics targets, future additions — receives events through its own strictly-ordered queue. Strict ordering is required because a destination that receives, for example, a nosebleed edit before the original creation event cannot reconstruct the intended state. Per-destination isolation is required so that one destination being unreachable does not stall sync to the others.

A dedicated Sembast store per destination, keyed by integer insertion order, provides FIFO semantics cheaply. A FIFO entry's `final_status` carries one of three terminal values plus the null pre-terminal state: `null` while the entry is still a drain candidate, `"sent"` once delivery succeeds, `"wedged"` once retry budget is exhausted or a permanent failure occurs, and `"tombstoned"` when the operator has declared the bundle undeliverable as-built via `tombstoneAndRefill` (REQ-d00144). Entries marked `sent`, `wedged`, or `tombstoned` are retained in the store as send-log records for FDA/ALCOA compliance. The head of the FIFO is wedged whenever its `final_status` is `wedged`; no bypass is allowed on a wedged head because allowing it would silently violate ordering. Recovery from a wedged head is specified in REQ-d00144.

## Assertions

A. Each registered synchronization destination SHALL have exactly one associated FIFO store identified by its `destination_id`.

B. A FIFO entry SHALL carry the fields `entry_id`, `event_ids`, `event_id_range`, `sequence_in_queue`, `wire_payload`, `wire_format`, `transform_version`, `enqueued_at`, `attempts[]`, `final_status`, and `sent_at`. The `event_ids` and `event_id_range` fields hold the batch contract defined in REQ-d00128; a single-event batch is a batch of length one.

C. The `final_status` field SHALL be either `null` or one of the values `"sent"`, `"wedged"`, or `"tombstoned"`; `null` means "not yet terminal" and the three enum values are the complete set of terminal states. No other values SHALL be legal.

D. Once a FIFO entry's `final_status` is non-null, the entry SHALL NOT be deleted from its FIFO store; the entry SHALL be retained as a permanent send-log record.

E. `sequence_in_queue` SHALL be assigned monotonically at row insertion from a per-destination counter that SHALL NOT rewind and SHALL NOT reuse values when a row is deleted. A gap in `sequence_in_queue` between two surviving rows is the audit signal that one or more rows were deleted from the FIFO store (the only code path that deletes FIFO rows is REQ-d00144-C).

*End* *Per-Destination FIFO Queue Semantics* | **Hash**: 92a66dd9

---

# REQ-d00120: Canonical Hashing for Cross-Platform Event Verification

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004

## Rationale

The `event_hash` field on every event carries a SHA-256 digest that downstream systems — diary server, sponsor portal, EDC, any future verifier — use to confirm the event they received is byte-identical to the event the originating mobile device recorded. For that verification to work, every implementation that computes the hash must feed the hash function identical bytes.

Dart's native `jsonEncode` preserves Map insertion order and has number-formatting quirks that do not reproduce on other platforms: a Python receiver that round-trips the event through `json.loads` loses the insertion order; a Postgres `numeric` column may return `1` where Dart wrote `1.0`; JavaScript's JSON module escapes Unicode differently than Dart's. Each of these platform differences silently changes the hashed byte sequence and produces a different digest even when the event's semantic content is unchanged.

Adopting [RFC 8785 (JSON Canonicalization Scheme, JCS)](https://www.rfc-editor.org/rfc/rfc8785) as the canonical serialization used at hash-input time closes the gap. JCS pins down key ordering (sorted lexicographically at every depth), number formatting (ECMA-262 `Number.prototype.toString`, including negative-zero and trailing-zero normalization), string escaping (minimal, consistent), and whitespace (none). Libraries implementing JCS exist in every language the system needs: `rfc8785` on PyPI, `json-canonicalize` on npm, `serde_json_canonicalizer` on crates.io, and the in-repo `canonical_json_jcs` package on the mobile side.

## Assertions

A. The `event_hash` field on every persisted event SHALL be computed as SHA-256 over the UTF-8 bytes of the RFC 8785 (JCS) canonical JSON serialization of the event's identity fields.

B. The identity fields hashed SHALL be exactly `event_id`, `aggregate_id`, `entry_type`, `event_type`, `sequence_number`, `data`, `initiator`, `flow_token`, `client_timestamp`, `previous_event_hash`, and `metadata`; no other fields SHALL be included in the hash input. `user_id` and `device_id` are no longer top-level on `StoredEvent` (replaced by `initiator` and `metadata.provenance[0].identifier` respectively).

C. A receiver implementing RFC 8785 in any language SHALL be able to reconstruct the canonical byte sequence from the received identity fields and independently verify the `event_hash` value.

D. The canonicalization scheme used SHALL NOT be changed without a spec amendment and coordinated update across all implementations; changing the algorithm silently would break tamper-detection on all pre-existing events.

E. When a receiver appends a `ProvenanceEntry` to `metadata.provenance` during ingest, the event's `event_hash` SHALL be recomputed over the identity field set specified in assertion B (which includes `metadata`, and therefore the extended provenance chain), and the recomputed value SHALL be stored in place of the wire `event_hash`. The originator's `event_hash` remains recoverable via the Chain 1 walk specified in REQ-d00146-F. Cross-store byte-for-byte comparison of raw `event_hash` is not a valid identity check on ingested events; the Chain 1 walk is the specified mechanism.
On every ingest hop the `event_hash` field is a function of the provenance chain as it stood at that hop. A receiver's stored `event_hash` is therefore the receiver's own output hash, not the originator's output hash. Identity preservation across hops is verified by the Chain 1 walk (each receiver entry's `arrival_hash` equals the hash the prior state would produce), not by naive field equality.

*End* *Canonical Hashing for Cross-Platform Event Verification* | **Hash**: 70f2e3d2

---

# REQ-d00121: diary_entries Materialization from Event Log

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00013

## Rationale

REQ-p00004-E requires the system to derive current data state by replaying events from the event store, and REQ-p00004-L requires the current view to be updated automatically when new events are created. On the mobile side the `diary_entries` store fulfils both: it is a materialized projection of the append-only `event_log`, rebuildable from events at any time, never written to except as the fold of some event sequence.

A pure-function materializer is the mechanism that makes this hold. `Materializer.apply(previous, event, def, firstEventTimestamp) -> DiaryEntry` takes the prior view row (or null for the first event on an aggregate), the incoming event, the `EntryTypeDefinition` for its `entry_type`, and the `client_timestamp` of the first event on this aggregate; it returns the new view row deterministically. No I/O, no clock reads, no randomness — the same inputs always produce the same output, which is what lets the same function drive both the online write path (called from `EntryService.record()`'s transaction in a later phase) and the offline rebuild path (`rebuildMaterializedView`).

The three event types fold differently: `finalized` and `checkpoint` both merge `event.data.answers` into `previous.current_answers` — keys present in the event's delta (whether with a non-null value or an explicit `null`) overwrite the corresponding key in the merged result, and keys absent from the event preserve their prior value — and differ only in the `is_complete` flag the materialized row carries (`true` for `finalized`, `false` for `checkpoint`); `tombstone` preserves `current_answers` and `is_complete` but flips `is_deleted` to `true`. Each event therefore captures exactly the change the caller chose to apply, and the materialized view is a pure fold of those deltas in `sequence_number` order. The `effective_date` is resolved from the merged `current_answers` (not the event's bare delta) by walking `EntryTypeDefinition.effective_date_path` as a dotted JSON path; when the path is null or does not resolve, the materializer falls back to the first-event `client_timestamp` on this aggregate. Dart's `Map<String, Object?>` and JSON serialization preserve the "key absent" vs "key present with null value" distinction, which the fold contract depends on (assertion J).

The `rebuildMaterializedView(backend, lookup)` helper is the disaster-recovery counterpart: it reads all events in sequence order, folds them per aggregate, and replaces the entire `diary_entries` store with the result. It is not a runtime operation — it is a developer tool and recovery mechanism. Its existence, plus the purity of `Materializer.apply`, is what makes `diary_entries` a cache rather than a source of truth. Production code that reads `diary_entries` is implicitly relying on the invariant that calling `rebuildMaterializedView` would produce the same result; any code that writes `diary_entries` by a means other than the materializer breaks that invariant and the cache contract with it.

## Assertions

A. `Materializer.apply(previous, event, def, firstEventTimestamp)` SHALL be a pure function of its inputs: it SHALL NOT perform I/O, read the clock, or consume random values, such that identical inputs always produce identical outputs.

B. When `event.event_type` equals `"finalized"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_complete` is `true` and whose `current_answers` equals the key-wise merge of `previous.current_answers` (or the empty map when `previous` is null) under `event.data.answers`: for each key `k` present in `event.data.answers`, the merged value SHALL equal `event.data.answers[k]` — including when that value is `null` (explicit clear); for each key `k` absent from `event.data.answers`, the merged value SHALL equal `previous.current_answers[k]` (prior value preserved).

C. When `event.event_type` equals `"checkpoint"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_complete` is `false` and whose `current_answers` is produced by the same key-wise merge rule as assertion B.

D. When `event.event_type` equals `"tombstone"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_deleted` is `true`; all other fields, including `current_answers` and `is_complete`, SHALL carry over unchanged from the previous row.

E. For every event, the returned `DiaryEntry.latest_event_id` SHALL equal `event.event_id` and `DiaryEntry.updated_at` SHALL equal `event.client_timestamp`.

F. `DiaryEntry.effective_date` SHALL be computed by resolving `EntryTypeDefinition.effective_date_path` as a dotted-path JSON traversal into `current_answers` and parsing the resolved value as a full `DateTime` (ISO 8601 instant); when the path is null, does not resolve, or yields a value that cannot be parsed as a `DateTime`, `effective_date` SHALL fall back to `firstEventTimestamp`. Callers that require a date-only (calendar day) view SHALL perform that truncation at read time; the stored value preserves the full instant so later time-of-day-aware queries remain possible.

G. `rebuildMaterializedView(backend, lookup)` SHALL read all events ordered by `sequence_number`, fold them through `Materializer.apply`, and replace the entire `diary_entries` store with the result; prior contents of `diary_entries` SHALL NOT be read as input to the rebuild.

H. `rebuildMaterializedView` SHALL return the number of distinct `aggregate_id` values materialized in the rebuild.

I. The `diary_entries` store SHALL be treated as a cache derivable from `event_log` by `rebuildMaterializedView`; production code that writes `diary_entries` outside the materializer SHALL be considered a violation of the cache contract.

J. `Materializer.apply` SHALL distinguish "key absent from `event.data.answers`" from "key present with value `null`" when computing the merged `current_answers`: the first preserves `previous.current_answers[key]`; the second sets `merged[key]` to `null` (the key is present in the merged map with a `null` value). Implementations SHALL iterate `event.data.answers` via its key set (e.g., `for (final k in answers.keys)`) rather than by indexing an assumed key list, so absent keys are not confused with present-`null` keys.

*End* *diary_entries Materialization from Event Log* | **Hash**: aabfc89b

---

# REQ-d00122: Destination Contract for Per-Destination Sync

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

REQ-p01001 mandates offline queuing and FIFO delivery, but it does not specify how the queue knows what to enqueue or how the bytes that leave the device are shaped. On mobile the answer is a `Destination` abstraction: one object per synchronization target (the primary diary server, a future analytics backend, etc.) that owns three responsibilities. First, it declares which events it cares about via a `SubscriptionFilter` — a deterministic predicate over `(entry_type, event_type, metadata tags)` — so that an event landing on the log is enqueued to exactly the destinations that want it, with no fan-out broadcast and no manual wiring. Second, it declares its wire format as an opaque string identifier (`"json-v1"`, `"proto-v2"`) and exposes a `transform(event)` method that turns an in-memory event into a `WirePayload` — the bytes, their content type, and the `transform_version` that produced them. Every downstream `ProvenanceEntry` carries that `transform_version`, so a receiver disputing a payload can always trace which version of which destination's transform produced it. Third, it exposes a `send(payload)` method whose return value categorizes the outcome as `SendOk`, `SendTransient` (retryable — HTTP 5xx, network error, timeout), or `SendPermanent` (not retryable — HTTP 4xx excluding rate-limits, schema mismatch). The drain loop reads that categorization and decides to mark-sent, back off and retry, or mark-wedged and halt the FIFO.

Destinations are typically registered at app boot in a `DestinationRegistry`, but the registry stays open to runtime `addDestination` calls (REQ-d00129-A). The Phase-4 "freeze on first read" rule has been superseded by the REQ-d00129 dynamic lifecycle: uniqueness of destination `id` is enforced at `addDestination` time, and the `(startDate, endDate)` schedule attached to each registration controls when a destination actually accepts events. This lets a destination be brought online mid-study (e.g., a portal-audit destination added after enrollment) without the ordering violation the old freeze was guarding against — the schedule's `startDate` pins the exact point at which matching events start flowing, and past-start registrations trigger a deterministic historical replay (REQ-d00130) rather than a silent partial enqueue. The registry is bound to a `StorageBackend` at construction so schedule mutations (`setStartDate`, `setEndDate`) and destination deletions persist transactionally; tests construct one registry per test against an in-memory backend.

This requirement defines the contract — what a `Destination` is obliged to expose and how the registry behaves. The actual FIFO drain loop (what happens when `send` is called) is specified in REQ-d00124; the retry timing curve is specified in REQ-d00123; the concrete `PrimaryDiaryServerDestination` that implements this contract against the real HTTP server is deferred to Phase 5.

When a destination's backing sink must not be wedged by failures in an unrelated event category, register multiple `Destination` instances with disjoint `SubscriptionFilter`s against the same underlying sink rather than one destination filter-switching within a single FIFO. Each `Destination` owns its own FIFO and its own strict-order wedge; a wedge on one filter's events leaves the others draining normally. The library gives uniqueness of `destination.id` and per-destination `SubscriptionFilter` the structural support this pattern needs; no additional primitive is required.

## Assertions

A. A `Destination` SHALL expose a stable `id` string used as the identifier of its FIFO store; the id SHALL be unique across the `DestinationRegistry` and SHALL NOT change for the lifetime of the store.

B. A `Destination` SHALL expose a `SubscriptionFilter` that deterministically selects which events to enqueue based on the event's `entry_type`, `event_type`, and optional caller-supplied predicate.

C. A `Destination` SHALL declare a `wire_format` string identifier (e.g., `"json-v1"`); the value SHALL match the `wire_format` field on every `FifoEntry` produced for this destination.

D. `Destination.transform(List<StoredEvent> batch)` SHALL return a `WirePayload` covering the entire batch, with fields `bytes`, `content_type`, and `transform_version`; `transform_version` SHALL be recorded on the resulting `FifoEntry` and appended to `ProvenanceEntry.transform_version` on the receiver side. The batch SHALL be non-empty (REQ-d00128-D).

E. `Destination.send(payload)` SHALL return a `SendResult` value of exactly one of the variants `SendOk`, `SendTransient`, or `SendPermanent`; the destination's categorization of underlying HTTP codes, network errors, and timeouts into those variants SHALL be a per-destination concern not dictated by this contract.

F. A `SubscriptionFilter` SHALL support allow-listing by `entry_type` and/or `event_type`, SHALL support an optional escape-hatch `predicate` function, and SHALL distinguish an absent allow-list (match all) from an empty allow-list (match none).

G. The `DestinationRegistry` SHALL remain open to runtime `addDestination` calls throughout the process lifetime; it SHALL NOT freeze on first read. Uniqueness of destination `id` is enforced at `addDestination` time (REQ-d00129-A), and the schedule state attached to each registration (REQ-d00129-A+C+F+H) governs when a destination actually accepts events. The boot-time-only "freeze on first read" contract that this assertion previously described has been superseded by REQ-d00129's dynamic-lifecycle model.

*End* *Destination Contract for Per-Destination Sync* | **Hash**: 1b3481f3

---

# REQ-d00123: SyncPolicy Retry Backoff Curve

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

REQ-p01001-E requires exponential backoff on failed synchronization attempts but deliberately leaves the curve shape, cap, jitter, and lifetime maximum unspecified — those are platform-level tuning decisions. On mobile the chosen curve is governed by two conflicting pressures. Too-frequent retries drain the battery, generate load against a diary server that is already signaling distress (503s, timeouts), and chew through the user's cellular data on entries that are not going to succeed in the next few minutes anyway. Too-slow retries starve pending entries of delivery attempts so that an entry that would have succeeded five minutes ago continues to sit in the FIFO for an hour, violating the reasonableness expectation of REQ-p00006 (Offline-First Data Entry) that sync "happens soon" when the device is online.

The chosen curve: 60s initial backoff, ×5 multiplier per attempt, capped at 2h, ±10% jitter, 20 attempts maximum over approximately one week. Initial 60s is large enough that a transient server blip clears before the first retry; ×5 reaches the cap after four attempts so the curve spends most of its lifetime at the 2h cap rather than sprinting through dozens of short retries; ±10% jitter avoids the thundering-herd phenomenon where every device whose 10-minute backoff elapses at the same moment hits the server simultaneously. The 20-attempt cap puts a finite bound on the retry process — after approximately one week of failures the entry is marked `wedged`, wedging the FIFO, which gates further drain attempts on that destination and raises a human-visible "sync failed" signal to the user per REQ-p01001-H.

These constants are static module-level values, not runtime-configurable, because changing them mid-run would produce a user experience where a single entry's retry schedule mixed two different curves. Changing the curve requires a spec amendment and a coordinated app release. The values claimed here are from the design doc's §8.2 sync-policy table and carry the Phase-4 sign-off of design-review.

## Assertions

A. `SyncPolicy.initialBackoff` SHALL equal `Duration(seconds: 60)`.

B. `SyncPolicy.backoffMultiplier` SHALL equal `5.0`.

C. `SyncPolicy.maxBackoff` SHALL equal `Duration(hours: 2)`; computed backoff values SHALL be capped at this maximum.

D. `SyncPolicy.jitterFraction` SHALL equal `0.1`; each backoff SHALL be multiplied by `1 + uniform(-jitterFraction, +jitterFraction)` to avoid synchronized retry storms across devices.

E. `SyncPolicy.maxAttempts` SHALL equal `20`; an entry that accumulates this many `attempts` on its log SHALL be marked `wedged` on the next transient-failure drain step, wedging its FIFO.

F. `SyncPolicy.periodicInterval` SHALL equal `Duration(minutes: 15)` — the foreground sync-cycle cadence invoked from the Phase-5 trigger layer.

*End* *SyncPolicy Retry Backoff Curve* | **Hash**: 3efbe4b4

---

# REQ-d00124: Per-Destination FIFO Drain Loop

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

Given the `Destination` contract (REQ-d00122) and the retry curve (REQ-d00123), the drain loop is the component that actually moves bytes. One invocation operates on one destination's FIFO, reads the head entry, decides whether to call `send()` based on backoff elapsed since the last attempt, routes the `SendResult`, and appends an `AttemptResult` to the entry's attempts log regardless of outcome. The attempts log is append-only — `SHALL record every call to destination.send` — because it is the audit trail that satisfies REQ-p01001-M (log failed synchronization events with detailed error messages) and supplies the timestamps the next backoff computation reads.

The drain loop's most important property is strict FIFO order. Within a destination's FIFO, `readFifoHead` returns the first row in `sequence_in_queue` order whose `final_status` is `null` (pre-terminal, a drain candidate) or `wedged` (terminal, blocking); rows whose `final_status` is `sent` or `tombstoned` are passable and are skipped. The two terminal-passable statuses are audit records for delivered payloads (`sent`) and for operator-declared-undeliverable bundles whose events have been re-queued under REQ-d00144 (`tombstoned`); neither blocks subsequent delivery. The one blocking terminal state is `wedged`: a row whose retry budget is exhausted or whose permanent-failure classification means it cannot be retried as-built. When `readFifoHead` returns a wedged row, `drain` halts without calling `destination.send`, satisfying REQ-p01001-D by refusing to ship a later bundle past an undelivered earlier one. Recovery from a wedged head runs through `tombstoneAndRefill` (REQ-d00144), which converts the wedged row to `tombstoned`, clears the pending trail, and rewinds `fill_cursor` so the covered events are re-queued in fresh bundles against the current transform and destination state.

Multi-destination behavior is independent by construction: each destination's FIFO has its own wedged and passable rows, and one destination's wedge does not affect drain on any other destination. That property falls out of invoking `drain` per-destination within `sync_cycle` (REQ-d00125).

## Assertions

A. `drain(destination)` SHALL read the head of `fifo/{destination.id}` via `backend.readFifoHead(destination.id)`. `readFifoHead` SHALL return the first row in `sequence_in_queue` order whose `final_status` is `null` or `wedged`; rows whose `final_status` is `sent` or `tombstoned` SHALL be skipped. When the destination's FIFO has no such row, `readFifoHead` SHALL return `null` and `drain` SHALL return without calling `destination.send`.

B. When the head's computed backoff (from `SyncPolicy.backoffFor(attempts.length)` plus the most recent `attempts[last].attempted_at`) has not elapsed, `drain` SHALL return without calling `destination.send`.

C. On `SendOk`, `drain` SHALL mark the head entry `sent` via `backend.markFinal(id, entry_id, FinalStatus.sent)` and continue the loop to the next head entry.

D. On `SendPermanent`, `drain` SHALL mark the head entry `wedged` via `backend.markFinal(id, entry_id, FinalStatus.wedged)`.

E. On `SendTransient` where `attempts.length + 1 >= SyncPolicy.maxAttempts`, `drain` SHALL mark the head entry `wedged` via `backend.markFinal(id, entry_id, FinalStatus.wedged)`.

F. On `SendTransient` below the attempt limit, `drain` SHALL append the resulting `AttemptResult` via `backend.appendAttempt(id, entry_id, attempt)` and return; the entry's `final_status` remains `null`; the next backoff interval SHALL apply to the next `drain` trigger.

G. `drain` SHALL call `backend.appendAttempt(id, entry_id, attempt)` for every invocation of `destination.send`, regardless of outcome; the attempts log is append-only and SHALL record every send attempt made against an entry.

H. `drain` SHALL preserve strict FIFO order within a destination: terminal-passable statuses are `{sent, tombstoned}`; `wedged` is the sole blocking terminal state. `drain` SHALL return without calling `destination.send` whenever `readFifoHead` returns a row whose `final_status` is `wedged`. Recovery from a wedged head requires `tombstoneAndRefill` (REQ-d00144).

*End* *Per-Destination FIFO Drain Loop* | **Hash**: 92afab97

---

# REQ-d00125: sync_cycle() Orchestrator and Trigger Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00049, REQ-p01001

## Rationale

The drain loop per destination (REQ-d00124) is the inner mechanism; `sync_cycle()` is the top-level orchestrator that fans out across all registered destinations, drains them concurrently, and then performs the portal inbound poll that picks up tombstones authored on the portal side (§11.1 of the design doc). It is the single entry point every trigger — app-lifecycle resume, the 15-minute foreground timer, connectivity-restored notification, post-`record()` fire-and-forget, FCM message receipt — calls into. Centralizing on one entry point means the reentrancy guard lives in exactly one place: `sync_cycle()` tracks whether a prior invocation is still in flight and, if so, immediately returns from the second call with no side effects. The guard exists because the trigger set is inherently racy (an FCM message and a connectivity-restored event can fire within milliseconds of each other), and allowing concurrent sync cycles would produce overlapping `send` calls that each see the same pending head entry and each record an attempt — inflating the attempts count against the `maxAttempts` cap without actually improving delivery.

The "foreground-only" constraint — no WorkManager, no BGTaskScheduler — is a deliberate scope decision. Background isolate sync would require sponsor-specific keychain unlock flows on iOS, separate Dart isolate context for opening Sembast, and a second code path through the sync machinery that has its own failure modes and its own audit-trail contributions. All of that for the marginal benefit of syncing when the app is genuinely backgrounded on devices where the user has already moved on. The trade-off: the 15-minute foreground periodic timer and the app-resume trigger together guarantee that any entry queued while the app is in use is attempted within 15 minutes of the user opening the app; entries queued and then left on a fully-backgrounded-and-killed app wait until next launch. This is acceptable for patient diary data where intraday delivery latency is not a regulatory concern (REQ-p00006 guarantees data is not lost, not that it is delivered within minutes of creation).

The `portalInboundPoll()` step is the tombstone-propagation mechanism: the diary server exposes a read-side API that returns tombstones authored on the portal (clinician-initiated deletions), and `sync_cycle()` runs that poll after outbound drains so any server-authored tombstone overlays land in the same cycle as the outbound entries they interact with. Its implementation is Phase 5; Phase 4 ships it as a stub returning immediately so the call site is in place.

## Assertions

A. `syncCycle()` SHALL drain every registered destination concurrently via `Future.wait` over `DestinationRegistry.all().map(drain)`; an exception thrown from one destination's `drain` SHALL NOT cancel any other destination's `drain`.

B. After all outbound drains complete, `syncCycle()` SHALL invoke `portalInboundPoll()` — whose concrete implementation lands in Phase 5 and whose Phase-4 body is a no-op stub.

C. `syncCycle()` SHALL hold a single-isolate reentrancy guard: when invoked while a prior invocation has not yet completed, the second invocation SHALL return immediately without triggering any new drain work or any new `portalInboundPoll` call.

D. `syncCycle()` SHALL be callable — via wiring that lives in the Phase-5 trigger layer — from at least these five trigger sites: app-lifecycle resume, a foreground 15-minute periodic timer, post-`record()` fire-and-forget, connectivity-restored event, and FCM-message receipt (per REQ-p00049-A).

E. `syncCycle()` SHALL NOT run from a background isolate; no `WorkManager` task, `BGTaskScheduler` task, or equivalent background execution path SHALL be registered for synchronization.

*End* *sync_cycle() Orchestrator and Trigger Contract* | **Hash**: 03bfd328

---

# REQ-d00126: SyncPolicy Injectable Value Object

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

REQ-d00123 fixes the retry-backoff curve constants that production uses. Phase 4 modelled those constants as static class members on `SyncPolicy`, which made the curve impossible to override in unit tests without either editing the file under test or abandoning the assertion that `drain` actually respects the configured curve. Tests that want to verify transient-retry cadence need a fast curve (milliseconds, not a 60-second initial backoff) or they do not complete in reasonable time. The Phase 4.3 demo and future concrete destinations also need a principled way to pass a non-default policy through without monkey-patching the sync machinery.

The resolution is to model `SyncPolicy` as a `const` value object with instance fields, keep the production constants on a single `static const defaults` instance, and widen `drain` / `syncCycle` to accept an optional `SyncPolicy? policy` that falls back to `SyncPolicy.defaults` when null. Tests inject a fast policy; production passes nothing. The curve itself (REQ-d00123) is unchanged — `SyncPolicy.defaults` still evaluates to exactly the REQ-d00123 constants.

## Assertions

A. `SyncPolicy` SHALL be a value class with `final` fields and a `const` constructor. Default values SHALL be provided as `SyncPolicy.defaults`, a `static const` instance whose field values equal the constants named in REQ-d00123.

B. `drain()` and `syncCycle()` SHALL accept an optional `SyncPolicy? policy` parameter; when null, they SHALL fall back to `SyncPolicy.defaults`.

C. Phase-4 call sites that referenced `SyncPolicy.initialBackoff` (and siblings) as static members SHALL migrate to the `SyncPolicy.defaults.initialBackoff` instance-member form in one refactoring pass; no `@Deprecated` shims SHALL be introduced.

*End* *SyncPolicy Injectable Value Object* | **Hash**: 8ab70c79

---

# REQ-d00127: markFinal and appendAttempt Tolerate Missing FIFO Row

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

The drain loop (REQ-d00124) calls `destination.send(wirePayload)` outside any storage transaction because `send()` is a network round-trip that can take seconds. Immediately after `send()` returns, `drain` opens a transaction to append an `AttemptResult` and, if the result is terminal, to mark the row `sent` or `wedged`. In the interval between the `send` returning and that transaction opening, a concurrent user-initiated operation — `tombstoneAndRefill` clearing the pending trail and rewinding the cursor, or `deleteDestination` destroying the whole FIFO store — can remove the row `drain` is about to write to. Without tolerance for missing rows, the subsequent `markFinal` or `appendAttempt` throws, drain abends with an error that has no operational meaning (the work was done; the user asked for the row to be gone), and the caller sees a stack trace for what is the correct outcome.

The resolution is narrowly scoped: both operations no-op cleanly on a missing row or missing FIFO store, emit a diagnostic `warning`-level log line naming the race they close, and return without throwing. This is not a license to silently drop data — only the two specific ops documented here behave this way, and they behave this way only because the row's absence means the work has already been subsumed by a user operation that is allowed to remove it.

## Assertions

A. `StorageBackend.markFinal(destId, entryId, finalStatus)` SHALL be a no-op (return without throwing) if the FIFO row identified by `entryId` does not exist in the destination's FIFO store, and SHALL be a no-op if the FIFO store for `destId` does not exist.

B. `StorageBackend.appendAttempt(destId, entryId, attempt)` SHALL be a no-op on a missing row or missing FIFO store, with the same tolerance as `markFinal`.

C. Both methods SHALL emit a `warning`-level diagnostic log line when they no-op due to a missing target, naming the method, the row id, the destination id, and the expected race (`drain/tombstoneAndRefill` or `drain/delete`).

*End* *markFinal and appendAttempt Tolerate Missing FIFO Row* | **Hash**: 71b33da6

---

# REQ-d00128: FIFO Batch Shape and Fill Cursor

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

REQ-d00119 (Phase 2) defined a FIFO row as holding exactly one event, with a single `event_id` and a single `wire_payload`. Phase 4.3 migrates that shape to hold a batch — one row covers one or more events and carries exactly one wire payload for the whole batch. The motivation is destination-side: a destination whose server endpoint natively accepts a batch of events in one request should not be forced to send N separate requests for N events when the events arrive within a short window. The drain loop still treats one row as one wire transaction; what changes is that one wire transaction can now deliver several events.

The batch shape demands a `fill_cursor` per destination, recording the highest `sequence_number` that has already been promoted into any FIFO row for this destination regardless of `final_status`. Without a cursor, the logic that decides which events have not yet been enqueued for this destination would be forced to scan every FIFO row and cross-reference the event log, which does not scale. The cursor is per-destination because subscription filters and start/end windows (REQ-d00129) give each destination its own view of the event log. Idempotency of `fillBatch` — the act of promoting events into FIFO rows — depends on the cursor behaving transactionally alongside the FIFO-row write.

Batch assembly is destination-controlled: the destination declares a `canAddToBatch(currentBatch, candidate)` predicate, invoked per candidate, and a `maxAccumulateTime` hold on single-event batches so a destination that prefers to ship batches of two or more is not prematurely flushed when only one event is available.

## Assertions

A. `FifoEntry.event_ids` SHALL be a non-empty `List<String>` identifying every event included in the batch; each element SHALL be an `event_id` from the event log.

B. `FifoEntry.event_id_range` SHALL be a pair `(first_seq: int, last_seq: int)` drawn from the `sequence_number` values of the contained events; the pair SHALL be used for cursor advancement math.

C. `FifoEntry.wire_payload` SHALL be one `WirePayload` covering every event in the batch; no per-event wire payload SHALL be stored.

D. `Destination.transform(List<Event> batch)` SHALL produce one `WirePayload`; it SHALL NOT be called with an empty batch.

E. `Destination.canAddToBatch(List<Event> currentBatch, Event candidate)` SHALL be invoked by `fillBatch` for each candidate under consideration; returning `false` SHALL end the current batch (flushing it if `maxAccumulateTime` permits) and SHALL leave the candidate available for the next tick.

F. `Destination.maxAccumulateTime: Duration` SHALL be honored by `fillBatch`: a single-event batch SHALL NOT flush until `now() - batch.first.client_timestamp >= maxAccumulateTime` OR `canAddToBatch` has already returned `false` for a subsequent candidate.

G. The storage backend SHALL persist a `fill_cursor_{destination_id}: int` value under `backend_state` for each registered destination; the value SHALL be the largest `sequence_number` that has been promoted into any FIFO row for that destination, or `-1` when no row has yet been enqueued.

H. `fillBatch(destination)` SHALL be idempotent: repeated invocations with no new matching events SHALL produce no new FIFO rows and SHALL NOT advance `fill_cursor`.

*End* *FIFO Batch Shape and Fill Cursor* | **Hash**: d36f1dde

---

# REQ-d00129: Dynamic Destination Lifecycle

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

Phase 4 froze the `DestinationRegistry` on first read because a mid-run registration would silently change which events are enqueued to which queues. Phase 4.3 relaxes this to support a lifecycle that is driven by trial and enrollment state: a destination may be added late (e.g., a portal-audit destination brought online partway through a patient's study), may have a `startDate` that places it in dormant or scheduled state until the date is reached, may have a retroactive `startDate` that triggers historical replay over already-queued events, and may be deactivated at a scheduled future time without discarding in-flight work.

Immutability of `startDate` once set is load-bearing. If `startDate` could be moved earlier, the FIFO's contract that every enqueued event matches the destination's time window at enqueue time would weaken to a contract about the *current* window — forcing either a re-scan of already-enqueued rows when the window changed or acceptance of rows the current window would exclude. Both options break the audit trail. Fixing `startDate` at its first assignment avoids this; callers who need a different `startDate` register a different destination.

Mutability of `endDate` is safe because ending a window only stops new enqueues; already-enqueued rows keep their terminal statuses and remain in the FIFO store. `setEndDate` returns a result code so callers can distinguish three outcomes. `closed` fires when the call transitions the destination from "currently active" to "currently closed" — i.e. the new `endDate` is at or before `now()` and the destination was not previously closed. `scheduled` fires when the new `endDate` is in the future (the destination is currently active and will close at a later wall-clock time) or when a previously-closed destination is reopened with a future `endDate`. `applied` fires when the call does not change the destination's current active-vs-closed state relative to `now()` — for example, overwriting an existing past `endDate` with a different past `endDate`, or replacing a future-dated `endDate` with another future-dated `endDate` without crossing the `now()` boundary. The three codes are exclusive; every call returns exactly one.

Hard deletion is gated because some destinations carry regulatory audit weight and must not be purged in one call; the `allowHardDelete` field is an explicit opt-in that the destination's class declares, not a flag the caller toggles.

## Assertions

A. `DestinationRegistry.addDestination(Destination d)` SHALL register `d` at any time after bootstrap; if another destination with `d.id` is already registered, the call SHALL throw `ArgumentError`.

B. `Destination.allowHardDelete: bool get` SHALL default to `false` in the abstract class contract; concrete destinations that permit hard deletion SHALL override the getter to `true`.

C. `DestinationRegistry.setStartDate(String id, DateTime startDate)` SHALL throw `StateError` if the destination already has a non-null `startDate`. Once set, `startDate` SHALL be immutable for the lifetime of this destination registration.

D. If `setStartDate` is called with `startDate <= now()`, the library SHALL trigger historical replay synchronously in the same transaction.

E. If `setStartDate` is called with `startDate > now()`, no replay SHALL occur; subsequent events accumulate in `event_log` and are batched into the FIFO only after wall-clock time has crossed `startDate` (enforced by `fillBatch`'s time-window check).

F. `DestinationRegistry.setEndDate(String id, DateTime endDate)` SHALL return a `SetEndDateResult` enum; possible values are `closed` (endDate <= now), `scheduled` (endDate > now), and `applied` (no state change relative to the current wall-clock).

G. `DestinationRegistry.deactivateDestination(String id)` SHALL be equivalent to `setEndDate(id, DateTime.now())` and SHALL return `SetEndDateResult.closed`.

H. `DestinationRegistry.deleteDestination(String id)` SHALL throw `StateError` if the destination's `allowHardDelete == false`. When allowed, the call SHALL unregister the destination and delete its FIFO store in one transaction.

I. `fillBatch(destination)` SHALL filter candidate events by `event.client_timestamp >= dest.startDate AND event.client_timestamp <= min(dest.endDate, now())`; events outside this window SHALL NOT be enqueued to this destination.

*End* *Dynamic Destination Lifecycle* | **Hash**: 17ee5d1c

---

# REQ-d00130: Historical Replay on Past startDate

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

When a destination is registered with a `startDate` in the past, the library SHALL replay every matching event from the event log into the destination's FIFO in one transaction, building batches with the destination's own `canAddToBatch` and `transform` so the resulting rows are indistinguishable from rows that would have been produced had the destination been live the whole time. Running replay inside a sembast transaction provides the serialization guarantee needed to avoid double-enqueue: a `record()` call landing concurrently waits behind the replay transaction, and when it proceeds its own `fillBatch` walks from the cursor the replay has already advanced.

Replay is scoped to Phase-4.3 library correctness; portal-initiated replay or re-materialization is out of scope and covered by the out-of-scope memory note dated 2026-04-21.

## Assertions

A. Historical replay SHALL be a single-transaction walk of `event_log` from `fill_cursor + 1` forward, filtering by the destination's `subscriptionFilter` AND the time window from REQ-d00129-I.

B. Replay SHALL use the destination's own `canAddToBatch` and `transform` to produce FIFO rows identical in shape to those produced by `fillBatch` during live operation.

C. A new event appended during replay (same Dart isolate, under sembast transaction serialization) SHALL NOT be double-enqueued: the concurrent `record()` transaction SHALL wait behind the replay transaction, and when it runs, its `fillBatch` SHALL re-evaluate candidates strictly after the `fill_cursor` the replay advanced to.

*End* *Historical Replay on Past startDate* | **Hash**: 254b541a

---

# REQ-d00133: EntryService.record Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00006, REQ-p01001

## Rationale

`EntryService.record` is the sole write API invoked by widgets: it hides the atomic event-assembly, the materializer run, the sequence-counter advance, and the no-op detection behind one call whose semantics are stable across the widget/destination/transport evolutions that follow. Pulling it forward from Phase 5 into Phase 4.3 is driven by the Phase 4.6 demo, which needs to exercise this write path against the demo destination without the Phase 5 cutover dependencies (server destinations, trigger wiring, screen updates) landing first.

The assertion that diverges most from the original Phase-5 spec is D: the Phase-4.3 design defers destination fan-out out of the write transaction and into the next `fillBatch` tick. The rationale (design §6.8) is that the fan-out step needs to consult per-destination subscription filters and batch rules, which each involve work the write transaction should not own. Deferring fan-out to `fillBatch` localizes the write path's failure modes to the materializer and storage, simplifies the `EntryService` surface, and preserves the observable property that a successful `record()` call has appended an event even if the destination write is still pending.

No-op detection is merge-aware: a call is a duplicate of the aggregate's most recent event when merging the candidate `answers` into the materialized `previous.current_answers` produces a `current_answers` equal to the prior, the event_type's implied `is_complete` matches the prior row's `is_complete` (for `finalized`/`checkpoint`) or the prior's `is_deleted` is already `true` (for `tombstone`), and the candidate `checkpoint_reason` and `change_reason` match the most recent event's values. A single-event aggregate never triggers a no-op (no prior row exists).

## Assertions

A. `EntryService.record({entryType, aggregateId, eventType, answers, checkpointReason?, changeReason?})` SHALL be the sole write API invoked by widgets producing new events.

B. `EntryService` SHALL assign `event_id`, `sequence_number`, `previous_event_hash`, `event_hash`, and the first `ProvenanceEntry` atomically before the write.

C. `eventType` SHALL be one of `finalized`, `checkpoint`, `tombstone`; any other value SHALL cause `EntryService.record` to throw `ArgumentError` before any I/O.

D. `EntryService.record` SHALL perform the local write path in one `StorageBackend.transaction()`: append event, run materializer, upsert the `diary_entries` row, and increment the sequence counter. Per-destination FIFO fan-out SHALL be deferred to `fillBatch`, invoked on the next `syncCycle` tick; the transaction SHALL NOT invoke any destination's `transform` or `send`.

E. A failure inside step D — raised by the materializer or the storage layer — SHALL abort the whole write: no event SHALL be appended and no materializer output SHALL be visible to subsequent reads.

F. `EntryService.record` SHALL detect no-ops against the merged result. For `finalized` and `checkpoint` events the call SHALL return without writing when ALL of the following hold: (i) the key-wise merge of `answers` over `previous.current_answers` (per REQ-d00121-B) equals `previous.current_answers` under deep equality; (ii) the event's implied `is_complete` (`finalized → true`, `checkpoint → false`) equals the prior row's `is_complete`; (iii) `checkpoint_reason` equals the prior event's `checkpoint_reason` (or both are null); (iv) `change_reason` equals the prior event's `change_reason`. For `tombstone` events the call SHALL return without writing when BOTH: (i) the prior row's `is_deleted` is already `true`; (ii) `change_reason` matches the prior event's `change_reason`. A first event on an aggregate (no prior row) SHALL NOT be treated as a no-op.

G. After a successful write, `EntryService.record` SHALL invoke `syncCycle()` fire-and-forget (`unawaited`); the caller SHALL NOT rely on sync completion before the call returns.

H. `EntryService.record` SHALL validate that `entryType` is registered in the `EntryTypeRegistry` before accepting the write; an unregistered `entryType` SHALL cause the call to throw `ArgumentError` before any I/O.

I. `EntryService.record` SHALL populate the event's migration-bridge top-level fields (`client_timestamp`, `device_id`, `software_version`) from `metadata.provenance[0]`.

*End* *EntryService.record Contract* | **Hash**: 6d804b0e

---

# REQ-d00134: bootstrapAppendOnlyDatastore Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

`bootstrapAppendOnlyDatastore` is the single entry point an app's `main()` calls to wire together the storage backend, the `EntryTypeRegistry`, and the initial set of `Destination`s. Centralizing initialization on one function avoids the failure mode where different apps discover their own subset of the required setup and omit steps (e.g., registering entry types after destinations, which would let a destination start enqueuing events whose types are not registered).

Types register before destinations. Destinations that require entry-type information during construction (for subscription filters, transform configuration) need the registry populated already; the reverse ordering would need forward references.

Id-collision on a destination registration is promoted from a warning to a hard throw during bootstrap so a misconfigured app crashes at startup rather than rendering UI on top of a half-initialized datastore.

## Assertions

A. `bootstrapAppendOnlyDatastore({backend, source, entryTypes, destinations, materializers?, syncCycleTrigger?})` SHALL be the single entry point for initializing the datastore from an app's `main()`, and SHALL return an `AppendOnlyDatastore` facade carrying `eventStore`, `entryTypes`, `destinations`, and `securityContexts`.

B. `bootstrapAppendOnlyDatastore` SHALL auto-register the three reserved system entry types (`security_context_redacted`, `security_context_compacted`, `security_context_purged`; all `materialize: false`) BEFORE iterating the caller-supplied list, and SHALL register every caller-supplied `EntryTypeDefinition` into the `EntryTypeRegistry` before any `Destination` is registered.

C. `bootstrapAppendOnlyDatastore` SHALL register every supplied `Destination` into the `DestinationRegistry` via `addDestination`. The registry SHALL remain open to subsequent runtime `addDestination` calls per REQ-d00129-A.

D. If any two destinations supplied to `bootstrapAppendOnlyDatastore` share an `id`, OR if any caller-supplied `EntryTypeDefinition` id collides with a reserved system entry-type id, the call SHALL throw `ArgumentError` (with an explicit "reserved" message in the id-collision case); the app SHALL NOT proceed to UI rendering.

*End* *bootstrapAppendOnlyDatastore Contract* | **Hash**: 1f9f50c9

## REQ-d00135: Initiator Polymorphic Actor Type

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004

## Assertions

A. `Initiator` SHALL be a Dart 3 sealed class with exactly three variants: `UserInitiator`, `AutomationInitiator`, `AnonymousInitiator`.

B. Each `Initiator` variant SHALL round-trip through a JSON map carrying a `type` discriminator (`"user"`, `"automation"`, `"anonymous"`) and the variant's fields; the encoding SHALL match the design-doc shape (e.g., `{"type": "user", "user_id": "..."}`).

C. Every mobile call site that previously supplied a `userId: String` SHALL be migrated to supply `initiator: UserInitiator(userId)`; no top-level `user_id` field SHALL remain on `StoredEvent`.

D. `AutomationInitiator.triggeringEventId` SHALL be nullable; when non-null it identifies an upstream event's `event_id` that caused the automation's action.

E. `AnonymousInitiator.ipAddress` SHALL be nullable; `null` SHALL be the pre-auth value used by the PIN-login screen and similar flows.

F. `Initiator.fromJson` SHALL throw `FormatException` on an unknown `type` discriminator and on a missing required field per variant.

*End* *Initiator Polymorphic Actor Type* | **Hash**: 0b5663cc
---

## REQ-d00136: flowToken Correlation Field

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00013

## Assertions

A. `StoredEvent.flowToken` SHALL be a nullable `String?` column carried on the event record.

B. The format convention `'<aggregate-or-flow-name>:<id>'` (e.g., `'invite:ABC123'`) SHALL be documented in the library and in this requirement; the library SHALL NOT enforce the format at runtime.

C. Callers that participate in a multi-event business flow SHALL stamp the same `flowToken` value on every event of the flow so that audit queries can select the flow as a unit.

D. `SembastBackend` SHALL expose an efficient lookup by `flow_token` in the events store (`WHERE flow_token = ?` queries SHALL NOT require a full scan).

E. `flow_token` SHALL be part of the `event_hash` inputs so tampering with the token breaks the hash chain.

*End* *flowToken Correlation Field* | **Hash**: 0bf4ed09
---

## REQ-d00137: EventSecurityContext Sidecar Store

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01018

## Assertions

A. `EventSecurityContext` rows SHALL live in a separate storage namespace (sembast store `security_context`), not as columns on the `event_log` store.

B. The foreign-key direction SHALL be `security_context.event_id -> event_log.event_id`; the event row SHALL hold no reference back to security.

C. `EventStore.append` SHALL write the event row AND (when `security != null`) the security row in one backend transaction; any throw SHALL roll back both rows.

D. `SecurityContextStore.read(eventId)` SHALL return the row or `null` when no row exists for that event; a missing row SHALL NOT be an error.

E. Security-context mutations (write, update, delete) SHALL be performed only by `EventStore` so that each mutation commits atomically with the event-log row that describes it; the public `SecurityContextStore` interface SHALL expose read-only methods.

F. `SecurityContextStore.queryAudit({initiator?, flowToken?, ipAddress?, from?, to?, limit, cursor?})` SHALL return a `PagedAudit` of `AuditRow(event, context)` pairs sorted by `recordedAt` descending; `limit` SHALL be constrained to `[1, 1000]`; `cursor` SHALL be opaque; a corrupt cursor SHALL throw `ArgumentError`.

*End* *EventSecurityContext Sidecar Store* | **Hash**: 387fcb92
---

## REQ-d00138: Security Retention Policy and Redaction Audit

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01018

## Assertions

A. `SecurityRetentionPolicy` SHALL be an immutable value type carrying `fullRetention` (default 90 days), `truncatedRetention` (default 365 days additional), `truncateIpv4LastOctet` (default true), `truncateIpv6Suffix` (default true, `/48` mask), `dropUserAgentAfterFull` (default true), `dropGeoAfterFull` (default false), and `dropAllAfterTruncated` (default true); a `SecurityRetentionPolicy.defaults` static constant SHALL expose the defaults as a single value.

B. `EventStore.applyRetentionPolicy` SHALL truncate `EventSecurityContext` rows whose age exceeds `fullRetention`, applying each policy flag (IP truncation, UA drop, geo drop) to the row in place.

C. `EventStore.applyRetentionPolicy` SHALL delete `EventSecurityContext` rows whose age exceeds `fullRetention + truncatedRetention`.

D. `EventStore.clearSecurityContext(eventId, reason, redactedBy)` SHALL delete the security row for `eventId` AND append exactly one `security_context_redacted` event (with `aggregateType='security_context'`, `aggregateId=eventId`, `eventType='finalized'`, `data={'reason': <reason>}`, `initiator=redactedBy`) inside the same transaction.

E. A non-empty compact sweep SHALL emit exactly one `security_context_compacted` event recording the count and cutoff; an empty compact sweep SHALL emit no event.

F. A non-empty purge sweep SHALL emit exactly one `security_context_purged` event recording the count and cutoff; an empty purge sweep SHALL emit no event.

G. Redaction, compact, and purge events SHALL themselves be immutable `event_log` rows (not `security_context` rows) so the action of redaction is permanently auditable even after the underlying security data is gone.

*End* *Security Retention Policy and Redaction Audit* | **Hash**: 3ca5bb98
---

## REQ-d00139: No-Secrets Invariant on Event Data and flowToken

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01018

## Assertions

A. Event `data` and `flowToken` SHALL NOT contain unhashed credentials, OTPs, recovery tokens, session tokens, or any other value whose mere knowledge confers authority.

B. The rationale: read-only access to the event log is broad (SIEM pipelines, audit backups, read replicas, compliance exports, human auditors with SELECT privileges); defense-in-depth requires keeping secrets out even when full-database compromise would dominate the immediate threat.

C. Hashes (SHA-256 or stronger, with sufficient input entropy to resist precomputation) MAY appear in event `data` when needed for later verification correlation; the library SHALL NOT enforce this invariant at runtime — callers (actions lib, direct-write automation handlers) own the contract.

*End* *No-Secrets Invariant on Event Data and flowToken* | **Hash**: 8c4df58e
---

## REQ-d00140: Pluggable Materializer Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01006

## Assertions

A. `Materializer` SHALL be an abstract base class with `String get viewName`, `bool appliesTo(StoredEvent event)`, and `Future<void> applyInTxn(Txn, StorageBackend, {event, def, aggregateHistory})`.

B. `EventStore` SHALL accept `List<Materializer> materializers` at construction and SHALL invoke each matching materializer's `applyInTxn` inside the append transaction.

C. When an event's `EntryTypeDefinition.materialize == false`, NO materializer SHALL be invoked for that event regardless of `appliesTo`.

D. `rebuildView(materializer, backend, lookup)` SHALL replay the event log into exactly one view; running the function twice on the same log SHALL produce the same view rows (idempotent).

E. A throw from any materializer's `applyInTxn` SHALL roll back the entire append transaction — no event row, no security row, no other view rows.

F. `StorageBackend` SHALL expose generic view methods `readViewRowInTxn(txn, viewName, key)`, `upsertViewRowInTxn(txn, viewName, key, row)`, `deleteViewRowInTxn(txn, viewName, key)`, `findViewRows(viewName, {limit, offset})`, and `clearViewInTxn(txn, viewName)` so materializers can read and write view rows without the backend knowing about specific views.

*End* *Pluggable Materializer Contract* | **Hash**: fccf62b4
---

## REQ-d00141: EventStore Append Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004

## Assertions

A. The class named `EntryService` SHALL be renamed to `EventStore` and SHALL live at `apps/common-dart/append_only_datastore/lib/src/event_store.dart`.

B. `EventStore.append({entryType, aggregateId, aggregateType, eventType, data, initiator, flowToken?, metadata?, security?, checkpointReason?, changeReason?, dedupeByContent=false})` SHALL be the single public write method serving both mobile widgets and portal callers; it SHALL return the persisted `StoredEvent` or `null` when a `dedupeByContent` no-op was detected.

C. Mobile widget call sites SHALL pass per-field arguments directly; there SHALL NOT be an intermediate `EventDraft` value type on the mobile write path.

D. Neither `EventStore` nor `SecurityContextStore` SHALL gate access by user role, scope, or tenancy; access control SHALL live in the widget / request-handler layer (permission-blind invariant).

*End* *EventStore Append Contract* | **Hash**: 6e0f8625
---

## REQ-d00142: Source Stamping Provenance Identity

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004

## Assertions

A. The class named `DeviceInfo` SHALL be renamed to `Source` and SHALL carry exactly three fields: `hopId: String`, `identifier: String`, `softwareVersion: String`; `Source` SHALL NOT carry a `userId` field.

B. `Source.hopId` SHALL enumerate at least `'mobile-device'` and `'portal-server'` as well-known values; other hop identifiers are permitted.

C. `Source.softwareVersion` SHALL conform to the REQ-d00115-E format (`"<package-name>@<semver>[+<build>]"`); `Source` SHALL NOT validate this at runtime — the shape is a permanent caller obligation enforced downstream.

*End* *Source Stamping Provenance Identity* | **Hash**: 65bc37d4
---

## REQ-d00143: Storage Failure Taxonomy

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00006

## Assertions

A. `StorageException` SHALL be a sealed class with exactly three subclasses: `StorageTransientException`, `StoragePermanentException`, `StorageCorruptException`; no other subclasses SHALL exist.

B. A public function `classifyStorageException(Object error, StackTrace stack)` SHALL return a `StorageException` instance for any input; the function SHALL NOT throw.

C. `dart:async` `TimeoutException` and backend-raised transient-failure signals (lock contention, concurrent modification, timeout) SHALL classify as `StorageTransientException`. Sembast's `DatabaseException` type does not currently surface such signals — they are handled internally — so the sembast-only classifier has no `DatabaseException` codes that map to this variant.

D. `FormatException` raised during event-data JSON decode, hash-chain-mismatch signals (e.g. `FormatException` whose message contains `"hash chain"`), and sembast `DatabaseException.errInvalidCodec` (codec-decode failure, caller-visible indistinguishable from on-disk corruption) SHALL classify as `StorageCorruptException`.

E. `dart:io` `FileSystemException` with permission or access errors; bare `StateError` / `ArgumentError` from the backend; and sembast `DatabaseException` lifecycle codes (`errBadParam`, `errDatabaseNotFound`, `errDatabaseClosed`) SHALL classify as `StoragePermanentException`.

F. An unrecognized input type SHALL classify conservatively as `StoragePermanentException`; the classifier SHALL NOT fall through to `StorageTransientException` for unknown inputs.

G. Every `StorageException` instance SHALL preserve the original `cause: Object` and `stackTrace: StackTrace` passed to its constructor; these fields SHALL be retrievable for diagnostic traceability.

*End* *Storage Failure Taxonomy* | **Hash**: 59ed82f7
---

## REQ-d00144: tombstoneAndRefill Operation

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

## Rationale

A destination whose head row is wedged cannot make drain progress (REQ-d00124-H). `tombstoneAndRefill` is the recovery primitive: the operator declares the bundle at the FIFO head permanently undeliverable as-built — its wire bytes were malformed because of a transform bug that has since been fixed, or its content was rejected by the destination until a server-side change landed, or (in the case of a `null` head) the operator knows the bundle will never succeed and wants to short-circuit retry-exhaustion. The library archives that row as a tombstone preserving its `attempts[]` as the audit record of the delivery attempt, clears the pending trail that had been building up behind it, and rewinds `fill_cursor` so the next `fillBatch` rebuilds the events covered by the tombstoned target AND by the deleted trail into fresh bundles against the current transform and destination state.

The events in the tombstoned row are not abandoned — they remain on the event log and are re-queued by the next `fillBatch` into a new FIFO row whose bytes reflect the current code. The tombstoned row is strictly a bundle-level audit artifact: "this specific payload was attempted N times and failed; the same events have been re-shipped via a different payload." Requiring the target to be the FIFO's current head keeps the cascade coherent: earlier rows are all terminal-passable (`sent` or `tombstoned`), so rewinding `fill_cursor` past the target is guaranteed to reinstate only events whose latest FIFO row is either the tombstoned target or one of the deleted trail rows.

When the operator's fix is valid, the fresh rows drain through successfully. When the fix is invalid, the fresh rows reproduce the original failure and the operator runs another `tombstoneAndRefill` — honest signaling, not silent data loss. Trail rows behind the head always have empty `attempts[]` under strict-order drain (drain processes rows sequentially and only ever holds one in flight at a time, so any delivery attempts are recorded on the head itself); deleting them preserves the full audit history that ever existed for them. REQ-d00127's missing-row tolerance handles the narrow race where drain is mid-`send` on the head at the moment this operation runs.

`tombstoneAndRefill` is the sole recovery primitive for the drain loop and the sole code path by which a FIFO row reaches `final_status == tombstoned`.

## Assertions

A. `tombstoneAndRefill(String destId, String fifoRowId)` SHALL throw `ArgumentError` unless `fifoRowId` identifies the current head of the destination's FIFO — equivalently, the row that `readFifoHead(destId)` (REQ-d00124-A) would return. The head's `final_status` is therefore `null` or `wedged`.

B. Inside one storage transaction, the target row's `final_status` SHALL transition to `tombstoned`; its `attempts[]` and all other fields SHALL be preserved unchanged.

C. Inside the same transaction, every FIFO row whose `sequence_in_queue > target.sequence_in_queue` AND whose `final_status IS null` SHALL be deleted from the destination's FIFO store.

D. Inside the same transaction, `fill_cursor` SHALL be rewound to `target.event_id_range.first_seq - 1`, so the next `fillBatch` resumes promotion at the first event the target had covered.

E. The call SHALL return a `TombstoneAndRefillResult { String targetRowId, int deletedTrailCount, int rewoundTo }`.

F. A subsequent `fillBatch(destination)` invocation SHALL re-promote the events covered by the tombstoned target AND by the deleted trail into fresh FIFO rows built against the current transform and destination state.

*End* *tombstoneAndRefill Operation* | **Hash**: f812b27d
---

# REQ-d00145: EventStore Ingest Contract

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00013

## Rationale

Events that flow across systems require a receiver-side write path distinct from local origination. Naively re-appending a received event via `EventStore.append` (REQ-d00141) would mint fresh `event_id`, advance a local `sequence_number`, stamp a fresh `provenance[0]`, and recompute the hash chain from scratch — destroying the event's original identity and breaking cross-system verification.

`EventStore.ingestBatch` / `ingestEvent` / `logRejectedBatch` are the ingest surface. `ingestBatch` is the wire-boundary entry point: it accepts canonical-format bytes (`esd/batch@1` — the library's single canonical batch envelope), decomposes into constituent `StoredEvent` records, verifies each one's Chain 1 on the way in, stamps a receiver `ProvenanceEntry` with all four REQ-d00115 ingest fields populated (including `batch_context`), recomputes `event_hash` to cover the appended hop, and persists. `ingestEvent` is the process-local variant — no batch, so no `batch_context`. `logRejectedBatch` is a caller-composed companion: after `ingestBatch` throws, callers that want a forensic record of the rejected bytes invoke `logRejectedBatch`, which emits a single receiver-originated `ingest.batch_rejected` event carrying the bytes verbatim.

The idempotency contract is identity-preserving. A known `event_id` whose wire `event_hash` matches the stored copy's `provenance[thisHop].arrival_hash` produces an `ingest.duplicate_received` audit event under a receiver-scoped ingest-audit aggregate — the stored subject is never re-stamped. A known `event_id` whose wire hash differs is a hard error (`IngestIdentityMismatch`). A new `event_id` proceeds normally.

On success, an N-event batch produces N stored subject events (plus M dup-received audit events for any in-batch duplicates). No per-batch "received" audit event is emitted on the happy path — per-event `batch_context` is the happy-path audit. On failure, `ingestBatch` rolls back the entire batch (all-or-nothing) and throws a typed exception; the library does NOT implicitly emit an `ingest.batch_rejected` event. Audit retention on failure is the caller's to compose via `logRejectedBatch`.

## Assertions

A. `EventStore.ingestBatch(bytes, {required wireFormat})` SHALL decompose the bytes per the canonical batch format identified by `wireFormat` and, within a single `StorageBackend.transaction`, verify and ingest each decoded subject event. On any failure (decode, Chain 1 mismatch, identity mismatch, backend error), the method SHALL roll back and throw a typed exception; no events from the batch SHALL be persisted.

B. Phase 4.9 SHALL support exactly one `wireFormat` value: `"esd/batch@1"`. The canonical batch envelope is a JCS-canonicalized UTF-8 JSON object with fields `batch_format_version` (string, value `"1"`), `batch_id` (UUID string), `sender_hop` (string), `sender_identifier` (string), `sender_software_version` (`"<package-name>@<semver>[+<build>]"` per REQ-d00115-E), `sent_at` (ISO 8601 with timezone offset), and `events` (ordered list of `StoredEvent` JSON per REQ-d00118). Decode failures SHALL raise `IngestDecodeFailure`.

C. On Chain 1 verification failure for any subject event in a batch, `ingestBatch` SHALL raise `IngestChainBroken` with the `event_id` of the failing event.

D. On encountering a subject event whose `event_id` is already present in the destination's event log, `ingestBatch` SHALL perform an identity-match check: incoming wire `event_hash` SHALL equal stored `metadata.provenance[thisHop].arrival_hash`. On match, a receiver-originated `ingest.duplicate_received` event SHALL be emitted under the receiver-scoped ingest-audit aggregate with `data` containing `subject_event_id` and `subject_event_hash_on_record`, and ingest SHALL continue with the next subject event. On mismatch, `ingestBatch` SHALL raise `IngestIdentityMismatch`.

E. For each subject event ingested in a batch, `ingestBatch` SHALL append a receiver `ProvenanceEntry` carrying `arrival_hash`, `previous_ingest_hash`, `ingest_sequence_number`, and `batch_context` (all four populated per REQ-d00115-G+H+I+J) to `event.metadata.provenance`, recompute `event_hash` per REQ-d00120-E, and persist the event via the destination-role storage path (keyed by `ingest_sequence_number`, per REQ-d00117 transactional semantics).

F. `EventStore.verifyEventChain(StoredEvent)` (see REQ-d00146) SHALL, after a successful `ingestBatch`, return a `ChainVerdict` with `ok: true` and `failures: []` for every subject event and every duplicate-received event produced by that batch.

G. `EventStore.ingestEvent(StoredEvent incoming)` SHALL perform the same per-event semantics as a single subject event inside `ingestBatch`, with `batch_context` stamped as `null`. `ingestEvent` SHALL NOT emit any receiver-originated audit event except an `ingest.duplicate_received` event on the duplicate path.

H. `EventStore.logRejectedBatch(bytes, {wireFormat, reason, failedEventId?, errorDetail?})` SHALL emit exactly one `ingest.batch_rejected` event under the receiver-scoped ingest-audit aggregate, inside its own transaction. The event's `data` SHALL carry the supplied `bytes` verbatim (base64-encoded), plus `wire_format`, `byte_length`, `wire_bytes_hash` (SHA-256 hex of the bytes), `reason`, `failed_event_id`, and `error_detail`. The method SHALL NOT attempt to decode or ingest the bytes; `logRejectedBatch` is purely a logging verb.

I. The receiver-scoped ingest-audit aggregate SHALL have `aggregate_id` of the form `"ingest-audit:<source.hop>"` (the receiver's own hop identifier). `ingest.duplicate_received` and `ingest.batch_rejected` events SHALL share this aggregate identity. Patient-facing materializers for other aggregates SHALL NOT observe these events.

J. Every receiver-originated audit event (`ingest.duplicate_received` and `ingest.batch_rejected`) SHALL have `provenance[0]` stamped with the receiver's own `source` (per REQ-d00115-A), `arrival_hash: null`, `previous_ingest_hash` equal to the destination-local `event_hash` of the preceding event in Chain 2, `ingest_sequence_number` equal to the next value of the destination's ingest counter, and `batch_context` non-null when emitted in response to a batch (i.e., for `duplicate_received` events emitted from `ingestBatch`).

K. `ingestBatch` and `ingestEvent` SHALL NOT mutate any originator identity field (`event_id`, `aggregate_id`, `aggregate_type`, `entry_type`, `event_type`, `sequence_number`, `data`, `initiator`, `flow_token`, `client_timestamp`, `previous_event_hash`) on the incoming event. Only `metadata.provenance` is extended (one receiver entry appended), and `event_hash` is recomputed per REQ-d00120-E.

*End* *EventStore Ingest Contract* | **Hash**: 2213e000

---

# REQ-d00146: Chain-of-Custody Verification APIs

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004

## Rationale

Chain 1 (per-event, cross-hop) and Chain 2 (per-destination, cross-events) are both tamper-evident but the tamper detection is not self-activating — a library consumer must walk one or both chains to confirm nothing has been altered. The library provides two verification methods, one per chain, returning a non-throwing `ChainVerdict` so auditors can enumerate all mismatches in a single walk rather than catching exception-per-failure.

## Assertions

A. `EventStore.verifyEventChain(StoredEvent event)` SHALL walk `event.metadata.provenance` from index `length - 1` down to index `0`. At each index `k`, the method SHALL recompute the event_hash value that would exist at that hop by replacing `metadata.provenance` with a slice `[0..k]` (inclusive through index `k-1` only, for k > 0; the full slice at k=0), keeping all other identity fields, and canonicalizing per REQ-d00120. For `k > 0`, the recomputed hash SHALL equal `provenance[k].arrival_hash`; for `k == 0`, the recomputed hash SHALL equal the stored `event_hash` of the originator's record (not directly verifiable without access to the originator's store — the terminal case reports `ok: true` when the walk reaches `provenance[0]` without mismatch, acknowledging the trust-anchor is the originator).

B. `EventStore.verifyEventChain` SHALL return a `ChainVerdict(ok: bool, failures: List<ChainFailure>)`. `ok` SHALL be `true` if and only if no mismatch occurred during the walk. `failures` SHALL enumerate every mismatch in walk order; a single corrupted hop produces exactly one `ChainFailure` entry with `position` equal to the hop index, `kind` equal to `ChainFailureKind.arrivalHashMismatch`, `expectedHash` equal to the stored `arrival_hash`, and `actualHash` equal to the recomputed hash.

C. `EventStore.verifyIngestChain({int fromIngestSeq = 0, int? toIngestSeq})` SHALL walk this destination's Chain 2 from the event at `ingest_sequence_number >= fromIngestSeq` through the event at `ingest_sequence_number <= toIngestSeq` (or through tail if `toIngestSeq` is null). For each event at sequence `s` (s > fromIngestSeq), the method SHALL verify that `event.metadata.provenance[thisHop].previous_ingest_hash` equals the stored `event_hash` of the event at sequence `s - 1` on this destination. On mismatch, a `ChainFailure` SHALL be appended to the verdict's `failures` with `position` equal to `s`, `kind` equal to `ChainFailureKind.previousIngestHashMismatch`, `expectedHash` equal to the stored prior event's `event_hash`, and `actualHash` equal to the current event's `previous_ingest_hash`.

D. Neither verification method SHALL throw on chain corruption. Exceptions MAY be thrown for programming errors (malformed `StoredEvent` argument to `verifyEventChain`), storage-backend errors, or invalid argument ranges (e.g., `fromIngestSeq > toIngestSeq`).

E. Both verification methods SHALL be pure reads: they SHALL NOT write to any store, SHALL NOT advance any counter, and SHALL NOT emit audit events.

*End* *Chain-of-Custody Verification APIs* | **Hash**: ba47e4ed

---
