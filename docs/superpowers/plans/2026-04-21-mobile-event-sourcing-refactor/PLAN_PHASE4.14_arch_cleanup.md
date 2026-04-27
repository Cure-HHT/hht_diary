# Master Plan Phase 4.14: Architectural Cleanup + Unified Event Store + Audit-Query API + Greenfield Destination API

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle four logically-distinct cleanups identified by user review of the 4.10–4.13 run: (A) remove rehabilitate code + REQ-d00132 markers; (B) unify the origin and ingested event stores into one table; (C) reshape the Destination API so native destinations declare nativeness directly (eliminate the parse-and-strip dance); (D) add a typed `StorageBackend.queryAudit` and remove `debugDatabase()` entirely.

**Architecture:** Each group is independent of the others code-wise but they share the principle "fix the design now while greenfield." Group A is pure removal. Group B touches Phase 4.9's ingest path most heavily; chain reconstruction relies on a new `ProvenanceEntry.origin_sequence_number` field that preserves the originator's sequence_number when a receiver reassigns a local one. Group C reshapes how native destinations interact with `fillBatch`. Group D adds one new abstract method on `StorageBackend` and finishes closing the abstraction leak that §4.11.3 surfaced.

**Tech Stack:** Dart, sembast, `package:flutter_test`, `BatchEnvelope` (Phase 4.9), existing primitives.

**Decisions log:** `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (Phase 4.14 section §4.14.A–G pinned).

**Branch:** `mobile-event-sourcing-refactor`. **Ticket:** CUR-1154 (continuation). **Phase:** 4.14 (final library phase before mobile cutover CUR-1169). **Depends on:** Phase 4.13 complete on HEAD (`ea070883`).

---

## Applicable REQ assertions

| REQ | Topic | Validated via | Group |
| --- | --- | --- | --- |
| REQ-d00132 | Rehabilitate (REMOVED — lib markers + code paths deleted; spec section was already absent) | Group A | A |
| REQ-d00115 (extension) | `ProvenanceEntry.origin_sequence_number` field — receiver hop preserves originator's sequence_number for chain reconstruction | Group B | B |
| REQ-d00145 (amendment) | `ingestBatch` / `ingestEvent` reassign sequence_number from local counter; populate `origin_sequence_number` in the receiver's hop | Group B | B |
| REQ-d00146 (amendment) | `verifyIngestChain` walks the unified event store by local `sequence_number` | Group B | B |
| REQ-d00119-K (rewrite) | Phase 4.13's K assertion is reframed: native destinations declare native; library produces envelope metadata in fillBatch; storage just persists | Group C | C |
| REQ-d00149-E, REQ-d00150-E (amendment) | Backend-agnostic wording — "single backend instance per database", not "single SembastBackend" | Group A (doc fix) | A |
| REQ-d00151 (NEW) | `StorageBackend.queryAudit({...filters, cursor, limit}) → Future<PagedAudit>` typed audit-query | Group D | D |
| REQ-d00152 (NEW) | `Destination.serializesNatively: bool` declaration; library-managed native serialization contract | Group C | C |

---

## Execution rules

Each task = one commit. No `--no-verify`. Explicit `git add <files>`. Greenfield voice; no transition language. Per-function `// Implements: REQ-xxx-Y — ...` markers; per-test `// Verifies: REQ-xxx-Y` + assertion ID at start of `test(...)` description string.

User has parallel WIP under `apps/common-dart/event_sourcing_datastore/example/` — do not stage anything from that directory unless explicitly required by a task.

**Group ordering**: A → B → C → D. Group A is pure removal (cleanest baseline). Group B is the biggest architectural change (touches Phase 4.9's contract). Group C depends on B's unified store NOT being the case (C operates on FIFO storage, independent), but ordering after B keeps the test pass count predictable. Group D is independent but smallest — last.

**Checkpoint between groups**: full test + analyze must pass on each `Group X close` commit before starting Group `X+1`. If the orchestrator wants to ship Phase 4.14 in pieces, the natural cut points are after each group close.

**Phase invariants** (must be true at end of phase):

1. `flutter test` clean in `apps/common-dart/event_sourcing_datastore`.
2. `flutter analyze` clean in `event_sourcing_datastore` AND `event_sourcing_datastore/example`.
3. `flutter test` clean in `apps/common-dart/provenance` (38 unchanged unless Group B's ProvenanceEntry change adds tests).
4. `grep -rn "REQ-d00132\|rehabilitate\|rehabilitateExhaustedRow" apps/common-dart/event_sourcing_datastore/` — ZERO hits (Group A).
5. `grep -rn "_ingestedEventsStore\|nextIngestSequenceNumber\|appendIngestedEvent" apps/common-dart/event_sourcing_datastore/lib/` — ZERO hits (Group B). `appendEvent` handles both origin and ingest.
6. `grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/` — ZERO hits anywhere (Group D).
7. `grep -rn "Destination.transform\|destination.transform" apps/common-dart/event_sourcing_datastore/lib/` for native-flagged destinations — none called by lib (Group C).

---

## Plan

### Task 0: Baseline + worklog

**Files:** Create `PHASE_4.14_WORKLOG.md`.

- [ ] **Step 1: Confirm Phase 4.13 is committed on HEAD**

```bash
git log --oneline -3
```

- [ ] **Step 2: Run baseline checks**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: event_sourcing_datastore +594, provenance +38, all analyze clean.

- [ ] **Step 3: Snapshot the BEFORE state of the cleanup targets**

```bash
echo "=== rehabilitate / REQ-d00132 ==="
grep -rn "rehabilitate\|REQ-d00132" apps/common-dart/event_sourcing_datastore/ | wc -l
echo "=== _ingestedEventsStore + ingest counters ==="
grep -rn "_ingestedEventsStore\|nextIngestSequenceNumber\|readIngestTail\|appendIngestedEvent" apps/common-dart/event_sourcing_datastore/lib/ | wc -l
echo "=== debugDatabase ==="
grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/ | wc -l
```

Capture into the worklog as the BEFORE counts.

- [ ] **Step 4: Write `PHASE_4.14_WORKLOG.md`** (mirror Phase 4.13 worklog structure; track all task groups).

- [ ] **Step 5: Commit**

```bash
git add PHASE_4.14_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.14 Task 0: baseline + worklog"
```

---

## Group A: cleanup (rehabilitate removal + doc fixes)

### Task A1: Remove rehabilitate from `setFinalStatusTxn` legal transitions; remove `readFifoRow` if unused; delete `// Implements: REQ-d00132-*` markers

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`
- Modify: any test files referencing `rehabilitate` / `REQ-d00132`.

- [ ] **Step 1: Find every reference**

```bash
grep -rn "rehabilitate\|REQ-d00132\|readFifoRow" apps/common-dart/event_sourcing_datastore/
```

Triage:
- `readFifoRow` — was added to support rehabilitate's "validate target row exists" check. Verify it has NO other callers (use grep). If sole caller is rehab-related, remove from abstract `StorageBackend` AND from `SembastBackend` AND from test-helper subclasses.
- `setFinalStatusTxn`'s `wedged → null` transition — remove from the legal transitions list in the dartdoc and from the implementation. The remaining legal transitions are: `null → sent`, `null → wedged`, `null → tombstoned`, `wedged → tombstoned`. Anything else throws `StateError`.
- `// -------- Rehabilitate helpers (REQ-d00132) --------` section header in storage_backend.dart and sembast_backend.dart — delete.
- All `// Implements: REQ-d00132-*` markers — delete (and the surrounding rationale comments that reference rehab).
- Test files exercising `wedged → null` transitions or `readFifoRow` — delete those tests.

- [ ] **Step 2: Apply the deletions**

Greenfield voice — do not leave `// formerly rehabilitate-related` breadcrumbs. Just remove.

- [ ] **Step 3: Run the test suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: count drops by however many rehabilitate-specific tests existed (plan template assumes 2-4 tests). Surface the new count to orchestrator.

- [ ] **Step 4: Verify the cleanup is complete**

```bash
grep -rn "REQ-d00132\|rehabilitate\|readFifoRow" apps/common-dart/event_sourcing_datastore/
```

Expected: ZERO hits.

- [ ] **Step 5: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

- [ ] **Step 6: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart \
        <test files touched>
git commit -m "[CUR-1154] Phase 4.14 A1: remove rehabilitate code + REQ-d00132 markers"
```

---

### Task A2: Doc fix on REQ-d00149-E and REQ-d00150-E (backend-agnostic wording)

**Files:** Modify `spec/dev-event-sourcing-mobile.md`.

- [ ] **Step 1: Find both assertions**

```bash
grep -n "single SembastBackend\|single backend" spec/dev-event-sourcing-mobile.md
```

- [ ] **Step 2: Rewrite each E in place**

REQ-d00149-E currently reads (substantially):

> Consumers SHALL share a single `SembastBackend` instance per database; constructing multiple backends over the same database file is undefined behavior.

Rewrite to:

> Consumers SHALL share a single `StorageBackend` instance per backing storage; constructing multiple backends over the same backing storage is undefined behavior. Broadcast deduplication is the coordination mechanism, applicable to any `StorageBackend` implementation.

REQ-d00150-E currently references REQ-d00149-E — leave the cross-reference as-is, since the rewritten -E now applies generically.

- [ ] **Step 3: Update the dartdoc** on `StorageBackend.watchEvents` and `StorageBackend.watchFifo` (in `lib/src/storage/storage_backend.dart`) to match — replace any "SembastBackend" mention with "StorageBackend" in the consumer-sharing paragraph.

- [ ] **Step 4: Run analyze + tests** (sanity).

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
```

- [ ] **Step 5: Commit**

```bash
git add spec/dev-event-sourcing-mobile.md \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart
git commit -m "[CUR-1154] Phase 4.14 A2: REQ-d00149/150-E backend-agnostic wording"
```

(Pre-commit hook updates REQ-d00149 and REQ-d00150 hashes.)

---

### Task A3: Group A close — verify state, log

- [ ] **Step 1: Run full suite + analyze.**
- [ ] **Step 2: Update PHASE_4.14_WORKLOG.md — Group A complete.**
- [ ] **Step 3: Commit.**

---

## Group B: unify origin + ingested event stores

### Task B1: Spec — REQ-d00115 extension (`origin_sequence_number`); amend REQ-d00145; amend REQ-d00146

**Files:** `spec/dev-event-sourcing-mobile.md`.

- [ ] **Step 1: Find REQ-d00115 (ProvenanceEntry)**

Currently has 4 fields added by Phase 4.9 (arrival_hash, previous_ingest_hash, ingest_sequence_number, batch_context). Add a 5th:

```markdown
- **`origin_sequence_number: int?`** — populated on a receiver-hop ProvenanceEntry. Holds the originator's `sequence_number` value verbatim from the wire — preserved separately because the receiver assigns a NEW local `sequence_number` to the stored event so that origin and ingested events occupy a single event log keyed by one monotone counter. Null on origin entries (the originator's `sequence_number` lives on the StoredEvent itself).
```

Add corresponding assertion (next available letter; check current high letter on REQ-d00115). The new assertion documents the field's purpose, null semantics, and chain-reconstruction role.

- [ ] **Step 2: Find REQ-d00145 (ingestBatch / ingestEvent)**

Amend assertion E (or wherever the storage-keying rule lives) to read:

> The receiver SHALL reserve a fresh local `sequence_number` for every ingested event via `nextSequenceNumber` and overwrite the wire-supplied `sequence_number` on the stored event. The originator's wire-supplied `sequence_number` SHALL be preserved on the receiver-hop `ProvenanceEntry` as `origin_sequence_number` (REQ-d00115). Ingested events land in the same event store as origin events; there is no separate "ingest store."

Replace any reference to `ingest_sequence_number` as the storage key with `sequence_number` (the local counter). The Phase 4.9 `ingest_sequence_number` field on `ProvenanceEntry` becomes equal to the local `sequence_number`; consider whether to retire that field entirely or leave it as a synonym (`ingest_sequence_number` was always destination-local; with unification it equals the local seq_number for ingested events). **Decision deferred to B2's implementation step — read the existing code before deciding.**

- [ ] **Step 3: Find REQ-d00146 (verifyIngestChain)**

Amend assertion C (the storage-read for Chain 2 walk) to read against the unified event store keyed by local `sequence_number`. The signature `findEventsByIngestSeqRange({from, to})` becomes `findEventsByLocalSeqRange({from, to})` (or just reuse the existing `findAllEvents(afterSequence:, limit:)`).

- [ ] **Step 4: Commit**

```bash
git add spec/dev-event-sourcing-mobile.md
git commit -m "[CUR-1154] Phase 4.14 B1: spec — REQ-d00115 origin_sequence_number; amend REQ-d00145/146"
```

---

### Task B2: ProvenanceEntry adds `originSequenceNumber` field

**Files:** `apps/common-dart/provenance/lib/src/provenance_entry.dart` (or wherever ProvenanceEntry lives).

- [ ] **Step 1: Add the field** (`final int? originSequenceNumber;`), update constructor, fromJson/toJson, equality/hashCode/toString.
- [ ] **Step 2: Update provenance package tests** — add round-trip cases.
- [ ] **Step 3: Run provenance tests** — confirm pass count grows.
- [ ] **Step 4: Commit.**

---

### Task B3: Refactor `appendIngestedEvent` to use `_eventStore` + reassign `sequence_number`; populate `originSequenceNumber`

**Files:** `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` (and abstract on `storage_backend.dart`); `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (the ingest flow).

- [ ] **Step 1: Read the existing `appendIngestedEvent` + ingest flow** to understand the call sites in `EventStore.ingestBatch` / `ingestEvent`.

- [ ] **Step 2: Refactor**

The new shape:

```dart
// Inside EventStore.ingestBatch's per-event loop, after Chain 1 verify
// and before persistence:

final localSeq = await backend.nextSequenceNumber(txn);
final originSeq = incoming.sequenceNumber;
final receiverEntry = ProvenanceEntry(
  ...,
  arrivalHash: incoming.eventHash,
  previousIngestHash: chain2Tail,
  ingestSequenceNumber: localSeq,    // == localSeq under unification
  originSequenceNumber: originSeq,
  batchContext: batchCtx,
);
final storedEvent = incoming.copyWith(
  sequenceNumber: localSeq,
  metadata: {
    ...incoming.metadata,
    'provenance': [...incoming.metadata.provenance, receiverEntry.toJson()],
  },
);
final newHash = recomputeEventHash(storedEvent);
final finalEvent = storedEvent.copyWith(eventHash: newHash);
await backend.appendEvent(txn, finalEvent);  // SAME path as origin appends
```

Note: `appendEvent` (the existing origin-path method) handles persistence to `_eventStore`. The previously-separate `appendIngestedEvent` becomes unnecessary — DELETE it.

- [ ] **Step 3: Drop `_ingestedEventsStore` field, `nextIngestSequenceNumber`, `readIngestTail`, `readIngestTailInTxn`, `appendIngestedEvent`, `findEventsByIngestSeqRange`** from both abstract `StorageBackend` and concrete `SembastBackend`. Update any test-helper subclasses that override them.

- [ ] **Step 4: Update `findEventByIdInTxn` and `findEventById`** — single store now (per Phase 4.11 §4.11.7, the dual-store fallback collapses to one query).

- [ ] **Step 5: Update Phase 4.9's emission to `_eventsController`** — `appendEvent` already fires the broadcast (Phase 4.12 wired this). Since unification routes ingest through `appendEvent`, ingested events fire too — REQ-d00149-A "fires on both append and ingest" remains satisfied without a separate `appendIngestedEvent` emission.

- [ ] **Step 6: Run lib tests** — expect failures in any test that expected separate stores. Fix by updating test fixtures.

- [ ] **Step 7: Commit**

---

### Task B4: Update `verifyIngestChain` to walk unified store by local sequence_number

**Files:** `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (or wherever verifyIngestChain lives).

- [ ] **Step 1: Replace `findEventsByIngestSeqRange(from, to)` calls with `findAllEvents(afterSequence: from - 1, limit: to - from + 1)` or similar.**
- [ ] **Step 2: Update tests for verifyIngestChain accordingly.**
- [ ] **Step 3: Run tests + analyze.**
- [ ] **Step 4: Commit.**

---

### Task B5: Group B close — confirm zero `_ingestedEventsStore` references; full suite passes

- [ ] **Step 1: Greps**

```bash
grep -rn "_ingestedEventsStore\|nextIngestSequenceNumber\|readIngestTail\|appendIngestedEvent\|findEventsByIngestSeqRange" apps/common-dart/event_sourcing_datastore/lib/
```

Expected: ZERO hits.

- [ ] **Step 2: Run full test + analyze + provenance.**
- [ ] **Step 3: Update worklog Group B section.**
- [ ] **Step 4: Commit.**

---

## Group C: greenfield Destination API for native serialization

### Task C1: Spec — REQ-d00119-K rewrite + new REQ-d00152 (`Destination.serializesNatively`)

**Files:** `spec/dev-event-sourcing-mobile.md`.

- [ ] **Step 1: Rewrite REQ-d00119-K**

Original (after Phase 4.13) said the library detects native by parsing wire bytes. Rewrite to:

> K. `envelope_metadata` SHALL be a `BatchEnvelopeMetadata` value carrying `batch_format_version`, `batch_id`, `sender_hop`, `sender_identifier`, `sender_software_version`, `sent_at`. It SHALL be non-null when `wire_format == "esd/batch@1"` and null otherwise. Native FIFO rows SHALL be enqueued with envelope metadata supplied by the library's fillBatch path (NOT parsed from destination-supplied bytes — see REQ-d00152). The values SHALL be set at enqueue time and SHALL NOT be mutated thereafter — they are part of the FIFO row's identity for retry determinism. Drain reconstructs the wire bytes by combining `envelope_metadata` with `event_ids`-resolved events through `BatchEnvelope.encode`; the encoding is deterministic across retries (RFC 8785 JCS).

- [ ] **Step 2: Add REQ-d00152**

```markdown

---

# REQ-d00152: Destination Native-Serialization Declaration

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

A destination that consumes the library's canonical batch format (`esd/batch@1`) does not need to provide its own transform — the library already owns the canonical encoder. Forcing such destinations through a generic `transform(batch) → WirePayload` adds a redundant serialization pass and an opportunity for drift between the destination's encode and the library's. Greenfield design lets the destination simply declare `serializesNatively: true` and skip transform entirely; library produces envelope metadata at fillBatch time and persists it.

3rd-party destinations (sponsor CSV, Rave EDC XML, etc.) declare `serializesNatively: false` (the default) and continue to provide a `transform` whose output is stored verbatim as `wire_payload`.

## Assertions

A. `Destination.serializesNatively: bool` SHALL be a getter on the `Destination` interface, defaulting to `false`. Concrete destinations that produce `esd/batch@1` SHALL override to `true`.

B. When `destination.serializesNatively` is `true`, `fillBatch` SHALL NOT call `destination.transform`. Instead it SHALL build a `BatchEnvelopeMetadata` from the library's source identity (mint a fresh `batch_id`, stamp `sent_at = DateTime.now().toUtc()`, copy `sender_hop` / `sender_identifier` / `sender_software_version` from the library's source configuration) and pass it directly to `enqueueFifoTxn`. The resulting `FifoEntry` has `wire_payload: null` + `envelope_metadata: <non-null>` + `wire_format: "esd/batch@1"`.

C. When `destination.serializesNatively` is `false`, `fillBatch` SHALL call `destination.transform(batch) → WirePayload` and pass the result to `enqueueFifoTxn`. The resulting `FifoEntry` has `wire_payload: <Map>` + `envelope_metadata: null` + `wire_format: <destination's contentType>`.

D. The library SHALL NOT parse destination-supplied bytes to extract envelope metadata (the Phase 4.13 transient design is replaced). Native destinations declare; library produces. Lossy 3rd-party destinations transform; library stores.

E. `enqueueFifoTxn`'s signature SHALL accept either a `WirePayload` (3rd-party path) or a `BatchEnvelopeMetadata` + event list (native path) — the implementation chooses one based on `destination.serializesNatively`.

*End* *Destination Native-Serialization Declaration* | **Hash**: 00000000

```

(Hash placeholder per XP.3 — pre-commit hook populates.)

- [ ] **Step 3: Commit.**

---

### Task C2: `Destination.serializesNatively` declaration; library source identity

**Files:** `lib/src/destinations/destination.dart`; `lib/src/event_store.dart` (or wherever the library's source identity is configured).

- [ ] **Step 1: Add abstract getter `bool get serializesNatively => false;` to the `Destination` base class**.
- [ ] **Step 2: Confirm the library has access to source identity (`hopId`, `identifier`, `softwareVersion`)** — Phase 4.9 already required this for ProvenanceEntry stamping. Verify the field exists on EventStore or similar.
- [ ] **Step 3: Add a simple native `Destination` implementation in test_support** for tests to use (e.g. `NativeDestination` extending Destination, overriding `serializesNatively` to true).
- [ ] **Step 4: Commit.**

---

### Task C3: `fillBatch` branches on `destination.serializesNatively`

**Files:** `lib/src/sync/fill_batch.dart`.

- [ ] **Step 1: Locate the `destination.transform(batch) → WirePayload` call.**
- [ ] **Step 2: Branch:**

```dart
if (destination.serializesNatively) {
  final envelope = BatchEnvelopeMetadata(
    batchFormatVersion: '1',
    batchId: _mintBatchId(),
    senderHop: source.hopId,
    senderIdentifier: source.identifier,
    senderSoftwareVersion: source.softwareVersion,
    sentAt: now,
  );
  await backend.enqueueFifoTxn(
    txn,
    destination.id,
    batch,
    nativeEnvelope: envelope,  // new optional parameter on enqueueFifoTxn
  );
} else {
  final payload = await destination.transform(batch);
  await backend.enqueueFifoTxn(txn, destination.id, batch, wirePayload: payload);
}
```

- [ ] **Step 3: Update `enqueueFifoTxn`'s signature** to accept `wirePayload` OR `nativeEnvelope` (XOR — exactly one must be non-null). Refactor implementation to skip the parse-and-strip path entirely; storage just persists what fillBatch provided.

- [ ] **Step 4: Run tests; expect failures in tests that called `enqueueFifoTxn` with a native-bytes WirePayload.** Update those tests to use the new shape: pass `nativeEnvelope:` for native + `wirePayload:` for lossy.

- [ ] **Step 5: Commit.**

---

### Task C4: Group C close — verify, drop dead code

- [ ] **Step 1: Confirm enqueueFifoTxn no longer calls `BatchEnvelope.decode` from inside.** (The detect-and-strip code from Phase 4.13 is now dead.)
- [ ] **Step 2: Full suite + analyze.**
- [ ] **Step 3: Worklog update.**
- [ ] **Step 4: Commit.**

---

## Group D: typed `StorageBackend.queryAudit` + remove `debugDatabase`

### Task D1: Spec — REQ-d00151 (queryAudit on StorageBackend)

**Files:** `spec/dev-event-sourcing-mobile.md`.

- [ ] **Step 1: Append REQ-d00151 with `| **Hash**: 00000000` placeholder**:

```markdown
# REQ-d00151: queryAudit Storage-Layer API

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

Audit-context queries join two stores (security_context + events) with filtering, sorting, and cursor-based pagination. The implementation belongs at the storage layer because only the storage layer can do the join efficiently. Surfacing this via `StorageBackend` lets `SecurityContextStore` implementations remain narrow (single-row reads/writes) and removes the need for any consumer to reach past the abstraction via `debugDatabase()`.

## Assertions

A. `StorageBackend.queryAudit({Initiator? initiator, String? flowToken, String? ipAddress, DateTime? from, DateTime? to, int limit = 50, String? cursor}) → Future<PagedAudit>` SHALL be the supported entry point for cross-store audit queries. The contract matches the previous `SecurityContextStore.queryAudit` signature, with the same filter / cursor / limit semantics.

B. Implementations SHALL perform the cross-store join internally; consumers SHALL NOT reach past the abstraction (e.g., to a sembast `debugDatabase` accessor) to perform their own joins.

C. `SecurityContextStore.queryAudit` SHALL delegate to `backend.queryAudit` (or be removed from the interface if the typed backend method is the only call site needed by the application).

*End* *queryAudit Storage-Layer API* | **Hash**: 00000000
```

- [ ] **Step 2: Commit.**

---

### Task D2: Add abstract `StorageBackend.queryAudit`; implement on `SembastBackend`; delegate `SembastSecurityContextStore.queryAudit`

**Files:** abstract on `storage_backend.dart`; concrete on `sembast_backend.dart`; delegation on `sembast_security_context_store.dart`.

- [ ] **Step 1: Add the abstract method.**
- [ ] **Step 2: Move the body of `SembastSecurityContextStore.queryAudit` (lines 100–227) into `SembastBackend.queryAudit`**, swapping `_store` and `_eventStore` references for backend-private store handles. The cross-store finder pattern stays the same; only the location moves.
- [ ] **Step 3: `SembastSecurityContextStore.queryAudit` becomes**:

```dart
@override
Future<PagedAudit> queryAudit({...}) => backend.queryAudit(
  initiator: initiator,
  flowToken: flowToken,
  ipAddress: ipAddress,
  from: from,
  to: to,
  limit: limit,
  cursor: cursor,
);
```

- [ ] **Step 4: Run tests** — security store tests should pass unchanged (behavior preserved).

- [ ] **Step 5: Commit.**

---

### Task D3: REMOVE `debugDatabase()` from `SembastBackend`

**Files:** `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`; any test that uses it.

- [ ] **Step 1: Final grep**

```bash
grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/
```

Expected at this point: only the definition + (possibly) a test-helper that uses it for surgical mutations (the Phase 4.13 missing-event drain test, for example).

- [ ] **Step 2: For tests that need raw database access for surgical mutations**: add a test-only helper (e.g., `lib/src/storage/sembast_test_support.dart` exporting an `@visibleForTesting` accessor) OR rewrite the tests to use the public API.

- [ ] **Step 3: Delete `Database debugDatabase() => _database();` from `sembast_backend.dart`**.

- [ ] **Step 4: Final grep verifies ZERO hits.**

- [ ] **Step 5: Commit.**

---

### Task D4: Group D close — full suite + analyze; worklog update

- [ ] **Step 1: Full verification.**
- [ ] **Step 2: Worklog update.**
- [ ] **Step 3: Commit.**

---

## Task Final: Phase close

**Files:** `PHASE_4.14_WORKLOG.md`, `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md`.

- [ ] **Step 1: Run full phase invariants** (5 commands as in baseline).
- [ ] **Step 2: Final greps** for all four cleanup targets (rehabilitate, _ingestedEventsStore, debugDatabase, native-parse-and-strip).
- [ ] **Step 3: Mark all tasks done in worklog; add Final-verification section.**
- [ ] **Step 4: Append `**Closed:** 2026-MM-DD. Final verification: ...` to the Phase 4.14 section of decisions log.**
- [ ] **Step 5: Commit.**
- [ ] **Step 6: Surface phase-end summary** + the run summary covering 4.10 through 4.14.

---

## What does NOT change in this phase

- Materialized view reactive read (`watchEntry`) — still deferred to mobile cutover (CUR-1169).
- Compaction / log truncation — still deferred.
- Portal-side outbound FIFOs — still out of scope (user-confirmed sufficient: native + lossy 3rd-party).
- 4.11.2 framing fix — no code change; just a do-not-repeat reminder in §4.14.F.

## Risks

### Risk 1: Group B is large

Touches Phase 4.9's ingest path comprehensively. Mitigation: B1–B5 are sub-tasks; checkpoint after each. If a test failure cascade is unmanageable, the orchestrator can pause and re-scope.

### Risk 2: enqueueFifoTxn signature change ripples

Group C changes the method's parameter shape (XOR `wirePayload` / `nativeEnvelope`). Every call site updates. Mitigation: callers in lib are few (mostly fillBatch); test fixtures may be many — use grep to enumerate and bulk-update.

### Risk 3: Removing `debugDatabase()` may break test-only surgical-mutation patterns

Phase 4.13's missing-event drain test uses `debugDatabase` to surgically delete an event. Mitigation: provide a `@visibleForTesting`-marked alternate accessor in a test-support file before removing the public method.

### Risk 4: `nextIngestSequenceNumber` removal affects Phase 4.9's ingest counter logic

Mitigation: with unification, the Chain 2 ordering is the local `sequence_number`; the ingest counter is no longer needed because there's only one counter (`nextSequenceNumber`). Verify Phase 4.9's tests cover the unified flow.
