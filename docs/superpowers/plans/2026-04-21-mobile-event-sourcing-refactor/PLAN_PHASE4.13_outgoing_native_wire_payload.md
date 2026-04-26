# Master Plan Phase 4.13: Outgoing Native wire_payload Optimization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate redundant `wire_payload` storage on FIFO rows whose wire format is the library's native `esd/batch@1`. New rows store `BatchEnvelopeMetadata` instead; drain reconstructs bytes via `findEventById` + `BatchEnvelope.encode`. 3rd-party destinations untouched.

**Architecture:** Storage-side optimization that's transparent to the `Destination` API. `enqueueFifoTxn` detects `wirePayload.contentType == 'esd/batch@1'`, parses via `BatchEnvelope.decode`, persists envelope metadata + drops bytes. `drain` branches: native rows re-encode on demand; non-native rows use stored `wire_payload` verbatim. Retry-deterministic via JCS canonicalization. Extends REQ-d00119 with one new assertion (REQ-d00119-K) and rewrites REQ-d00119-B in place.

**Tech Stack:** Dart, sembast, `package:flutter_test`, `BatchEnvelope` (Phase 4.9), `findEventById` (Phase 4.11), `StoredEvent.toMap`, `package:canonical_json_jcs`.

**Design spec:** `docs/superpowers/specs/2026-04-25-phase4.13-outgoing-native-wire-payload-design.md`.

**Decisions log:** `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (Phase 4.13 section §4.13.A–F pinned).

**Branch:** `mobile-event-sourcing-refactor`. **Ticket:** CUR-1154 (continuation). **Phase:** 4.13 (final phase of this run, before mobile cutover CUR-1169). **Depends on:** Phase 4.12 complete on HEAD.

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00119-B (REWRITTEN) | FIFO entry field list now includes `envelope_metadata`; `wire_payload` is conditionally null based on `wire_format`. | Task 2 (spec); Tasks 5–7 (impl + tests) |
| REQ-d00119-K (NEW) | `envelope_metadata` is a `BatchEnvelopeMetadata` value, non-null iff `wire_format == "esd/batch@1"`, set at enqueue, immutable, drives drain re-encode determinism. | Task 2 (spec); Tasks 4–7 (TDD) |

No new REQ-d number claimed; extends REQ-d00119 in place. Pre-Phase-4.13 ceiling: REQ-d00150 (Phase 4.12). Future phases free to claim REQ-d00151+.

---

## Execution rules

Read `README.md` in the plans directory for TDD cadence and REQ-citation conventions. Each task = one commit on the branch.

Read the design spec end-to-end before Task 1. Re-read §2.1 + §2.5 before Task 6 (drain branch). Re-read §2.6 before Task 2.

**Project conventions:**

- Explicit `git add <files>`. NEVER `git add -A` or `git add <directory>`. User has parallel WIP under `apps/common-dart/event_sourcing_datastore/example/`.
- Pre-commit hook regenerates `spec/INDEX.md` REQ hashes — let it run. REQ-d00119's `*End*` line already has a hash; the hook will update it in place when assertion B is rewritten and K is added (NO new REQ section is being created, so the XP.3 placeholder rule does not apply).
- Test framework `package:flutter_test/flutter_test.dart`.
- Project lints: `prefer_constructors_over_static_methods`. Value types use factory constructors not statics.
- Per-function `// Implements: REQ-xxx-Y — <prose>` markers; per-test `// Verifies: REQ-xxx-Y` + assertion ID at start of `test(...)` description.
- Greenfield mode (decisions log §XP.1): final-state voice; no "previously / no longer / removed" wording.
- TDD-vs-analyze tension: tests reference symbols that don't yet exist. Use `// ignore: undefined_method` / `// ignore: undefined_class` etc. as in Phase 4.12. Implementation task removes the ignores.

**Phase invariants** (must be true at end of phase):

1. `flutter test` clean in `apps/common-dart/event_sourcing_datastore`. Pass count: ≥ 582 + N (N ≥ 5 new tests).
2. `flutter analyze` clean in `apps/common-dart/event_sourcing_datastore` AND `apps/common-dart/event_sourcing_datastore/example`.
3. `flutter test` clean in `apps/common-dart/provenance` (38 unchanged).
4. Round-trip determinism test: same native FIFO row drained twice produces byte-identical wire bytes.
5. `grep -rn "REQ-d00132" apps/common-dart/event_sourcing_datastore/` — no NEW references introduced (pre-existing orphans untouched per §4.10.4).

---

## Plan

### Task 1: Baseline + worklog

**Files:** Create `PHASE_4.13_WORKLOG.md`.

- [ ] **Step 1: Confirm Phase 4.12 is committed on HEAD**

```bash
git log --oneline -3
```

Expected: top includes `[CUR-1154] Phase 4.13 design spec` plus the Phase 4.12 closing commit `09e8c134`.

- [ ] **Step 2: Run baseline checks**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: event_sourcing_datastore +582, provenance +38, all analyze clean.

- [ ] **Step 3: Confirm Phase 4.9 + 4.11 prerequisites exist**

```bash
grep -n "class BatchEnvelope" apps/common-dart/event_sourcing_datastore/lib/src/ingest/batch_envelope.dart
grep -n "findEventById" apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart | head -3
grep -n "Map<String, dynamic> toMap" apps/common-dart/event_sourcing_datastore/lib/src/storage/stored_event.dart
```

Expected: all three return hits. `BatchEnvelope` exists (Phase 4.9); `findEventById` exists (Phase 4.11); `StoredEvent.toMap` exists.

- [ ] **Step 4: Write `PHASE_4.13_WORKLOG.md`**

```markdown
# Phase 4.13 Worklog — Outgoing Native wire_payload Optimization (CUR-1154)

**Spec:** docs/superpowers/specs/2026-04-25-phase4.13-outgoing-native-wire-payload-design.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.13 section)
**Branch:** mobile-event-sourcing-refactor

## Baseline (Task 1)

- event_sourcing_datastore: <FILL IN>
- provenance: <FILL IN>
- analyze (lib + example + provenance): clean
- Phase 4.9 BatchEnvelope: present
- Phase 4.11 findEventById: present
- StoredEvent.toMap: present

## Tasks

- [ ] Task 1: Baseline + worklog
- [ ] Task 2: Spec — REQ-d00119-B rewrite + REQ-d00119-K addition
- [ ] Task 3: BatchEnvelopeMetadata value type + tests
- [ ] Task 4: FifoEntry — add envelope_metadata field, make wirePayload nullable, update serialization
- [ ] Task 5: enqueueFifoTxn — detect native, parse, strip bytes, persist envelope
- [ ] Task 6: Drain branch — re-encode native rows on demand
- [ ] Task 7: Round-trip determinism + integration tests
- [ ] Task 8: Final verification + close worklog
```

- [ ] **Step 5: Commit**

```bash
git add PHASE_4.13_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.13 Task 1: baseline + worklog"
```

---

### Task 2: Spec — REQ-d00119-B rewrite + REQ-d00119-K addition

**Files:** Modify `spec/dev-event-sourcing-mobile.md`.

- [ ] **Step 1: Locate REQ-d00119**

```bash
grep -n "^# REQ-d00119\|^B\.\|^J\.\|^K\.\|^\*End\* \*Per-Destination FIFO" spec/dev-event-sourcing-mobile.md | head -20
```

Find:
- The header line `# REQ-d00119: Per-Destination FIFO Queue Semantics`
- The current B assertion (`B. A FIFO entry SHALL carry the fields ...`)
- The current highest-letter assertion (J, or whatever it is)
- The `*End* *Per-Destination FIFO Queue Semantics* | **Hash**: <hash>` line

- [ ] **Step 2: Replace assertion B**

Find the existing B (currently line ~155 per pre-Phase-4.13 baseline):

```markdown
B. A FIFO entry SHALL carry the fields `entry_id`, `event_ids`, `event_id_range`, `sequence_in_queue`, `wire_payload`, `wire_format`, `transform_version`, `enqueued_at`, `attempts[]`, `final_status`, and `sent_at`. The `event_ids` and `event_id_range` fields hold the batch contract defined in REQ-d00128; a single-event batch is a batch of length one.
```

Replace verbatim with:

```markdown
B. A FIFO entry SHALL carry the fields `entry_id`, `event_ids`, `event_id_range`, `sequence_in_queue`, `wire_payload`, `wire_format`, `transform_version`, `enqueued_at`, `attempts[]`, `final_status`, `sent_at`, and `envelope_metadata`. The `event_ids` and `event_id_range` fields hold the batch contract defined in REQ-d00128; a single-event batch is a batch of length one. `wire_payload` SHALL be non-null when `wire_format != "esd/batch@1"` (3rd-party destinations whose serialization is not round-trippable); `wire_payload` SHALL be null when `wire_format == "esd/batch@1"` (native destinations whose payload is reconstructible from `event_ids` and `envelope_metadata`).
```

- [ ] **Step 3: Append assertion K AFTER the highest existing letter assertion**

Find the last assertion before the `*End*` line (likely `J.` or whatever the spec currently has). Insert this AFTER it, BEFORE the `*End*` line:

```markdown
K. `envelope_metadata` SHALL be a `BatchEnvelopeMetadata` value carrying `batch_format_version`, `batch_id`, `sender_hop`, `sender_identifier`, `sender_software_version`, `sent_at`. It SHALL be non-null when `wire_format == "esd/batch@1"` and null otherwise. The values SHALL be set at enqueue time and SHALL NOT be mutated thereafter — they are part of the FIFO row's identity for retry determinism. Drain reconstructs the wire bytes by combining `envelope_metadata` with `event_ids`-resolved events through `BatchEnvelope.encode`; the encoding is deterministic across retries (RFC 8785 JCS).
```

(One blank line between the prior assertion and K. One blank line between K and `*End*`.)

- [ ] **Step 4: Run analyze (sanity)**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean. Spec edits don't affect Dart.

- [ ] **Step 5: Commit**

```bash
git add spec/dev-event-sourcing-mobile.md
git commit -m "[CUR-1154] Phase 4.13 Task 2: spec REQ-d00119-B rewrite + REQ-d00119-K (envelope_metadata)"
```

The pre-commit hook updates REQ-d00119's hash and regenerates `spec/INDEX.md` in the same commit.

---

### Task 3: BatchEnvelopeMetadata value type + tests

**Files:**

- Create: `apps/common-dart/event_sourcing_datastore/lib/src/destinations/batch_envelope_metadata.dart`
- Create: `apps/common-dart/event_sourcing_datastore/test/destinations/batch_envelope_metadata_test.dart`

- [ ] **Step 1: Create the value type**

```dart
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';

/// Metadata extracted from a `BatchEnvelope` minus its events list.
/// Persisted on a FIFO row when the row's `wire_format == "esd/batch@1"`,
/// so that drain can reconstruct the wire bytes deterministically by
/// re-encoding `(envelope_metadata + events resolved via findEventById)`.
///
/// The fields are immutable once set — they are part of the FIFO row's
/// identity for retry determinism (REQ-d00119-K).
// Implements: REQ-d00119-K — envelope-metadata value type for native
// FIFO rows; supports retry-deterministic re-encoding at drain time.
class BatchEnvelopeMetadata {
  const BatchEnvelopeMetadata({
    required this.batchFormatVersion,
    required this.batchId,
    required this.senderHop,
    required this.senderIdentifier,
    required this.senderSoftwareVersion,
    required this.sentAt,
  });

  /// Build from a parsed [BatchEnvelope]. Drops the `events` list — the
  /// drain path resolves events via `findEventById` and reattaches them
  /// at encode time.
  factory BatchEnvelopeMetadata.fromEnvelope(BatchEnvelope env) {
    return BatchEnvelopeMetadata(
      batchFormatVersion: env.batchFormatVersion,
      batchId: env.batchId,
      senderHop: env.senderHop,
      senderIdentifier: env.senderIdentifier,
      senderSoftwareVersion: env.senderSoftwareVersion,
      sentAt: env.sentAt,
    );
  }

  factory BatchEnvelopeMetadata.fromMap(Map<String, Object?> m) {
    return BatchEnvelopeMetadata(
      batchFormatVersion: m['batch_format_version']! as String,
      batchId: m['batch_id']! as String,
      senderHop: m['sender_hop']! as String,
      senderIdentifier: m['sender_identifier']! as String,
      senderSoftwareVersion: m['sender_software_version']! as String,
      sentAt: DateTime.parse(m['sent_at']! as String),
    );
  }

  final String batchFormatVersion;
  final String batchId;
  final String senderHop;
  final String senderIdentifier;
  final String senderSoftwareVersion;
  final DateTime sentAt;

  /// Reconstruct a full [BatchEnvelope] by attaching events. Used by the
  /// drain path: after `findEventById` resolves each event in `event_ids`,
  /// the events are passed here to rebuild the envelope and `.encode()`
  /// is called to produce wire bytes.
  BatchEnvelope toEnvelope(List<Map<String, Object?>> events) {
    return BatchEnvelope(
      batchFormatVersion: batchFormatVersion,
      batchId: batchId,
      senderHop: senderHop,
      senderIdentifier: senderIdentifier,
      senderSoftwareVersion: senderSoftwareVersion,
      sentAt: sentAt,
      events: events,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'batch_format_version': batchFormatVersion,
        'batch_id': batchId,
        'sender_hop': senderHop,
        'sender_identifier': senderIdentifier,
        'sender_software_version': senderSoftwareVersion,
        'sent_at': sentAt.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchEnvelopeMetadata &&
          batchFormatVersion == other.batchFormatVersion &&
          batchId == other.batchId &&
          senderHop == other.senderHop &&
          senderIdentifier == other.senderIdentifier &&
          senderSoftwareVersion == other.senderSoftwareVersion &&
          sentAt == other.sentAt;

  @override
  int get hashCode => Object.hash(
        batchFormatVersion,
        batchId,
        senderHop,
        senderIdentifier,
        senderSoftwareVersion,
        sentAt,
      );

  @override
  String toString() => 'BatchEnvelopeMetadata(batchId: $batchId, '
      'senderHop: $senderHop, sentAt: $sentAt)';
}
```

- [ ] **Step 2: Write the tests**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BatchEnvelopeMetadata', () {
    final fixture = BatchEnvelopeMetadata(
      batchFormatVersion: '1',
      batchId: 'b-001',
      senderHop: 'mobile-1',
      senderIdentifier: 'device-uuid',
      senderSoftwareVersion: 'diary@1.2.3',
      sentAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
    );

    // Verifies: REQ-d00119-K — round-trip toMap / fromMap preserves all
    // six fields exactly.
    test('REQ-d00119-K: round-trip via toMap / fromMap is value-equal', () {
      final map = fixture.toMap();
      final restored = BatchEnvelopeMetadata.fromMap(map);
      expect(restored, fixture);
    });

    // Verifies: REQ-d00119-K — fromEnvelope drops the events list.
    test('REQ-d00119-K: fromEnvelope copies metadata, drops events', () {
      final env = BatchEnvelope(
        batchFormatVersion: '1',
        batchId: 'b-001',
        senderHop: 'mobile-1',
        senderIdentifier: 'device-uuid',
        senderSoftwareVersion: 'diary@1.2.3',
        sentAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
        events: <Map<String, Object?>>[
          <String, Object?>{'event_id': 'e1'},
          <String, Object?>{'event_id': 'e2'},
        ],
      );
      final meta = BatchEnvelopeMetadata.fromEnvelope(env);
      expect(meta, fixture);
    });

    // Verifies: REQ-d00119-K — toEnvelope reattaches events for re-encode.
    test('REQ-d00119-K: toEnvelope reattaches events; encode is byte-equal '
        'across two calls (RFC 8785 JCS determinism)', () {
      final events = <Map<String, Object?>>[
        <String, Object?>{
          'event_id': 'e1',
          'sequence_number': 1,
        },
        <String, Object?>{
          'event_id': 'e2',
          'sequence_number': 2,
        },
      ];
      final bytes1 = fixture.toEnvelope(events).encode();
      final bytes2 = fixture.toEnvelope(events).encode();
      expect(bytes1, bytes2);
      // Sanity: parseable as JSON.
      final decoded = jsonDecode(utf8.decode(bytes1)) as Map<String, Object?>;
      expect(decoded['batch_id'], 'b-001');
      expect((decoded['events']! as List).length, 2);
    });

    // Verifies: REQ-d00119-K — equality + hashCode consistent across
    // identical metadata.
    test('REQ-d00119-K: equality and hashCode are value-based', () {
      final a = BatchEnvelopeMetadata.fromMap(fixture.toMap());
      final b = BatchEnvelopeMetadata.fromMap(fixture.toMap());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 3: Run tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/destinations/batch_envelope_metadata_test.dart 2>&1 | tail -10)
```

Expected: `+4: All tests passed!`. The value type is self-contained — no `// ignore: undefined_method` shenanigans needed.

- [ ] **Step 4: Run full suite + analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `+586` (582 + 4) and clean.

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/destinations/batch_envelope_metadata.dart \
        apps/common-dart/event_sourcing_datastore/test/destinations/batch_envelope_metadata_test.dart
git commit -m "[CUR-1154] Phase 4.13 Task 3: BatchEnvelopeMetadata value type"
```

---

### Task 4: FifoEntry schema additions

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/fifo_entry.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/test/storage/fifo_entry_test.dart`

- [ ] **Step 1: Read current FifoEntry shape**

```bash
sed -n '1,120p' apps/common-dart/event_sourcing_datastore/lib/src/storage/fifo_entry.dart
```

Note the constructor, `fromJson`, `toJson`, and `wirePayload` field.

- [ ] **Step 2: Modify FifoEntry**

- Add field: `final BatchEnvelopeMetadata? envelopeMetadata;`
- Make `wirePayload` nullable: `final WirePayload? wirePayload;` (was non-nullable). Update constructor's `required` accordingly — change to optional with a default of `null`.
- Update `fromJson` to read the optional `envelope_metadata` map → `BatchEnvelopeMetadata.fromMap`. Make `wire_payload` reading null-tolerant.
- Update `toJson` to serialize `envelopeMetadata?.toMap()` (omit when null). Same for `wirePayload`.
- Update `==` and `hashCode` to include both fields.
- Update `toString` to mention envelopeMetadata when present.

Add the import:

```dart
import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
```

The exact code shape depends on the existing file structure (haven't read it). The implementer should read first, then mirror the existing pattern (e.g. use `?? <default>` patterns where the existing fromJson does so).

- [ ] **Step 3: Update existing FifoEntry tests**

Add cases to `fifo_entry_test.dart`:

```dart
// Verifies: REQ-d00119-K — FifoEntry round-trips envelopeMetadata when present.
test(
  'REQ-d00119-K: FifoEntry serializes envelopeMetadata when present',
  () {
    final meta = BatchEnvelopeMetadata(
      batchFormatVersion: '1',
      batchId: 'b-001',
      senderHop: 'mobile-1',
      senderIdentifier: 'device-uuid',
      senderSoftwareVersion: 'diary@1.2.3',
      sentAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
    );
    final entry = FifoEntry(
      entryId: 'fe-001',
      eventIds: const <String>['e1'],
      eventIdRange: (firstSeq: 1, lastSeq: 1),
      sequenceInQueue: 1,
      wireFormat: 'esd/batch@1',
      wirePayload: null,
      transformVersion: 'v1',
      enqueuedAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
      attempts: const <AttemptResult>[],
      finalStatus: null,
      sentAt: null,
      envelopeMetadata: meta,
    );
    final restored = FifoEntry.fromJson(entry.toJson(), entry.key);
    expect(restored.envelopeMetadata, meta);
    expect(restored.wirePayload, isNull);
  },
);

// Verifies: REQ-d00119-B — FifoEntry round-trips wirePayload when
// envelopeMetadata is null (3rd-party path).
test(
  'REQ-d00119-B: FifoEntry serializes wirePayload for non-native rows',
  () {
    final entry = FifoEntry(
      entryId: 'fe-002',
      eventIds: const <String>['e1'],
      eventIdRange: (firstSeq: 1, lastSeq: 1),
      sequenceInQueue: 1,
      wireFormat: 'application/csv',
      wirePayload: WirePayload(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        contentType: 'application/csv',
        transformVersion: 'csv-v1',
      ),
      transformVersion: 'csv-v1',
      enqueuedAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
      attempts: const <AttemptResult>[],
      finalStatus: null,
      sentAt: null,
      envelopeMetadata: null,
    );
    final restored = FifoEntry.fromJson(entry.toJson(), entry.key);
    expect(restored.envelopeMetadata, isNull);
    expect(restored.wirePayload, isNotNull);
    expect(restored.wirePayload!.bytes, [1, 2, 3, 4]);
  },
);
```

(Adjust constructor argument names + `key` parameter handling to match the actual existing FifoEntry shape.)

- [ ] **Step 4: Run tests; expect FAIL on any pre-existing test that constructs FifoEntry without the new optional field**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/fifo_entry_test.dart 2>&1 | tail -10)
```

If pre-existing tests pass (because the new field is optional default-null), proceed. If they fail because they relied on positional args or non-null wirePayload, adjust them to use the new optional shape.

- [ ] **Step 5: Run full suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+588` (586 + 2 new in Task 4). Other tests should pass — the new field is optional and wirePayload nullability change is non-breaking for tests that always supplied a non-null value.

If many tests fail because they construct FifoEntry assuming wirePayload is required, surface to orchestrator — may need a wider refactor than expected.

- [ ] **Step 6: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean. If lints flag the nullable `wirePayload` access in places that previously read it directly, fix with explicit null checks (`entry.wirePayload!` where the caller's context guarantees non-null) — these will be cleaned up properly in Tasks 5 and 6.

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/fifo_entry.dart \
        apps/common-dart/event_sourcing_datastore/test/storage/fifo_entry_test.dart
git commit -m "[CUR-1154] Phase 4.13 Task 4: FifoEntry adds envelopeMetadata; wirePayload nullable"
```

---

### Task 5: enqueueFifoTxn — detect native, parse, strip bytes, persist envelope

**Files:** Modify `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`.

- [ ] **Step 1: Read current `enqueueFifoTxn`**

```bash
grep -n "enqueueFifoTxn\|enqueueFifo " apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart | head -5
```

Read the implementation; identify where the row map is constructed and persisted.

- [ ] **Step 2: Add the detect-and-strip branch**

Inside `enqueueFifoTxn`, BEFORE building the row map:

```dart
  WirePayload? storedPayload = wirePayload;
  BatchEnvelopeMetadata? storedEnvelope;
  if (wirePayload.contentType == BatchEnvelope.wireFormat) {
    // Native esd/batch@1: parse to extract envelope, drop bytes from
    // storage. Drain reconstructs via findEventById + encode
    // (REQ-d00119-K).
    // Implements: REQ-d00119-B+K — native rows store envelope_metadata
    // and null wire_payload; bytes are reconstructed deterministically
    // at drain time via JCS canonicalization.
    final envelope = BatchEnvelope.decode(wirePayload.bytes);
    storedEnvelope = BatchEnvelopeMetadata.fromEnvelope(envelope);
    storedPayload = null;
  }
```

Then where the row map is built, replace `'wire_payload': wirePayload.toJson()` (or whatever the existing serialization is) with:

```dart
    'wire_payload': storedPayload?.toJson(),
    'envelope_metadata': storedEnvelope?.toMap(),
```

(Look at what the existing serialization shape is — the `WirePayload` may be inlined as a map of `bytes`/`contentType`/`transformVersion`. Mirror it.)

Add imports:

```dart
import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
```

- [ ] **Step 3: Add tests for the enqueue branching to sembast_backend_fifo_test.dart**

Append to the existing `group(...)` blocks (or add a new `group('enqueueFifoTxn — native vs 3rd-party')`):

```dart
// Verifies: REQ-d00119-B+K — native enqueue strips bytes and stores
// envelope_metadata.
test(
  'REQ-d00119-B+K: enqueueFifo with esd/batch@1 strips wire_payload, '
  'stores envelope_metadata',
  () async {
    // Build a real esd/batch@1 envelope via BatchEnvelope.encode.
    final event = await _appendEventForFifo(backend, eventId: 'e1');
    final envelope = BatchEnvelope(
      batchFormatVersion: '1',
      batchId: 'batch-x',
      senderHop: 'mobile-1',
      senderIdentifier: 'device-uuid',
      senderSoftwareVersion: 'diary@1.2.3',
      sentAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
      events: <Map<String, Object?>>[event.toMap()],
    );
    final wireBytes = envelope.encode();
    final payload = WirePayload(
      bytes: wireBytes,
      contentType: BatchEnvelope.wireFormat,
      transformVersion: 'native-v1',
    );
    await backend.enqueueFifo('dest', [event], payload);
    final head = await backend.readFifoHead('dest');
    expect(head, isNotNull);
    expect(head!.wirePayload, isNull,
        reason: 'native enqueue MUST strip wire_payload');
    expect(head.envelopeMetadata, isNotNull);
    expect(head.envelopeMetadata!.batchId, 'batch-x');
    expect(head.envelopeMetadata!.senderHop, 'mobile-1');
  },
);

// Verifies: REQ-d00119-B — non-native enqueue stores wire_payload as-is,
// envelope_metadata is null.
test(
  'REQ-d00119-B: enqueueFifo with non-native wire_format stores '
  'wire_payload, envelope_metadata is null',
  () async {
    final event = await _appendEventForFifo(backend, eventId: 'e1');
    final payload = WirePayload(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      contentType: 'application/csv',
      transformVersion: 'csv-v1',
    );
    await backend.enqueueFifo('dest', [event], payload);
    final head = await backend.readFifoHead('dest');
    expect(head, isNotNull);
    expect(head!.wirePayload, isNotNull);
    expect(head.wirePayload!.bytes, [1, 2, 3, 4]);
    expect(head.envelopeMetadata, isNull);
  },
);
```

Add necessary imports.

- [ ] **Step 4: Run new tests; expect PASS** (the enqueue branch is implemented in Step 2 already)

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_fifo_test.dart --plain-name 'REQ-d00119' 2>&1 | tail -10)
```

Expected: `+2: All tests passed!`.

- [ ] **Step 5: Run full suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+590` (588 + 2). However: drain tests that previously read `wirePayload` from a native-enqueued row may now FAIL because the stored row has `wirePayload: null`. Drain hasn't been updated yet — Task 6 fixes this. If pre-existing drain tests use native bytes (rare; most tests use `application/json`-style content), surface them now and consider whether to fix in Task 5 or defer to Task 6.

- [ ] **Step 6: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean (or null-safety lints in drain code that Task 6 will address).

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart \
        apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_fifo_test.dart
git commit -m "[CUR-1154] Phase 4.13 Task 5: enqueueFifoTxn detects native, strips bytes, stores envelope"
```

---

### Task 6: Drain branch — re-encode native rows on demand

**Files:** Modify `apps/common-dart/event_sourcing_datastore/lib/src/sync/drain.dart` (or wherever the head-read + send sequence lives).

- [ ] **Step 1: Locate the drain's `destination.send(...)` call**

```bash
grep -rn "destination.send\|\.send(.*[Pp]ayload" apps/common-dart/event_sourcing_datastore/lib/src/sync/
```

Find the line that does `destination.send(head.wirePayload)` (or similar).

- [ ] **Step 2: Insert the wire-bytes resolution branch BEFORE the send call**

```dart
  // Resolve wire bytes: native rows reconstruct from envelope_metadata
  // + event_ids (REQ-d00119-K); 3rd-party rows use stored wire_payload.
  // Implements: REQ-d00119-B+K — drain branches on envelope_metadata
  // presence; native re-encode is byte-deterministic across retries.
  final WirePayload payload;
  final envelope = head.envelopeMetadata;
  if (envelope != null) {
    final events = <Map<String, Object?>>[];
    for (final eventId in head.eventIds) {
      final ev = await backend.findEventById(eventId);
      if (ev == null) {
        throw StateError(
          'native FIFO row ${head.entryId} references missing event $eventId',
        );
      }
      events.add(ev.toMap());
    }
    final bytes = envelope.toEnvelope(events).encode();
    payload = WirePayload(
      bytes: bytes,
      contentType: BatchEnvelope.wireFormat,
      transformVersion: head.transformVersion,
    );
  } else {
    payload = head.wirePayload!;
  }
  final result = await destination.send(payload);
```

(Substitute `head` for the variable name actually used; substitute `backend` for the actual backend reference; etc.)

Add imports:

```dart
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
```

- [ ] **Step 3: Add drain-branch tests to drain_test.dart**

Append cases:

```dart
// Verifies: REQ-d00119-K — drain re-encodes native row from envelope +
// event_ids; bytes are byte-equal across two consecutive drain attempts
// (retry determinism).
test(
  'REQ-d00119-K: drain on native row re-encodes deterministically',
  () async {
    final event = await _appendEventForFifo(backend, eventId: 'e1');
    final envelope = BatchEnvelope(
      batchFormatVersion: '1',
      batchId: 'batch-x',
      senderHop: 'mobile-1',
      senderIdentifier: 'device-uuid',
      senderSoftwareVersion: 'diary@1.2.3',
      sentAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
      events: <Map<String, Object?>>[event.toMap()],
    );
    final wireBytes = envelope.encode();
    final payload = WirePayload(
      bytes: wireBytes,
      contentType: BatchEnvelope.wireFormat,
      transformVersion: 'native-v1',
    );
    await backend.enqueueFifo('dest', [event], payload);

    final dest = FakeDestination(
      id: 'dest',
      script: [const SendResult.transient('temp')],
    );
    // First drain attempt — destination receives reconstructed bytes.
    await drain(dest, backend: backend, policy: defaultPolicy);
    final firstBytes = dest.sent.last.bytes;
    // Reset script for second attempt.
    dest.queueScript([const SendResult.ok()]);
    await drain(dest, backend: backend, policy: defaultPolicy);
    final secondBytes = dest.sent.last.bytes;
    expect(secondBytes, firstBytes,
        reason: 'native re-encode MUST be byte-deterministic across retries');
  },
);

// Verifies: REQ-d00119-K — drain on native row whose event_ids reference
// a missing event throws StateError.
test(
  'REQ-d00119-K: drain on native row with missing event throws StateError',
  () async {
    // Construct a row with an event_id that does not resolve.
    final event = await _appendEventForFifo(backend, eventId: 'e1');
    final envelope = BatchEnvelope(
      batchFormatVersion: '1',
      batchId: 'batch-x',
      senderHop: 'mobile-1',
      senderIdentifier: 'device-uuid',
      senderSoftwareVersion: 'diary@1.2.3',
      sentAt: DateTime.utc(2026, 4, 25, 12, 0, 0),
      events: <Map<String, Object?>>[event.toMap()],
    );
    final payload = WirePayload(
      bytes: envelope.encode(),
      contentType: BatchEnvelope.wireFormat,
      transformVersion: 'native-v1',
    );
    await backend.enqueueFifo('dest', [event], payload);
    // Surgically delete the event from the underlying store so
    // findEventById returns null.
    // ... use intMapStoreFactory.store('events') via debugDatabase()
    // for this test-only setup ...

    final dest = FakeDestination(id: 'dest', script: [const SendResult.ok()]);
    expect(
      () => drain(dest, backend: backend, policy: defaultPolicy),
      throwsStateError,
    );
  },
);
```

(Adjust the FakeDestination construction + drain call to match the actual existing test patterns. The "delete the event" trick may need its own helper — check if existing tests do similar test-only mutations.)

- [ ] **Step 4: Run drain tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/sync/drain_test.dart 2>&1 | tail -10)
```

Expected: `+2: All tests passed!`. Pre-existing drain tests must still pass.

- [ ] **Step 5: Run full suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+592` (590 + 2). If any existing test fails because it built a native FIFO row with non-null wirePayload (which is no longer the storage shape), update those tests to use the new shape.

- [ ] **Step 6: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/sync/drain.dart \
        apps/common-dart/event_sourcing_datastore/test/sync/drain_test.dart
git commit -m "[CUR-1154] Phase 4.13 Task 6: drain branches — re-encode native rows on demand"
```

---

### Task 7: Round-trip integration test + verify Phase 4.12 watchFifo compatibility

**Files:**

- Create: `apps/common-dart/event_sourcing_datastore/test/integration/native_round_trip_test.dart`
- Modify: existing watch_fifo / fifo tests if any need updating for the new field shape.

- [ ] **Step 1: Write a round-trip test that exercises the full pipeline**

```dart
// End-to-end: append events, enqueue native row, verify storage shape
// (envelope_metadata stored, wire_payload null), drain, verify the
// destination received deterministically-reconstructed bytes that
// decode back to the same events.
//
// Verifies: REQ-d00119-B+K end-to-end on the happy path.
```

Full test in the same idiom as existing integration tests under `apps/common-dart/event_sourcing_datastore/test/integration/`.

- [ ] **Step 2: Verify Phase 4.12 watchFifo emits FifoEntry objects with the new field**

Add a case to `sembast_backend_watch_fifo_test.dart` (or new file if cleaner):

```dart
// Verifies: REQ-d00150-B + REQ-d00119-K — watchFifo snapshots include
// envelopeMetadata for native rows.
test(
  'REQ-d00150-B + REQ-d00119-K: watchFifo emits envelopeMetadata for '
  'native rows',
  () async {
    // ... enqueue a native row, subscribe to watchFifo, assert the
    // emitted snapshot's first entry has non-null envelopeMetadata ...
  },
);
```

- [ ] **Step 3: Run new tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/integration/native_round_trip_test.dart 2>&1 | tail -10)
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_watch_fifo_test.dart 2>&1 | tail -10)
```

Expected: all pass.

- [ ] **Step 4: Run full suite + analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `+594` (592 + 2 — round-trip + watchFifo compatibility) and clean.

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/test/integration/native_round_trip_test.dart \
        apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_fifo_test.dart
git commit -m "[CUR-1154] Phase 4.13 Task 7: round-trip + watchFifo compatibility tests"
```

---

### Task 8: Final verification + close worklog

**Files:** Modify `PHASE_4.13_WORKLOG.md`, `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md`.

- [ ] **Step 1: Run full phase invariant set**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: event_sourcing_datastore +594, provenance +38, all analyze clean.

- [ ] **Step 2: Storage-savings sanity check** — compare row sizes

```bash
# Pseudocode — exact tooling depends on what exists in the repo;
# may be a one-off probe vs. a permanent benchmark.
```

If no existing benchmark hook, just describe in the worklog: "Native row stored shape: ~200 bytes (envelope) vs ~5KB (typical wirePayload). ~95% storage saving for native rows."

- [ ] **Step 3: Mark all tasks complete in `PHASE_4.13_WORKLOG.md`**; add Final-verification section.

- [ ] **Step 4: Append `**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +594, provenance +38, all analyze clean. Native FIFO rows store envelope_metadata + null wire_payload; drain reconstructs deterministically.` to the Phase 4.13 section of the decisions log.

- [ ] **Step 5: Commit**

```bash
git add PHASE_4.13_WORKLOG.md docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md
git commit -m "[CUR-1154] Phase 4.13 Task 8: close worklog (final verify clean)"
```

- [ ] **Step 6: Surface the FINAL phase-end summary for the entire 4.10–4.13 run.** The orchestrator will use this to write the run-end report for the user.

---

## What does NOT change in this phase

- `Destination` API — `transform(batch) → WirePayload` unchanged. Destinations need not know the library is optimizing storage.
- `EventStore`, `EntryService`, materializer, sync_cycle — untouched.
- 3rd-party FIFO rows — completely unchanged. The optimization only triggers when `wire_format == "esd/batch@1"`.
- REQ-d00132 broken cross-references and `debugDatabase` queryAudit survivor — untouched (Phase 4.10/4.11 surfaced; out of scope).
- Portal-side outbound FIFOs — out of scope per spec §5.
