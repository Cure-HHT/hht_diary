# Master Plan Phase 4.9: Sync-Through Ingest

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a receiver-side write path to the library (`EventStore.ingestBatch` / `ingestEvent` / `logRejectedBatch` + `verifyEventChain` / `verifyIngestChain`) that preserves originator identity verbatim, stamps a per-hop Chain 1 audit link (`arrival_hash`), stamps a per-destination Chain 2 audit link (`previous_ingest_hash` + `ingest_sequence_number`), and integrates ingested events into the destination's tamper-evident log.

**Architecture:** Four new fields on `ProvenanceEntry` (in the `provenance` package) carry both chains. `event_sourcing_datastore` adds an `ingest` subtree with typed errors, result types, a verdict type, and a canonical `esd/batch@1` batch codec. `StorageBackend` gains destination-role methods (ingest counter, ingest tail, event-by-id lookup in-txn, ingested-event persistence keyed by `ingest_sequence_number`). `EventStore` gains three public write methods (`ingestBatch`, `ingestEvent`, `logRejectedBatch`) and two verification methods, plus a private helper that emits library-originated audit events (`ingest.duplicate_received`, `ingest.batch_rejected`) under a receiver-scoped ingest-audit aggregate. No existing code path is modified; `EventStore.append` / `StorageBackend.appendEvent` are untouched.

**Tech Stack:** Dart / Flutter, sembast, `canonical_json_jcs` (already in-tree) for RFC 8785 canonicalization, `crypto` for SHA-256, the `provenance` package (in-tree under `apps/common-dart/provenance`), and the `event_sourcing_datastore` package (in-tree under `apps/common-dart/event_sourcing_datastore`).

**Design spec:** `docs/superpowers/specs/2026-04-24-phase4.9-sync-through-ingest-design.md`.

**Branch:** `mobile-event-sourcing-refactor` (shared). **Ticket:** CUR-1154 (continuation). **Phase:** 4.9 (after 4.8). **Depends on:** Phase 4.8 (merge materialization) complete on HEAD.

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00115 (extension) | ProvenanceEntry gains `arrival_hash`, `previous_ingest_hash`, `ingest_sequence_number`, `batch_context` | Task 2 (spec); Task 3 (implementation + round-trip tests) |
| REQ-d00120 (extension) | `event_hash` is recomputed when a receiver appends a provenance entry | Task 2 (spec); Task 7/8 (tests demonstrating rehash) |
| REQ-d00145 (new) | `ingestBatch` / `ingestEvent` / `logRejectedBatch` contracts | Task 2 (spec); Tasks 7, 8, 9 |
| REQ-d00146 (new) | `verifyEventChain` / `verifyIngestChain` contracts; `ChainVerdict` shape | Task 2 (spec); Task 10 |

---

## Execution rules

Read `README.md` in the plans directory for TDD cadence, phase-boundary squash behavior (user is squash-merging the PR, so no per-phase squash required), cross-phase invariants, and REQ-citation conventions. At phase end, `flutter test` and `flutter analyze` MUST be clean on both `apps/common-dart/provenance` and `apps/common-dart/event_sourcing_datastore`, and `flutter analyze` MUST be clean on `apps/common-dart/event_sourcing_datastore/example`.

Read the design spec `docs/superpowers/specs/2026-04-24-phase4.9-sync-through-ingest-design.md` end-to-end before Task 1. Re-read §2.1 (two chains), §2.3 (canonical batch format + `BatchContext`), §2.5 (`ingestBatch` flow), §2.8 (idempotency), and §2.10 (failure model / approach A) before starting Tasks 7–9. Re-read §2.11 (verification APIs) before Task 10.

This phase makes **zero** changes to `EventStore.append`, `StorageBackend.appendEvent`, materializer code, or any consumer app. Origin-role behavior is untouched end-to-end; phase 4.9 adds destination-role behavior alongside.

---

## Plan

### Task 1: Baseline verification + worklog

**TASK_FILE**: `PHASE4.9_TASK_1.md`

**Files:**
- Create: `PHASE_4.9_WORKLOG.md` at repo root (mirror `PHASE_4.8_WORKLOG.md` structure).
- Create: `PHASE4.9_TASK_1.md` at repo root.

- [ ] **Confirm Phase 4.8 is committed on HEAD**:

```bash
git log --oneline | grep "Phase 4.8" | head
```

Expected: `[CUR-1154] Phase 4.8 Task 6: final verification + worklog close` is present. Record the SHA in the TASK_FILE.

- [ ] **Baseline tests — all green on BOTH packages**:

```bash
(cd apps/common-dart/provenance && flutter test && flutter analyze)
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
(cd apps/common-dart/event_sourcing_datastore/example && flutter pub get && flutter analyze)
```

Expected: all tests pass on both packages; analyze clean on all three commands. Record exact test counts in the TASK_FILE (provenance package count + event_sourcing_datastore package count).

- [ ] **Create `PHASE_4.9_WORKLOG.md`** at repo root. Structure mirrors `PHASE_4.8_WORKLOG.md`:
  - Phase: 4.9 — sync-through ingest
  - Ticket: CUR-1154 (continuation, no new ticket)
  - Design doc: `docs/superpowers/specs/2026-04-24-phase4.9-sync-through-ingest-design.md`
  - Plan doc: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.9_sync_through_ingest.md`
  - REQ-d claims: REQ-d00115 (extended), REQ-d00120 (extended), REQ-d00145 (new), REQ-d00146 (new)

- [ ] **Create `PHASE4.9_TASK_1.md`** summarizing baseline SHA, test counts, and plan anchor.

- [ ] **Commit**:

```bash
git add PHASE_4.9_WORKLOG.md PHASE4.9_TASK_1.md
git commit -m "[CUR-1154] Phase 4.9 Task 1: baseline + worklog"
```

---

### Task 2: Spec changes

**TASK_FILE**: `PHASE4.9_TASK_2.md`

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md` (extend REQ-d00115, extend REQ-d00120, add REQ-d00145 section, add REQ-d00146 section).
- Modify: `spec/INDEX.md` (pre-commit hook regenerates hashes).

**No tests in this task** — spec text only.

- [ ] **Locate REQ-d00115 in `spec/dev-event-sourcing-mobile.md`** (around line 17 at spec-time). Confirm it has assertions A through F currently.

- [ ] **Add REQ-d00115 assertion G** (after F):

> G. A `ProvenanceEntry` MAY carry a nullable `arrival_hash` string. This field SHALL be `null` on the originator's entry (`provenance[0]` stamped by the originating system). For every entry stamped by a receiver hop on ingest, `arrival_hash` SHALL be non-null and SHALL equal the value of `event.event_hash` as the event appeared on the wire when this hop received it — i.e., the `event_hash` stored by the immediately-preceding hop. The field SHALL NOT be mutated after the entry is appended.

- [ ] **Add REQ-d00115 assertion H**:

> H. A `ProvenanceEntry` MAY carry a nullable `previous_ingest_hash` string. This field SHALL be `null` on the originator's entry and SHALL be `null` on the first-ever provenance entry stamped by a given receiver hop (no destination-local predecessor). For every other receiver-stamped entry, `previous_ingest_hash` SHALL be non-null and SHALL equal the stored `event_hash` of the event immediately preceding this event in the destination's Chain 2 (ingest order). The field SHALL NOT be mutated after the entry is appended.

- [ ] **Add REQ-d00115 assertion I**:

> I. A `ProvenanceEntry` MAY carry a nullable `ingest_sequence_number` integer. This field SHALL be `null` on the originator's entry. For every receiver-stamped entry on a given destination, `ingest_sequence_number` SHALL be non-null, monotonically increasing by 1 across all entries stamped at that destination (across all originators, across all ingestBatch and ingestEvent calls, across receiver-originated audit events — §2.9 of the design spec), and MUST NOT be rewound or reused.

- [ ] **Add REQ-d00115 assertion J**:

> J. A `ProvenanceEntry` MAY carry a nullable `batch_context` record with fields `batch_id` (UUID string), `batch_position` (non-negative integer), `batch_size` (positive integer), `batch_wire_bytes_hash` (SHA-256 hex string), and `batch_wire_format` (string). `batch_context` SHALL be non-null on receiver-stamped entries produced by `EventStore.ingestBatch`, and SHALL be `null` on all other entries (originator entries, process-local `ingestEvent` entries, and entries on receiver-originated audit events emitted outside a batch context).

- [ ] **Extend REQ-d00115 rationale paragraph** (at the start of the REQ, before Assertions). Append a new paragraph after the existing rationale:

> The cross-system provenance chain serves two distinct audit requirements: per-event identity preservation across hops (Chain 1), supported by `arrival_hash`; and per-destination tamper-evidence across events from multiple originators (Chain 2), supported by `previous_ingest_hash` and `ingest_sequence_number`. `batch_context` composes batch-level audit onto per-event records — an event received as part of an `esd/batch@1` batch carries its batch's identity and position, so an auditor can reconstruct the batch from stored events (see REQ-d00145) without duplicating wire bytes into the event store.

- [ ] **Locate REQ-d00120** (around line 157). Confirm assertions A–D currently present.

- [ ] **Add REQ-d00120 assertion E**:

> E. When a receiver appends a `ProvenanceEntry` to `metadata.provenance` during ingest, the event's `event_hash` SHALL be recomputed over the identity field set specified in assertion B (which includes `metadata`, and therefore the extended provenance chain), and the recomputed value SHALL be stored in place of the wire `event_hash`. The originator's `event_hash` remains recoverable via the Chain 1 walk specified in REQ-d00145-F. Cross-store byte-for-byte comparison of raw `event_hash` is not a valid identity check on ingested events; the Chain 1 walk is the specified mechanism.

- [ ] **Extend REQ-d00120 rationale**. Append a new paragraph:

> On every ingest hop the `event_hash` field is a function of the provenance chain as it stood at that hop. A receiver's stored `event_hash` is therefore the receiver's own output hash, not the originator's output hash. Identity preservation across hops is verified by the Chain 1 walk (each receiver entry's `arrival_hash` equals the hash the prior state would produce), not by naive field equality.

- [ ] **Add new REQ-d00145 section** in `spec/dev-event-sourcing-mobile.md`. Place it after REQ-d00144 (order is numeric).

Full text:

```markdown
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

*End* *EventStore Ingest Contract*
```

The `| **Hash**:` trailer is blank for new REQs; the pre-commit hook stamps it.

- [ ] **Add new REQ-d00146 section** in `spec/dev-event-sourcing-mobile.md`, immediately after REQ-d00145:

```markdown
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

*End* *Chain-of-Custody Verification APIs*
```

- [ ] **Commit** (the pre-commit hook regenerates `spec/INDEX.md` hashes):

```bash
git add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git commit -m "[CUR-1154] Phase 4.9 Task 2: spec changes for sync-through ingest"
```

Expected: commit succeeds; pre-commit hook updates `spec/INDEX.md` for the four touched REQs (REQ-d00115, REQ-d00120, REQ-d00145, REQ-d00146). If hook fails, read the error, fix the REQ text, re-stage, and re-commit as a new commit (never amend).

---

### Task 3: ProvenanceEntry + BatchContext schema (TDD)

**TASK_FILE**: `PHASE4.9_TASK_3.md`

**Files:**
- Create: `apps/common-dart/provenance/lib/src/batch_context.dart`
- Modify: `apps/common-dart/provenance/lib/provenance.dart` (export BatchContext)
- Modify: `apps/common-dart/provenance/lib/src/provenance_entry.dart` (add 4 new fields)
- Modify: `apps/common-dart/provenance/test/provenance_entry_test.dart` (add new tests)
- Create: `apps/common-dart/provenance/test/batch_context_test.dart`

**Implements**: REQ-d00115-G, -H, -I, -J.

#### Step 1: Write failing test for BatchContext round-trip

Create `apps/common-dart/provenance/test/batch_context_test.dart`:

```dart
import 'package:provenance/provenance.dart';
import 'package:test/test.dart';

void main() {
  group('BatchContext', () {
    test('round-trips through JSON preserving all five fields', () {
      const ctx = BatchContext(
        batchId: '01234567-89ab-cdef-0123-456789abcdef',
        batchPosition: 2,
        batchSize: 5,
        batchWireBytesHash: 'deadbeef' * 8,
        batchWireFormat: 'esd/batch@1',
      );
      final json = ctx.toJson();
      final back = BatchContext.fromJson(json);
      expect(back, equals(ctx));
    });

    test('equality and hashCode compare all fields', () {
      const a = BatchContext(
        batchId: 'same',
        batchPosition: 0,
        batchSize: 1,
        batchWireBytesHash: 'h',
        batchWireFormat: 'esd/batch@1',
      );
      const b = BatchContext(
        batchId: 'same',
        batchPosition: 0,
        batchSize: 1,
        batchWireBytesHash: 'h',
        batchWireFormat: 'esd/batch@1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('fromJson rejects missing fields', () {
      expect(
        () => BatchContext.fromJson(<String, Object?>{
          'batch_id': 'x',
          // missing batch_position
        }),
        throwsFormatException,
      );
    });
  });
}
```

#### Step 2: Run — expect fail ("BatchContext" not defined)

```bash
cd apps/common-dart/provenance && flutter test test/batch_context_test.dart
```

Expected: compile error / test failure — class `BatchContext` not found.

#### Step 3: Implement `BatchContext`

Create `apps/common-dart/provenance/lib/src/batch_context.dart`:

```dart
/// Per-event record of batch membership for events received via
/// `EventStore.ingestBatch`.
///
/// Stamped into the receiver-hop `ProvenanceEntry.batchContext` field. Null
/// on originator entries, null on process-local `ingestEvent` entries, null
/// on receiver-originated audit events not emitted in response to a batch.
///
/// All five fields together recover the context an auditor needs to recover
/// a batch from stored events: the batch id groups the events, the position
/// orders them, the size bounds the expected set, the wire-bytes hash pins
/// the bytes the receiver hashed, and the wire format identifies the
/// canonicalization procedure used.
// Implements: REQ-d00115-J — batch-context schema.
class BatchContext {
  const BatchContext({
    required this.batchId,
    required this.batchPosition,
    required this.batchSize,
    required this.batchWireBytesHash,
    required this.batchWireFormat,
  });

  factory BatchContext.fromJson(Map<String, Object?> json) {
    final batchId = _requireString(json, 'batch_id');
    final batchPosition = _requireInt(json, 'batch_position');
    final batchSize = _requireInt(json, 'batch_size');
    final batchWireBytesHash = _requireString(json, 'batch_wire_bytes_hash');
    final batchWireFormat = _requireString(json, 'batch_wire_format');
    if (batchPosition < 0) {
      throw FormatException(
        'BatchContext: batch_position must be non-negative; got $batchPosition',
      );
    }
    if (batchSize <= 0) {
      throw FormatException(
        'BatchContext: batch_size must be positive; got $batchSize',
      );
    }
    if (batchPosition >= batchSize) {
      throw FormatException(
        'BatchContext: batch_position ($batchPosition) must be less than '
        'batch_size ($batchSize)',
      );
    }
    return BatchContext(
      batchId: batchId,
      batchPosition: batchPosition,
      batchSize: batchSize,
      batchWireBytesHash: batchWireBytesHash,
      batchWireFormat: batchWireFormat,
    );
  }

  final String batchId;
  final int batchPosition;
  final int batchSize;
  final String batchWireBytesHash;
  final String batchWireFormat;

  Map<String, Object?> toJson() => <String, Object?>{
    'batch_id': batchId,
    'batch_position': batchPosition,
    'batch_size': batchSize,
    'batch_wire_bytes_hash': batchWireBytesHash,
    'batch_wire_format': batchWireFormat,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchContext &&
          batchId == other.batchId &&
          batchPosition == other.batchPosition &&
          batchSize == other.batchSize &&
          batchWireBytesHash == other.batchWireBytesHash &&
          batchWireFormat == other.batchWireFormat;

  @override
  int get hashCode => Object.hash(
    batchId,
    batchPosition,
    batchSize,
    batchWireBytesHash,
    batchWireFormat,
  );

  @override
  String toString() =>
      'BatchContext('
      'batchId: $batchId, '
      'position: $batchPosition, '
      'size: $batchSize, '
      'wireBytesHash: $batchWireBytesHash, '
      'wireFormat: $batchWireFormat)';
}

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('BatchContext: missing or non-string "$key"');
  }
  return value;
}

int _requireInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('BatchContext: missing or non-int "$key"');
  }
  return value;
}
```

#### Step 4: Export BatchContext from the provenance package

Edit `apps/common-dart/provenance/lib/provenance.dart`. Replace:

```dart
export 'src/append_hop.dart';
export 'src/provenance_entry.dart';
```

with:

```dart
export 'src/append_hop.dart';
export 'src/batch_context.dart';
export 'src/provenance_entry.dart';
```

#### Step 5: Run — expect pass on BatchContext tests

```bash
cd apps/common-dart/provenance && flutter test test/batch_context_test.dart
```

Expected: all 3 tests pass.

#### Step 6: Write failing tests for ProvenanceEntry's four new fields

Add to `apps/common-dart/provenance/test/provenance_entry_test.dart` (or create the test file if it doesn't exist — check first; all existing tests should continue to pass). Add a new test group:

```dart
group('ProvenanceEntry ingest fields (REQ-d00115-G+H+I+J)', () {
  test('defaults to null for all four ingest fields', () {
    final entry = ProvenanceEntry(
      hop: 'mobile-device',
      receivedAt: DateTime.parse('2026-04-24T12:00:00Z'),
      identifier: 'device-abc',
      softwareVersion: 'daily_diary@1.0.0',
    );
    expect(entry.arrivalHash, isNull);
    expect(entry.previousIngestHash, isNull);
    expect(entry.ingestSequenceNumber, isNull);
    expect(entry.batchContext, isNull);
  });

  test('non-null ingest fields round-trip through JSON', () {
    final entry = ProvenanceEntry(
      hop: 'portal-server',
      receivedAt: DateTime.parse('2026-04-24T12:00:01Z'),
      identifier: 'portal-1',
      softwareVersion: 'portal@0.1.0',
      arrivalHash: 'abc123',
      previousIngestHash: 'def456',
      ingestSequenceNumber: 42,
      batchContext: const BatchContext(
        batchId: 'batch-xyz',
        batchPosition: 3,
        batchSize: 5,
        batchWireBytesHash: 'hhh',
        batchWireFormat: 'esd/batch@1',
      ),
    );
    final json = entry.toJson();
    final back = ProvenanceEntry.fromJson(json);
    expect(back, equals(entry));
    expect(back.arrivalHash, equals('abc123'));
    expect(back.previousIngestHash, equals('def456'));
    expect(back.ingestSequenceNumber, equals(42));
    expect(back.batchContext, isNotNull);
    expect(back.batchContext!.batchId, equals('batch-xyz'));
  });

  test('json omits ingest fields when all null', () {
    final entry = ProvenanceEntry(
      hop: 'mobile-device',
      receivedAt: DateTime.parse('2026-04-24T12:00:00Z'),
      identifier: 'device-abc',
      softwareVersion: 'daily_diary@1.0.0',
    );
    final json = entry.toJson();
    expect(json.containsKey('arrival_hash'), isFalse);
    expect(json.containsKey('previous_ingest_hash'), isFalse);
    expect(json.containsKey('ingest_sequence_number'), isFalse);
    expect(json.containsKey('batch_context'), isFalse);
  });

  test('equality and hashCode include the four new fields', () {
    final a = ProvenanceEntry(
      hop: 'h',
      receivedAt: DateTime.parse('2026-04-24T12:00:00Z'),
      identifier: 'i',
      softwareVersion: 's@1',
      arrivalHash: 'x',
    );
    final b = ProvenanceEntry(
      hop: 'h',
      receivedAt: DateTime.parse('2026-04-24T12:00:00Z'),
      identifier: 'i',
      softwareVersion: 's@1',
      arrivalHash: 'y',  // differs only here
    );
    expect(a, isNot(equals(b)));
    expect(a.hashCode, isNot(equals(b.hashCode)));
  });
});
```

#### Step 7: Run — expect fail (new fields don't exist)

```bash
cd apps/common-dart/provenance && flutter test
```

Expected: compile error — `arrivalHash`, `previousIngestHash`, `ingestSequenceNumber`, `batchContext` not defined on `ProvenanceEntry`.

#### Step 8: Extend `ProvenanceEntry` with the four new fields

Edit `apps/common-dart/provenance/lib/src/provenance_entry.dart`. At the top add the import:

```dart
import 'package:provenance/src/batch_context.dart';
```

Modify the constructor, adding the four new parameters as optional (default null):

```dart
const ProvenanceEntry({
  required this.hop,
  required this.receivedAt,
  required this.identifier,
  required this.softwareVersion,
  this.transformVersion,
  this.arrivalHash,
  this.previousIngestHash,
  this.ingestSequenceNumber,
  this.batchContext,
});
```

Add the fields:

```dart
final String? arrivalHash;
final String? previousIngestHash;
final int? ingestSequenceNumber;
final BatchContext? batchContext;
```

Extend `fromJson` to read the new fields:

```dart
factory ProvenanceEntry.fromJson(Map<String, Object?> json) {
  final hop = _requireString(json, 'hop');
  final receivedAtRaw = _requireString(json, 'received_at');
  final identifier = _requireString(json, 'identifier');
  final softwareVersion = _requireString(json, 'software_version');
  final transformVersionRaw = json['transform_version'];
  if (transformVersionRaw != null && transformVersionRaw is! String) {
    throw const FormatException(
      'ProvenanceEntry: "transform_version" must be a String when present',
    );
  }
  if (!_offsetPattern.hasMatch(receivedAtRaw)) {
    throw FormatException(
      'ProvenanceEntry: "received_at" must include an explicit timezone '
      'offset (Z or +/-HH[:]MM); got "$receivedAtRaw"',
    );
  }
  final DateTime receivedAt;
  try {
    receivedAt = DateTime.parse(receivedAtRaw);
  } on FormatException catch (e) {
    throw FormatException(
      'ProvenanceEntry: "received_at" is not a valid ISO 8601 string: '
      '${e.message}',
    );
  }
  final arrivalHash = _optionalString(json, 'arrival_hash');
  final previousIngestHash = _optionalString(json, 'previous_ingest_hash');
  final ingestSequenceNumber = _optionalInt(json, 'ingest_sequence_number');
  final batchContextRaw = json['batch_context'];
  BatchContext? batchContext;
  if (batchContextRaw != null) {
    if (batchContextRaw is! Map<String, Object?>) {
      throw const FormatException(
        'ProvenanceEntry: "batch_context" must be an object when present',
      );
    }
    batchContext = BatchContext.fromJson(batchContextRaw);
  }
  return ProvenanceEntry(
    hop: hop,
    receivedAt: receivedAt,
    identifier: identifier,
    softwareVersion: softwareVersion,
    transformVersion: transformVersionRaw as String?,
    arrivalHash: arrivalHash,
    previousIngestHash: previousIngestHash,
    ingestSequenceNumber: ingestSequenceNumber,
    batchContext: batchContext,
  );
}
```

Extend `toJson` to emit only non-null ingest fields (to preserve backward compatibility with the existing shape):

```dart
Map<String, Object?> toJson() => <String, Object?>{
  'hop': hop,
  'received_at': receivedAt.toIso8601String(),
  'identifier': identifier,
  'software_version': softwareVersion,
  'transform_version': transformVersion,
  if (arrivalHash != null) 'arrival_hash': arrivalHash,
  if (previousIngestHash != null) 'previous_ingest_hash': previousIngestHash,
  if (ingestSequenceNumber != null)
    'ingest_sequence_number': ingestSequenceNumber,
  if (batchContext != null) 'batch_context': batchContext!.toJson(),
};
```

Extend `operator ==` and `hashCode`:

```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is ProvenanceEntry &&
        hop == other.hop &&
        receivedAt == other.receivedAt &&
        identifier == other.identifier &&
        softwareVersion == other.softwareVersion &&
        transformVersion == other.transformVersion &&
        arrivalHash == other.arrivalHash &&
        previousIngestHash == other.previousIngestHash &&
        ingestSequenceNumber == other.ingestSequenceNumber &&
        batchContext == other.batchContext;

@override
int get hashCode => Object.hash(
  hop,
  receivedAt,
  identifier,
  softwareVersion,
  transformVersion,
  arrivalHash,
  previousIngestHash,
  ingestSequenceNumber,
  batchContext,
);
```

Add helper functions at the bottom:

```dart
String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException(
      'ProvenanceEntry: "$key" must be a String when present',
    );
  }
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException(
      'ProvenanceEntry: "$key" must be an int when present',
    );
  }
  return value;
}
```

#### Step 9: Run tests — expect pass

```bash
cd apps/common-dart/provenance && flutter test && flutter analyze
```

Expected: all tests pass (existing + 4 new); analyze clean.

#### Step 10: Commit

```bash
git add apps/common-dart/provenance/
git commit -m "[CUR-1154] Phase 4.9 Task 3: ProvenanceEntry + BatchContext schema (REQ-d00115-G+H+I+J)"
```

---

### Task 4: Canonical esd/batch@1 batch codec (TDD)

**TASK_FILE**: `PHASE4.9_TASK_4.md`

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/lib/src/ingest/batch_envelope.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/batch_envelope_test.dart`

**Implements**: REQ-d00145-B (canonical batch format).

#### Step 1: Write failing tests for the batch codec

Create `apps/common-dart/event_sourcing_datastore/test/ingest/batch_envelope_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:test/test.dart';

// Minimal fake StoredEvent-shaped maps for envelope tests; we're exercising
// the envelope codec, not StoredEvent validation.
Map<String, Object?> _fakeEventMap(String eventId) => <String, Object?>{
  'event_id': eventId,
  'aggregate_id': 'agg-$eventId',
  'aggregate_type': 'diary_entry',
  'entry_type': 'diary',
  'event_type': 'checkpoint',
  'sequence_number': 1,
  'data': const {},
  'metadata': const {'change_reason': 'initial', 'provenance': []},
  'initiator': const {'kind': 'system'},
  'flow_token': null,
  'client_timestamp': '2026-04-24T12:00:00Z',
  'previous_event_hash': null,
  'event_hash': 'deadbeef',
};

void main() {
  group('BatchEnvelope encode/decode', () {
    test('round-trips a single-event envelope preserving all fields', () {
      final envelope = BatchEnvelope(
        batchFormatVersion: '1',
        batchId: 'batch-xyz',
        senderHop: 'mobile-device',
        senderIdentifier: 'device-abc',
        senderSoftwareVersion: 'daily_diary@1.0.0',
        sentAt: DateTime.parse('2026-04-24T12:00:00Z'),
        events: <Map<String, Object?>>[_fakeEventMap('e1')],
      );
      final bytes = envelope.encode();
      final decoded = BatchEnvelope.decode(bytes);
      expect(decoded.batchId, equals('batch-xyz'));
      expect(decoded.events.length, equals(1));
      expect(decoded.events[0]['event_id'], equals('e1'));
    });

    test('encoding is deterministic (JCS-canonical)', () {
      final envelope = BatchEnvelope(
        batchFormatVersion: '1',
        batchId: 'batch-xyz',
        senderHop: 'mobile-device',
        senderIdentifier: 'device-abc',
        senderSoftwareVersion: 'daily_diary@1.0.0',
        sentAt: DateTime.parse('2026-04-24T12:00:00Z'),
        events: <Map<String, Object?>>[
          _fakeEventMap('e1'),
          _fakeEventMap('e2'),
        ],
      );
      final bytes1 = envelope.encode();
      final bytes2 = envelope.encode();
      expect(bytes1, equals(bytes2));
    });

    test('decode rejects non-JSON bytes with IngestDecodeFailure', () {
      final garbage = Uint8List.fromList(<int>[0xff, 0xfe, 0xfd]);
      expect(() => BatchEnvelope.decode(garbage), throwsA(isA<IngestDecodeFailure>()));
    });

    test('decode rejects missing batch_format_version', () {
      final bad = utf8.encode(jsonEncode(<String, Object?>{
        'batch_id': 'x',
        'sender_hop': 'y',
        'sender_identifier': 'z',
        'sender_software_version': 'a@1',
        'sent_at': '2026-04-24T12:00:00Z',
        'events': <Object?>[],
      }));
      expect(
        () => BatchEnvelope.decode(Uint8List.fromList(bad)),
        throwsA(isA<IngestDecodeFailure>()),
      );
    });

    test('decode rejects unsupported batch_format_version', () {
      final bad = utf8.encode(jsonEncode(<String, Object?>{
        'batch_format_version': '2',
        'batch_id': 'x',
        'sender_hop': 'y',
        'sender_identifier': 'z',
        'sender_software_version': 'a@1',
        'sent_at': '2026-04-24T12:00:00Z',
        'events': <Object?>[],
      }));
      expect(
        () => BatchEnvelope.decode(Uint8List.fromList(bad)),
        throwsA(isA<IngestDecodeFailure>()),
      );
    });
  });
}
```

Note: `IngestDecodeFailure` is introduced here but fully fleshed out in Task 5. The minimal declaration to unblock this test lives in `batch_envelope.dart` initially and is moved / refined during Task 5.

#### Step 2: Run — expect fail

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/batch_envelope_test.dart
```

Expected: compile errors — `BatchEnvelope`, `IngestDecodeFailure` not defined.

#### Step 3: Implement `BatchEnvelope`

Create `apps/common-dart/event_sourcing_datastore/lib/src/ingest/batch_envelope.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:canonical_json_jcs/canonical_json_jcs.dart';

/// Thrown by [BatchEnvelope.decode] when the input bytes cannot be parsed as
/// a well-formed `esd/batch@1` envelope. Moved to `ingest_errors.dart` in
/// Task 5.
// Implements: REQ-d00145-B.
class IngestDecodeFailure implements Exception {
  const IngestDecodeFailure(this.message);
  final String message;
  @override
  String toString() => 'IngestDecodeFailure: $message';
}

/// The library's canonical batch envelope. Phase 4.9 supports exactly one
/// format version: `"1"` (identifier `"esd/batch@1"`).
// Implements: REQ-d00145-B.
class BatchEnvelope {
  const BatchEnvelope({
    required this.batchFormatVersion,
    required this.batchId,
    required this.senderHop,
    required this.senderIdentifier,
    required this.senderSoftwareVersion,
    required this.sentAt,
    required this.events,
  });

  final String batchFormatVersion;
  final String batchId;
  final String senderHop;
  final String senderIdentifier;
  final String senderSoftwareVersion;
  final DateTime sentAt;
  /// Raw StoredEvent JSON. Callers decode each map into `StoredEvent` using
  /// `StoredEvent.fromMap` inside the ingest flow.
  final List<Map<String, Object?>> events;

  /// Canonical identifier for this format.
  static const String wireFormat = 'esd/batch@1';

  /// JCS-canonicalize this envelope into wire bytes.
  Uint8List encode() {
    final map = <String, Object?>{
      'batch_format_version': batchFormatVersion,
      'batch_id': batchId,
      'sender_hop': senderHop,
      'sender_identifier': senderIdentifier,
      'sender_software_version': senderSoftwareVersion,
      'sent_at': sentAt.toIso8601String(),
      'events': events,
    };
    return Uint8List.fromList(canonicalJsonJcsUtf8(map));
  }

  /// Parse wire bytes as a canonical envelope. Throws [IngestDecodeFailure]
  /// on any malformedness.
  static BatchEnvelope decode(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw IngestDecodeFailure('not valid UTF-8 JSON: $e');
    }
    if (decoded is! Map<String, Object?>) {
      throw const IngestDecodeFailure('envelope must be a JSON object');
    }
    final version = decoded['batch_format_version'];
    if (version != '1') {
      throw IngestDecodeFailure(
        'unsupported batch_format_version: got ${version ?? "(missing)"}; '
        'expected "1"',
      );
    }
    final batchId = _requireString(decoded, 'batch_id');
    final senderHop = _requireString(decoded, 'sender_hop');
    final senderIdentifier = _requireString(decoded, 'sender_identifier');
    final senderSoftwareVersion = _requireString(decoded, 'sender_software_version');
    final sentAtStr = _requireString(decoded, 'sent_at');
    final DateTime sentAt;
    try {
      sentAt = DateTime.parse(sentAtStr);
    } catch (e) {
      throw IngestDecodeFailure('sent_at not parseable: $e');
    }
    final eventsRaw = decoded['events'];
    if (eventsRaw is! List) {
      throw const IngestDecodeFailure('events must be a JSON array');
    }
    final events = <Map<String, Object?>>[];
    for (var i = 0; i < eventsRaw.length; i++) {
      final e = eventsRaw[i];
      if (e is! Map<String, Object?>) {
        throw IngestDecodeFailure('events[$i] must be a JSON object');
      }
      events.add(Map<String, Object?>.from(e));
    }
    return BatchEnvelope(
      batchFormatVersion: version,
      batchId: batchId,
      senderHop: senderHop,
      senderIdentifier: senderIdentifier,
      senderSoftwareVersion: senderSoftwareVersion,
      sentAt: sentAt,
      events: events,
    );
  }
}

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw IngestDecodeFailure('missing or non-string "$key"');
  }
  return value;
}
```

#### Step 4: Run tests — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/batch_envelope_test.dart && flutter analyze
```

Expected: 5 tests pass; analyze clean.

#### Step 5: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 4: canonical esd/batch@1 envelope codec"
```

---

### Task 5: Ingest error + result types + ChainVerdict

**TASK_FILE**: `PHASE4.9_TASK_5.md`

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/lib/src/ingest/ingest_errors.dart`
- Create: `apps/common-dart/event_sourcing_datastore/lib/src/ingest/ingest_result.dart`
- Create: `apps/common-dart/event_sourcing_datastore/lib/src/ingest/chain_verdict.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/ingest/batch_envelope.dart` (remove the stub `IngestDecodeFailure` class; import it from the new errors file)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart` (export the new types)
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_types_test.dart` (basic construction / equality tests)

**Implements**: REQ-d00146 (verdict/failure types); REQ-d00145-C/D (typed errors).

#### Step 1: Create `ingest_errors.dart`

```dart
/// Thrown by `EventStore.ingestBatch` / `ingestEvent` / `BatchEnvelope.decode`
/// when the input bytes cannot be parsed as a well-formed `esd/batch@1`
/// envelope (malformed JSON, wrong shape, unsupported format version,
/// missing required fields).
// Implements: REQ-d00145-B.
class IngestDecodeFailure implements Exception {
  const IngestDecodeFailure(this.message);
  final String message;
  @override
  String toString() => 'IngestDecodeFailure: $message';
}

/// Thrown by `ingestBatch` / `ingestEvent` when an incoming event's Chain 1
/// does not verify — some hop's `arrival_hash` does not match the hash the
/// prior state would produce.
// Implements: REQ-d00145-C.
class IngestChainBroken implements Exception {
  const IngestChainBroken({
    required this.eventId,
    required this.hopIndex,
    required this.expectedHash,
    required this.actualHash,
  });
  final String eventId;
  final int hopIndex;
  final String expectedHash;
  final String actualHash;
  @override
  String toString() =>
      'IngestChainBroken(eventId: $eventId, hopIndex: $hopIndex, '
      'expected: $expectedHash, actual: $actualHash)';
}

/// Thrown by `ingestBatch` / `ingestEvent` when an incoming event's
/// `event_id` matches an already-stored event but the incoming wire
/// `event_hash` differs from the stored copy's
/// `provenance[thisHop].arrival_hash` (i.e., the two copies are NOT
/// byte-identical).
// Implements: REQ-d00145-D.
class IngestIdentityMismatch implements Exception {
  const IngestIdentityMismatch({
    required this.eventId,
    required this.incomingHash,
    required this.storedArrivalHash,
  });
  final String eventId;
  final String incomingHash;
  final String storedArrivalHash;
  @override
  String toString() =>
      'IngestIdentityMismatch(eventId: $eventId, incoming: $incomingHash, '
      'storedArrival: $storedArrivalHash)';
}
```

#### Step 2: Create `ingest_result.dart`

```dart
/// Outcome of a single subject event's processing inside `ingestBatch` or
/// `ingestEvent`.
enum IngestOutcome {
  /// New event, stored with a fresh receiver provenance entry.
  ingested,

  /// Known event — identity matched, no mutation; a duplicate_received
  /// audit event was emitted separately.
  duplicate,
}

/// Per-event outcome from a single ingest call.
class PerEventIngestOutcome {
  const PerEventIngestOutcome({
    required this.eventId,
    required this.outcome,
    required this.resultHash,
  });

  final String eventId;
  final IngestOutcome outcome;

  /// The stored `event_hash` after processing: for `ingested`, this is the
  /// hash the receiver computed post-provenance-append; for `duplicate`,
  /// this is the stored copy's current `event_hash` (unchanged).
  final String resultHash;
}

/// Result of `ingestBatch`.
class IngestBatchResult {
  const IngestBatchResult({
    required this.batchId,
    required this.events,
  });
  final String batchId;
  final List<PerEventIngestOutcome> events;
}
```

#### Step 3: Create `chain_verdict.dart`

```dart
/// Reason a single chain link failed verification.
enum ChainFailureKind {
  /// `provenance[k].arrival_hash` did not equal the recomputed hash at hop k.
  arrivalHashMismatch,

  /// `provenance[thisHop].previous_ingest_hash` did not equal the stored
  /// `event_hash` of the prior event in Chain 2.
  previousIngestHashMismatch,

  /// An expected provenance entry was missing (e.g., empty provenance on a
  /// non-origin event).
  provenanceMissing,
}

/// A single broken link encountered during a chain walk.
class ChainFailure {
  const ChainFailure({
    required this.position,
    required this.kind,
    required this.expectedHash,
    required this.actualHash,
  });

  /// For Chain 1: the `provenance[]` index of the failing hop.
  /// For Chain 2: the `ingest_sequence_number` of the failing event.
  final int position;
  final ChainFailureKind kind;
  final String expectedHash;
  final String actualHash;
}

/// Non-throwing verdict returned by `verifyEventChain` / `verifyIngestChain`.
// Implements: REQ-d00146-B+C.
class ChainVerdict {
  const ChainVerdict({required this.ok, required this.failures});
  final bool ok;
  final List<ChainFailure> failures;

  static const ChainVerdict valid = ChainVerdict(ok: true, failures: <ChainFailure>[]);
}
```

#### Step 4: Write basic tests for the new types

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_types_test.dart`:

```dart
import 'package:event_sourcing_datastore/src/ingest/chain_verdict.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_errors.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_result.dart';
import 'package:test/test.dart';

void main() {
  group('IngestOutcome', () {
    test('enum has two values', () {
      expect(IngestOutcome.values, hasLength(2));
      expect(IngestOutcome.values, contains(IngestOutcome.ingested));
      expect(IngestOutcome.values, contains(IngestOutcome.duplicate));
    });
  });

  group('ChainVerdict', () {
    test('valid constant has ok=true and empty failures', () {
      expect(ChainVerdict.valid.ok, isTrue);
      expect(ChainVerdict.valid.failures, isEmpty);
    });

    test('construction with failures marks ok=false', () {
      const verdict = ChainVerdict(
        ok: false,
        failures: <ChainFailure>[
          ChainFailure(
            position: 2,
            kind: ChainFailureKind.arrivalHashMismatch,
            expectedHash: 'a',
            actualHash: 'b',
          ),
        ],
      );
      expect(verdict.ok, isFalse);
      expect(verdict.failures, hasLength(1));
    });
  });

  group('IngestChainBroken', () {
    test('carries diagnostic fields in toString', () {
      const err = IngestChainBroken(
        eventId: 'e1',
        hopIndex: 1,
        expectedHash: 'a',
        actualHash: 'b',
      );
      expect(err.toString(), contains('e1'));
      expect(err.toString(), contains('hopIndex: 1'));
    });
  });
}
```

#### Step 5: Remove the stub `IngestDecodeFailure` from `batch_envelope.dart`

Edit `apps/common-dart/event_sourcing_datastore/lib/src/ingest/batch_envelope.dart`. Delete the `class IngestDecodeFailure { ... }` block. Add at the top:

```dart
import 'package:event_sourcing_datastore/src/ingest/ingest_errors.dart';
```

#### Step 6: Export the new types from the library

Edit `apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart`. Add exports alphabetically in the existing export block:

```dart
export 'src/ingest/batch_envelope.dart' show BatchEnvelope;
export 'src/ingest/chain_verdict.dart' show ChainFailure, ChainFailureKind, ChainVerdict;
export 'src/ingest/ingest_errors.dart' show IngestChainBroken, IngestDecodeFailure, IngestIdentityMismatch;
export 'src/ingest/ingest_result.dart' show IngestBatchResult, IngestOutcome, PerEventIngestOutcome;
```

#### Step 7: Re-export `BatchContext` via event_sourcing_datastore

Since `BatchContext` lives in the `provenance` package but is part of the ingest API surface, confirm it's reachable from event_sourcing_datastore via the normal transitive re-export. If not, add an explicit re-export. Check with:

```bash
cd apps/common-dart/event_sourcing_datastore && grep -rn "package:provenance" lib/
```

If provenance is already transitively exported, no change needed. Otherwise add `export 'package:provenance/provenance.dart' show BatchContext;`.

#### Step 8: Run — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze
```

Expected: all tests pass (existing + the new ingest_types_test); analyze clean.

#### Step 9: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 5: ingest error, result, verdict types"
```

---

### Task 6: StorageBackend destination-role methods (TDD)

**TASK_FILE**: `PHASE4.9_TASK_6.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart` (add 4 new abstract methods).
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` (implement the new methods; add two new `backend_state` keys).
- Create: `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_ingest_test.dart`

**Implements**: supports REQ-d00145-E (destination-role persistence) and REQ-d00145-D (idempotency check).

#### Step 1: Add abstract methods to `StorageBackend`

Open `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart` and add, after `writeFillCursorTxn`:

```dart
// ------ Destination-role (ingest) ------

/// Reserve-and-increment the per-destination ingest counter within [txn]
/// and return the reserved value. Mirrors [nextSequenceNumber] but for
/// the destination-role counter. Monotone across all events that land in
/// this destination's log via the ingest path or via receiver-originated
/// audit-event emission. MUST NOT rewind or reuse values.
// Implements: REQ-d00115-I; supports REQ-d00145-E+J.
Future<int> nextIngestSequenceNumber(Txn txn);

/// Read this destination's current Chain 2 tail: `(seq, eventHash)`,
/// where `seq` is the highest `ingest_sequence_number` that has been
/// stamped (or 0 if none), and `eventHash` is the `event_hash` of the
/// event at that seq (or `null` if none). Non-transactional; reads the
/// last-committed value. Callers that need coherence with the current
/// transaction MUST use [readIngestTailInTxn].
// Implements: REQ-d00115-H; supports REQ-d00145-E.
Future<(int seq, String? eventHash)> readIngestTail();

/// Transactional variant of [readIngestTail]. Participates in the calling
/// `ingestBatch` / `ingestEvent` / `logRejectedBatch` transaction so that
/// writes already staged in the same transaction are visible.
Future<(int seq, String? eventHash)> readIngestTailInTxn(Txn txn);

/// Append [event] to the destination's event log keyed by
/// `metadata.provenance.last.ingest_sequence_number`. Updates the Chain 2
/// tail (last ingest seq + last event_hash) atomically in the same
/// transaction. Does NOT advance [nextSequenceNumber]'s origin counter.
///
/// Callers are responsible for having already reserved the ingest
/// sequence number via [nextIngestSequenceNumber] and stamped it onto
/// the event's receiver `ProvenanceEntry`.
// Implements: REQ-d00145-E.
Future<void> appendIngestedEvent(Txn txn, StoredEvent event);

/// Read a single event by `event_id` within [txn]. Returns `null` when no
/// event with that id is present. Used by ingest's idempotency check
/// (REQ-d00145-D). Phase 4.11 promotes a non-transactional variant to
/// the public API; Phase 4.9 exposes only the in-txn form.
Future<StoredEvent?> findEventByIdInTxn(Txn txn, String eventId);
```

#### Step 2: Add the `StoredEvent` import if not already present

Check `storage_backend.dart`'s imports. `StoredEvent` should already be imported (it's used on `appendEvent`). No change.

#### Step 3: Write failing tests for sembast implementations

Create `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_ingest_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

// Reuse the existing test helpers — if the repo has a helper that opens an
// in-memory sembast-backed StorageBackend for tests, use it. Otherwise
// instantiate inline:
Future<SembastBackend> _openBackend() async {
  final db = await databaseFactoryMemory.openDatabase('ingest_test_db');
  return SembastBackend(db);
}

StoredEvent _fakeStoredEvent({
  required String eventId,
  required int sequenceNumber,
}) {
  // Build a StoredEvent with valid-enough identity fields for storage
  // round-trip. Exact construction matches whatever test helper patterns
  // already exist in test/ — copy from e.g. end_to_end_test.dart.
  // Placeholder — implementer fills in using the existing test_support helpers.
  throw UnimplementedError(
    'Use existing test_support helpers to build a StoredEvent with event_id '
    'set to $eventId and sequence_number set to $sequenceNumber.',
  );
}

void main() {
  group('SembastBackend ingest-side methods', () {
    test('nextIngestSequenceNumber returns 1 on first call, then 2', () async {
      final backend = await _openBackend();
      await backend.transaction((txn) async {
        final first = await backend.nextIngestSequenceNumber(txn);
        final second = await backend.nextIngestSequenceNumber(txn);
        expect(first, equals(1));
        expect(second, equals(2));
      });
    });

    test('readIngestTail returns (0, null) on an empty backend', () async {
      final backend = await _openBackend();
      final tail = await backend.readIngestTail();
      expect(tail.$1, equals(0));
      expect(tail.$2, isNull);
    });

    test('appendIngestedEvent advances the Chain 2 tail', () async {
      final backend = await _openBackend();
      final event = _fakeStoredEvent(eventId: 'e1', sequenceNumber: 100);
      // Assume event has receiver provenance with ingest_sequence_number=1
      // and event_hash='hash-at-rest'.
      await backend.transaction((txn) async {
        final ingestSeq = await backend.nextIngestSequenceNumber(txn);
        // Construct event with ingestSequenceNumber = ingestSeq in its
        // last provenance entry; omitted here for brevity.
        await backend.appendIngestedEvent(txn, event);
      });
      final tail = await backend.readIngestTail();
      expect(tail.$1, equals(1));
      expect(tail.$2, equals('hash-at-rest'));
    });

    test('findEventByIdInTxn returns null when event_id is absent', () async {
      final backend = await _openBackend();
      await backend.transaction((txn) async {
        final found = await backend.findEventByIdInTxn(txn, 'nope');
        expect(found, isNull);
      });
    });

    test('findEventByIdInTxn returns the event when present', () async {
      final backend = await _openBackend();
      // Append an originated event via the normal path; then find it.
      // Use existing appendEvent helper for this setup.
      // (Details depend on the test-support helpers in the repo.)
      throw UnimplementedError('Use existing origin-path helpers to stage an event.');
    });
  });
}
```

The implementer fills in the test-setup placeholders using the existing `test/test_support/` helpers — reference `end_to_end_test.dart` and `sembast_backend_fifo_test.dart` for patterns.

#### Step 4: Run — expect fail

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_ingest_test.dart
```

Expected: compile errors — methods not yet defined on the abstract class (and test helpers missing).

#### Step 5: Implement the sembast methods

Open `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`. Add two new constants near the existing `_sequenceKey`:

```dart
static const _ingestSequenceKey = 'ingest_sequence_counter';
static const _ingestTailHashKey = 'ingest_tail_event_hash';
```

Implement the four new methods. A sketch; the implementer fills in details using the existing `_backendState` / `_eventsStore` patterns:

```dart
@override
Future<int> nextIngestSequenceNumber(Txn txn) async {
  final current =
      (await _backendStateStore.record(_ingestSequenceKey).get(txn.raw) as int?) ?? 0;
  final next = current + 1;
  await _backendStateStore.record(_ingestSequenceKey).put(txn.raw, next);
  return next;
}

@override
Future<(int, String?)> readIngestTail() async {
  final seq = (await _backendStateStore.record(_ingestSequenceKey).get(_db) as int?) ?? 0;
  final hash = await _backendStateStore.record(_ingestTailHashKey).get(_db) as String?;
  return (seq, hash);
}

@override
Future<(int, String?)> readIngestTailInTxn(Txn txn) async {
  final seq = (await _backendStateStore.record(_ingestSequenceKey).get(txn.raw) as int?) ?? 0;
  final hash = await _backendStateStore.record(_ingestTailHashKey).get(txn.raw) as String?;
  return (seq, hash);
}

@override
Future<void> appendIngestedEvent(Txn txn, StoredEvent event) async {
  // Extract the receiver's stamped ingest_sequence_number from the last
  // ProvenanceEntry.
  final provenance = event.metadata['provenance'] as List<Object?>;
  final lastEntry = provenance.last as Map<String, Object?>;
  final ingestSeq = lastEntry['ingest_sequence_number'] as int;

  // Persist to the events store using ingestSeq as the key.
  await _eventsStore.record(ingestSeq).put(txn.raw, event.toMap());

  // Update the Chain 2 tail atomically in the same txn.
  await _backendStateStore.record(_ingestTailHashKey).put(txn.raw, event.eventHash);
}

@override
Future<StoredEvent?> findEventByIdInTxn(Txn txn, String eventId) async {
  final finder = Finder(filter: Filter.equals('event_id', eventId), limit: 1);
  final record = await _eventsStore.findFirst(txn.raw, finder: finder);
  if (record == null) return null;
  return StoredEvent.fromMap(Map<String, Object?>.from(record.value), record.key as int);
}
```

The exact `_backendStateStore` / `_eventsStore` / `_db` names match whatever the existing sembast backend uses — copy the pattern. The `int` key on `_eventsStore.record(ingestSeq)` assumes the store is `intMapStoreFactory`; keep it that way.

**NOTE on key collision**: the existing `appendEvent` (origin path) also keys into `_eventsStore` using the origin `sequence_number`. On an origin-only backend (mobile), the origin counter and the ingest counter never collide because only one is ever used. On a destination backend that also hosts receiver-originated audit events, those events take the ingest path (Task 7 uses `appendIngestedEvent` for them too), so they use the ingest counter and don't collide with any origin entries. The contract in the REQ is clear: destinations use `ingest_sequence_number` as the storage key.

#### Step 6: Update `StorageBackend` doc comment to call out the ingest path

Add a comment above the new methods in `storage_backend.dart`:

```dart
// Methods below compose the destination-role (ingest) write path. Origin
// writes continue to use appendEvent (REQ-d00141). See Phase 4.9 design
// spec (docs/superpowers/specs/2026-04-24-phase4.9-sync-through-ingest-design.md)
// for the two-chain framing and the ingest flow.
```

#### Step 7: Run tests — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_ingest_test.dart && flutter analyze
```

Expected: all ingest tests pass; analyze clean.

#### Step 8: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 6: StorageBackend destination-role methods"
```

---

### Task 7: `EventStore.ingestEvent` process-local API (TDD)

**TASK_FILE**: `PHASE4.9_TASK_7.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (add `ingestEvent`, private helper for emitting receiver-originated audit events with Chain 2 stamping, hash-recompute helper).
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_event_happy_path_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_duplicate_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_identity_mismatch_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_chain_broken_test.dart`

**Implements**: REQ-d00145-C, -D, -G, -I, -J, -K; REQ-d00120-E; REQ-d00115-G+H+I.

This is the largest task. It splits into four TDD rounds, one per test file. Each round: write test, run, implement, run, commit at the end of the task.

#### Step 1: Write happy-path test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_event_happy_path_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:provenance/provenance.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.ingestEvent — happy path', () {
    test('new event is stored with receiver provenance and rehashed', () async {
      // Setup: originator EventStore produces an event; destination
      // EventStore ingests it.
      // Use existing test_support helpers to open two backends with
      // different `source` identities (mobile-device vs portal-server).
      //
      // Steps:
      //   1. originator.append(...) → StoredEvent e with provenance=[origin],
      //      arrival_hash=null at provenance[0], event_hash=H0.
      //   2. destination.ingestEvent(e).
      //   3. Read the stored copy from destination.backend.findEventByIdInTxn.
      //   4. Assert:
      //      a. stored.metadata.provenance.length == 2
      //      b. stored.metadata.provenance[0] equals e.metadata.provenance[0]
      //         (originator entry unchanged).
      //      c. stored.metadata.provenance[1].hop == destination's hop id.
      //      d. stored.metadata.provenance[1].arrivalHash == H0.
      //      e. stored.metadata.provenance[1].previousIngestHash is null
      //         (first-ever ingest at this destination).
      //      f. stored.metadata.provenance[1].ingestSequenceNumber == 1.
      //      g. stored.metadata.provenance[1].batchContext is null
      //         (process-local ingest).
      //      h. stored.event_hash != H0 (rehashed).
      //      i. e.eventId == stored.eventId.
      //      j. e.aggregateId == stored.aggregateId.
      //      k. e.sequenceNumber == stored.sequenceNumber (originator's).
      //      l. e.previousEventHash == stored.previousEventHash (originator's).
      //
      // Implementer fills in exact setup using test_support helpers.
    });

    test('ingestEvent returns PerEventIngestOutcome with outcome=ingested', () async {
      // Similar setup; assert the returned PerEventIngestOutcome has
      // outcome == IngestOutcome.ingested and resultHash == the rehashed
      // event_hash.
    });

    test('second unique event gets ingest_sequence_number=2', () async {
      // Ingest two distinct events; assert the second's provenance[last].
      // ingestSequenceNumber == 2 and previousIngestHash matches the first's
      // stored event_hash.
    });
  });
}
```

The `// Implementer fills in...` markers signal where the executing agent uses the existing `test/test_support/` helpers. Patterns to follow: `end_to_end_test.dart` for opening backends, `entry_service_test.dart` for building events.

#### Step 2: Run — expect fail (ingestEvent not defined)

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_event_happy_path_test.dart
```

Expected: compile error or skipped-placeholder tests.

#### Step 3: Implement `ingestEvent` on `EventStore`

In `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`, add a private helper for recomputing `event_hash` and the public `ingestEvent` method.

Add imports at the top:

```dart
import 'package:event_sourcing_datastore/src/ingest/chain_verdict.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_errors.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_result.dart';
import 'package:provenance/provenance.dart';
```

Add a private helper for computing `event_hash` over a given record map. Look for the existing `_eventHash` private function — it exists in `_appendInTxn`. Extract (or reuse) it so both paths call the same canonicalization.

Add these methods to the `EventStore` class:

```dart
/// Process-local ingest. See design spec §2.6.
///
/// Accepts an [incoming] StoredEvent (fully formed, with its current
/// `event_hash` and `metadata.provenance`), verifies Chain 1, checks
/// idempotency by event_id, stamps a receiver ProvenanceEntry with
/// Chain 2 fields (batch_context = null), recomputes event_hash,
/// persists.
// Implements: REQ-d00145-G+I+J+K.
Future<PerEventIngestOutcome> ingestEvent(StoredEvent incoming) async {
  return backend.transaction((txn) async {
    return _ingestOneInTxn(txn, incoming, batchContext: null);
  });
}

/// Per-event ingest logic, called from both `ingestEvent` and the
/// `ingestBatch` loop (Task 8).
///
/// [batchContext] is non-null when this is called from `ingestBatch`, null
/// when called from `ingestEvent`.
Future<PerEventIngestOutcome> _ingestOneInTxn(
  Txn txn,
  StoredEvent incoming, {
  required BatchContext? batchContext,
}) async {
  // 1. Chain 1 verify on the incoming provenance.
  final verdict = _verifyChainOn(incoming);
  if (!verdict.ok) {
    final failure = verdict.failures.first;
    throw IngestChainBroken(
      eventId: incoming.eventId,
      hopIndex: failure.position,
      expectedHash: failure.expectedHash,
      actualHash: failure.actualHash,
    );
  }

  // 2. Idempotency check.
  final existing = await backend.findEventByIdInTxn(txn, incoming.eventId);
  if (existing != null) {
    final lastProvenance =
        existing.metadata['provenance'] as List<Object?>;
    final thisHopEntry = lastProvenance.last as Map<String, Object?>;
    final storedArrivalHash = thisHopEntry['arrival_hash'] as String?;
    if (storedArrivalHash == incoming.eventHash) {
      // Duplicate — emit audit event, return.
      await _emitDuplicateReceivedInTxn(
        txn,
        subjectEventId: incoming.eventId,
        subjectEventHashOnRecord: existing.eventHash,
        batchContext: batchContext,
      );
      return PerEventIngestOutcome(
        eventId: incoming.eventId,
        outcome: IngestOutcome.duplicate,
        resultHash: existing.eventHash,
      );
    } else {
      throw IngestIdentityMismatch(
        eventId: incoming.eventId,
        incomingHash: incoming.eventHash,
        storedArrivalHash: storedArrivalHash ?? '(null)',
      );
    }
  }

  // 3. Stamp receiver provenance.
  final (currentSeq, currentTailHash) = await backend.readIngestTailInTxn(txn);
  final nextSeq = await backend.nextIngestSequenceNumber(txn);
  final receiverEntry = ProvenanceEntry(
    hop: source.hopId,
    receivedAt: _now(),
    identifier: source.identifier,
    softwareVersion: source.softwareVersion,
    arrivalHash: incoming.eventHash,
    previousIngestHash: currentSeq == 0 ? null : currentTailHash,
    ingestSequenceNumber: nextSeq,
    batchContext: batchContext,
  );

  // 4. Build the updated event record map and recompute hash.
  final updatedEvent = _appendReceiverProvenance(incoming, receiverEntry);

  // 5. Persist.
  await backend.appendIngestedEvent(txn, updatedEvent);

  return PerEventIngestOutcome(
    eventId: updatedEvent.eventId,
    outcome: IngestOutcome.ingested,
    resultHash: updatedEvent.eventHash,
  );
}

/// Walk Chain 1 on [event].metadata.provenance and return a verdict.
/// Public Chain-1 verifier (REQ-d00146-A) in Task 10 delegates to this.
ChainVerdict _verifyChainOn(StoredEvent event) {
  final provenance = (event.metadata['provenance'] as List<Object?>)
      .cast<Map<String, Object?>>();
  if (provenance.isEmpty) {
    return const ChainVerdict(
      ok: false,
      failures: <ChainFailure>[
        ChainFailure(
          position: -1,
          kind: ChainFailureKind.provenanceMissing,
          expectedHash: '(non-empty)',
          actualHash: '(empty)',
        ),
      ],
    );
  }
  final failures = <ChainFailure>[];
  for (var k = provenance.length - 1; k > 0; k--) {
    final entry = provenance[k];
    final expected = entry['arrival_hash'] as String?;
    if (expected == null) {
      failures.add(ChainFailure(
        position: k,
        kind: ChainFailureKind.arrivalHashMismatch,
        expectedHash: '(non-null)',
        actualHash: '(null)',
      ));
      continue;
    }
    final recomputed = _hashWithProvenanceSlice(event, provenance.sublist(0, k));
    if (recomputed != expected) {
      failures.add(ChainFailure(
        position: k,
        kind: ChainFailureKind.arrivalHashMismatch,
        expectedHash: expected,
        actualHash: recomputed,
      ));
    }
  }
  return ChainVerdict(ok: failures.isEmpty, failures: failures);
}

/// Build a new StoredEvent whose metadata.provenance has [receiverEntry]
/// appended and whose event_hash is recomputed over the updated identity.
StoredEvent _appendReceiverProvenance(
  StoredEvent incoming,
  ProvenanceEntry receiverEntry,
) {
  final oldProvenance = (incoming.metadata['provenance'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final newProvenance = <Map<String, Object?>>[
    ...oldProvenance,
    receiverEntry.toJson(),
  ];
  final newMetadata = <String, Object?>{
    ...incoming.metadata,
    'provenance': newProvenance,
  };
  final recordMap = incoming.toMap();
  recordMap['metadata'] = newMetadata;
  recordMap.remove('event_hash'); // rehash will overwrite
  final newHash = _eventHash(recordMap);
  recordMap['event_hash'] = newHash;
  return StoredEvent.fromMap(recordMap, incoming.sequenceNumber);
}

String _hashWithProvenanceSlice(
  StoredEvent event,
  List<Map<String, Object?>> provenanceSlice,
) {
  final recordMap = event.toMap();
  final newMetadata = <String, Object?>{
    ...event.metadata,
    'provenance': provenanceSlice,
  };
  recordMap['metadata'] = newMetadata;
  recordMap.remove('event_hash');
  return _eventHash(recordMap);
}
```

Add the duplicate-received emission helper (shape mirrors the existing `_appendInTxn` but with Chain 2 stamping on `provenance[0]`):

```dart
Future<void> _emitDuplicateReceivedInTxn(
  Txn txn, {
  required String subjectEventId,
  required String subjectEventHashOnRecord,
  required BatchContext? batchContext,
}) async {
  final now = _now();
  final (currentSeq, currentTailHash) = await backend.readIngestTailInTxn(txn);
  final nextSeq = await backend.nextIngestSequenceNumber(txn);

  final provenance0 = ProvenanceEntry(
    hop: source.hopId,
    receivedAt: now,
    identifier: source.identifier,
    softwareVersion: source.softwareVersion,
    arrivalHash: null,
    previousIngestHash: currentSeq == 0 ? null : currentTailHash,
    ingestSequenceNumber: nextSeq,
    batchContext: batchContext,
  );

  final auditAggregateId = 'ingest-audit:${source.hopId}';
  final localSeq = await backend.nextSequenceNumber(txn);
  final eventId = _uuid.v4();
  final recordMap = <String, Object?>{
    'event_id': eventId,
    'aggregate_id': auditAggregateId,
    'aggregate_type': 'ingest-audit',
    'entry_type': 'ingest-audit',
    'event_type': 'ingest.duplicate_received',
    'sequence_number': localSeq,
    'data': <String, Object?>{
      'subject_event_id': subjectEventId,
      'subject_event_hash_on_record': subjectEventHashOnRecord,
    },
    'metadata': <String, Object?>{
      'provenance': <Map<String, Object?>>[provenance0.toJson()],
    },
    'initiator': const {'kind': 'system'},
    'flow_token': null,
    'client_timestamp': now.toIso8601String(),
    'previous_event_hash': await backend.readLatestEventHash(txn),
  };
  final eventHash = _eventHash(recordMap);
  recordMap['event_hash'] = eventHash;
  final event = StoredEvent.fromMap(recordMap, 0);
  await backend.appendIngestedEvent(txn, event);
}
```

Extract the private `_eventHash` function if it's currently inside another method; promote to a top-level private function on the class:

```dart
String _eventHash(Map<String, Object?> recordMap) {
  final identityMap = <String, Object?>{
    'event_id': recordMap['event_id'],
    'aggregate_id': recordMap['aggregate_id'],
    'entry_type': recordMap['entry_type'],
    'event_type': recordMap['event_type'],
    'sequence_number': recordMap['sequence_number'],
    'data': recordMap['data'],
    'initiator': recordMap['initiator'],
    'flow_token': recordMap['flow_token'],
    'client_timestamp': recordMap['client_timestamp'],
    'previous_event_hash': recordMap['previous_event_hash'],
    'metadata': recordMap['metadata'],
  };
  final bytes = canonicalJsonJcsUtf8(identityMap);
  return sha256.convert(bytes).toString();
}
```

#### Step 4: Run happy-path test — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_event_happy_path_test.dart
```

Expected: all tests pass.

#### Step 5: Write duplicate-ingest test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_duplicate_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.ingestEvent — duplicate (REQ-d00145-D)', () {
    test('second ingest of identical event emits duplicate_received and returns duplicate outcome', () async {
      // Setup: two EventStores (originator, destination).
      // 1. originator.append(...) → e.
      // 2. destination.ingestEvent(e) → outcome=ingested.
      // 3. destination.ingestEvent(e) again → outcome=duplicate; resultHash
      //    unchanged from first ingest.
      // 4. Query destination for aggregate 'ingest-audit:<dest.hopId>' →
      //    one event of event_type 'ingest.duplicate_received' whose
      //    data.subject_event_id == e.eventId.
      // 5. Query destination for the original subject event's aggregate →
      //    still exactly one event; unchanged.
      // Implementer fills in using test_support helpers.
    });

    test('duplicate_received event carries batchContext=null for ingestEvent path', () async {
      // Same setup; assert the emitted ingest.duplicate_received event's
      // provenance[0].batchContext is null (REQ-d00115-J for process-local path).
    });
  });
}
```

#### Step 6: Run — expect pass (implementation from Step 3 already handles duplicates)

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_duplicate_test.dart
```

Expected: all tests pass. If they fail, the `_emitDuplicateReceivedInTxn` helper needs fixing.

#### Step 7: Write identity-mismatch test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_identity_mismatch_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.ingestEvent — identity mismatch (REQ-d00145-D)', () {
    test('ingesting an event whose event_id matches but event_hash differs throws', () async {
      // 1. originator.append(...) → e1.
      // 2. destination.ingestEvent(e1) → ingested.
      // 3. Construct e1' with same event_id but tampered data (different
      //    event_hash). Can be done by taking e1's JSON, changing a data
      //    field, and rebuilding StoredEvent without recomputing hash
      //    (or with a mismatched hash injected).
      // 4. destination.ingestEvent(e1') throws IngestIdentityMismatch.
      // 5. Transaction rolled back — no new events landed. Assert via
      //    tail query.
    });
  });
}
```

#### Step 8: Run — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_identity_mismatch_test.dart
```

Expected: all tests pass.

#### Step 9: Write chain-broken test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_chain_broken_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.ingestEvent — chain broken (REQ-d00145-C)', () {
    test('ingesting an event with a tampered arrival_hash on a prior hop throws', () async {
      // Setup: simulate a 2-hop chain by ingesting at an intermediate
      // destination, then tampering with the resulting provenance entry's
      // arrival_hash, then attempting to ingest at a third destination.
      // Alternative: hand-craft a StoredEvent whose provenance has a
      // malformed arrival_hash on provenance[1] (deliberately wrong value).
      // destination.ingestEvent(tampered) throws IngestChainBroken with
      // hopIndex matching the tampered position.
    });
  });
}
```

#### Step 10: Run — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_chain_broken_test.dart
```

Expected: all tests pass.

#### Step 11: Run full suite + analyze

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze
```

Expected: all tests pass (existing + 4 new test files); analyze clean.

#### Step 12: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 7: EventStore.ingestEvent (REQ-d00145-G)"
```

---

### Task 8: `EventStore.ingestBatch` wire-side API (TDD)

**TASK_FILE**: `PHASE4.9_TASK_8.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (add `ingestBatch`).
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_batch_happy_path_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_batch_reconstruction_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/batch_context_test.dart`

**Implements**: REQ-d00145-A, -B, -E, -J (batch_context stamping).

#### Step 1: Write happy-path test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_batch_happy_path_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.ingestBatch — happy path (REQ-d00145-A+B+E)', () {
    test('3-event batch stores 3 events with populated batch_context on each', () async {
      // Setup:
      //  1. originator.append three events (e1, e2, e3) all under the
      //     same aggregate (for test simplicity — can also be multiple
      //     aggregates).
      //  2. Build a BatchEnvelope wrapping [e1, e2, e3] with
      //     sender_hop=originator.hopId, batch_id=<uuid>, sent_at=now.
      //  3. envelope.encode() → bytes.
      //  4. destination.ingestBatch(bytes, wireFormat: 'esd/batch@1').
      //
      // Assertions:
      //  a. Result.batchId == envelope.batchId.
      //  b. Result.events.length == 3; all outcome == ingested.
      //  c. For each stored subject on destination: provenance.last is
      //     the receiver entry; its batch_context is non-null with
      //     batchId matching, batchSize==3, batchPosition matching its
      //     0-indexed position, batchWireFormat=='esd/batch@1',
      //     batchWireBytesHash==sha256(bytes).
      //  d. No 'ingest.batch_received' event exists in the destination's
      //     event log (alt design — batch_context IS the per-event audit).
      //  e. verifyIngestChain on the destination returns ok=true.
      //     (This uses the Task-10 API; if Task 10 is not yet implemented,
      //     substitute a manual Chain 2 check.)
    });

    test('single-event batch works (batchSize=1, batchPosition=0)', () async {
      // Degenerate case — still valid.
    });

    test('batch with one duplicate + two new subjects lands 2 new + 1 dup marker', () async {
      // 1. destination pre-ingests e1 via ingestEvent.
      // 2. Build batch [e1, e2, e3] where e1 is already-stored.
      // 3. destination.ingestBatch(bytes).
      // 4. Assertions:
      //    - outcomes: [duplicate, ingested, ingested].
      //    - destination stored e2, e3 (not re-stored e1).
      //    - one ingest.duplicate_received event emitted under
      //      ingest-audit aggregate with data.subject_event_id == e1.eventId.
      //    - duplicate_received event's provenance[0].batchContext is
      //      non-null and matches this batch's id/size/hash (REQ-d00115-J).
    });
  });
}
```

#### Step 2: Run — expect fail (ingestBatch not defined)

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_batch_happy_path_test.dart
```

Expected: compile error.

#### Step 3: Implement `ingestBatch`

Add to `event_store.dart` (after `ingestEvent`):

```dart
/// Wire-side ingest. See design spec §2.5.
// Implements: REQ-d00145-A+B+E.
Future<IngestBatchResult> ingestBatch(
  Uint8List bytes, {
  required String wireFormat,
}) async {
  // Currently only esd/batch@1 is supported.
  if (wireFormat != BatchEnvelope.wireFormat) {
    throw IngestDecodeFailure(
      'unsupported wireFormat: "$wireFormat"; expected "${BatchEnvelope.wireFormat}"',
    );
  }
  final envelope = BatchEnvelope.decode(bytes);
  final wireBytesHash = sha256.convert(bytes).toString();
  final outcomes = <PerEventIngestOutcome>[];

  await backend.transaction((txn) async {
    for (var i = 0; i < envelope.events.length; i++) {
      final eventMap = envelope.events[i];
      final storedEvent = StoredEvent.fromMap(
        Map<String, Object?>.from(eventMap),
        0,
      );
      final batchContext = BatchContext(
        batchId: envelope.batchId,
        batchPosition: i,
        batchSize: envelope.events.length,
        batchWireBytesHash: wireBytesHash,
        batchWireFormat: envelope.batchFormatVersion == '1'
            ? BatchEnvelope.wireFormat
            : 'esd/batch@${envelope.batchFormatVersion}',
      );
      final outcome = await _ingestOneInTxn(
        txn,
        storedEvent,
        batchContext: batchContext,
      );
      outcomes.add(outcome);
    }
  });

  return IngestBatchResult(batchId: envelope.batchId, events: outcomes);
}
```

Add the necessary import if not already present:

```dart
import 'dart:typed_data';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
```

#### Step 4: Run happy-path test — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_batch_happy_path_test.dart
```

Expected: all tests pass.

#### Step 5: Write reconstruction test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_batch_reconstruction_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';

void main() {
  group('Batch reconstruction (REQ-d00115-J; design §2.3)', () {
    test('stored events from an ingested batch reconstruct to bytes matching batch_wire_bytes_hash', () async {
      // 1. Build envelope, encode → bytes.
      // 2. destination.ingestBatch(bytes).
      // 3. Query stored subjects on destination (ordered by
      //    provenance.last.batchContext.batchPosition ASC).
      // 4. For each stored subject, strip the receiver's provenance entry
      //    (the last one) to recover the pre-ingest state.
      // 5. Wrap in a new BatchEnvelope with the metadata from any one of
      //    the events' batchContext (all five BatchContext fields are
      //    shared, except batchPosition).
      // 6. Encode the reconstructed envelope.
      // 7. sha256(reconstructed_bytes).toString() == stored
      //    batchContext.batchWireBytesHash.
    });
  });
}
```

#### Step 6: Run — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_batch_reconstruction_test.dart
```

Expected: passes if canonicalization is stable. If fails, the canonicalization of events is not round-tripping — examine `_appendReceiverProvenance`'s stripping logic in the test.

#### Step 7: Write all-or-nothing rollback test

Create a test inside the happy-path file (or as a new `ingest_batch_rollback_test.dart` file):

```dart
test('batch with one identity-mismatching subject rolls back entirely', () async {
  // 1. destination pre-ingests e1.
  // 2. Construct e1' with same event_id as e1 but tampered data (different hash).
  // 3. Build batch [e2 (new), e1' (mismatch), e3 (new)].
  // 4. destination.ingestBatch(bytes) throws IngestIdentityMismatch.
  // 5. Assertions:
  //    - Destination's Chain 2 tail unchanged (no e2, no e3, no dup markers).
  //    - e1 still stored with original content.
  //    - No ingest.batch_rejected event emitted implicitly.
});
```

#### Step 8: Run — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_batch_happy_path_test.dart
```

Expected: all tests pass.

#### Step 9: Run full suite + analyze

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze
```

Expected: all tests pass; analyze clean.

#### Step 10: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 8: EventStore.ingestBatch (REQ-d00145-A+B+E)"
```

---

### Task 9: `EventStore.logRejectedBatch` caller-composed audit (TDD)

**TASK_FILE**: `PHASE4.9_TASK_9.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (add `logRejectedBatch` + its helper).
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/log_rejected_batch_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/caller_composition_test.dart`

**Implements**: REQ-d00145-H+I+J.

#### Step 1: Write tests for `logRejectedBatch`

Create `apps/common-dart/event_sourcing_datastore/test/ingest/log_rejected_batch_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.logRejectedBatch (REQ-d00145-H+I)', () {
    test('emits one ingest.batch_rejected event with bytes, hash, reason, metadata', () async {
      final bytes = Uint8List.fromList(utf8.encode('garbage bytes'));
      await destination.logRejectedBatch(
        bytes,
        wireFormat: 'esd/batch@1',
        reason: 'decodeFailure',
        failedEventId: null,
        errorDetail: 'test: invalid envelope',
      );
      // Query destination's ingest-audit aggregate:
      //  - exactly one event of event_type 'ingest.batch_rejected'.
      //  - data.wire_bytes (base64-decode) == original bytes.
      //  - data.wire_bytes_hash == sha256(bytes).
      //  - data.reason == 'decodeFailure'.
      //  - data.error_detail == 'test: invalid envelope'.
      //  - provenance[0].ingestSequenceNumber != null (Chain 2 stamped).
      //  - provenance[0].batchContext == null (no decoded batch).
    });

    test('two consecutive calls emit two events; Chain 2 threads cleanly', () async {
      // logRejectedBatch twice; assert both events present; second's
      // previous_ingest_hash == first's stored event_hash.
    });
  });
}
```

Create `apps/common-dart/event_sourcing_datastore/test/ingest/caller_composition_test.dart`:

```dart
test('caller composes ingestBatch + logRejectedBatch on failure', () async {
  // 1. destination pre-ingests e1.
  // 2. Build batch [e1' (identity-mismatch variant)] bytes.
  // 3. Caller pattern:
  //      try {
  //        await destination.ingestBatch(bytes, wireFormat: 'esd/batch@1');
  //      } on IngestIdentityMismatch catch (e) {
  //        await destination.logRejectedBatch(
  //          bytes,
  //          wireFormat: 'esd/batch@1',
  //          reason: 'identityMismatch',
  //          failedEventId: e.eventId,
  //          errorDetail: e.toString(),
  //        );
  //      }
  // 4. Assertions:
  //    - ingestBatch threw.
  //    - No subject events from the rejected batch landed.
  //    - Exactly one ingest.batch_rejected event with reason='identityMismatch'
  //      and failed_event_id == e1.eventId.
  //    - Chain 2: tail advanced exactly once past the rejection event
  //      (plus the pre-existing ingest of e1 from step 1).
});
```

#### Step 2: Run — expect fail

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/log_rejected_batch_test.dart test/ingest/caller_composition_test.dart
```

Expected: compile error — `logRejectedBatch` not defined.

#### Step 3: Implement `logRejectedBatch`

Add to `event_store.dart`:

```dart
/// Caller-composed rejection audit. See design spec §2.7.
// Implements: REQ-d00145-H+I+J.
Future<void> logRejectedBatch(
  Uint8List bytes, {
  required String wireFormat,
  required String reason,
  String? failedEventId,
  String? errorDetail,
}) async {
  await backend.transaction((txn) async {
    final now = _now();
    final wireBytesHash = sha256.convert(bytes).toString();
    final (currentSeq, currentTailHash) = await backend.readIngestTailInTxn(txn);
    final nextSeq = await backend.nextIngestSequenceNumber(txn);
    final provenance0 = ProvenanceEntry(
      hop: source.hopId,
      receivedAt: now,
      identifier: source.identifier,
      softwareVersion: source.softwareVersion,
      arrivalHash: null,
      previousIngestHash: currentSeq == 0 ? null : currentTailHash,
      ingestSequenceNumber: nextSeq,
      batchContext: null,
    );

    final auditAggregateId = 'ingest-audit:${source.hopId}';
    final localSeq = await backend.nextSequenceNumber(txn);
    final eventId = _uuid.v4();
    final recordMap = <String, Object?>{
      'event_id': eventId,
      'aggregate_id': auditAggregateId,
      'aggregate_type': 'ingest-audit',
      'entry_type': 'ingest-audit',
      'event_type': 'ingest.batch_rejected',
      'sequence_number': localSeq,
      'data': <String, Object?>{
        'wire_bytes': base64Encode(bytes),
        'wire_format': wireFormat,
        'byte_length': bytes.length,
        'wire_bytes_hash': wireBytesHash,
        'reason': reason,
        'failed_event_id': failedEventId,
        'error_detail': errorDetail,
      },
      'metadata': <String, Object?>{
        'provenance': <Map<String, Object?>>[provenance0.toJson()],
      },
      'initiator': const {'kind': 'system'},
      'flow_token': null,
      'client_timestamp': now.toIso8601String(),
      'previous_event_hash': await backend.readLatestEventHash(txn),
    };
    final eventHash = _eventHash(recordMap);
    recordMap['event_hash'] = eventHash;
    final event = StoredEvent.fromMap(recordMap, 0);
    await backend.appendIngestedEvent(txn, event);
  });
}
```

Add `dart:convert` import if not present (for `base64Encode`).

#### Step 4: Run — expect pass

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/log_rejected_batch_test.dart test/ingest/caller_composition_test.dart
```

Expected: all tests pass.

#### Step 5: Run full suite + analyze

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze
```

Expected: all tests pass; analyze clean.

#### Step 6: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 9: EventStore.logRejectedBatch (REQ-d00145-H)"
```

---

### Task 10: Verification APIs — `verifyEventChain` + `verifyIngestChain` (TDD)

**TASK_FILE**: `PHASE4.9_TASK_10.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (add `verifyEventChain`, `verifyIngestChain`).
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/verify_event_chain_test.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/verify_ingest_chain_test.dart`

**Implements**: REQ-d00146-A+B+C+D+E.

#### Step 1: Write `verifyEventChain` tests

Create `apps/common-dart/event_sourcing_datastore/test/ingest/verify_event_chain_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.verifyEventChain (REQ-d00146-A+B)', () {
    test('returns ok=true for a well-formed ingested event', () async {
      // 1. originator.append e1.
      // 2. destination.ingestEvent(e1).
      // 3. Read stored copy.
      // 4. destination.verifyEventChain(stored) → ok=true, failures=[].
    });

    test('returns ok=false with one ChainFailure when arrival_hash is tampered', () async {
      // 1. Setup as above.
      // 2. Take the stored event; mutate provenance[1].arrival_hash to a
      //    wrong value (construct a new StoredEvent manually).
      // 3. verifyEventChain returns ok=false, failures.length == 1,
      //    failures[0].position == 1,
      //    failures[0].kind == ChainFailureKind.arrivalHashMismatch,
      //    failures[0].expectedHash == tampered value,
      //    failures[0].actualHash == recomputed hash.
    });

    test('does not throw on a corrupted chain', () async {
      // Same tampered event; verifyEventChain returns; does not throw.
    });

    test('returns ok=true on an origin-only event (length-1 provenance)', () async {
      // originator.append → read → verifyEventChain returns ok=true.
    });
  });
}
```

#### Step 2: Implement `verifyEventChain`

Add to `event_store.dart`:

```dart
/// Walk Chain 1 on [event].metadata.provenance backward from tail to origin.
/// Non-throwing. See design spec §2.11.
// Implements: REQ-d00146-A+B+D+E.
Future<ChainVerdict> verifyEventChain(StoredEvent event) async {
  return _verifyChainOn(event);
}
```

`_verifyChainOn` was already added in Task 7. This public method is a thin wrapper.

#### Step 3: Run

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/verify_event_chain_test.dart
```

Expected: all tests pass.

#### Step 4: Write `verifyIngestChain` tests

Create `apps/common-dart/event_sourcing_datastore/test/ingest/verify_ingest_chain_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('EventStore.verifyIngestChain (REQ-d00146-C)', () {
    test('returns ok=true over a clean sequence of ingests', () async {
      // destination.ingestEvent(e1), ingestEvent(e2), ingestEvent(e3).
      // verifyIngestChain() → ok=true, failures=[].
    });

    test('returns ok=false when one previous_ingest_hash is tampered', () async {
      // Ingest e1, e2, e3. Manually tamper e2's provenance[last]
      //   .previous_ingest_hash to a wrong value (requires direct sembast
      //   manipulation since public API is immutable).
      // verifyIngestChain returns ok=false, failures.length==1,
      //   position == e2's ingest_sequence_number (2),
      //   kind == ChainFailureKind.previousIngestHashMismatch.
    });

    test('respects fromIngestSeq / toIngestSeq bounds', () async {
      // Ingest e1..e10.
      // verifyIngestChain(fromIngestSeq: 3, toIngestSeq: 5) only walks 3..5.
      // Break #7, verify returns ok=true when range excludes 7.
    });

    test('throws ArgumentError when fromIngestSeq > toIngestSeq', () async {
      // verifyIngestChain(fromIngestSeq: 5, toIngestSeq: 3) throws.
    });
  });
}
```

#### Step 5: Implement `verifyIngestChain`

Add to `event_store.dart`:

```dart
/// Walk Chain 2 on this destination's event log. Non-throwing. See design
/// spec §2.11.
// Implements: REQ-d00146-C+D+E.
Future<ChainVerdict> verifyIngestChain({
  int fromIngestSeq = 0,
  int? toIngestSeq,
}) async {
  final (tailSeq, _) = await backend.readIngestTail();
  final upperBound = toIngestSeq ?? tailSeq;
  if (fromIngestSeq > upperBound) {
    throw ArgumentError(
      'fromIngestSeq ($fromIngestSeq) must be <= toIngestSeq ($upperBound)',
    );
  }
  final failures = <ChainFailure>[];
  StoredEvent? prev;
  // Iterate events by ingest_sequence_number ascending. Backend needs a
  // helper to enumerate events by key range. Implementer uses sembast's
  // finder directly (see the existing findAllEvents pattern) or adds a
  // new backend method `findEventsByIngestSeqRange`. For Phase 4.9 the
  // simplest approach is to iterate key-ascending over _eventsStore.
  final events = await backend.findEventsByIngestSeqRange(
    from: fromIngestSeq,
    to: upperBound,
  );
  for (final event in events) {
    final thisSeq = _ingestSeqOf(event);
    if (thisSeq <= fromIngestSeq) {
      prev = event;
      continue;
    }
    final provenance = (event.metadata['provenance'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final lastEntry = provenance.last;
    final previousIngestHash = lastEntry['previous_ingest_hash'] as String?;
    final expected = prev?.eventHash;
    if (previousIngestHash != expected) {
      failures.add(ChainFailure(
        position: thisSeq,
        kind: ChainFailureKind.previousIngestHashMismatch,
        expectedHash: expected ?? '(null)',
        actualHash: previousIngestHash ?? '(null)',
      ));
    }
    prev = event;
  }
  return ChainVerdict(ok: failures.isEmpty, failures: failures);
}

int _ingestSeqOf(StoredEvent event) {
  final provenance = (event.metadata['provenance'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final lastEntry = provenance.last;
  return lastEntry['ingest_sequence_number'] as int;
}
```

Add the new backend method `findEventsByIngestSeqRange` to `StorageBackend` (abstract) and `SembastBackend` (impl). Simple sembast finder over the events store by key range (keys ARE ingest_sequence_numbers on a destination). If the add feels out of scope here, narrow the verify method to take advantage of `findAllEvents` which already exists.

#### Step 6: Run + analyze

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze
```

Expected: all tests pass; analyze clean.

#### Step 7: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 10: verifyEventChain + verifyIngestChain (REQ-d00146)"
```

---

### Task 11: Multi-originator integration test

**TASK_FILE**: `PHASE4.9_TASK_11.md`

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/test/ingest/multi_originator_test.dart`

**Implements**: validation of REQ-d00115-H, -I (Chain 2 spans originators); REQ-d00120-E (hash recompute per hop).

No new code — pure integration test exercising previously-implemented methods.

#### Step 1: Write the multi-originator integration test

Create `apps/common-dart/event_sourcing_datastore/test/ingest/multi_originator_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

void main() {
  group('Multi-originator ingest (design §8; Requirement 2)', () {
    test('events from two different originators thread Chain 2 cleanly', () async {
      // Setup:
      //  - originatorA: EventStore with source.hopId='mobile-device-A',
      //    identifier='device-AAA'.
      //  - originatorB: EventStore with source.hopId='mobile-device-B',
      //    identifier='device-BBB'.
      //  - destination: EventStore with source.hopId='portal-server',
      //    identifier='portal-1'.
      //
      // Actions:
      //  1. A produces eA1, eA2 under aggregate aggA.
      //  2. B produces eB1, eB2 under aggregate aggB.
      //  3. destination.ingestEvent(eA1).
      //  4. destination.ingestEvent(eB1).
      //  5. destination.ingestEvent(eA2).
      //  6. destination.ingestEvent(eB2).
      //
      // Assertions:
      //  a. Destination's Chain 2 (ingest order) visits events with
      //     ingest_sequence_number 1,2,3,4 in that order.
      //  b. Each event's provenance.last.previous_ingest_hash matches the
      //     prior event's stored event_hash, regardless of originator.
      //  c. verifyIngestChain() returns ok=true.
      //  d. Per-aggregate fold: all aggA events have monotone
      //     sequence_number (originator A's) and fold cleanly; same for
      //     aggB.
      //  e. verifyEventChain passes for every stored event.
    });

    test('ingestBatch from originator A + ingestBatch from originator B threads cleanly', () async {
      // 1. A builds batch [eA1, eA2], encode, destination.ingestBatch.
      // 2. B builds batch [eB1, eB2], encode, destination.ingestBatch.
      // 3. Chain 2 threads 5 events in order:
      //    seq1: ingest-audit duplicate_received? (no, none are dupes yet)
      //    Actually wait — in the alt design there are no batch-received
      //    events on happy path. So Chain 2 has exactly 4 events: eA1,
      //    eA2, eB1, eB2. Assert seq numbers 1..4.
    });
  });
}
```

#### Step 2: Run

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/multi_originator_test.dart
```

Expected: all tests pass.

#### Step 3: Run full suite + analyze

```bash
cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze
```

Expected: all tests pass; analyze clean.

#### Step 4: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.9 Task 11: multi-originator integration test"
```

---

### Task 12: Final verification + worklog close

**TASK_FILE**: `PHASE4.9_TASK_12.md`

**No file changes** — verification only, plus worklog update.

- [ ] **Full test suites**:

```bash
(cd apps/common-dart/provenance && flutter test && flutter analyze)
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
(cd apps/common-dart/event_sourcing_datastore/example && flutter pub get && flutter analyze)
```

Expected: all green on all three commands.

- [ ] **Grep for sanity — all key terms are wired in only the expected places**:

```bash
grep -rn "arrival_hash\|arrivalHash" \
  apps/common-dart/provenance/lib \
  apps/common-dart/event_sourcing_datastore/lib
```

Expected: matches in `provenance_entry.dart` (field definition, JSON round-trip), `event_store.dart` (stamping in `_ingestOneInTxn`, verification in `_verifyChainOn`), and no other files.

```bash
grep -rn "previous_ingest_hash\|previousIngestHash" \
  apps/common-dart/provenance/lib \
  apps/common-dart/event_sourcing_datastore/lib
```

Expected: matches in `provenance_entry.dart`, `event_store.dart` (stamping in `_ingestOneInTxn`, `_emitDuplicateReceivedInTxn`, `logRejectedBatch`, verification in `verifyIngestChain`), and no other files.

```bash
grep -rn "ingest_sequence_number\|ingestSequenceNumber" \
  apps/common-dart/provenance/lib \
  apps/common-dart/event_sourcing_datastore/lib
```

Expected: matches in `provenance_entry.dart`, `storage_backend.dart` (abstract methods), `sembast_backend.dart` (impl), `event_store.dart` (stamping).

```bash
grep -rn "batch_context\|batchContext\|BatchContext" \
  apps/common-dart/provenance/lib \
  apps/common-dart/event_sourcing_datastore/lib
```

Expected: matches in `batch_context.dart` (definition), `provenance_entry.dart` (field), `event_store.dart` (stamping in `_ingestOneInTxn`, never in `ingestEvent`'s direct call path except as null).

```bash
grep -rn "ingest.batch_rejected" \
  apps/common-dart/event_sourcing_datastore/lib
```

Expected: matches ONLY in `logRejectedBatch` — the library does not emit this event internally anywhere else.

```bash
grep -rn "ingest.duplicate_received" \
  apps/common-dart/event_sourcing_datastore/lib
```

Expected: matches ONLY in `_emitDuplicateReceivedInTxn` — emitted once per dup in ingest paths.

- [ ] **REQ spec sanity**:

```bash
grep -n "REQ-d00145\|REQ-d00146" spec/INDEX.md
```

Expected: both REQs present with regenerated hashes.

- [ ] **Update `PHASE_4.9_WORKLOG.md`** at repo root with the completion checklist and commit SHAs. Format mirrors Phase 4.8's worklog close.

- [ ] **Commit**:

```bash
git add PHASE_4.9_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.9 Task 12: final verification + worklog close"
```

Phase 4.9 complete. Running order from here: Phase 4.10 (wedge-aware fillBatch skip) picks up on HEAD. No phase-boundary squash required (user is squash-merging on PR).

---

## Self-review of this plan

**Spec coverage** (checked against `docs/superpowers/specs/2026-04-24-phase4.9-sync-through-ingest-design.md`):

- §2.1 Two hash chains → Task 2 (spec) + Tasks 7–10 (implementation + tests).
- §2.2 ProvenanceEntry schema additions → Tasks 2, 3.
- §2.3 Canonical batch format + BatchContext → Tasks 3 (BatchContext), 4 (envelope), 8 (stamping).
- §2.4 Hash recompute on ingest → Task 2 (spec), Task 7 (`_appendReceiverProvenance`), Task 7 happy-path test.
- §2.5 `ingestBatch` → Task 8.
- §2.6 `ingestEvent` → Task 7.
- §2.7 `logRejectedBatch` → Task 9.
- §2.8 Idempotency → Task 7 duplicate + identity-mismatch tests.
- §2.9 Receiver-originated system events → Task 7 (duplicate), Task 9 (batch_rejected).
- §2.10 Failure model (approach A) → Task 8 rollback test + Task 9 caller-composition test.
- §2.11 Verification APIs → Task 10.
- §2.12 Storage-key implication → Task 6 (appendIngestedEvent keys by ingest_sequence_number).
- §2.13 `previous_event_hash` semantics → Task 2 (REQ-d00120-E rationale).
- §3 Caller API summary → Tasks 7, 8, 9, 10.
- §4 REQ impact → Task 2.
- §5 Code delta → Tasks 3–10.
- §6 Tests → Task-by-task test files.
- §7 Risks → mitigations embedded (Risk 1 chain walk complexity: a deep-chain test could be added in Task 10 if desired; Risk 2 storage-key migration: Task 6 uses a dedicated method `appendIngestedEvent` distinct from `appendEvent`, no shared path; Risk 3 `previous_event_hash` semantic cliff: Task 2 spec rationale + comments in code; Risk 4 caller forgets `logRejectedBatch`: Task 9 caller-composition test exemplifies the pattern; Risk 5 duplicate-received spam: noted out-of-scope; Risk 6 `ingestEvent` bypasses batch auditing: Task 7 doc comment on `ingestEvent`; Risk 7 reconstruction depends on canonicalization: Task 8 reconstruction test).
- §8 Out of scope → enforced by plan scope (no tasks touch origin `append`, materializer, consumer apps).
- §9 Validation checklist → Task 12.

All design requirements have a task.

**Placeholder scan**: the test-file skeletons in Tasks 6–11 contain numbered-comment placeholders (`// 1. ...`, `// 2. ...`) describing the concrete setup an implementer executes using the existing `test/test_support/` helpers. These are NOT spec placeholders — they're acknowledgment that the exact helper-function names in test_support are not visible from this plan without the implementer reading the source. The implementer fills in by grepping `test_support/` and following the patterns in `end_to_end_test.dart`, `entry_service_test.dart`, and `sembast_backend_fifo_test.dart`. No "TBD" / "fill in later" / "handle edge cases" in the production code blocks.

**Type consistency**:
- `BatchContext { batchId, batchPosition, batchSize, batchWireBytesHash, batchWireFormat }` — consistent across Tasks 3, 8, and tests.
- `ProvenanceEntry` new fields: `arrivalHash`, `previousIngestHash`, `ingestSequenceNumber`, `batchContext` — consistent across Tasks 3, 6, 7, 8, 9, 10.
- `IngestBatchResult { batchId, events: List<PerEventIngestOutcome> }` — consistent Tasks 5, 8.
- `PerEventIngestOutcome { eventId, outcome: IngestOutcome, resultHash }` — consistent Tasks 5, 7, 8.
- `ChainVerdict { ok, failures: List<ChainFailure> }` — consistent Tasks 5, 10.
- `IngestChainBroken { eventId, hopIndex, expectedHash, actualHash }` — consistent Tasks 5, 7.
- `IngestIdentityMismatch { eventId, incomingHash, storedArrivalHash }` — consistent Tasks 5, 7.
- `IngestDecodeFailure { message }` — consistent Tasks 4, 5.

**Method signatures**:
- `ingestBatch(bytes, {required wireFormat}) → Future<IngestBatchResult>` — Tasks 8, 9 (composition example), 11.
- `ingestEvent(StoredEvent) → Future<PerEventIngestOutcome>` — Tasks 7, 11.
- `logRejectedBatch(bytes, {wireFormat, reason, failedEventId?, errorDetail?}) → Future<void>` — Tasks 9, 11.
- `verifyEventChain(StoredEvent) → Future<ChainVerdict>` — Task 10.
- `verifyIngestChain({fromIngestSeq, toIngestSeq?}) → Future<ChainVerdict>` — Task 10, 11.

No signature drift across tasks.

**Backend method additions**: `nextIngestSequenceNumber(Txn)`, `readIngestTail()`, `readIngestTailInTxn(Txn)`, `appendIngestedEvent(Txn, StoredEvent)`, `findEventByIdInTxn(Txn, String)`, `findEventsByIngestSeqRange({from, to})` — all introduced in Task 6 or Task 10, used consistently thereafter.

No contradictions surfaced during self-review.
