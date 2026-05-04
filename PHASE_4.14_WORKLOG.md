# Phase 4.14 Worklog — Architectural Cleanup + Unified Event Store + Audit-Query API + Greenfield Destination API (CUR-1154)

**Plan:** docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.14_arch_cleanup.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.14 section §4.14.A-G)
**Branch:** mobile-event-sourcing-refactor
**Depends on:** Phase 4.13 closed at `ea070883`

## Baseline (Task 0)

- event_sourcing_datastore: +594 All tests passed
- provenance: +38 All tests passed
- analyze (event_sourcing_datastore lib): No issues found
- analyze (event_sourcing_datastore/example): No issues found
- analyze (provenance): No issues found

### BEFORE counts (cleanup targets)

- `rehabilitate` / `REQ-d00132` references: 22 hits across `apps/common-dart/event_sourcing_datastore/`
- `_ingestedEventsStore` / `nextIngestSequenceNumber` / `readIngestTail` / `appendIngestedEvent` references: 40 hits across `apps/common-dart/event_sourcing_datastore/lib/`
- `debugDatabase` references: 19 hits across `apps/common-dart/event_sourcing_datastore/`

## Tasks

### Group A: cleanup (rehabilitate removal + doc fixes)

- [x] Task 0: Baseline + worklog
- [x] Task A1: Remove rehabilitate from `setFinalStatusTxn`; delete REQ-d00132 markers
- [x] Task A2: Doc fix on REQ-d00149-E and REQ-d00150-E (backend-agnostic wording)
- [x] Task A3: Group A close — verify state, log

### Group A close (verification)

- event_sourcing_datastore: +594 All tests passed (unchanged from baseline; no rehab-specific tests existed at the start of phase 4.14)
- provenance: +38 All tests passed
- analyze (event_sourcing_datastore lib + example, provenance): clean
- `grep -rn "rehabilit\|REQ-d00132" apps/common-dart/event_sourcing_datastore/{lib,test}/` — ZERO hits
- `readFifoRow` retained: 14 hits across lib + test (1 abstract decl + 1 SembastBackend impl + 12 test-suite references). Per A1 plan triage rule ("If sole caller is rehab-related, remove"), the condition is not met — `readFifoRow` has live non-rehab callers in `test/integration/strict_order_regression_test.dart` and `test/sync/drain_test.dart` that inspect rows by `entry_id` for tombstone-and-refill and wedge-trail verification. Its dartdoc has been rewritten to describe the API in its own terms (no rehabilitate references).
- `setFinalStatusTxn` callers verified: only `lib/src/ops/tombstone_and_refill.dart` (lib) and three test-helper subclass overrides (passive delegation). No callers exercise transitions outside the remaining legal set.

### Group A commits

- cee904f6 Task 0 baseline + worklog
- 7ed528b0 Task A1 remove rehabilitate code paths + REQ-d00132 markers
- 89344e3c Task A2 REQ-d00149/150-E backend-agnostic wording
- (this commit) Task A3 Group A close

### Group B: unify origin + ingested event stores

- [x] Task B1: Spec — REQ-d00115 extension (`origin_sequence_number`); amend REQ-d00145; amend REQ-d00146
- [x] Task B2: ProvenanceEntry adds `originSequenceNumber` field
- [x] Task B3: Refactor `appendIngestedEvent` to use `_eventStore` + reassign `sequence_number`
  - Dropped `_ingestedEventsStore`, `nextIngestSequenceNumber`, `readIngestTail{,InTxn}`, `appendIngestedEvent`, `findEventsByIngestSeqRange` from abstract + concrete + test-helper subclasses (`_DelegatingBackend`, `_SpyBackend`, `_InMemoryBackend`).
  - `EventStore.ingestBatch`/`ingestEvent`/`logRejectedBatch`/`_emitDuplicateReceivedInTxn` now reserve a fresh local `sequence_number` via `nextSequenceNumber`, capture `originSeq = incoming.sequenceNumber`, stamp `originSequenceNumber` on the receiver `ProvenanceEntry`, and persist via `appendEvent`.
  - Decision: kept `ProvenanceEntry.ingestSequenceNumber` (under unification it equals the local `sequence_number` for ingested events; see receiver-hop dartdoc on REQ-d00115-K).
  - Updated `_verifyChainOn`/`_hashWithProvenanceSlice` to substitute the seq value at each hop using `origin_sequence_number` for hop 1 and the prior receiver's `ingest_sequence_number` for hop k>1, so Chain 1 verify works after the receiver reassigns the stored event's `sequence_number`.
  - Migrated `verifyIngestChain` to walk the unified store: scan `findAllEvents`, filter to ingest-stamped (last provenance has `ingest_sequence_number`), walk in-range. (Overlaps with B4; finished here so B3 leaves the lib compiling and tests green.)
  - Deleted `test/storage/sembast_backend_ingest_test.dart` (6 tests; all directly exercised the removed methods).
  - Added `REQ-d00149-A: watchEvents emits ingested events (unified store)` test confirming ingest routes through `appendEvent`'s broadcast.
  - Test count 594 → 589 (net −5: −6 from deleted file, +1 from the new watchEvents test). All pass; analyze clean (lib + example + provenance).
- [x] Task B4: Update `verifyIngestChain` to walk unified store by local sequence_number (substantially folded into B3; see note above — B4 reduces to docstring + dedicated test polish)
  - Renamed `verifyIngestChain` parameters `fromIngestSeq`/`toIngestSeq` → `fromSequenceNumber`/`toSequenceNumber` to match the spec amendment in REQ-d00146-C (B1). The walk reads via `findAllEvents`; there is no separate ingest-only counter, so the parameter names now reflect the underlying local `sequence_number`.
  - Updated `verify_ingest_chain_test.dart` call sites and the assertion-marker header to track the renamed parameters.
  - Dropped a stale "(in Task 8)" plan-task reference from the `_ingestOneInTxn` dartdoc.
  - Added `test/ingest/multi_hop_chain1_test.dart` — regression coverage for the hop-mapping seq-substitution branch in `_verifyChainOn` that the existing 2-hop `verify_event_chain_test` fixtures cannot reach. Two tests:
    - 3-hop chain (originator A → mobile relay B → portal C): exercises the `k > 1 → provenance[k-1].ingest_sequence_number` substitution path flagged by the B3 implementer.
    - 4-hop chain (A → B → D → C) confirms the recursion holds at depth 4.
  - Existing end-to-end coverage (no new tests required):
    - `verify_ingest_chain_test` walks 3 events from one originator on the unified store — passes.
    - `multi_originator_test` walks 4 events from 2 originators (per-event interleaved AND batched paths) and asserts `verifyIngestChain` ok — passes.
  - Test count 589 → 591 (+2 multi-hop). Analyze clean across lib + example + provenance.
- [x] Task B5: Group B close
  - Greps confirm ZERO hits in lib for `_ingestedEventsStore`, `nextIngestSequenceNumber`, `readIngestTail`, `appendIngestedEvent`, `findEventsByIngestSeqRange` (Phase invariant 5).
  - `flutter test`: event_sourcing_datastore +591 (baseline 594 → −6 deleted ingest-store tests in B3 + 1 watchEvents test in B3 + 2 multi-hop in B4 = 591). provenance +45 (baseline 38 + 7 originSequenceNumber round-trip tests in B2 = 45).
  - `flutter analyze`: clean across event_sourcing_datastore lib + example + provenance.

### Group B commits

- 47f0f27c Task B1 spec — REQ-d00115 origin_sequence_number; amend REQ-d00145/146
- 22843780 Task B2 ProvenanceEntry adds originSequenceNumber field
- d7c8da99 Task B3 unify origin + ingested event stores
- 9788676c Task B4 verifyIngestChain dartdoc + multi-hop Chain 1 test
- (this commit) Task B5 Group B close

### Group C: greenfield Destination API for native serialization

- [x] Task C1: Spec — REQ-d00119-K rewrite + new REQ-d00152
- [x] Task C2: `Destination.serializesNatively` declaration; library source identity
- [x] Task C3: `fillBatch` branches on `destination.serializesNatively`
- [x] Task C4: Group C close — verify, drop dead code

### Group C close (verification)

- `grep -rn "BatchEnvelope.decode" apps/common-dart/event_sourcing_datastore/lib/src/storage/` — ZERO hits. The Phase 4.13 detect-and-strip path inside `enqueueFifoTxn` is removed; the only `BatchEnvelope` references in `sembast_backend.dart` are now `BatchEnvelopeMetadata` (the typed `nativeEnvelope` parameter) and `BatchEnvelope.wireFormat` (the `"esd/batch@1"` string constant). The native branch persists `nativeEnvelope` directly; the 3rd-party branch decodes destination-supplied JSON bytes once into a Map column. No wire envelope parsing happens in storage.
- `flutter test` (event_sourcing_datastore): +595 All tests passed.
- `flutter test` (provenance): +45 All tests passed.
- `flutter analyze` (event_sourcing_datastore lib + example, provenance): clean.

### Group C commits

- b2c2378e Task C1 spec — REQ-d00119-K rewrite + REQ-d00152 native serialization declaration
- 83b42b4a Task C2 Destination.serializesNatively getter + NativeDestination test support
- a2d5bacd Task C3 fillBatch branches on serializesNatively; enqueueFifo XOR shape
- (this commit) Task C4 Group C close

### Group D: typed `StorageBackend.queryAudit` + remove `debugDatabase`

- [x] Task D1: Spec — REQ-d00151 (queryAudit Storage-Layer API)
- [x] Task D2: Add abstract `StorageBackend.queryAudit`; implement on `SembastBackend`; `SembastSecurityContextStore.queryAudit` becomes thin delegator
  - Moved the join body (previously lines ~96-224 of `sembast_security_context_store.dart`) into `SembastBackend.queryAudit`. Backend grew a private `_securityContextStore` ref (multiple sembast `StoreRef` handles to the same store name read/write the same records, so cohabitation with `SembastSecurityContextStore`'s ref is correct).
  - `SembastSecurityContextStore.queryAudit` is now a 12-line forward to `backend.queryAudit(...)` covering all 7 named parameters.
  - `_CursorPoint` private class moved (renamed `_AuditCursorPoint`) into `sembast_backend.dart`; the security store no longer needs `dart:convert`, `_eventStore`, or `StoredEvent`.
  - Test-helper subclasses updated: `_SpyBackend` (event_repository_test.dart) + `_DelegatingBackend` (entry_service_test.dart) delegate to `_inner.queryAudit(...)`; `_InMemoryBackend` (storage_backend_contract_test.dart) returns `const PagedAudit(rows: [])`.
  - Security store tests pass unchanged (11/11).
- [x] Task D3: REMOVE `debugDatabase()` from `SembastBackend`
  - The Phase 4.13 missing-event drain test (in `drain_test.dart`) and 16 other test sites needed surgical raw-database access (e.g., asserting on-disk FIFO row payload shape, deleting an event row to simulate corruption). Per the plan's "whatever's cleanest" guidance, added a `@visibleForTesting`-marked accessor in `lib/src/storage/sembast_test_support.dart` (a `part of 'sembast_backend.dart'` extension) exposing `databaseForTesting`.
  - Deleted `Database debugDatabase() => _database();` from `sembast_backend.dart`. All 17 test call sites renamed to `databaseForTesting`. The library exports `SembastBackendTestSupport` so test files importing `package:event_sourcing_datastore/event_sourcing_datastore.dart` see the extension.
  - `grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/` — ZERO hits anywhere (lib + test + example).
- [x] Task D4: Group D close

### Group D close (verification)

- `flutter test` (event_sourcing_datastore): +595 All tests passed.
- `flutter test` (provenance): +45 All tests passed.
- `flutter analyze` (event_sourcing_datastore lib + example, provenance): clean.
- `grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/` — ZERO hits (Phase invariant 6).

### Group D commits

- 7cc470df Task D1 spec — REQ-d00151 queryAudit Storage-Layer API
- b47ca182 Task D2 StorageBackend.queryAudit; SembastSecurityContextStore delegates
- d3b48f02 Task D3 remove debugDatabase; @visibleForTesting databaseForTesting
- (this commit) Task D4 Group D close

### Phase close

- [x] Task Final: Phase close — invariants, decisions log, summary

### Final verification (Task Final)

Phase invariants (5 commands):

- `flutter test` (event_sourcing_datastore): `00:05 +595: All tests passed!`
- `flutter test` (provenance): `00:00 +45: All tests passed!`
- `flutter analyze` (event_sourcing_datastore lib): `No issues found! (ran in 0.7s)`
- `flutter analyze` (event_sourcing_datastore/example): `No issues found! (ran in 0.5s)`
- `flutter analyze` (provenance): `No issues found! (ran in 0.2s)`

Cleanup-target greps (Phase invariants 4-7):

- `grep -rn "REQ-d00132\|rehabilitate" apps/common-dart/event_sourcing_datastore/` — ZERO hits (exit 1)
- `grep -rn "_ingestedEventsStore\|nextIngestSequenceNumber\|appendIngestedEvent" apps/common-dart/event_sourcing_datastore/lib/` — ZERO hits (exit 1)
- `grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/` — ZERO hits (exit 1)
- `grep -n "BatchEnvelope.decode" apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` — ZERO hits (exit 1)

Test-count delta vs. baseline:

- event_sourcing_datastore: 594 (baseline) -> 595 (+1 net). Group B: -6 deleted ingest-store tests, +1 watchEvents unified-store test, +2 multi-hop Chain 1 tests = -3. Group C: +4 (serializesNatively branching + XOR-shape + native drain reconstruction). Group D: +0 (security-store behavior preserved; queryAudit moved without test churn).
- provenance: 38 (baseline) -> 45 (+7 from Group B's `originSequenceNumber` round-trip cases on REQ-d00115-K).

Phase 4.14 commit range (cee904f6 .. 6dab7c9f, plus this closing commit): 16 commits prior to Task Final + 1 closing = 17 total.
