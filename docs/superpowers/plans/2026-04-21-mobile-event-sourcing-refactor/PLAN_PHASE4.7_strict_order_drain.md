# Master Plan Phase 4.7: Strict-Order Drain Semantics Fix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the REQ-d00119-D "continue past exhausted" drift by making drain halt at the wedged head, collapsing `unjam` and `rehabilitate` into a single `tombstoneAndRefill` operator primitive, and codifying the `sequence_in_queue` monotonic-never-reused invariant as the audit signal for trail-row deletion.

**Architecture:** Three terminal statuses (`sent`, `wedged`, `tombstoned`) with `FifoEntry.finalStatus: FinalStatus?` where `null` is pre-terminal; drain halts at the first `wedged` row; `tombstoneAndRefill(destId, headRowId)` performs an atomic cascade (target flipped to `tombstoned`, trailing `null` rows deleted, `fill_cursor` rewound to `target.event_id_range.first_seq - 1`) so the next `fillBatch` rebuilds the target and trail into fresh bundles.

**Tech Stack:** Dart / Flutter, sembast, the existing `append_only_datastore` package under `apps/common-dart/append_only_datastore`.

**Design spec:** `docs/superpowers/specs/2026-04-23-strict-order-drain-fix-design.md`.

**Branch**: `mobile-event-sourcing-refactor` (shared, same as Phase 4.6 — no new branch per user decision 2026-04-23).
**Ticket**: CUR-1154 (continuation).
**Phase**: 4.7 (after 4.6).
**Depends on**: Phase 4.6 complete. (Phase 4.6 ships with today's drift in place; this phase fixes it.)

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00119-C | final_status enum values | Task 3 |
| REQ-d00119-D | non-null rows retained | Task 3 (regression) |
| REQ-d00119-E (NEW) | sequence_in_queue monotonic + never reused | Task 3, Task 6 |
| REQ-d00124-A | readFifoHead returns first {null, wedged} | Task 5 |
| REQ-d00124-D | SendPermanent → markFinal(wedged) | Task 5 |
| REQ-d00124-E | SendTransient at max → markFinal(wedged) | Task 5 |
| REQ-d00124-H | drain halts at wedged head | Task 5 |
| REQ-d00144-A (NEW) | tombstoneAndRefill head-only precondition | Task 6 |
| REQ-d00144-B (NEW) | target transition to tombstoned, attempts[] preserved | Task 6 |
| REQ-d00144-C (NEW) | trail null rows deleted | Task 6 |
| REQ-d00144-D (NEW) | fill_cursor rewound to target.first_seq - 1 | Task 6 |
| REQ-d00144-E (NEW) | TombstoneAndRefillResult return shape | Task 6 |
| REQ-d00144-F (NEW) | next fillBatch re-promotes target + trail | Task 6 |

---

## Execution rules

Read `README.md` in the plans directory for:
- TDD cadence — every implementation file gets unit tests first, failing, then implementation; `// Implements:` / `// Verifies:` markers with REQ citations.
- Phase-boundary squash procedure — all intra-phase commits squashed to one at phase end with subject `[CUR-1154] Phase 4.7: strict-order drain semantics fix`.
- Cross-phase invariants — at phase end, `dart test` / `flutter test` / `flutter analyze` must be clean on every touched package.
- REQ citation convention — per-function comments, not file headers.

Read the design spec `docs/superpowers/specs/2026-04-23-strict-order-drain-fix-design.md` in full before Task 1.

---

## Plan

### Task 1: Baseline verification + worklog

**TASK_FILE**: `PHASE4.7_TASK_1.md`

**Files:**
- Create: `PHASE_4.7_WORKLOG.md` at repo root (mirrors Phase 4.6's structure)
- Create: `PHASE4.7_TASK_1.md`

- [ ] **Confirm Phase 4.6 complete**: `git log --oneline -1` should show a Phase 4.6 commit as HEAD. If not, stop.

- [ ] **Baseline tests — all green**:

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all tests pass; analyze clean.

- [ ] **Confirm REQ-d00144 slot is free in spec/INDEX.md**:

```bash
grep "REQ-d00144" spec/INDEX.md spec/dev-event-sourcing-mobile.md
```

Expected: no matches. (REQ-d00143 is the last claimed number as of 2026-04-23.)

- [ ] **Create `PHASE_4.7_WORKLOG.md`** at repo root. Copy the controller block structure from `PHASE_4.6_WORKLOG.md`. Populate with:
  - Phase: 4.7 — strict-order drain semantics fix
  - Ticket: CUR-1154
  - Design doc: `docs/superpowers/specs/2026-04-23-strict-order-drain-fix-design.md`
  - Plan doc: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.7_strict_order_drain.md`
  - REQ-d substitution table: REQ-d00144 claimed for tombstoneAndRefill; no other new REQs.

- [ ] **Commit**:

```bash
git add PHASE_4.7_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.7 Task 1: baseline + worklog"
```

---

### Task 2: Spec changes

**TASK_FILE**: `PHASE4.7_TASK_2.md`

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md` (REQ-d00119, REQ-d00122, REQ-d00123, REQ-d00124, REQ-d00127; add REQ-d00144; remove REQ-d00131, REQ-d00132)
- Modify: `spec/INDEX.md` (drop d00131/d00132 rows, add d00144 row, update hashes where affected)

**No tests in this task** — spec text only.

- [ ] **REQ-d00119-C rewrite**. Replace the current assertion C body with:

> C. The `final_status` field SHALL be either `null` or one of the values `"sent"`, `"wedged"`, or `"tombstoned"`; `null` means "not yet terminal" and the three enum values are the complete set of terminal states. No other values SHALL be legal.

- [ ] **REQ-d00119-D — no text change** beyond the cascade in the enum rename: the retain-forever clause already reads "Once a FIFO entry's `final_status` has transitioned out of pending…"; retarget that phrasing to "Once a FIFO entry's `final_status` is non-null…" to match the nullable shape.

- [ ] **REQ-d00119 — add new assertion E**:

> E. `sequence_in_queue` SHALL be assigned monotonically at row insertion from a per-destination counter that SHALL NOT rewind and SHALL NOT reuse values when a row is deleted. A gap in `sequence_in_queue` between two surviving rows is the audit signal that one or more rows were deleted from the FIFO store (the only code path that deletes FIFO rows is REQ-d00144-C).

- [ ] **REQ-d00124 rewrite assertions A, D, E, H**:

> A. `drain(destination)` SHALL read the head of `fifo/{destination.id}` via `backend.readFifoHead(destination.id)`. `readFifoHead` SHALL return the first row in `sequence_in_queue` order whose `final_status` is `null` or `wedged`; rows whose `final_status` is `sent` or `tombstoned` SHALL be skipped. When the destination's FIFO has no such row, `readFifoHead` SHALL return `null` and `drain` SHALL return without calling `destination.send`.
>
> D. On `SendPermanent`, `drain` SHALL mark the head entry `wedged` via `backend.markFinal(id, entry_id, FinalStatus.wedged)`.
>
> E. On `SendTransient` where `attempts.length + 1 >= SyncPolicy.maxAttempts`, `drain` SHALL mark the head entry `wedged` via `backend.markFinal(id, entry_id, FinalStatus.wedged)`.
>
> H. `drain` SHALL preserve strict FIFO order within a destination: terminal-passable statuses are `{sent, tombstoned}`; `wedged` is the sole blocking terminal state. `drain` SHALL return without calling `destination.send` whenever `readFifoHead` returns a row whose `final_status` is `wedged`. Recovery from a wedged head requires `tombstoneAndRefill` (REQ-d00144).

Update REQ-d00124 rationale prose accordingly — strike the "continue past exhausted" justification language; replace with a short paragraph explaining that strict order is preserved by halting at wedged rather than by skipping past them.

- [ ] **REQ-d00123-E rename**:

> E. `SyncPolicy.maxAttempts` SHALL equal `20`; an entry that accumulates this many `attempts` on its log SHALL be marked `wedged` on the next transient-failure drain step, wedging its FIFO.

- [ ] **REQ-d00127 rationale update**. Change the race-list phrase in the rationale paragraph to: "…a concurrent user-initiated operation — `tombstoneAndRefill` clearing the pending trail and rewinding the cursor, or `deleteDestination` destroying the whole FIFO store — can remove the row `drain` is about to write to." Assertions A/B/C unchanged; assertion C's log-line-race identifier string becomes `drain/tombstoneAndRefill` or `drain/delete` instead of `drain/unjam` or `drain/delete`.

- [ ] **REQ-d00122 rationale addition**. Append one paragraph at the end of the existing rationale:

> When a destination's backing sink must not be wedged by failures in an unrelated event category, register multiple `Destination` instances with disjoint `SubscriptionFilter`s against the same underlying sink rather than one destination filter-switching within a single FIFO. Each `Destination` owns its own FIFO and its own strict-order wedge; a wedge on one filter's events leaves the others draining normally. The library gives uniqueness of `destination.id` and per-destination `SubscriptionFilter` the structural support this pattern needs; no additional primitive is required.

- [ ] **Add REQ-d00144**. Insert at the end of the dev REQ section in `spec/dev-event-sourcing-mobile.md`, using the full text (Rationale + Assertions A–F) from §4.3 of the design spec. Header:

```markdown
# REQ-d00144: tombstoneAndRefill Operation

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001
```

- [ ] **Remove REQ-d00131**. Delete the entire `# REQ-d00131: Unjam Destination Operation` section from `spec/dev-event-sourcing-mobile.md`.

- [ ] **Remove REQ-d00132**. Delete the entire `# REQ-d00132: Rehabilitate Exhausted FIFO Row` section from `spec/dev-event-sourcing-mobile.md`.

- [ ] **Update `spec/INDEX.md`**. Drop the REQ-d00131 and REQ-d00132 rows. Add a REQ-d00144 row with topic "tombstoneAndRefill Operation" and the file `dev-event-sourcing-mobile.md`. Hash column: leave empty or compute from the written text per the project's hash convention.

- [ ] **Commit**:

```bash
git add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git commit -m "[CUR-1154] Phase 4.7 Task 2: spec changes for strict-order drain fix"
```

---

### Task 3: FinalStatus enum refactor

**TASK_FILE**: `PHASE4.7_TASK_3.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/final_status.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/fifo_entry.dart`
- Modify: every file referencing `FinalStatus.pending` or `FinalStatus.exhausted` (see sweep list below)
- Modify: every test referencing those enum values

**Implements**: REQ-d00119-C (nullable enum), REQ-d00119-E (monotonic sequence_in_queue).

- [ ] **Step 1: Write failing tests for the new enum + FifoEntry shape.**

In `test/storage/fifo_entry_test.dart`:

```dart
test('REQ-d00119-C: finalStatus is nullable; null is not a terminal state', () {
  final entry = FifoEntry(
    entryId: 'e1',
    eventIds: const ['ev1'],
    eventIdRange: (firstSeq: 1, lastSeq: 1),
    sequenceInQueue: 1,
    wirePayload: const {'k': 'v'},
    wireFormat: 'json-v1',
    transformVersion: 'v1',
    enqueuedAt: DateTime.utc(2026, 4, 23, 10),
    attempts: const [],
    finalStatus: null,
    sentAt: null,
  );
  expect(entry.finalStatus, isNull);
});

test('REQ-d00119-C: FinalStatus enum has exactly {sent, wedged, tombstoned}', () {
  expect(FinalStatus.values.toSet(), {
    FinalStatus.sent,
    FinalStatus.wedged,
    FinalStatus.tombstoned,
  });
});

test('REQ-d00119-C: FinalStatus.fromJson rejects pending and exhausted', () {
  expect(() => FinalStatus.fromJson('pending'), throwsFormatException);
  expect(() => FinalStatus.fromJson('exhausted'), throwsFormatException);
  expect(FinalStatus.fromJson('sent'), FinalStatus.sent);
  expect(FinalStatus.fromJson('wedged'), FinalStatus.wedged);
  expect(FinalStatus.fromJson('tombstoned'), FinalStatus.tombstoned);
});

test('REQ-d00119-C: FifoEntry.fromJson accepts null final_status', () {
  final json = {
    'entry_id': 'e1',
    'event_ids': ['ev1'],
    'event_id_range': {'first_seq': 1, 'last_seq': 1},
    'sequence_in_queue': 1,
    'wire_payload': {'k': 'v'},
    'wire_format': 'json-v1',
    'transform_version': 'v1',
    'enqueued_at': '2026-04-23T10:00:00.000Z',
    'attempts': <Map<String, Object?>>[],
    'final_status': null,
    'sent_at': null,
  };
  final entry = FifoEntry.fromJson(json);
  expect(entry.finalStatus, isNull);
  expect(entry.toJson()['final_status'], isNull);
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
(cd apps/common-dart/append_only_datastore && flutter test test/storage/fifo_entry_test.dart)
```

Expected: compile errors and/or test failures (the current enum still has `pending` and `exhausted`).

- [ ] **Step 3: Rewrite `lib/src/storage/final_status.dart`**:

```dart
/// Terminal state of a FifoEntry within its destination's FIFO.
///
/// A FifoEntry's `finalStatus` is nullable: `null` means "not yet
/// terminal" (drain may attempt the row), and a non-null value is one
/// of three terminal states below. Once a FIFO entry's `finalStatus` is
/// non-null it is retained forever as an audit record; the FIFO never
/// deletes it (REQ-d00119-D). The sole code path that deletes a FIFO
/// row is REQ-d00144-C (the `tombstoneAndRefill` trail sweep), and
/// that path only deletes rows whose `finalStatus` is `null`.
// Implements: REQ-d00119-C — final_status is null or one of
// {sent, wedged, tombstoned}.
enum FinalStatus {
  sent,
  wedged,
  tombstoned;

  /// Parse a wire-format string; throws [FormatException] on unknown input.
  factory FinalStatus.fromJson(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    throw FormatException(
      'FinalStatus: unknown value "$raw" '
      '(legal values: sent | wedged | tombstoned)',
    );
  }

  /// Serialize to the wire-format string used in persisted records.
  String toJson() => name;
}
```

- [ ] **Step 4: Update `lib/src/storage/fifo_entry.dart`**.

Change the `finalStatus` field type from `FinalStatus` to `FinalStatus?`. Update the constructor param, `fromJson`, `toJson`, `==`, and `hashCode`. Concretely:

- Field declaration: `final FinalStatus? finalStatus;`
- Constructor param: `required this.finalStatus,` (no change to `required` — nullable parameters are still required but may be null).
- `fromJson`: accept `final_status == null` and pass through as `finalStatus: null`. The existing line 155-160 check rejects non-string `final_status`; adjust to accept null AND string:

```dart
final finalStatusRaw = json['final_status'];
if (finalStatusRaw != null && finalStatusRaw is! String) {
  throw const FormatException(
    'FifoEntry: "final_status" must be a String or null',
  );
}
final finalStatus = finalStatusRaw == null
    ? null
    : FinalStatus.fromJson(finalStatusRaw);
```

And in the return object: `finalStatus: finalStatus,` (just pass the local).

- `toJson`: `'final_status': finalStatus?.toJson(),` — emits null when null.

- Update the class doc comment to say "`finalStatus` is nullable; `null` means not-yet-terminal."

- Update the `Implements:` marker:

```dart
// Implements: REQ-d00119-B+C — carries the documented columns;
// final_status typed as FinalStatus? — null is pre-terminal, the
// three enum values are the complete set of terminal states.
```

- [ ] **Step 5: Global sweep — replace every `== FinalStatus.pending` with `== null` and every `FinalStatus.exhausted` with `FinalStatus.wedged`**. Expected sites (verify via grep, fix exhaustively):

```bash
grep -rn "FinalStatus.pending\|FinalStatus.exhausted" apps/common-dart/append_only_datastore/lib/ apps/common-dart/append_only_datastore/test/ apps/common-dart/append_only_datastore/example/lib/
```

Known sites from the pre-fix tree include:

- `lib/src/storage/sembast_backend.dart` (lines 736, 790, 878-1151): enum enqueue default, readFifoHead filter, markFinal/setFinalStatus branches, exhausted filter at line 1067, pending filter at line 981.
- `lib/src/sync/drain.dart`: `FinalStatus.exhausted` at lines 104 and 115 (already being rewritten in Task 5, but the rename lands here).
- `lib/src/ops/unjam.dart` and `lib/src/ops/rehabilitate.dart`: mixed references (these files are deleted in Task 7; for now update the references so the files compile until deletion).
- Example app: `example/lib/demo_destination.dart`, `example/lib/app_state.dart`, `example/lib/widgets/fifo_panel.dart`, `example/lib/widgets/detail_panel.dart`.
- Tests: every file under `test/` using the enum values.

When updating sembast_backend.dart:
- `FilterequalsnulltoJson` style: sembast supports `Filter.isNull('final_status')`. Use this for the "null final_status" case.
- Enqueue default at line 736: `finalStatus: FinalStatus.pending` → `finalStatus: null`.
- setFinalStatusTxn (line 1096+): the logic is being replaced by the new flow in Task 6 but for Task 3 keep the method compiling — change its validation to reject `FinalStatus.tombstoned` inputs (that transition is owned by `tombstoneAndRefill` in Task 6) and otherwise accept `FinalStatus.wedged` and `FinalStatus.sent`. The old `setFinalStatusTxn only supports rehabilitate (exhausted -> pending)` string becomes a stale comment; Task 7 removes the method along with rehabilitate.

- [ ] **Step 6: Write test for REQ-d00119-E (monotonic sequence_in_queue)**.

In `test/storage/sembast_backend_fifo_test.dart`, add:

```dart
test('REQ-d00119-E: sequence_in_queue is monotonic per destination, never reused', () async {
  // Arrange: a backend with three rows enqueued, then one deleted.
  final backend = await _openSembast();
  addTearDown(backend.close);
  const destId = 'test-dest';
  await _setupDormantDestination(backend, destId);  // helper defined in test_support
  final e1 = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  final e2 = await backend.enqueueFifo(destId, _fakeFifoInsert(2));
  final e3 = await backend.enqueueFifo(destId, _fakeFifoInsert(3));
  expect(e1.sequenceInQueue, 1);
  expect(e2.sequenceInQueue, 2);
  expect(e3.sequenceInQueue, 3);

  // Act: delete e2 via a raw sembast txn that mimics tombstoneAndRefill's
  // trail delete (we cannot call tombstoneAndRefill yet; Task 6 adds it).
  await backend.transaction((txn) async {
    await _rawDeleteFifoRow(txn, destId, e2.entryId);
  });

  // Enqueue a fourth row. Its sequence_in_queue MUST be 4, not 2.
  final e4 = await backend.enqueueFifo(destId, _fakeFifoInsert(4));
  expect(e4.sequenceInQueue, 4);
});
```

Where `_rawDeleteFifoRow` is a small test helper added to `test/test_support/` that invokes the sembast store's `delete` inside the provided txn. Add the helper if it does not exist; keep it minimal.

- [ ] **Step 7: Implement REQ-d00119-E if not already implied by current code**.

The current `enqueueFifo` / `enqueueFifoTxn` in `sembast_backend.dart` reads the counter from `backend_state`, increments, and writes back. Verify it does NOT reuse deleted slots (it should not — the counter is a monotonic integer, not derived from row count). If it does anything cleverer than "++counter", fix so the counter is strictly monotonic and never resets or reuses. Add a `// Implements: REQ-d00119-E —` marker on the counter update.

- [ ] **Step 8: Run all unit tests**

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all tests pass. Some existing tests may need mechanical updates (e.g., `expect(entry.finalStatus, FinalStatus.pending)` → `expect(entry.finalStatus, isNull)`). Fix each one inline as TDD dictates; do not suppress failures.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/
git commit -m "[CUR-1154] Phase 4.7 Task 3: FinalStatus nullable + {sent, wedged, tombstoned}"
```

---

### Task 4: Rename ExhaustedFifoSummary → WedgedFifoSummary and storage surface

**TASK_FILE**: `PHASE4.7_TASK_4.md`

**Files:**
- Rename: `apps/common-dart/append_only_datastore/lib/src/storage/exhausted_fifo_summary.dart` → `wedged_fifo_summary.dart`
- Modify: `lib/src/storage/storage_backend.dart` — `exhaustedFifos()` → `wedgedFifos()`; drop `exhaustedRowsOf()` if present (used only by rehabilitate, deleted Task 7).
- Modify: `lib/src/storage/sembast_backend.dart` — concrete impls of the renamed methods.
- Modify: every caller of `ExhaustedFifoSummary` / `exhaustedFifos()` / `exhaustedRowsOf()`.
- Modify: tests and test_support helpers.

**Implements**: rationale consistency with REQ-d00119-C (wedged is the sole blocking terminal state).

- [ ] **Step 1: Rename the class and file.**

Rename the class:
- `class ExhaustedFifoSummary` → `class WedgedFifoSummary`
- Field rename: `exhaustedAt` → `wedgedAt` (DateTime field).
- JSON key rename: `"exhausted_at"` → `"wedged_at"`.
- Update all fromJson/toJson references and error messages.
- Update the class doc comment: "Summary of one wedged FIFO…"

Rename the file:

```bash
git mv apps/common-dart/append_only_datastore/lib/src/storage/exhausted_fifo_summary.dart apps/common-dart/append_only_datastore/lib/src/storage/wedged_fifo_summary.dart
```

- [ ] **Step 2: Update `storage_backend.dart` abstract surface.**

- `Future<List<ExhaustedFifoSummary>> exhaustedFifos();` → `Future<List<WedgedFifoSummary>> wedgedFifos();`
- Doc-comment update: "Summarize every destination whose head row is wedged."
- If `exhaustedRowsOf(String destinationId)` is present, delete it — it is only used by `rehabilitateAllExhausted`, which Task 7 removes.

- [ ] **Step 3: Update `sembast_backend.dart` concrete impls.**

- `wedgedFifos()` — query filter changes from `FinalStatus.exhausted` to `FinalStatus.wedged`.
- Drop `exhaustedRowsOf` if it was in the abstract surface.

- [ ] **Step 4: Update every caller.**

Grep and fix exhaustively:

```bash
grep -rn "ExhaustedFifoSummary\|exhaustedFifos\|exhaustedRowsOf\|exhausted_fifo_summary" apps/common-dart/append_only_datastore/
```

Known callers include the example `fifo_panel.dart`, `app_state.dart`, and any tests. Update each to use `WedgedFifoSummary` / `wedgedFifos()`.

- [ ] **Step 5: Update tests.**

- `test/storage/sembast_backend_fifo_test.dart` — update assertions naming `exhaustedFifos()` / `ExhaustedFifoSummary` / `exhausted_at`.
- Any other test file referencing these names.

- [ ] **Step 6: Run tests + analyze.**

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all green.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/
git commit -m "[CUR-1154] Phase 4.7 Task 4: rename ExhaustedFifoSummary to WedgedFifoSummary"
```

---

### Task 5: readFifoHead new contract + drain halt-at-wedged

**TASK_FILE**: `PHASE4.7_TASK_5.md`

**Files:**
- Modify: `lib/src/storage/storage_backend.dart` — `readFifoHead` doc comment for the new contract.
- Modify: `lib/src/storage/sembast_backend.dart` — `readFifoHead` implementation.
- Modify: `lib/src/sync/drain.dart` — drain halt check when head is `wedged`.
- Modify: `test/storage/sembast_backend_fifo_test.dart` — new test cases for readFifoHead returning wedged rows.
- Modify: `test/sync/drain_test.dart` — new tests for halt-at-wedged; delete tests asserting "continue past exhausted."

**Implements**: REQ-d00124-A, REQ-d00124-D, REQ-d00124-E, REQ-d00124-H.

- [ ] **Step 1: Write failing tests for readFifoHead new contract**.

In `test/storage/sembast_backend_fifo_test.dart`:

```dart
test('REQ-d00124-A: readFifoHead returns first row with finalStatus in {null, wedged}', () async {
  final backend = await _openSembast();
  addTearDown(backend.close);
  const destId = 'test-dest';
  await _setupDormantDestination(backend, destId);

  // Seed: row 1 sent, row 2 wedged, row 3 null (pending).
  final r1 = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  final r2 = await backend.enqueueFifo(destId, _fakeFifoInsert(2));
  await backend.enqueueFifo(destId, _fakeFifoInsert(3));
  await backend.markFinal(destId, r1.entryId, FinalStatus.sent);
  await backend.markFinal(destId, r2.entryId, FinalStatus.wedged);

  final head = await backend.readFifoHead(destId);
  expect(head, isNotNull);
  expect(head!.entryId, r2.entryId);
  expect(head.finalStatus, FinalStatus.wedged);
});

test('REQ-d00124-A: readFifoHead skips tombstoned rows', () async {
  final backend = await _openSembast();
  addTearDown(backend.close);
  const destId = 'test-dest';
  await _setupDormantDestination(backend, destId);

  final r1 = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  final r2 = await backend.enqueueFifo(destId, _fakeFifoInsert(2));
  // Simulate a prior tombstoneAndRefill by directly flipping row 1.
  // (Task 6 adds the real operation; here we just need the data state.)
  await _rawSetFinalStatus(destId, r1.entryId, FinalStatus.tombstoned);

  final head = await backend.readFifoHead(destId);
  expect(head, isNotNull);
  expect(head!.entryId, r2.entryId);
  expect(head.finalStatus, isNull);
});

test('REQ-d00124-A: readFifoHead returns null when only terminal-passable rows exist', () async {
  final backend = await _openSembast();
  addTearDown(backend.close);
  const destId = 'test-dest';
  await _setupDormantDestination(backend, destId);

  final r1 = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  final r2 = await backend.enqueueFifo(destId, _fakeFifoInsert(2));
  await backend.markFinal(destId, r1.entryId, FinalStatus.sent);
  await _rawSetFinalStatus(destId, r2.entryId, FinalStatus.tombstoned);

  expect(await backend.readFifoHead(destId), isNull);
});
```

- [ ] **Step 2: Run tests to verify failure.**

```bash
(cd apps/common-dart/append_only_datastore && flutter test test/storage/sembast_backend_fifo_test.dart)
```

Expected: the new cases fail (current `readFifoHead` filters for `final_status == pending` / `== null` only).

- [ ] **Step 3: Update `readFifoHead` in `sembast_backend.dart`** (line 784+):

Replace the filter at line 790 with a predicate that admits rows whose `final_status` is null OR equals `"wedged"`. sembast's `Filter.or([...])` composes two filters:

```dart
Future<FifoEntry?> readFifoHead(String destinationId) async {
  // REQ-d00124-A: return first row in sequence_in_queue order whose
  // final_status is null (pre-terminal) or "wedged" (blocking terminal).
  // Rows whose final_status is "sent" or "tombstoned" are skipped.
  final records = await _fifoStoreOf(destinationId).find(
    await _database,
    finder: Finder(
      filter: Filter.or([
        Filter.isNull('final_status'),
        Filter.equals('final_status', FinalStatus.wedged.toJson()),
      ]),
      sortOrders: [SortOrder('sequence_in_queue', true)],
      limit: 1,
    ),
  );
  if (records.isEmpty) return null;
  return FifoEntry.fromJson(Map<String, Object?>.from(records.first.value));
}
```

Update the doc comment block at lines 775-783 to match the new contract.

- [ ] **Step 4: Update `storage_backend.dart` abstract doc comment for `readFifoHead`** (line 248-252):

```dart
/// Return the head row of `destinationId`'s FIFO — the first row in
/// `sequence_in_queue` order whose `final_status` is either `null`
/// (pre-terminal; drain may attempt) or `FinalStatus.wedged` (blocking
/// terminal; drain halts). Rows whose `final_status` is
/// `FinalStatus.sent` or `FinalStatus.tombstoned` SHALL be skipped.
/// Returns `null` when no such row exists.
// Implements: REQ-d00124-A — readFifoHead returns first {null, wedged};
// skips {sent, tombstoned}.
Future<FifoEntry?> readFifoHead(String destinationId);
```

- [ ] **Step 5: Write failing tests for drain halt-at-wedged**.

In `test/sync/drain_test.dart`:

```dart
test('REQ-d00124-H: drain halts when head is wedged, does not call send', () async {
  final backend = await _openSembast();
  addTearDown(backend.close);
  final destination = FakeDestination(id: 'd1');
  const destId = 'd1';
  await _registerDormantDestination(backend, destId);

  final row = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  await backend.markFinal(destId, row.entryId, FinalStatus.wedged);

  destination.sendOverrides.add(SendOk());  // would be consumed if called

  await drain(destination, backend: backend);

  expect(destination.sendInvocations, isEmpty);  // drain did NOT call send
  final afterRow = await backend.readFifoRow(destId, row.entryId);
  expect(afterRow!.finalStatus, FinalStatus.wedged);  // unchanged
});

test('REQ-d00124-D: SendPermanent marks head wedged; drain halts on next iteration', () async {
  final backend = await _openSembast();
  addTearDown(backend.close);
  final destination = FakeDestination(id: 'd1');
  const destId = 'd1';
  await _registerDormantDestination(backend, destId);

  final r1 = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  await backend.enqueueFifo(destId, _fakeFifoInsert(2));  // trailing pending
  destination.sendOverrides.add(SendPermanent(error: 'schema-skew'));

  await drain(destination, backend: backend);

  final after1 = await backend.readFifoRow(destId, r1.entryId);
  expect(after1!.finalStatus, FinalStatus.wedged);
  // Trail row 2 stays null: drain halted at wedged r1 before attempting r2.
  expect(destination.sendInvocations.length, 1);
});

test('REQ-d00124-E: SendTransient at maxAttempts marks head wedged; drain halts', () async {
  final backend = await _openSembast();
  addTearDown(backend.close);
  final destination = FakeDestination(id: 'd1');
  const destId = 'd1';
  await _registerDormantDestination(backend, destId);

  final r1 = await backend.enqueueFifo(destId, _fakeFifoInsert(1));
  await backend.enqueueFifo(destId, _fakeFifoInsert(2));

  // Policy: max 1 attempt. First transient triggers wedged.
  const policy = SyncPolicy(
    initialBackoff: Duration.zero,
    backoffMultiplier: 1.0,
    maxBackoff: Duration.zero,
    jitterFraction: 0.0,
    maxAttempts: 1,
    periodicInterval: Duration(seconds: 1),
  );
  destination.sendOverrides.add(SendTransient(error: '5xx'));

  await drain(destination, backend: backend, policy: policy);

  final after1 = await backend.readFifoRow(destId, r1.entryId);
  expect(after1!.finalStatus, FinalStatus.wedged);
  expect(destination.sendInvocations.length, 1);
});
```

Delete any existing tests in this file that assert "continue past exhausted" — those enforce the old semantics that this fix replaces. Mark each deletion with a one-line comment `// Deleted in Phase 4.7: pre-fix assertion of continue-past-exhausted semantics, now REQ-d00124-H halts at wedged.` in the commit message, not in-file.

- [ ] **Step 6: Run tests to verify failure**.

```bash
(cd apps/common-dart/append_only_datastore && flutter test test/sync/drain_test.dart)
```

Expected: new cases fail; the second and third tests in particular fail because drain currently does NOT halt — it continues past the wedged (nee exhausted) row and attempts trail.

- [ ] **Step 7: Update `lib/src/sync/drain.dart`**.

Add the halt check after the null check, and update the doc comments to reflect strict-order semantics (no more "continue past exhausted" prose).

Replace lines 53-55:

```dart
while (true) {
  final head = await backend.readFifoHead(destination.id);
  if (head == null) return;
  // REQ-d00124-H: drain halts at a wedged head; recovery is via
  // tombstoneAndRefill (REQ-d00144). The row is still read so that
  // UI surfaces can observe the wedge via backend.readFifoHead without
  // also having to query wedgedFifos separately.
  if (head.finalStatus == FinalStatus.wedged) return;
```

Rewrite the top-of-function doc comment block (currently lines 12-44) to describe strict-order halt semantics:

```dart
/// Drain the head of [destination]'s FIFO: check backoff, call
/// [Destination.send], record the attempt, and route the result into
/// a `sent` or `wedged` final-status as appropriate. Returns when:
///
/// - [readFifoHead] returns null (no pending or wedged row); or
/// - [readFifoHead] returns a `wedged` row (strict-order halt per
///   REQ-d00124-H — recovery via tombstoneAndRefill, REQ-d00144); or
/// - the pending head's backoff has not elapsed; or
/// - the most recent [Destination.send] returned [SendTransient] below
///   the `maxAttempts` cap (backoff applies on the next drain tick).
///
/// On [SendOk] the head is marked `sent` and the loop advances. On
/// [SendPermanent] or [SendTransient]-at-`maxAttempts` the head is
/// marked `wedged` (REQ-d00124-D+E); on the next loop iteration
/// [readFifoHead] returns that now-wedged row, and drain halts.
///
/// Strict FIFO order (REQ-d00124-H): terminal-passable statuses are
/// `{sent, tombstoned}`; `wedged` is the sole blocking terminal state.
/// No row whose `sequence_in_queue` is greater than a wedged row's
/// SHALL be attempted until the operator runs tombstoneAndRefill.
///
/// [policy] is an optional [SyncPolicy] override; null falls back to
/// [SyncPolicy.defaults] (REQ-d00126-B).
// Implements: REQ-d00124-A+B+C+D+E+F+G+H — strict-FIFO drain with
// halt-at-wedged.
// Implements: REQ-d00126-B — optional SyncPolicy? parameter; null
// falls back to SyncPolicy.defaults.
```

In the `switch (result)` block (lines 96+), update the `case SendPermanent()` and `case SendTransient()` at-maxAttempts branches to call `markFinal(... FinalStatus.wedged)` (the Task 3 sweep already renamed these, but verify). Both branches retain their `continue` — the next iteration sees the now-wedged head via `readFifoHead` and drain halts naturally at the top-of-loop check.

Strike the REQ comment prose on lines 91-95 ("exhausting the head row… CONTINUES to the next pending row; readFifoHead skips exhausted rows on the next iteration, so drain advances through the FIFO in sequence_in_queue order rather than wedging on an exhausted head") — that commentary contradicts the new behavior. Replace with:

```dart
// Implements: REQ-d00124-D+E — SendPermanent and SendTransient-at-
// maxAttempts both mark the head wedged. The next loop iteration sees
// the wedged row via readFifoHead and drain halts (REQ-d00124-H).
```

- [ ] **Step 8: Run all tests**

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all green. If a test still asserts continue-past behavior, delete it as noted in Step 5.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/
git commit -m "[CUR-1154] Phase 4.7 Task 5: readFifoHead returns {null,wedged}; drain halts at wedged"
```

---

### Task 6: Implement `tombstoneAndRefill`

**TASK_FILE**: `PHASE4.7_TASK_6.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/ops/tombstone_and_refill.dart`
- Create: `apps/common-dart/append_only_datastore/test/ops/tombstone_and_refill_test.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` — add `deleteNullRowsAfterSequenceInQueueTxn` abstract method.
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` — implement the new abstract method.
- Modify: `apps/common-dart/append_only_datastore/lib/src/destinations/destination_schedule.dart` — add `TombstoneAndRefillResult` class.
- Modify: `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart` — export `tombstoneAndRefill` and `TombstoneAndRefillResult`.

**Implements**: REQ-d00144 A–F.

- [ ] **Step 1: Add `TombstoneAndRefillResult`** to `lib/src/destinations/destination_schedule.dart` (below the existing `UnjamResult`, which Task 7 deletes):

```dart
/// Result of `tombstoneAndRefill` — REQ-d00144-E.
///
/// Carries three operator-visible integers: the `entry_id` of the
/// target row that was flipped to `tombstoned`, the count of trail
/// null rows deleted in the same transaction, and the value `fill_cursor`
/// was rewound to.
// Implements: REQ-d00144-E — TombstoneAndRefillResult shape.
class TombstoneAndRefillResult {
  const TombstoneAndRefillResult({
    required this.targetRowId,
    required this.deletedTrailCount,
    required this.rewoundTo,
  });

  /// `entry_id` of the tombstoned target row.
  final String targetRowId;

  /// Count of null-finalStatus rows whose sequence_in_queue was strictly
  /// greater than the target's sequence_in_queue that were deleted from
  /// the FIFO store in the same transaction (REQ-d00144-C).
  final int deletedTrailCount;

  /// Value the per-destination fill_cursor was rewound to
  /// (REQ-d00144-D) — equals target.event_id_range.first_seq - 1.
  final int rewoundTo;
}
```

- [ ] **Step 2: Add `deleteNullRowsAfterSequenceInQueueTxn`** to `storage_backend.dart`:

```dart
/// Delete every FIFO row on [destinationId] whose `sequence_in_queue`
/// is strictly greater than [afterSequenceInQueue] AND whose
/// `final_status IS null`. Returns the count of rows deleted.
///
/// Used by `tombstoneAndRefill` to sweep the trail behind a
/// tombstoned target in one transaction (REQ-d00144-C). Rows whose
/// `final_status` is terminal ({sent, wedged, tombstoned}) are left
/// untouched regardless of their `sequence_in_queue` — per REQ-d00119-D
/// all non-null rows are retained forever.
// Implements: REQ-d00144-C — trail-delete predicate for tombstoneAndRefill.
Future<int> deleteNullRowsAfterSequenceInQueueTxn(
  Txn txn,
  String destinationId,
  int afterSequenceInQueue,
);
```

- [ ] **Step 3: Implement `deleteNullRowsAfterSequenceInQueueTxn`** in `sembast_backend.dart`. Mirror the pattern of `deletePendingRowsTxn` (which Task 7 deletes) but scope the filter to `sequence_in_queue > afterSequenceInQueue AND final_status IS null`:

```dart
@override
Future<int> deleteNullRowsAfterSequenceInQueueTxn(
  Txn txn,
  String destinationId,
  int afterSequenceInQueue,
) async {
  final sembastTxn = _asSembast(txn);
  final store = _fifoStoreOf(destinationId);
  final keysDeleted = await store.delete(
    sembastTxn,
    finder: Finder(
      filter: Filter.and([
        Filter.isNull('final_status'),
        Filter.greaterThan('sequence_in_queue', afterSequenceInQueue),
      ]),
    ),
  );
  return keysDeleted;
}
```

- [ ] **Step 4: Write failing tests** in `test/ops/tombstone_and_refill_test.dart`.

Structure:
- One `group('tombstoneAndRefill()', () { ... })` per REQ-d00144 assertion.
- Each test has arrange / act / assert and cites the REQ in its name.
- Use the existing test_support helpers for backend setup.

Key test cases:

```dart
test('REQ-d00144-A: throws ArgumentError when fifoRowId is not the head', () async {
  // Arrange: destination with head = row 1 (wedged), row 2 (null).
  // Act: call tombstoneAndRefill with row 2's entryId (non-head).
  // Assert: ArgumentError thrown; no mutation.
});

test('REQ-d00144-A: throws ArgumentError when target is sent', () async {
  // Target a sent row directly (not head).
});

test('REQ-d00144-A: throws ArgumentError when target is tombstoned', () async {
  // Set a row to tombstoned via raw txn; call tombstoneAndRefill on it.
});

test('REQ-d00144-A: throws ArgumentError when row does not exist', () async {
  // fifoRowId for a non-existent row.
});

test('REQ-d00144-B: wedged head transitions to tombstoned; attempts preserved', () async {
  // Seed head with attempts[2 items] + finalStatus=wedged.
  // Act: tombstoneAndRefill(head.entryId).
  // Assert: final_status=tombstoned, attempts unchanged.
});

test('REQ-d00144-B: null head transitions to tombstoned; attempts preserved', () async {
  // Seed head with attempts[1 item] + finalStatus=null.
  // Act: tombstoneAndRefill(head.entryId).
  // Assert: final_status=tombstoned, attempts unchanged.
});

test('REQ-d00144-C: trail null rows after target are deleted', () async {
  // Seed: row 1 sent, row 2 wedged (head), rows 3-5 null (trail).
  // Act: tombstoneAndRefill(row2.entryId).
  // Assert: rows 3-5 gone; row 1 (sent) and row 2 (tombstoned) remain.
});

test('REQ-d00144-C: sequence_in_queue gap is visible after trail delete', () async {
  // Check that sequence_in_queue jumps from 2 (tombstoned) to 6 (first fresh)
  // after a fillBatch following the cascade, with 3-5 permanently gone.
});

test('REQ-d00144-D: fill_cursor rewinds to target.first_seq - 1', () async {
  // Seed: event log has events 1-10; row 1 covers events 1-3 (sent),
  // row 2 covers events 4-6 (wedged, head), row 3 covers events 7-9 (null).
  // Act: tombstoneAndRefill(row2.entryId).
  // Assert: fill_cursor == 3 (= row 2's first_seq - 1 = 4 - 1).
});

test('REQ-d00144-D: fill_cursor rewinds to -1 when no sent rows exist', () async {
  // Seed: row 1 wedged (head, covers events 1-3); no sent rows.
  // Act: tombstoneAndRefill(row1.entryId).
  // Assert: fill_cursor == 0 (= 1 - 1 = row 1's first_seq - 1).
});

test('REQ-d00144-E: returns TombstoneAndRefillResult with correct fields', () async {
  // Sanity: result.targetRowId, deletedTrailCount, rewoundTo are correct.
});

test('REQ-d00144-F: next fillBatch re-promotes target events AND trail events', () async {
  // End-to-end: seed wedge + trail, tombstoneAndRefill, fillBatch, drain.
  // Assert fresh FIFO rows cover target.events + trail.events; drain delivers.
});
```

Each test should use a small helper like `_seedFifo(backend, destId, [...])` to arrange the state from a concise list of `(range, status)` tuples. Add the helper to `test/test_support/fifo_entry_helpers.dart` if the existing one cannot express tombstoned rows (the new status needs a branch).

- [ ] **Step 5: Run tests to verify failure**

```bash
(cd apps/common-dart/append_only_datastore && flutter test test/ops/tombstone_and_refill_test.dart)
```

Expected: all fail (the function does not exist yet).

- [ ] **Step 6: Implement `tombstoneAndRefill`** in `lib/src/ops/tombstone_and_refill.dart`:

```dart
import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';

/// Recover a FIFO wedged at its head — or preemptively declare a
/// still-pending head undeliverable — by archiving the head row as a
/// tombstone, clearing the pending trail, and rewinding `fill_cursor`
/// so the next `fillBatch` rebuilds the events into fresh bundles.
///
/// The sole operator recovery primitive for the drain loop; the only
/// code path by which a FIFO row reaches `final_status == tombstoned`.
///
/// Preconditions (REQ-d00144-A), checked BEFORE opening the transaction
/// so a mis-call does not hold a write lock:
/// - The row identified by [fifoRowId] on [destinationId] SHALL exist.
/// - The row SHALL be the current head of the destination's FIFO
///   (i.e., `readFifoHead(destinationId)` returns this row). Its
///   `final_status` is therefore either `null` (pre-terminal) or
///   `FinalStatus.wedged` (blocking terminal); a `sent` or
///   `tombstoned` target, or a non-head target, is rejected with
///   `ArgumentError`.
///
/// Cascade inside one `StorageBackend.transaction` (REQ-d00144-B+C+D):
/// - Target row flips to `FinalStatus.tombstoned`; `attempts[]` and all
///   other fields preserved.
/// - Every row whose `sequence_in_queue > target.sequence_in_queue` AND
///   whose `final_status IS null` is deleted from the FIFO store.
/// - `fill_cursor_<destinationId>` is rewound to
///   `target.event_id_range.first_seq - 1`.
///
/// Returns a [TombstoneAndRefillResult] (REQ-d00144-E).
// Implements: REQ-d00144-A — head-only + existence preconditions,
// checked pre-transaction so ArgumentError does not hold a write lock.
// Implements: REQ-d00144-B — wedged|null -> tombstoned; attempts[]
// preserved (delegated to backend.setFinalStatusTxn).
// Implements: REQ-d00144-C — trail null rows deleted
// (deleteNullRowsAfterSequenceInQueueTxn).
// Implements: REQ-d00144-D — fill_cursor rewind to target.first_seq-1
// (writeFillCursorTxn).
// Implements: REQ-d00144-E — TombstoneAndRefillResult shape.
Future<TombstoneAndRefillResult> tombstoneAndRefill(
  String destinationId,
  String fifoRowId, {
  required StorageBackend backend,
}) async {
  // REQ-d00144-A: pre-transaction precondition checks.
  final head = await backend.readFifoHead(destinationId);
  if (head == null || head.entryId != fifoRowId) {
    throw ArgumentError.value(
      fifoRowId,
      'fifoRowId',
      'tombstoneAndRefill($destinationId, $fifoRowId): target is not '
          'the current head of the FIFO. readFifoHead returned '
          '${head?.entryId}. (REQ-d00144-A)',
    );
  }
  // head.finalStatus is null or wedged here (readFifoHead contract).
  // No further status check needed.

  final targetFirstSeq = head.eventIdRange.firstSeq;
  final targetSeqInQueue = head.sequenceInQueue;

  return backend.transaction((txn) async {
    // REQ-d00144-B: flip target to tombstoned; attempts[] and other
    // fields preserved by setFinalStatusTxn.
    await backend.setFinalStatusTxn(
      txn,
      destinationId,
      fifoRowId,
      FinalStatus.tombstoned,
    );
    // REQ-d00144-C: delete null rows strictly after target.
    final deletedTrailCount = await backend
        .deleteNullRowsAfterSequenceInQueueTxn(
      txn,
      destinationId,
      targetSeqInQueue,
    );
    // REQ-d00144-D: rewind fill_cursor to target.first_seq - 1.
    final rewoundTo = targetFirstSeq - 1;
    await backend.writeFillCursorTxn(txn, destinationId, rewoundTo);
    // REQ-d00144-E: return the operator-visible counts.
    return TombstoneAndRefillResult(
      targetRowId: fifoRowId,
      deletedTrailCount: deletedTrailCount,
      rewoundTo: rewoundTo,
    );
  });
}
```

- [ ] **Step 7: Update `setFinalStatusTxn` to accept `FinalStatus.tombstoned` and `FinalStatus.wedged`**.

The current implementation (lines 1096-1153 of sembast_backend.dart) only supports `exhausted -> pending` per rehabilitate. Widen its contract so tombstoneAndRefill's `null|wedged -> tombstoned` flip is accepted and nothing else:

```dart
@override
Future<void> setFinalStatusTxn(
  Txn txn,
  String destinationId,
  String entryId,
  FinalStatus status,
) async {
  // Accept: null|wedged -> tombstoned (REQ-d00144-B).
  // Accept: null -> wedged (REQ-d00124-D/E, via markFinal wrapper too).
  // Accept: null -> sent (REQ-d00124-C, via markFinal wrapper too).
  // Reject: any transition TO a terminal that the source row has
  //         already reached (one-way rule preserved).
  //
  // The one-way rule for terminal transitions is implemented below.
  final sembastTxn = _asSembast(txn);
  final store = _fifoStoreOf(destinationId);
  final record = await store.record(entryId).get(sembastTxn);
  if (record == null) {
    throw StateError(
      'setFinalStatusTxn($destinationId, $entryId, $status): target '
      'row not found. (REQ-d00127 callers must check existence.)',
    );
  }
  final currentRaw = (record as Map)['final_status'];
  final current = currentRaw == null
      ? null
      : FinalStatus.fromJson(currentRaw as String);

  // One-way rule: once terminal, no further transitions except the
  // wedged -> tombstoned path owned by tombstoneAndRefill.
  final valid =
      (current == null && (status == FinalStatus.sent ||
                            status == FinalStatus.wedged ||
                            status == FinalStatus.tombstoned)) ||
      (current == FinalStatus.wedged && status == FinalStatus.tombstoned);
  if (!valid) {
    throw StateError(
      'setFinalStatusTxn($destinationId, $entryId): illegal transition '
      '$current -> $status. Legal transitions: null -> {sent, wedged, '
      'tombstoned}; wedged -> tombstoned. (REQ-d00119-D one-way rule.)',
    );
  }
  // Serialize null as null; enum values as their JSON name. sentAt is
  // populated only on the null -> sent transition.
  final updated = Map<String, Object?>.from(record as Map);
  updated['final_status'] = status.toJson();
  if (status == FinalStatus.sent) {
    updated['sent_at'] = DateTime.now().toUtc().toIso8601String();
  }
  await store.record(entryId).put(sembastTxn, updated);
}
```

- [ ] **Step 8: Export the new symbols** from `lib/append_only_datastore.dart`:

Add the two names to the existing export list. Follow the alphabetical / thematic ordering already in the file.

```dart
export 'src/destinations/destination_schedule.dart' show
    // ... existing ...
    TombstoneAndRefillResult;
export 'src/ops/tombstone_and_refill.dart' show tombstoneAndRefill;
```

- [ ] **Step 9: Run tombstoneAndRefill tests**

```bash
(cd apps/common-dart/append_only_datastore && flutter test test/ops/tombstone_and_refill_test.dart)
```

Expected: all pass.

- [ ] **Step 10: Run full test suite + analyze**

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all green. If any test in `sembast_backend_*_test.dart` broke due to the widened `setFinalStatusTxn`, fix inline.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/
git commit -m "[CUR-1154] Phase 4.7 Task 6: implement tombstoneAndRefill (REQ-d00144)"
```

---

### Task 7: Delete `unjam`, `rehabilitate`, and `UnjamResult`

**TASK_FILE**: `PHASE4.7_TASK_7.md`

**Files:**
- Delete: `apps/common-dart/append_only_datastore/lib/src/ops/unjam.dart`
- Delete: `apps/common-dart/append_only_datastore/lib/src/ops/rehabilitate.dart`
- Delete: `apps/common-dart/append_only_datastore/test/ops/unjam_test.dart`
- Delete: `apps/common-dart/append_only_datastore/test/ops/rehabilitate_test.dart`
- Modify: `apps/common-dart/append_only_datastore/lib/src/destinations/destination_schedule.dart` — remove `UnjamResult`.
- Modify: `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart` — remove exports for `unjamDestination`, `rehabilitateExhaustedRow`, `rehabilitateAllExhausted`, `UnjamResult`.
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` — delete `deletePendingRowsTxn`, `maxSentSequenceTxn`, `exhaustedRowsOf` (only used by now-deleted ops).
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` — delete the concrete impls of the three methods above.

**No new tests**. Deletion task.

- [ ] **Step 1: Delete the op files and their tests**

```bash
cd apps/common-dart/append_only_datastore
git rm lib/src/ops/unjam.dart lib/src/ops/rehabilitate.dart
git rm test/ops/unjam_test.dart test/ops/rehabilitate_test.dart
```

- [ ] **Step 2: Remove `UnjamResult` from `destination_schedule.dart`**. Delete the class definition and its doc comment block.

- [ ] **Step 3: Remove exports** from `lib/append_only_datastore.dart`. Delete lines naming `unjamDestination`, `rehabilitateExhaustedRow`, `rehabilitateAllExhausted`, `UnjamResult`.

- [ ] **Step 4: Delete `deletePendingRowsTxn`, `maxSentSequenceTxn`, `exhaustedRowsOf`** from `storage_backend.dart` abstract + `sembast_backend.dart` concrete. Verify no callers remain:

```bash
grep -rn "deletePendingRowsTxn\|maxSentSequenceTxn\|exhaustedRowsOf" apps/common-dart/append_only_datastore/
```

Expected: zero matches after deletion.

- [ ] **Step 5: Run full test suite + analyze**

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all green. The example app's `fifo_panel.dart` still references the deleted symbols at this point; Task 8 fixes that. To keep this task green, either sequence Task 8 immediately (no intervening commit) or temporarily stub the example-app button handlers to `print('unimplemented')` — preference: do Task 8 right after Task 7 and commit them together if it simplifies the test-green requirement. If splitting, comment out the example-app button handlers as a transient step and remove the comment in Task 8.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/
git commit -m "[CUR-1154] Phase 4.7 Task 7: delete unjam, rehabilitate, UnjamResult"
```

---

### Task 8: Swap example app's FifoPanel buttons to tombstoneAndRefill

**TASK_FILE**: `PHASE4.7_TASK_8.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/example/lib/widgets/fifo_panel.dart`
- Modify: `apps/common-dart/append_only_datastore/example/lib/app_state.dart` (if it routes ops)

**No new tests** (per Phase 4.6's design non-goal §4.2: widget tests are not part of the demo).

- [ ] **Step 1: Remove Unjam + Rehabilitate UI affordances**

In `fifo_panel.dart`, delete:
- Import of `rehabilitateAllExhausted` and `rehabilitateExhaustedRow` (from the now-deleted rehabilitate.dart).
- Import of `unjamDestination` (from the now-deleted unjam.dart).
- Unjam button widget, its callback, and any "bulk rehab" button.
- Per-row Rehabilitate button on exhausted rows.

- [ ] **Step 2: Add a TombstoneAndRefill button on the head row**

Shown when the head row's `finalStatus` is `null` (pending with attempts) or `FinalStatus.wedged`. Clicking calls `tombstoneAndRefill(destinationId, rowId)`.

Pattern (adapt to the panel's existing widget conventions):

```dart
import 'package:append_only_datastore/append_only_datastore.dart' show
    tombstoneAndRefill, TombstoneAndRefillResult;

// Inside the head-row widget:
if (headRow.finalStatus == null || headRow.finalStatus == FinalStatus.wedged) {
  ElevatedButton(
    onPressed: () async {
      final result = await tombstoneAndRefill(
        destinationId,
        headRow.entryId,
        backend: appState.backend,
      );
      appState.refresh();  // or whatever the existing refresh pattern is
    },
    child: const Text('Tombstone & Refill'),
  ),
}
```

- [ ] **Step 3: Update `app_state.dart` if it proxies ops**

Look for any `unjam(...)` / `rehabilitate(...)` methods on AppState; replace with `tombstoneAndRefill(...)`.

- [ ] **Step 4: Flutter analyze the example**

```bash
(cd apps/common-dart/append_only_datastore && flutter analyze)
```

Expected: clean. No unused imports, no dangling references.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/example/
git commit -m "[CUR-1154] Phase 4.7 Task 8: FifoPanel uses tombstoneAndRefill"
```

---

### Task 9: Update USER_JOURNEYS.md

**TASK_FILE**: `PHASE4.7_TASK_9.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md`

- [ ] **Step 1: Rewrite the JNY-09 (Recovery) journey** to reflect the new single-primitive recovery.

The current JNY-09 walks operator through Unjam + Rehabilitate. Replace with a single journey that walks:
1. Trigger a wedge on a specific FIFO row (via `DemoDestination`'s controls).
2. Observe drain halts — later rows stay `null`, no deliveries past the wedge.
3. Click "Tombstone & Refill" on the wedged head.
4. Observe:
   - The wedged row is now `tombstoned` in the panel (terminal, retained for audit).
   - Trail rows are gone — `sequence_in_queue` shows a gap between the tombstoned row and the first fresh row.
   - Fresh rows appear after fillBatch runs on the next sync tick.
   - Drain delivers the fresh rows in sequence order.

Keep the journey prose style consistent with existing journeys: `## Actor`, `## Goal`, `## Setup`, `## Steps`, `## Expected Outcome`.

- [ ] **Step 2: Remove any references to unjam or rehabilitate** from other journeys; update if any cross-reference them.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md
git commit -m "[CUR-1154] Phase 4.7 Task 9: update USER_JOURNEYS.md for tombstoneAndRefill"
```

---

### Task 10: Regression test for the #60-before-#59 drift

**TASK_FILE**: `PHASE4.7_TASK_10.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/test/integration/strict_order_regression_test.dart`

**Implements**: regression coverage for REQ-d00124-D+H under a two-row wedge scenario matching the Phase 4.6 demo reproducer.

- [ ] **Step 1: Write the regression test**

```dart
// Regression test for REQ-d00119-D "continue past exhausted" drift.
//
// Phase 4.6 demo surfaced that an exhausted head row #59 did not block
// a trailing pending row #60 — drain skipped past #59 and shipped #60
// before #59 was resolved, producing out-of-order delivery to receipt-
// order-committing destinations. This test asserts the post-fix
// strict-order semantics: drain halts at the wedged head; the trail
// stays pending until operator action.
// Verifies: REQ-d00124-D+H, REQ-d00144-A+B+C+D+F.

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:test/test.dart';
// ... test setup imports ...

void main() {
  group('strict-order regression (REQ-d00119-D drift)', () {
    test('drain halts at wedged #59; #60 stays null until tombstoneAndRefill',
        () async {
      // Arrange: backend with two FIFO rows #59 (events 59-59) and
      // #60 (events 60-60). Secondary destination whose send returns
      // SendPermanent for event #59 and SendOk for event #60.
      // (Use the same DemoDestination-style recording send fn.)
      // ...

      // Act: run drain once.
      await drain(secondaryDest, backend: backend);

      // Assert: #59 is wedged; #60 is still null; destination received
      // no deliveries past #59.
      final r59 = await backend.readFifoRow(destId, row59.entryId);
      final r60 = await backend.readFifoRow(destId, row60.entryId);
      expect(r59!.finalStatus, FinalStatus.wedged);
      expect(r60!.finalStatus, isNull);
      expect(secondaryDest.delivered, equals(<int>[]));  // nothing delivered

      // Act: operator runs tombstoneAndRefill on wedged head.
      final result = await tombstoneAndRefill(
        destId,
        row59.entryId,
        backend: backend,
      );
      expect(result.deletedTrailCount, 1);  // #60 was in the trail
      expect(result.rewoundTo, 58);  // #59 first_seq - 1 = 58

      // Act: fillBatch + drain.
      await fillBatch(secondaryDest, backend: backend);
      // Configure sendFn to succeed on both events after operator fix.
      secondaryDest.sendOverrides
        ..clear()
        ..add(SendOk())  // fresh bundle covering events 59-60
        ..add(SendOk());
      await drain(secondaryDest, backend: backend);

      // Assert: fresh bundle delivered both events in sequence order.
      expect(secondaryDest.delivered, equals(<int>[59, 60]));
    });
  });
}
```

- [ ] **Step 2: Run the regression test**

```bash
(cd apps/common-dart/append_only_datastore && flutter test test/integration/strict_order_regression_test.dart)
```

Expected: pass.

- [ ] **Commit**:

```bash
git add apps/common-dart/append_only_datastore/test/integration/strict_order_regression_test.dart
git commit -m "[CUR-1154] Phase 4.7 Task 10: regression test for strict-order drift"
```

---

### Task 11: Final verification

**TASK_FILE**: `PHASE4.7_TASK_11.md`

**No file changes** — verification only.

- [ ] **Step 1: Full test suite**

```bash
(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)
```

Expected: all green.

- [ ] **Step 2: Flutter analyze on the example app**

```bash
(cd apps/common-dart/append_only_datastore/example && flutter analyze)
```

Expected: clean.

- [ ] **Step 3: Grep for stale references**

```bash
grep -rn "FinalStatus.pending\|FinalStatus.exhausted\|ExhaustedFifoSummary\|unjamDestination\|rehabilitateExhausted\|rehabilitateAllExhausted\|UnjamResult\|deletePendingRowsTxn\|maxSentSequenceTxn\|exhaustedRowsOf" apps/common-dart/append_only_datastore/
```

Expected: zero matches in `lib/` and `test/`. The only expected hit is in historical commit messages or squashed-out files (N/A post-squash).

- [ ] **Step 4: Verify spec consistency**

```bash
grep -n "REQ-d00131\|REQ-d00132\|exhausted" spec/dev-event-sourcing-mobile.md spec/INDEX.md
```

Expected: zero matches for REQ-d00131 and REQ-d00132 (except possibly in unrelated rationale text referencing the concept of exhaustion in a past tense). Zero matches for `"exhausted"` as a status name; `"wedge"` / `"wedged"` describe the state.

- [ ] **Step 5: Update `PHASE_4.7_WORKLOG.md`** with the completion checklist + summary. Mark all tasks complete.

- [ ] **Commit**:

```bash
git add PHASE_4.7_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.7 Task 11: final verification + worklog close"
```

---

### Task 12: Phase squash

**TASK_FILE**: `PHASE4.7_TASK_12.md`

- [ ] **Step 1: Review the phase's commit log**

```bash
git log --oneline origin/main..HEAD | head -30
```

Confirm all commits since Phase 4.6's squash are Phase 4.7 commits; no cross-contamination.

- [ ] **Step 2: Squash into a single commit**

Per README's phase-boundary squash procedure:

```bash
git reset --soft <phase-4.6-commit-sha>
git commit -m "[CUR-1154] Phase 4.7: strict-order drain semantics fix

- REQ-d00119-C/E: final_status nullable; enum {sent, wedged, tombstoned};
  sequence_in_queue monotonic + never reused.
- REQ-d00124-A/D/E/H: drain halts at wedged head; readFifoHead returns
  first {null, wedged}; {sent, tombstoned} are terminal-passable.
- REQ-d00144 (new): tombstoneAndRefill — sole operator recovery
  primitive; atomic cascade (target -> tombstoned, trail null rows
  deleted, fill_cursor rewound to target.first_seq - 1).
- REQ-d00122 rationale: multi-Destination pattern for per-topic
  ordering isolation.
- REQ-d00123-E, REQ-d00127 rationale: terminology update.
- REQ-d00131, REQ-d00132 removed; unjam / rehabilitate collapsed into
  tombstoneAndRefill.
- ExhaustedFifoSummary -> WedgedFifoSummary; exhaustedFifos -> wedgedFifos.
- Example FifoPanel: single TombstoneAndRefill button replaces Unjam +
  Rehabilitate.
- USER_JOURNEYS.md JNY-09 rewritten for the new recovery flow.
- Regression test: two-destination #60-before-#59 drift.

Design spec: docs/superpowers/specs/2026-04-23-strict-order-drain-fix-design.md
"
```

- [ ] **Step 3: Verify HEAD is the single Phase 4.7 commit**

```bash
git log --oneline origin/main..HEAD
```

Expected: one line, the squash commit above Phase 4.6's squash.

- [ ] **Step 4: Force-push only after confirming with the user** (per CLAUDE.md safety rules). Do NOT force-push without explicit authorization.

Phase complete.

---

## Self-review of this plan

**Spec coverage:**
- REQ-d00119-C (nullable + enum) → Task 3.
- REQ-d00119-D (retain) → Task 3 (no code change; invariant holds).
- REQ-d00119-E (monotonic sequence_in_queue) → Task 3 (test + verify impl).
- REQ-d00122 rationale → Task 2.
- REQ-d00123-E terminology → Task 2.
- REQ-d00124-A (readFifoHead) → Task 5.
- REQ-d00124-D (SendPermanent → wedged) → Tasks 3 + 5.
- REQ-d00124-E (SendTransient at max → wedged) → Tasks 3 + 5.
- REQ-d00124-H (halt at wedged) → Task 5.
- REQ-d00127 rationale → Task 2.
- REQ-d00131 removal → Tasks 2 + 7.
- REQ-d00132 removal → Tasks 2 + 7.
- REQ-d00144-A (head-only precondition) → Task 6.
- REQ-d00144-B (target transition, attempts preserved) → Task 6.
- REQ-d00144-C (trail delete) → Task 6.
- REQ-d00144-D (cursor rewind) → Task 6.
- REQ-d00144-E (result shape) → Task 6.
- REQ-d00144-F (next fillBatch re-promotes) → Task 6.

All design-spec items mapped to tasks.

**Placeholder scan:** No TBDs or placeholder phrases. Every step either contains specific code / command / file reference or is a narrowly scoped mechanical action (e.g., "update the doc comment block").

**Type consistency:** `FinalStatus?`, `FinalStatus.wedged`, `FinalStatus.tombstoned`, `TombstoneAndRefillResult { targetRowId, deletedTrailCount, rewoundTo }`, `tombstoneAndRefill(String destId, String fifoRowId, {required StorageBackend backend})`, `deleteNullRowsAfterSequenceInQueueTxn(Txn, String, int) -> int` used consistently across Tasks 3, 5, 6, 7, 8, 10.
