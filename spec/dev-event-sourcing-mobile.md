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

## Assertions

A. The system SHALL append exactly one `ProvenanceEntry` to `event.metadata.provenance` on each hop that receives the event, such that the length of the chain equals the number of systems the event has traversed.

B. The system SHALL NOT mutate any `ProvenanceEntry` already present in the chain; subsequent hops SHALL only append.

C. Each `ProvenanceEntry` SHALL carry the fields `hop` (string), `received_at` (ISO 8601 with timezone offset), `identifier` (string), `software_version` (string), and an optional `transform_version` (string).

D. The `identifier` SHALL be a device UUID when the hop represents a patient-facing mobile device; for server hops the `identifier` SHALL be a server instance identifier.

E. The `software_version` SHALL follow the format `"<package-name>@<semver>[+<build>]"`, enabling each hop's software version to be precisely identified from the provenance entry alone.

F. The `transform_version` field SHALL be non-null when and only when this hop's incoming wire payload was produced by a transform at the previous hop; absence SHALL indicate the payload was passed through without transformation.

*End* *ProvenanceEntry Schema and Append Rules* | **Hash**: e129e6a9

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

E. `StorageBackend.enqueueFifo(txn, destination_id, fifo_entry)` SHALL append `fifo_entry` to destination `destination_id`'s FIFO with `final_status` equal to `"pending"` and with an empty `attempts[]` list.

F. Key-value bookkeeping for the backend, including the sequence counter and schema version, SHALL be stored in a Sembast store named `backend_state`; the store name `metadata` SHALL NOT be used for this purpose.

*End* *StorageBackend Transaction Contract* | **Hash**: edab4770

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

A dedicated Sembast store per destination, keyed by integer insertion order, provides FIFO semantics cheaply. Entries never leave the store: once sent they are marked `"sent"` but retained as send-log records for FDA/ALCOA compliance, and once repeatedly failed they are marked `"exhausted"` and the head of the FIFO is permanently wedged. No bypass is allowed on an exhausted head because allowing it would silently violate ordering. This requirement fixes the FIFO entry shape and the three legal `final_status` values; the fuller operational semantics (attempt accumulation, backoff curve, `SyncPolicy` constants, drain loop behavior) are refined in a later phase.

## Assertions

A. Each registered synchronization destination SHALL have exactly one associated FIFO store identified by its `destination_id`.

B. A FIFO entry SHALL carry the fields `entry_id`, `event_id`, `sequence_in_queue`, `wire_payload`, `wire_format`, `transform_version`, `enqueued_at`, `attempts[]`, `final_status`, and `sent_at`.

C. The `final_status` field SHALL take exactly one of the values `"pending"`, `"sent"`, or `"exhausted"`; no other values SHALL be legal.

D. Once a FIFO entry's `final_status` has transitioned out of `"pending"`, the entry SHALL NOT be deleted from its FIFO store; the entry SHALL be retained as a permanent send-log record.

*End* *Per-Destination FIFO Queue Semantics* | **Hash**: 27595d15

---

# REQ-d00120: Canonical Hashing for Cross-Platform Event Verification

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004

## Rationale

The `event_hash` field on every event carries a SHA-256 digest that downstream systems — diary server, sponsor portal, EDC, any future verifier — use to confirm the event they received is byte-identical to the event the originating mobile device recorded. For that verification to work, every implementation that computes the hash must feed the hash function identical bytes.

Dart's native `jsonEncode` preserves Map insertion order and has number-formatting quirks that do not reproduce on other platforms: a Python receiver that round-trips the event through `json.loads` loses the insertion order; a Postgres `numeric` column may return `1` where Dart wrote `1.0`; JavaScript's JSON module escapes Unicode differently than Dart's. Each of these platform differences silently changes the hashed byte sequence and produces a different digest even when the event's semantic content is unchanged.

Adopting [RFC 8785 (JSON Canonicalization Scheme, JCS)](https://www.rfc-editor.org/rfc/rfc8785) as the canonical serialization used at hash-input time closes the gap. JCS pins down key ordering (sorted lexicographically at every depth), number formatting (ECMA-262 `Number.prototype.toString`, including negative-zero and trailing-zero normalization), string escaping (minimal, consistent), and whitespace (none). Libraries implementing JCS exist in every language the system needs: `rfc8785` on PyPI, `json-canonicalize` on npm, `serde_json_canonicalizer` on crates.io, and the in-repo `canonical_json_jcs` package on the mobile side.

## Assertions

A. The `event_hash` field on every persisted event SHALL be computed as SHA-256 over the UTF-8 bytes of the RFC 8785 (JCS) canonical JSON serialization of the event's identity fields.

B. The identity fields hashed SHALL be exactly `event_id`, `aggregate_id`, `entry_type`, `event_type`, `sequence_number`, `data`, `user_id`, `device_id`, `client_timestamp`, and `previous_event_hash`; no other fields SHALL be included in the hash input.

C. A receiver implementing RFC 8785 in any language SHALL be able to reconstruct the canonical byte sequence from the received identity fields and independently verify the `event_hash` value.

D. The canonicalization scheme used SHALL NOT be changed without a spec amendment and coordinated update across all implementations; changing the algorithm silently would break tamper-detection on all pre-existing events.

*End* *Canonical Hashing for Cross-Platform Event Verification* | **Hash**: e09d751a
