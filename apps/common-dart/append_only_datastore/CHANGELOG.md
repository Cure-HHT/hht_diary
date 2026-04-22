# Changelog

## 0.2.0 (2026-04-22) - CUR-1154 Phase 3: materialization

Introduces the `diary_entries` materializer and the disaster-recovery
rebuild helper. The materializer is shipped but **unwired** — no
production call site invokes it in this phase. Phase 5 wires it into
`EntryService.record()`'s transaction path.

New public surface (exported from `append_only_datastore.dart`):

- `Materializer` — pure static `apply({previous, event, def, firstEventTimestamp})`
  folding a `StoredEvent` into the next `DiaryEntry` row. Whole-replacement
  answer semantics; `tombstone` preserves prior fields and flips
  `is_deleted = true`; `effective_date` resolves via dotted JSON path with
  fallback to `firstEventTimestamp`.
- `EntryTypeDefinitionLookup` — abstract single-method registry keyed by
  `entry_type` id. Returns `null` when unknown; callers decide whether
  null is an error at the use site.
- `rebuildMaterializedView(backend, lookup)` — top-level helper that
  replays every event through the materializer and atomically replaces
  the `diary_entries` store. Returns the count of aggregates materialized.
  Unknown `entry_type` in the event log raises `StateError`.

StorageBackend surface change:

- Added `clearEntries(Txn)` — delete all rows from `diary_entries`. Used
  by `rebuildMaterializedView` for atomic view replacement; not intended
  for runtime use.

Dependency addition:

- `trial_data_types` is now a regular dependency (was only implied).
  The materializer references `EntryTypeDefinition` from that package.

Spec:

- `spec/dev-event-sourcing-mobile.md` REQ-d00121 (9 assertions) —
  contract for the materializer and rebuild helper.

## 0.1.0 (2026-04-22) - CUR-1154 Phase 2: storage abstraction

Introduces the `StorageBackend` abstraction and a concrete `SembastBackend`
implementation for the mobile event-sourcing refactor. The repository's
public API is byte-exact vs. 0.0.3; existing callers continue to work
unchanged.

New public surface (exported from `append_only_datastore.dart`):

- `StorageBackend` — abstract contract (events, diary_entries view,
  per-destination FIFO, backend_state KV bookkeeping).
- `Txn` — opaque lexical-scope handle passed to `transaction(body)`.
- `SembastBackend` — concrete implementation over a pre-opened Sembast
  `Database`.
- `StoredEvent` — the stored event value type (moved here from
  `event_repository.dart`; the old import path still works via re-export).
- `AppendResult`, `DiaryEntry`, `FifoEntry`, `AttemptResult`,
  `FinalStatus`, `ExhaustedFifoSummary` — storage-layer value types.
- `SendResult` sealed hierarchy: `SendOk`, `SendTransient`, `SendPermanent`.

Event record changes (REQ-d00118):

- Added a first-class `entry_type` field on every event (required).
- Removed the device-side `server_timestamp` field — the ingesting
  server is the sole authority on its own timestamp.

Hash chain (REQ-d00120):

- `event_hash` is now computed as SHA-256 over RFC 8785 (JCS) canonical
  JSON bytes of the identity-field subset. Cross-platform receivers can
  independently verify by re-canonicalizing the received fields and
  recomputing the digest. Implementation uses the new in-monorepo
  `canonical_json_jcs` package (Apache-2.0, adapted from
  affinidi-ssi-dart).

Storage layer:

- Sembast `metadata` store renamed to `backend_state` to eliminate the
  name collision with the event-level `metadata` field. All KV
  bookkeeping (sequence counter, schema version, known-FIFO set) lives
  in `backend_state` (REQ-d00117-F).
- `EventRepository` now delegates event-log writes and queries through
  the injected `StorageBackend`. Callers unchanged.
- New `diary_entries` materialized view store (wired to `upsertEntry` +
  `findEntries`; no production writer until Phase 3).
- New per-destination FIFO store pattern `fifo_{destinationId}` with
  strict ordering, one-way `final_status` transitions, and retention of
  terminal entries (REQ-d00119). No production writer until Phase 4.

Legacy (deferred to Phase 5):

- `getUnsyncedEvents`, `markEventsSynced`, `getUnsyncedCount` and the
  `synced_at` column on events are retained with TODO(CUR-1154, Phase 5)
  markers. FIFO-based per-destination sync will replace them.

Dependencies added:

- `canonical_json_jcs` (path, new in-monorepo package).
- `collection: ^1.19.0` (direct, was transitive via flutter_test). Used
  for `DeepCollectionEquality` on nested-map value types.

## 0.0.1

- TODO: Describe initial release.
