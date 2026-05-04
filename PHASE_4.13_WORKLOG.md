# Phase 4.13 Worklog — Outgoing Native wire_payload Optimization (CUR-1154)

**Spec:** docs/superpowers/specs/2026-04-25-phase4.13-outgoing-native-wire-payload-design.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.13 section)
**Branch:** mobile-event-sourcing-refactor

## Baseline (Task 1)

- event_sourcing_datastore: +582 All tests passed
- provenance: +38 All tests passed
- analyze (lib + example + provenance): clean
- Phase 4.9 BatchEnvelope: present (lib/src/ingest/batch_envelope.dart line 10)
- Phase 4.11 findEventById: present (lib/src/storage/storage_backend.dart line 457)
- StoredEvent.toMap: present (lib/src/storage/stored_event.dart line 190)

## Tasks

- [x] Task 1: Baseline + worklog
- [x] Task 2: Spec — REQ-d00119-B rewrite + REQ-d00119-K addition
- [x] Task 3: BatchEnvelopeMetadata value type + tests
- [x] Task 4: FifoEntry — add envelope_metadata field, make wirePayload nullable, update serialization
- [x] Task 5: enqueueFifoTxn — detect native, parse, strip bytes, persist envelope
- [x] Task 6: Drain branch — re-encode native rows on demand
- [x] Task 7: Round-trip determinism + integration tests
- [x] Task 8: Final verification + close worklog

## Final verification (Task 8)

**Closed:** 2026-04-25.

- event_sourcing_datastore: +594 All tests passed (baseline +582 + 12 new across Tasks 3-7).
- provenance: +38 All tests passed (unchanged across the phase).
- analyze (event_sourcing_datastore lib): No issues found.
- analyze (event_sourcing_datastore/example): No issues found.
- analyze (provenance): No issues found.

**Round-trip determinism (invariant 4):** verified by
`test/integration/native_round_trip_test.dart` and the drain-branch tests in
`test/sync/drain_test.dart`: a native FIFO row drained twice produces
byte-identical wire bytes (RFC 8785 JCS canonicalization + immutable
`envelope_metadata` + immutable events per REQ-p00004).

**REQ-d00132 invariant 5:** no NEW references introduced; pre-existing orphans
left untouched per decisions log §4.10.4.

**Storage-savings sanity:** native FIFO rows persist `envelope_metadata`
(six string fields plus one ISO-8601 timestamp, on the order of a few
hundred bytes) and a null `wire_payload`. The naive shape would persist
the full encoded `esd/batch@1` JSON bytes — every event in the batch,
embedded as a JSON map with all envelope, ingest, and payload fields.
For a typical 10-event batch that naive shape is on the order of 5-10
KB per row, so the envelope_metadata shape is roughly 95% smaller for
native rows. 3rd-party rows (non-native `wire_format`) store
`wire_payload` verbatim and carry a null `envelope_metadata`.

**Phase 4.13 commit range:** `2fae2651..10f5b6f3` (10 commits prior to this
closing commit; this Task 8 commit becomes the 11th).

- 2fae2651 design spec
- 7ed3fa31 implementation plan (8 tasks)
- d8276bf6 Task 1 baseline + worklog
- 467298d7 Task 2 spec REQ-d00119-B rewrite + REQ-d00119-K
- 23a3e502 Task 3 BatchEnvelopeMetadata value type
- 5c88b9cf §4.13.G FifoEntry.wirePayload Map note
- 91aec2eb Task 4 FifoEntry adds envelopeMetadata; wirePayload nullable
- 39f81dad Task 5 enqueueFifoTxn detects native, strips bytes, stores envelope
- 9afd644a Task 6 drain branches — re-encode native rows on demand
- 10f5b6f3 Task 7 round-trip + watchFifo compatibility tests
- (this commit) Task 8 close worklog
