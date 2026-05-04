# Master Plan Phase 4.10: Wedge-Aware fillBatch Skip

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `fillBatch(destination)` return without promoting events when the destination's FIFO head is wedged, eliminating the speculative bundle/delete/rebundle round-trip on `tombstoneAndRefill` recovery.

**Architecture:** One early-return at the top of `fillBatch` — read the FIFO head; if its `final_status == FinalStatus.wedged`, return. No event-log walk, no transform call, no FIFO row write, no `fill_cursor` advance during the wedge. Recovery via `tombstoneAndRefill` (rewinds cursor) or `rehabilitate` (cursor preserved, next fill walks from wedge-time cursor). Library-only, additive, no new REQ number — extends REQ-d00128 with one assertion (REQ-d00128-I).

**Tech Stack:** Dart, sembast (in-memory for tests), `package:flutter_test/flutter_test.dart`. Uses existing `event_sourcing_datastore` primitives (`StorageBackend.readFifoHead`, `FinalStatus.wedged`, `markFinal`).

**Design spec:** `docs/superpowers/specs/2026-04-24-phase4.10-wedge-aware-fillbatch-design.md`.

**Decisions log:** `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (see Phase 4.10 section for pinned decisions — do not re-litigate).

**Branch:** `mobile-event-sourcing-refactor` (shared). **Ticket:** CUR-1154 (continuation). **Phase:** 4.10 (after 4.9). **Depends on:** Phase 4.9 (sync-through ingest) complete on HEAD (commit `55fdd0ab`+).

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00128 (extension) | New assertion I — `fillBatch` SHALL early-return without state mutation when `readFifoHead` returns a wedged row. Cursor not advanced. | Task 2 (spec); Task 3 (failing tests); Task 4 (implementation); Task 5 (recovery test) |
| REQ-d00124-H (cross-reference, unchanged) | Drain halts on wedged head — the rule that makes wedge-skip the right behavior | Comment-only cross-reference in `fill_batch.dart` |

---

## Execution rules

Read `README.md` in the plans directory for TDD cadence and REQ-citation conventions. NOTE: the per-phase squash procedure described there is OUT OF DATE for this phase — user confirmed PR is squash-merge, so no per-phase squash. Each task = one commit on the branch.

Read the design spec `docs/superpowers/specs/2026-04-24-phase4.10-wedge-aware-fillbatch-design.md` end-to-end before Task 1. Re-read §2.1 (behavior change), §2.2 (cursor handling), §6 (REQ-traceability comments) before Task 4.

**Project conventions to follow:**

- Implementer MUST use explicit `git add <files>`, NEVER `git add <directory>` or `git add -A`. User has parallel WIP in `apps/common-dart/event_sourcing_datastore/example/`.
- Pre-commit hook regenerates `spec/INDEX.md` REQ hashes — let it run; if it modifies the staged set, re-stage `spec/INDEX.md` and re-commit. No `--no-verify`.
- Test framework is `package:flutter_test/flutter_test.dart` (not bare `package:test/test.dart`).
- Project lints enforce `prefer_constructors_over_static_methods` — use factory constructors not static helpers for type-returning helpers.
- Per-function `// Implements: REQ-xxx-Y — <prose>` and per-test `// Verifies: REQ-xxx-Y` markers (per `README.md` §"REQ citation convention").
- Greenfield mode (per `PHASE_4.10-4.13_DECISIONS_LOG.md` §XP.1): no backward-compat code, no transition logic, no "preserves prior behavior" wording.

**Phase invariants** (must be true at end of phase):

1. `flutter test` clean in `apps/common-dart/event_sourcing_datastore`.
2. `flutter analyze` clean in `apps/common-dart/event_sourcing_datastore` AND in `apps/common-dart/event_sourcing_datastore/example`.
3. `flutter test` clean in `apps/common-dart/provenance` (no changes expected, but verify nothing regressed).
4. Test count for `event_sourcing_datastore`: ≥ 564 + 2 (the two new tests from Task 3 / Task 5).
5. Demo example app builds (`cd apps/common-dart/event_sourcing_datastore/example && flutter analyze`); no FifoPanel / demo-app code change in this phase.

---

## Plan

### Task 1: Baseline verification + worklog

**Files:**

- Create: `PHASE_4.10_WORKLOG.md` at repo root (mirror `PHASE_4.9_WORKLOG.md` structure if it exists; otherwise minimal: title, ticket, design-spec link, decisions-log link, task checklist).

- [ ] **Step 1: Confirm Phase 4.9 is committed on HEAD**

```bash
git log --oneline -5
```

Expected: top commits include `55fdd0ab [CUR-1154] Phase 4.9 follow-up: full batch reconstruction test ...` (or later HEAD). If any uncommitted changes exist that are not the current task's, stop and surface to the orchestrator — do not proceed.

- [ ] **Step 2: Run `event_sourcing_datastore` tests; confirm 564 pass**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -20)
```

Expected: `All tests passed!` and `+564` (or higher; baseline from initial briefing).

- [ ] **Step 3: Run `provenance` tests; confirm 38 pass**

```bash
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -20)
```

Expected: `All tests passed!` and `+38`.

- [ ] **Step 4: Run analyze on both packages + example**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -5)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -5)
```

Expected for each: `No issues found!`. If any package reports issues, stop — those issues belong to a prior phase, not this one.

- [ ] **Step 5: Write the worklog stub**

Create `PHASE_4.10_WORKLOG.md` at repo root with:

```markdown
# Phase 4.10 Worklog — Wedge-Aware fillBatch Skip (CUR-1154)

**Spec:** docs/superpowers/specs/2026-04-24-phase4.10-wedge-aware-fillbatch-design.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.10 section)
**Branch:** mobile-event-sourcing-refactor

## Baseline (Task 1)

- event_sourcing_datastore: <FILL IN: pass count from Step 2>
- provenance: <FILL IN: pass count from Step 3>
- analyze (lib + example + provenance): clean

## Tasks

- [ ] Task 1: Baseline + worklog
- [ ] Task 2: Spec change — REQ-d00128-I
- [ ] Task 3: Failing tests for REQ-d00128-I
- [ ] Task 4: Implementation — wedge-skip early return
- [ ] Task 5: Recovery test — post-tombstoneAndRefill in-one-pass fill
- [ ] Task 6: Final verification + close worklog
```

Replace `<FILL IN: ...>` with the actual numbers observed in Steps 2 and 3.

- [ ] **Step 6: Commit**

```bash
git add PHASE_4.10_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.10 Task 1: baseline + worklog"
```

---

### Task 2: Spec change — add REQ-d00128-I

**Files:**

- Modify: `spec/dev-event-sourcing-mobile.md` (REQ-d00128 section, ~line 406–436).

- [ ] **Step 1: Read the current REQ-d00128 block**

```bash
grep -n "REQ-d00128" spec/dev-event-sourcing-mobile.md | head
```

Locate the assertion list (current assertions A–H) and the `*End* *FIFO Batch Shape and Fill Cursor* | **Hash**: ...` close marker.

- [ ] **Step 2: Append assertion I to the assertion list**

After the existing assertion H (the idempotency-on-no-new-events rule), and BEFORE the `*End*` marker, insert:

```markdown
I. `fillBatch(destination)` SHALL return without promoting any events when `backend.readFifoHead(destination.id)` returns a row whose `final_status` is `FinalStatus.wedged`. The early return SHALL NOT advance `fill_cursor` and SHALL NOT call `Destination.transform`. Recovery via `tombstoneAndRefill` (REQ-d00144) rewinds `fill_cursor` so the next `fillBatch` promotes the covered events in one pass against the current transform and destination state. Recovery via `rehabilitate` (REQ-d00132) leaves `fill_cursor` unchanged; the next `fillBatch` walks the event log from the wedge-time cursor.
```

(Use real newlines, not literal `\n`. One blank line between assertion H and assertion I.)

- [ ] **Step 3: Extend the rationale paragraph for REQ-d00128**

In the `## Rationale` section of REQ-d00128 (currently three paragraphs ending with the `canAddToBatch` paragraph), append a fourth paragraph:

```markdown
Drain halts at a wedged head per REQ-d00124-H, so any FIFO row promoted behind a wedged head is speculative work that `tombstoneAndRefill`'s trail-delete sweep (REQ-d00144-C) would have to undo. `fillBatch` therefore early-returns when the destination's head is wedged: no event-log walk, no `Destination.transform` call, no FIFO row write, no `fill_cursor` advance. After `tombstoneAndRefill` rewinds the cursor, the next `fillBatch` promotes the covered events in one pass against the current (post-fix) transform and destination state. The wedge-skip eliminates the bundle/delete/rebundle round-trip on the dominant wedge-recovery path.
```

- [ ] **Step 4: Re-run analyze on touched packages (sanity)**

Spec edits do not affect Dart analyze, but verify no accidental cross-impact:

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -5)
```

Expected: `No issues found!`.

- [ ] **Step 5: Commit**

The pre-commit hook regenerates `spec/INDEX.md` REQ hashes. Stage both:

```bash
git add spec/dev-event-sourcing-mobile.md
git commit -m "[CUR-1154] Phase 4.10 Task 2: spec REQ-d00128-I (wedge-aware fillBatch)"
```

If the pre-commit hook modifies `spec/INDEX.md`, re-stage and re-commit:

```bash
git add spec/INDEX.md spec/dev-event-sourcing-mobile.md
git commit -m "[CUR-1154] Phase 4.10 Task 2: spec REQ-d00128-I (wedge-aware fillBatch)"
```

---

### Task 3: Failing tests for REQ-d00128-I (wedge-skip writes nothing)

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_test.dart`

- [ ] **Step 1: Read the existing test file structure** to confirm helpers and group placement

```bash
sed -n '1,70p' apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_test.dart
```

Confirm: `_appendEvent` helper at top of file; `group('fillBatch()', ...)` wraps all tests; `setUp` opens an in-memory `SembastBackend`. Existing tests use `FakeDestination` and `DestinationSchedule` — both already imported.

- [ ] **Step 2: Add the wedge-skip test inside the `group('fillBatch()', ...)` block**

Insert after the last existing test in the group (right before the closing `});` of the group), before any drain/sync_cycle logic:

```dart
// Verifies: REQ-d00128-I — when readFifoHead returns a wedged row,
// fillBatch returns without enqueueing any new rows, without calling
// Destination.transform, and without advancing fill_cursor.
test(
  'REQ-d00128-I: fillBatch is a no-op when FIFO head is wedged',
  () async {
    // Step 1: enqueue one matching event and let fillBatch promote it
    // into a FIFO row, then mark that row wedged. This is the wedge
    // setup the new behavior must respect.
    await _appendEvent(
      backend,
      eventId: 'e1',
      clientTimestamp: DateTime.utc(2026, 4, 22, 11),
    );
    final dest = FakeDestination(id: 'fake', batchCapacity: 10);
    final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
    await fillBatch(
      dest,
      backend: backend,
      schedule: schedule,
      clock: () => DateTime.utc(2026, 4, 22, 12),
    );
    final wedgedRow = await backend.readFifoHead('fake');
    expect(wedgedRow, isNotNull);
    await backend.markFinal('fake', wedgedRow!.entryId, FinalStatus.wedged);

    // Step 2: snapshot post-wedge state.
    final cursorBeforeSecondFill = await backend.readFillCursor('fake');
    final transformCallsBefore = dest.transformCalls;

    // Step 3: append more matching events, then call fillBatch again.
    // The new behavior: it must NOT promote them, NOT advance cursor,
    // NOT call transform.
    await _appendEvent(
      backend,
      eventId: 'e2',
      clientTimestamp: DateTime.utc(2026, 4, 22, 11, 30),
    );
    await _appendEvent(
      backend,
      eventId: 'e3',
      clientTimestamp: DateTime.utc(2026, 4, 22, 11, 45),
    );

    await fillBatch(
      dest,
      backend: backend,
      schedule: schedule,
      clock: () => DateTime.utc(2026, 4, 22, 12),
    );

    // Cursor unchanged.
    expect(await backend.readFillCursor('fake'), cursorBeforeSecondFill);
    // No additional transform calls.
    expect(dest.transformCalls, transformCallsBefore);
    // Head is still the wedged row, with status wedged.
    final headAfter = await backend.readFifoHead('fake');
    expect(headAfter, isNotNull);
    expect(headAfter!.entryId, wedgedRow.entryId);
    expect(headAfter.finalStatus, FinalStatus.wedged);
  },
);
```

- [ ] **Step 3: Verify `FakeDestination` exposes `transformCalls`; if not, add it**

```bash
grep -n 'transformCalls' apps/common-dart/event_sourcing_datastore/test/test_support/fake_destination.dart
```

If absent, modify `fake_destination.dart` to track transform invocations. Add a counter field and increment it in the `transform` override:

```dart
/// Count of times `transform` has been invoked. Used by Phase 4.10
/// wedge-skip tests to assert `transform` is NOT called when fillBatch
/// early-returns on a wedged head (REQ-d00128-I).
int transformCalls = 0;

@override
Future<WirePayload> transform(List<StoredEvent> batch) {
  transformCalls += 1;
  // ... existing body unchanged ...
}
```

(Read the existing `transform` body and increment at the top before the existing logic. Do NOT remove or alter the existing `ArgumentError` on empty batch.)

- [ ] **Step 4: Verify needed imports are present in `fill_batch_test.dart`**

```bash
head -15 apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_test.dart
```

Required: `final_status.dart` for `FinalStatus.wedged`. If absent, add:

```dart
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
```

- [ ] **Step 5: Run the new test; verify it FAILS for the right reason**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test --plain-name 'REQ-d00128-I' 2>&1 | tail -30)
```

Expected: the test fails with an assertion failure on `cursorBeforeSecondFill` (the cursor advanced past it) OR on `transformCalls` (transform was called). The failure proves the test is wired correctly.

If the test fails for an unrelated reason (e.g., import missing, type mismatch), fix the test setup and re-run until you see the assertion-failure mode.

- [ ] **Step 6: Commit the failing test**

```bash
git add apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_test.dart \
        apps/common-dart/event_sourcing_datastore/test/test_support/fake_destination.dart
git commit -m "[CUR-1154] Phase 4.10 Task 3: failing test for REQ-d00128-I (wedge-skip)"
```

---

### Task 4: Implementation — wedge-skip early return in fillBatch

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/sync/fill_batch.dart`

- [ ] **Step 1: Re-read the existing function to understand insertion point**

```bash
sed -n '40,80p' apps/common-dart/event_sourcing_datastore/lib/src/sync/fill_batch.dart
```

Confirm: function starts ~line 52, dormant-schedule check on line 61, window-bound check on line 70, `readFillCursor` call on line 73. New check goes between window-bound check (line 70) and cursor read (line 73).

- [ ] **Step 2: Add `FinalStatus` import**

At the top of the file, alongside other `package:event_sourcing_datastore/src/...` imports, add:

```dart
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
```

- [ ] **Step 3: Insert the wedge-skip early-return**

Between the window-bound check and the `readFillCursor` call, insert:

```dart
  // REQ-d00128-I — wedge-aware skip. If the destination's FIFO head is
  // wedged, drain halts at it (REQ-d00124-H), so any row we promote
  // behind it would be speculative work that tombstoneAndRefill's
  // trail-delete sweep (REQ-d00144-C) would have to undo. Return
  // without promoting; recovery rewinds fill_cursor and the next
  // fillBatch fills in one pass.
  final head = await backend.readFifoHead(destination.id);
  if (head?.finalStatus == FinalStatus.wedged) return;
```

Place this AFTER `if (schedule.startDate!.isAfter(upper)) return;` and BEFORE `final fillCursor = await backend.readFillCursor(destination.id);`.

- [ ] **Step 4: Update the function-level `// Implements:` comment block**

Find the existing block above the function declaration (currently ~lines 45–51):

```dart
// Implements: REQ-d00128-E+F+G+H — canAddToBatch-driven batch assembly,
// maxAccumulateTime hold on single-event batches, fill_cursor advance
// to batch.last.sequenceNumber, idempotent no-op when no new matching
// events.
// Implements: REQ-d00129-I — filter candidates by
// client_timestamp ∈ [startDate, min(endDate, now())]; events outside
// the window are never enqueued.
```

Replace with:

```dart
// Implements: REQ-d00128-E+F+G+H+I — canAddToBatch-driven batch assembly,
// maxAccumulateTime hold on single-event batches, fill_cursor advance to
// batch.last.sequenceNumber, idempotent no-op when no new matching events,
// and wedge-aware early return when readFifoHead's row is wedged.
// Implements: REQ-d00129-I — filter candidates by
// client_timestamp ∈ [startDate, min(endDate, now())]; events outside
// the window are never enqueued.
// Honors: REQ-d00124-H — drain halts on a wedged head; the wedge-skip
// branch above avoids speculative rows that tombstoneAndRefill would
// have to undo.
```

- [ ] **Step 5: Update the doc-comment algorithm steps above the function**

The existing doc comment (~lines 10–48) lists steps 1–8. Insert a new step between today's step 2 (window-closed check) and today's step 3 (read fill_cursor). Renumber today's 3–8 to 4–9. The new step:

```text
/// 3. Read `readFifoHead(destination.id)`. If the returned row's
///    `final_status == FinalStatus.wedged`, return — drain halts at a
///    wedged head (REQ-d00124-H), so any row promoted now would be
///    speculative work that `tombstoneAndRefill`'s trail-delete sweep
///    (REQ-d00144-C) would undo. Recovery rewinds `fill_cursor`
///    (REQ-d00128-I) and the next `fillBatch` promotes in one pass.
```

- [ ] **Step 6: Run the wedge-skip test; verify it PASSES**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test --plain-name 'REQ-d00128-I' 2>&1 | tail -10)
```

Expected: `All tests passed!`.

- [ ] **Step 7: Run the FULL `event_sourcing_datastore` test suite; verify nothing regressed**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -10)
```

Expected: `+565` (baseline 564 + 1 new test from Task 3) or higher. `All tests passed!`.

- [ ] **Step 8: Run analyze; verify clean**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -5)
```

Expected: `No issues found!`.

- [ ] **Step 9: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/sync/fill_batch.dart
git commit -m "[CUR-1154] Phase 4.10 Task 4: implement REQ-d00128-I wedge-skip"
```

---

### Task 5: Recovery test — post-tombstoneAndRefill in-one-pass fill

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_test.dart`

- [ ] **Step 1: Locate `tombstoneAndRefill` operator and its import path**

```bash
grep -rn 'tombstoneAndRefill' apps/common-dart/event_sourcing_datastore/lib/src/ | head -5
```

Note the import path. The operator may live under `lib/src/sync/ops/` or similar.

- [ ] **Step 2: Add the recovery test inside the same `group('fillBatch()', ...)` block, after the wedge-skip test from Task 3**

```dart
// Verifies: REQ-d00128-I (recovery half) — after the wedged head is
// tombstoned and refilled, the next fillBatch promotes events that
// arrived during the wedge in one pass against the rewound cursor.
test(
  'REQ-d00128-I: post-tombstoneAndRefill, fillBatch promotes wedge-era '
  'events in one pass',
  () async {
    // Setup: destination with batchCapacity=10 (so a single fillBatch
    // can produce one row covering many events).
    final dest = FakeDestination(id: 'fake', batchCapacity: 10);
    final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
    final clock = () => DateTime.utc(2026, 4, 22, 12);

    // Phase A: enqueue + wedge a single-event row (e1).
    await _appendEvent(
      backend,
      eventId: 'e1',
      clientTimestamp: DateTime.utc(2026, 4, 22, 10),
    );
    await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);
    final wedged = await backend.readFifoHead('fake');
    expect(wedged, isNotNull);
    await backend.markFinal('fake', wedged!.entryId, FinalStatus.wedged);

    // Phase B: append two MORE matching events while wedged. fillBatch
    // wedge-skips both invocations — no FIFO rows added, no cursor
    // advance.
    await _appendEvent(
      backend,
      eventId: 'e2',
      clientTimestamp: DateTime.utc(2026, 4, 22, 10, 30),
    );
    await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);
    await _appendEvent(
      backend,
      eventId: 'e3',
      clientTimestamp: DateTime.utc(2026, 4, 22, 11),
    );
    await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);

    // Sanity: still only the wedged row in the FIFO.
    expect(await backend.readFifoHead('fake'), isNotNull);
    expect((await backend.readFifoHead('fake'))!.entryId, wedged.entryId);

    // Phase C: operator tombstoneAndRefill — flips wedged -> tombstoned,
    // rewinds fill_cursor.
    await tombstoneAndRefill(
      'fake',
      wedged.entryId,
      backend: backend,
    );

    // Phase D: next fillBatch. Promotes e1, e2, e3 in ONE pass into
    // ONE FIFO row (batchCapacity=10 admits all three), advances
    // fill_cursor to e3.sequenceNumber.
    await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);

    final fresh = await backend.readFifoHead('fake');
    expect(fresh, isNotNull);
    expect(fresh!.eventIds, ['e1', 'e2', 'e3']);
    expect(fresh.finalStatus, isNull);
    expect(await backend.readFillCursor('fake'), 3);
  },
);
```

- [ ] **Step 3: Add the `tombstoneAndRefill` import to `fill_batch_test.dart`** (using path discovered in Step 1)

Example (substitute actual path):

```dart
import 'package:event_sourcing_datastore/src/sync/ops/tombstone_and_refill.dart';
```

- [ ] **Step 4: Run the recovery test; verify PASSES**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test --plain-name 'post-tombstoneAndRefill' 2>&1 | tail -10)
```

Expected: `All tests passed!`. If it fails, the most likely cause is `tombstoneAndRefill`'s rewind-target math — re-read REQ-d00131 / REQ-d00144 to confirm what `fill_cursor` value the rewind picks for a destination whose only sent row is `-1` (i.e., none sent yet). Adjust test expectations only if they encode an incorrect understanding of `tombstoneAndRefill`; do NOT loosen them just to pass.

- [ ] **Step 5: Run the full test suite; verify nothing regressed**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -10)
```

Expected: `+566` (baseline 564 + 2 new tests). `All tests passed!`.

- [ ] **Step 6: Run analyze; verify clean**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -5)
```

Expected: `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_test.dart
git commit -m "[CUR-1154] Phase 4.10 Task 5: recovery test for REQ-d00128-I"
```

---

### Task 6: Final verification + close worklog

**Files:**

- Modify: `PHASE_4.10_WORKLOG.md`

- [ ] **Step 1: Run the FULL phase invariant set**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -5)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -5)
```

All five must show `All tests passed!` / `No issues found!`. Provenance pass count: 38 (unchanged). `event_sourcing_datastore` pass count: ≥ 566.

- [ ] **Step 2: Mark all tasks complete in `PHASE_4.10_WORKLOG.md`**

Edit the worklog: change every `- [ ]` to `- [x]` in the Tasks section. Add a "Final verification" section with the test/analyze command outputs.

- [ ] **Step 3: Append a "Phase 4.10 closed" line to the decisions log**

In `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md`, under "Phase 4.10" section, add a line at the bottom:

```markdown
**Closed:** 2026-04-24. Final verification: event_sourcing_datastore +566, provenance +38, all analyze clean.
```

- [ ] **Step 4: Commit the worklog and decisions-log updates**

```bash
git add PHASE_4.10_WORKLOG.md docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md
git commit -m "[CUR-1154] Phase 4.10 Task 6: close worklog (final verify clean)"
```

- [ ] **Step 5: Surface phase-end summary to orchestrator**

Report: phase commits range (`<first>..<last>`), final test counts, any unexpected behavior or judgment calls beyond what's pinned in the decisions log.

---

## What does NOT change in this phase

- `StorageBackend` interface — no new methods. (`readFifoHead` already exists; we just call it earlier.)
- `Destination` interface — no new methods.
- `Drain`, `SyncCycle`, `EntryService`, materializers, schedules — untouched.
- The example demo app's `FifoPanel` — see §4 of the design spec; the "trail stays empty during wedge" UX consequence is documented but not implemented in this phase.
- Any other REQ — only REQ-d00128 grows by one assertion (I).
