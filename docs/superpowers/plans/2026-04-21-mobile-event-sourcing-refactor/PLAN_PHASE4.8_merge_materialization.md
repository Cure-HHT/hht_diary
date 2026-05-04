# Master Plan Phase 4.8: Merge-Semantics Materialization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace REQ-d00121-B/C's whole-replace materialization with key-wise merge so each event captures the change (the delta) rather than the full resulting state; update REQ-d00133-F's no-op detection to a merge-aware rule; preserve all other library semantics.

**Architecture:** One fold-function change in `DiaryEntriesMaterializer.foldPure` (finalized/checkpoint branches merge instead of whole-replace; tombstone unchanged). One no-op-detection refactor in `EntryService.record` (read the materialized row, merge the candidate delta, compare against prior; tombstone short-circuits on `isDeleted==true`). No public API shape changes. Caller API `record({answers: Map, ...})` unchanged in signature; the semantic of `answers` shifts from "full new state" to "delta the caller chose to apply." Consumer apps are not touched (their cutover is Phase 5).

**Tech Stack:** Dart / Flutter, sembast, `package:collection`'s `DeepCollectionEquality`, the `event_sourcing_datastore` package under `apps/common-dart/event_sourcing_datastore`.

**Design spec:** `docs/superpowers/specs/2026-04-23-merge-materialization-design.md`.

**Branch**: `mobile-event-sourcing-refactor` (shared). **Ticket**: CUR-1154 (continuation). **Phase**: 4.8 (after 4.7). **Depends on**: Phase 4.7 complete. The branch currently has Phase 4.7 + fork restructure + Phase 4.8 design spec committed; this plan is ready to execute on top of that.

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00121-B | finalized merges delta into prior current_answers | Task 3 |
| REQ-d00121-C | checkpoint merges delta into prior current_answers | Task 3 |
| REQ-d00121-D | tombstone unchanged (preserves current_answers, flips is_deleted) | Task 3 (regression) |
| REQ-d00121-J (NEW) | absent-vs-present-null distinction preserved in fold | Task 3 |
| REQ-d00133-F | no-op detection is merge-aware | Task 4 |

---

## Execution rules

Read `README.md` in the plans directory for TDD cadence, phase-boundary squash (user has opted to squash on PR merge, so no per-phase squash is needed this time), cross-phase invariants, and REQ-citation conventions. At phase end, `flutter test` and `flutter analyze` must be clean on `event_sourcing_datastore` and its example.

Read the design spec `docs/superpowers/specs/2026-04-23-merge-materialization-design.md` in full before Task 1. Particular attention to §2.1 (merge rule), §2.5 (no-op under merge), §2.8 (sync-through compatibility — this phase does not touch the ingest path but its correctness depends on the purity of `Materializer.apply`).

---

## Plan

### Task 1: Baseline verification + worklog

**TASK_FILE**: `PHASE4.8_TASK_1.md`

**Files:**
- Create: `PHASE_4.8_WORKLOG.md` at repo root (mirror the Phase 4.7 structure).
- Create: `PHASE4.8_TASK_1.md` at repo root.

- [ ] **Confirm Phase 4.8 spec is committed**:

```bash
git log --oneline | grep "Phase 4.8\|merge-materialization" | head
```

Expected: shows `[CUR-1154] Design spec: merge-semantics materialization (Phase 4.8)` and the `§2.8 sync-through compatibility` fixup commit.

- [ ] **Baseline tests — all green**:

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
```

Expected: all tests pass (~492 as of Phase 4.7-and-fork HEAD); `flutter analyze` clean. Record the exact test count in the TASK_FILE.

- [ ] **Create `PHASE_4.8_WORKLOG.md`** at repo root mirroring `PHASE_4.7_WORKLOG.md`'s structure. Populate with:
  - Phase: 4.8 — merge-semantics materialization
  - Ticket: CUR-1154 (continuation, no new ticket)
  - Design doc: `docs/superpowers/specs/2026-04-23-merge-materialization-design.md`
  - Plan doc: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.8_merge_materialization.md`
  - REQ-d substitution table: no new REQ numbers claimed (REQ-d00121 extended with assertion J, REQ-d00121-B/C rewritten, REQ-d00133-F rewritten).

- [ ] **Create `PHASE4.8_TASK_1.md`** at repo root summarizing baseline SHA, test count, and plan anchor.

- [ ] **Commit**:

```bash
git add PHASE_4.8_WORKLOG.md PHASE4.8_TASK_1.md
git commit -m "[CUR-1154] Phase 4.8 Task 1: baseline + worklog"
```

---

### Task 2: Spec changes

**TASK_FILE**: `PHASE4.8_TASK_2.md`

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md` (REQ-d00121 assertions B, C, add J; REQ-d00121 rationale; REQ-d00133 rationale + assertion F).
- Modify: `spec/INDEX.md` — regenerate hash for REQ-d00121 and REQ-d00133 via pre-commit hook.

**No tests in this task** — spec text only.

- [ ] **Read the current REQ-d00121 section in `spec/dev-event-sourcing-mobile.md`**. It's around line 181 (was unchanged by Phase 4.7). Confirm the current assertion B/C/D text + rationale — Phase 4.7's spec work didn't touch this REQ.

- [ ] **Rewrite REQ-d00121 assertion B**:

> B. When `event.event_type` equals `"finalized"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_complete` is `true` and whose `current_answers` equals the key-wise merge of `previous.current_answers` (or the empty map when `previous` is null) under `event.data.answers`: for each key `k` present in `event.data.answers`, the merged value SHALL equal `event.data.answers[k]` — including when that value is `null` (explicit clear); for each key `k` absent from `event.data.answers`, the merged value SHALL equal `previous.current_answers[k]` (prior value preserved).

- [ ] **Rewrite REQ-d00121 assertion C**:

> C. When `event.event_type` equals `"checkpoint"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_complete` is `false` and whose `current_answers` is produced by the same key-wise merge rule as assertion B.

- [ ] **REQ-d00121 assertion D — unchanged**. Tombstone still preserves `current_answers` and flips `is_deleted` to `true`.

- [ ] **Add new REQ-d00121 assertion J** (insert after the existing I):

> J. `Materializer.apply` SHALL distinguish "key absent from `event.data.answers`" from "key present with value `null`" when computing the merged `current_answers`: the first preserves `previous.current_answers[key]`; the second sets `merged[key]` to `null` (the key is present in the merged map with a `null` value). Implementations SHALL iterate `event.data.answers` via its key set (e.g., `for (final k in answers.keys)`) rather than by indexing an assumed key list, so absent keys are not confused with present-`null` keys.

- [ ] **Rewrite REQ-d00121 rationale paragraph** that currently describes whole-replacement. Replace with a merge-framing paragraph:

> The three event types fold differently: `finalized` and `checkpoint` both merge `event.data.answers` into `previous.current_answers` — keys present in the event's delta (whether with a non-null value or an explicit `null`) overwrite the corresponding key in the merged result, and keys absent from the event preserve their prior value — and differ only in the `is_complete` flag the materialized row carries (`true` for `finalized`, `false` for `checkpoint`); `tombstone` preserves `current_answers` and `is_complete` but flips `is_deleted` to `true`. Each event therefore captures exactly the change the caller chose to apply, and the materialized view is a pure fold of those deltas in `sequence_number` order. The `effective_date` is resolved from the merged `current_answers` (not the event's bare delta) by walking `EntryTypeDefinition.effective_date_path` as a dotted JSON path; when the path is null or does not resolve, the materializer falls back to the first-event `client_timestamp` on this aggregate. Dart's `Map<String, Object?>` and JSON serialization preserve the "key absent" vs "key present with null value" distinction, which the fold contract depends on (assertion J).

- [ ] **Rewrite REQ-d00133 rationale** — in the paragraph that mentions `canonical(answers)` no-op detection. Replace with a merge-aware framing:

> No-op detection is merge-aware: a call is a duplicate of the aggregate's most recent event when merging the candidate `answers` into the materialized `previous.current_answers` produces a `current_answers` equal to the prior, the event_type's implied `is_complete` matches the prior row's `is_complete` (for `finalized`/`checkpoint`) or the prior's `is_deleted` is already `true` (for `tombstone`), and the candidate `checkpoint_reason` and `change_reason` match the most recent event's values. A single-event aggregate never triggers a no-op (no prior row exists).

- [ ] **Rewrite REQ-d00133 assertion F**:

> F. `EntryService.record` SHALL detect no-ops against the merged result. For `finalized` and `checkpoint` events the call SHALL return without writing when ALL of the following hold: (i) the key-wise merge of `answers` over `previous.current_answers` (per REQ-d00121-B) equals `previous.current_answers` under deep equality; (ii) the event's implied `is_complete` (`finalized → true`, `checkpoint → false`) equals the prior row's `is_complete`; (iii) `checkpoint_reason` equals the prior event's `checkpoint_reason` (or both are null); (iv) `change_reason` equals the prior event's `change_reason`. For `tombstone` events the call SHALL return without writing when BOTH: (i) the prior row's `is_deleted` is already `true`; (ii) `change_reason` matches the prior event's `change_reason`. A first event on an aggregate (no prior row) SHALL NOT be treated as a no-op.

- [ ] **Commit**:

```bash
git add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git commit -m "[CUR-1154] Phase 4.8 Task 2: spec changes for merge materialization"
```

The pre-commit hook will regenerate `spec/INDEX.md` hashes for the two touched REQs; include the hook-updated INDEX in the commit.

---

### Task 3: Materializer merge implementation (TDD)

**TASK_FILE**: `PHASE4.8_TASK_3.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/materialization/diary_entries_materializer.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/test/materialization/diary_entries_materializer_test.dart` (or whichever test file holds the existing `foldPure` tests — verify path first).

**Implements**: REQ-d00121-B, -C, -J.

#### Step 1: Write failing tests for merge behavior

In `test/materialization/diary_entries_materializer_test.dart`, add a new test group. Use the file's existing helpers for constructing events and EntryTypeDefinitions; follow its naming conventions. Skeleton:

```dart
group('DiaryEntriesMaterializer.foldPure — merge semantics (REQ-d00121-B+C+J)', () {
  final def = const EntryTypeDefinition(
    id: 'diary',
    version: '1',
    name: 'Diary',
    widgetId: 'w',
    widgetConfig: {},
  );
  final ts = DateTime.utc(2026, 4, 23, 12);

  test('REQ-d00121-B: finalized with delta {a: 9} over prior {a:1, b:2} merges to {a:9, b:2}', () {
    final prior = DiaryEntry(
      entryId: 'agg1',
      entryType: 'diary',
      effectiveDate: ts,
      currentAnswers: const {'a': 1, 'b': 2},
      isComplete: false,
      isDeleted: false,
      latestEventId: 'e0',
      updatedAt: ts,
    );
    final event = _fakeEvent(
      aggregateId: 'agg1',
      eventId: 'e1',
      eventType: 'finalized',
      answers: const {'a': 9},
      ts: ts.add(const Duration(seconds: 1)),
    );
    final result = DiaryEntriesMaterializer.foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: ts,
    );
    expect(result.currentAnswers, equals(<String, Object?>{'a': 9, 'b': 2}));
    expect(result.isComplete, isTrue);
  });

  test('REQ-d00121-C: checkpoint with delta {a: 9} over prior {a:1, b:2} merges to {a:9, b:2}', () {
    // same as above but eventType: 'checkpoint', expect isComplete: false.
  });

  test('REQ-d00121-J: present-null clears the prior value', () {
    final prior = DiaryEntry(
      entryId: 'agg1',
      entryType: 'diary',
      effectiveDate: ts,
      currentAnswers: const {'a': 1, 'b': 2},
      isComplete: false,
      isDeleted: false,
      latestEventId: 'e0',
      updatedAt: ts,
    );
    final event = _fakeEvent(
      aggregateId: 'agg1',
      eventId: 'e1',
      eventType: 'checkpoint',
      answers: const {'b': null},
      ts: ts.add(const Duration(seconds: 1)),
    );
    final result = DiaryEntriesMaterializer.foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: ts,
    );
    expect(result.currentAnswers.containsKey('b'), isTrue);
    expect(result.currentAnswers['b'], isNull);
    expect(result.currentAnswers['a'], equals(1));
  });

  test('REQ-d00121-J: absent key preserves prior value', () {
    final prior = DiaryEntry(
      entryId: 'agg1',
      entryType: 'diary',
      effectiveDate: ts,
      currentAnswers: const {'a': 1, 'b': 2, 'c': 3},
      isComplete: true,
      isDeleted: false,
      latestEventId: 'e0',
      updatedAt: ts,
    );
    final event = _fakeEvent(
      aggregateId: 'agg1',
      eventId: 'e1',
      eventType: 'checkpoint',
      answers: const {'a': 9},
      ts: ts.add(const Duration(seconds: 1)),
    );
    final result = DiaryEntriesMaterializer.foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: ts,
    );
    expect(result.currentAnswers, equals(<String, Object?>{'a': 9, 'b': 2, 'c': 3}));
  });

  test('REQ-d00121-B: finalized on null previous initializes current_answers with the delta', () {
    final event = _fakeEvent(
      aggregateId: 'agg1',
      eventId: 'e1',
      eventType: 'finalized',
      answers: const {'a': 1, 'b': 2},
      ts: ts,
    );
    final result = DiaryEntriesMaterializer.foldPure(
      previous: null,
      event: event,
      def: def,
      firstEventTimestamp: ts,
    );
    expect(result.currentAnswers, equals(<String, Object?>{'a': 1, 'b': 2}));
    expect(result.isComplete, isTrue);
  });

  test('REQ-d00121-J: empty delta preserves prior exactly', () {
    final prior = DiaryEntry(
      entryId: 'agg1',
      entryType: 'diary',
      effectiveDate: ts,
      currentAnswers: const {'a': 1},
      isComplete: false,
      isDeleted: false,
      latestEventId: 'e0',
      updatedAt: ts,
    );
    final event = _fakeEvent(
      aggregateId: 'agg1',
      eventId: 'e1',
      eventType: 'checkpoint',
      answers: const {},
      ts: ts.add(const Duration(seconds: 1)),
    );
    final result = DiaryEntriesMaterializer.foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: ts,
    );
    expect(result.currentAnswers, equals(<String, Object?>{'a': 1}));
  });

  test('REQ-d00121-D: tombstone preserves merged current_answers and flips is_deleted', () {
    final prior = DiaryEntry(
      entryId: 'agg1',
      entryType: 'diary',
      effectiveDate: ts,
      currentAnswers: const {'a': 1, 'b': null},
      isComplete: true,
      isDeleted: false,
      latestEventId: 'e0',
      updatedAt: ts,
    );
    final event = _fakeEvent(
      aggregateId: 'agg1',
      eventId: 'e1',
      eventType: 'tombstone',
      answers: const {},
      ts: ts.add(const Duration(seconds: 1)),
    );
    final result = DiaryEntriesMaterializer.foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: ts,
    );
    expect(result.currentAnswers, equals(<String, Object?>{'a': 1, 'b': null}));
    expect(result.isDeleted, isTrue);
    expect(result.isComplete, isTrue);  // tombstone preserves isComplete from prior
  });
});
```

`_fakeEvent` is a helper already present in this test file (or use the existing `_makeEvent`-style helper; check the file for the name). If not present, add a small one that constructs a `StoredEvent` with just the fields these tests need.

#### Step 2: Run tests to verify failure

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/materialization/diary_entries_materializer_test.dart)
```

Expected: new tests fail on the `{a:9, b:2}` assertions. Prior whole-replace behavior produces `{a:9}` (b dropped). Similarly the null-clear tests fail because the whole-replace path uses the event's answers directly.

#### Step 3: Implement the merge rule

Edit `lib/src/materialization/diary_entries_materializer.dart`. Replace the `finalized` / `checkpoint` branch in `foldPure` (lines ~87–103) with:

```dart
case 'finalized':
case 'checkpoint':
  final isComplete = event.eventType == 'finalized';
  final merged = mergeAnswers(
    previous?.currentAnswers ?? const <String, Object?>{},
    eventAnswers,
  );
  return DiaryEntry(
    entryId: event.aggregateId,
    entryType: event.entryType,
    effectiveDate: _resolveEffectiveDate(
      merged,
      def,
      firstEventTimestamp,
    ),
    currentAnswers: merged,
    isComplete: isComplete,
    isDeleted: previous?.isDeleted ?? false,
    latestEventId: event.eventId,
    updatedAt: event.clientTimestamp,
  );
```

Add a public static helper (both `foldPure` and `EntryService.record` will call it):

```dart
/// Merge an event's delta into the prior current_answers map.
///
/// Each key present in [delta] overwrites the corresponding key in
/// [prior], including when the delta's value is `null` (explicit clear).
/// Each key absent from [delta] preserves the prior value. The iteration
/// uses `delta.keys` rather than indexing, so "key absent" and "key
/// present with null value" are distinguished per REQ-d00121-J.
///
/// Returns an unmodifiable map.
// Implements: REQ-d00121-B+C+J — key-wise merge that preserves the
// absent-vs-present-null distinction via iteration over the delta's
// key set.
static Map<String, Object?> mergeAnswers(
  Map<String, Object?> prior,
  Map<String, Object?> delta,
) {
  final merged = Map<String, Object?>.from(prior);
  for (final key in delta.keys) {
    merged[key] = delta[key];
  }
  return Map<String, Object?>.unmodifiable(merged);
}
```

Update the `// Implements:` marker on `foldPure` to reflect merge semantics. The current marker reads:

```
// Implements: REQ-d00121-B+C+D+E+F — fold event into view row per
// event_type; whole-replacement answers for finalized/checkpoint,
// tombstone preserves fields and flips is_deleted; effective_date
// resolved via dotted-path lookup with fallback.
```

Change to:

```
// Implements: REQ-d00121-B+C+D+E+F+J — fold event into view row per
// event_type; key-wise merge of answers for finalized/checkpoint
// (absent key preserves prior, present key overwrites including
// null-as-clear), tombstone preserves fields and flips is_deleted;
// effective_date resolved from merged answers via dotted-path lookup
// with fallback.
```

Update the preceding doc-comment block on `foldPure` (the `/// Event-type folding rules:` list) to replace "whole-replace `current_answers`" with "merge `event.data.answers` into `current_answers`" for both finalized and checkpoint.

Note the `_resolveEffectiveDate` call now takes `merged` (the full merged state) rather than `eventAnswers` (the bare delta). This is a correctness fix: `effective_date` should be resolved from the aggregate's current state, not from the delta that may not include the path's field.

#### Step 4: Run tests to verify pass

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/materialization/diary_entries_materializer_test.dart)
```

Expected: all merge-semantics tests pass.

#### Step 5: Audit existing foldPure tests

Read the existing `foldPure` tests in the same file (tests written for the whole-replace era). Identify any test whose assertion was "absent-from-event key drops from current_answers" — that invariant is now false. Three possibilities per such test:

1. **Test was demonstrating whole-replace specifically** (e.g., "checkpoint drops a field that was in prior"): rewrite as a merge-semantics test (e.g., "checkpoint with `field: null` clears it").
2. **Test happened to pass under whole-replace but was really checking something else** (e.g., the test constructs the event with every field so whole-replace and merge produce the same result): leave alone.
3. **Test is now meaningless** (purely asserting the whole-replace invariant): delete it.

Document each case in the commit message.

Run the full materialization test suite to catch anything missed:

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/materialization/)
```

Expected: green.

#### Step 6: Run the full suite + analyze

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
```

Expected: all green. Note that `EntryService.record` tests may start failing here because the no-op detection hasn't been updated yet; that's Task 4's scope. If any test fails, verify the failure is in entry_service / record territory; other failures must be fixed in this task.

If entry-service tests fail here, mark this task `DONE_WITH_CONCERNS` and carry the failing tests into Task 4. Otherwise commit.

#### Step 7: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.8 Task 3: DiaryEntriesMaterializer merges deltas (REQ-d00121-B+C+J)"
```

---

### Task 4: EntryService merge-aware no-op detection (TDD)

**TASK_FILE**: `PHASE4.8_TASK_4.md`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/entry_service.dart` — rewrite the no-op block inside `record()`; prune now-unused helpers (`_contentHash`, `_canonicalAnswers` if present).
- Modify: `apps/common-dart/event_sourcing_datastore/test/entry_service_test.dart` — update the no-op tests to merge-aware expectations.

**Implements**: REQ-d00133-F (revised).

#### Step 1: Audit the current no-op test coverage

Read `test/entry_service_test.dart` end-to-end. Identify every test under the "no-op detection" group (search for `REQ-d00133-F` markers, or the `no-op` / `duplicate` keyword in test names). Record each test's premise.

Typical existing tests (verify against the file):

- "duplicate finalized returns null without writing"
- "checkpoint with same answers returns null"
- "checkpoint with different answers writes an event"
- "tombstone after tombstone is a no-op"
- "change_reason mismatch is not a no-op"
- "checkpoint_reason mismatch is not a no-op"

Under merge, the semantics shift: "same answers" is no longer "full-state equal" but "merge produces unchanged prior." Some existing tests happen to exercise the full-state case and pass under both rules; those stay as-is. Others need re-specified deltas and expected outcomes.

#### Step 2: Write new / updated failing tests

Add to `test/entry_service_test.dart` (adapt to the file's existing helpers for EntryService construction):

```dart
group('EntryService.record — merge-aware no-op detection (REQ-d00133-F)', () {
  // ... (set up helper factory `makeService(...)` used by existing tests)

  test('REQ-d00133-F: checkpoint with empty delta over matching prior is a no-op', () async {
    // Arrange: prior checkpoint wrote {a: 1, b: 2} with change_reason='initial'.
    // Act: call record() with eventType=checkpoint, answers: {}, no checkpointReason,
    //      changeReason implicitly 'initial'.
    // Assert: return value is null; storage tail is still the prior event.
  });

  test('REQ-d00133-F: checkpoint with delta values all matching prior is a no-op', () async {
    // Arrange: prior checkpoint wrote {a: 1, b: 2}, change_reason='initial'.
    // Act: record() with answers: {a: 1}, changeReason='initial'.
    // Assert: null return; no new event.
  });

  test('REQ-d00133-F: checkpoint with delta values diverging from prior is NOT a no-op', () async {
    // Arrange: prior wrote {a: 1}.
    // Act: record() with answers: {a: 2}.
    // Assert: non-null return; event appended; view shows {a: 2}.
  });

  test('REQ-d00133-F: checkpoint with null-for-present-field (explicit clear) is NOT a no-op', () async {
    // Arrange: prior wrote {a: 1, b: 2}.
    // Act: record() with answers: {b: null}.
    // Assert: non-null return; view's b is present-null.
  });

  test('REQ-d00133-F: finalized after checkpoint with matching answers IS an event (is_complete changes)', () async {
    // Arrange: prior is a checkpoint with {a: 1}.
    // Act: record() with eventType=finalized, answers: {a: 1}.
    // Assert: non-null return; view's is_complete flips to true. Even though
    //         the answers merge produces unchanged state, the is_complete
    //         transition is the change.
  });

  test('REQ-d00133-F: finalized after finalized with matching answers IS a no-op', () async {
    // Arrange: prior is a finalized with {a: 1}.
    // Act: record() with eventType=finalized, answers: {a: 1}.
    // Assert: null return.
  });

  test('REQ-d00133-F: change_reason mismatch is NOT a no-op (even if merge unchanged)', () async {
    // Arrange: prior wrote {a: 1} with change_reason='initial'.
    // Act: record() with answers: {} (empty delta), changeReason='user_edit'.
    // Assert: non-null return.
  });

  test('REQ-d00133-F: checkpoint_reason mismatch is NOT a no-op', () async {
    // Similar to above for checkpoint_reason.
  });

  test('REQ-d00133-F: tombstone after tombstone with same change_reason is a no-op', () async {
    // Arrange: prior is a tombstone.
    // Act: record(eventType=tombstone, changeReason same).
    // Assert: null.
  });

  test('REQ-d00133-F: tombstone on a non-deleted aggregate is NOT a no-op', () async {
    // Arrange: prior is a checkpoint (isDeleted=false).
    // Act: record(eventType=tombstone, ...).
    // Assert: non-null.
  });

  test('REQ-d00133-F: first event on an aggregate is NEVER a no-op', () async {
    // Arrange: empty aggregate history.
    // Act: record(eventType=checkpoint, answers: {}).
    // Assert: non-null return. Empty-delta-on-empty-prior still creates the first event.
  });
});
```

Delete or update any existing no-op test whose premise was specifically "whole-replace of identical full state is a no-op" once the merge-aware replacements cover the same ground. Document each deletion/rewrite in the commit message.

#### Step 3: Run tests to verify failure

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/entry_service_test.dart)
```

Expected: multiple new tests fail (no-op detection still uses content-hash rule). A subset of old tests may also fail if Task 3's materializer change affects their downstream assertions about `current_answers` shape.

#### Step 4: Rewrite the no-op detection block in `entry_service.dart`

Find the block (around lines ~172–200) that reads:

```dart
final aggregateHistory = await backend.findEventsForAggregateInTxn(
  txn,
  aggregateId,
);
if (aggregateHistory.isNotEmpty) {
  final prior = aggregateHistory.last;
  final priorHash = _contentHash(...);
  if (candidateHash == priorHash) return null;
}
```

Replace with:

```dart
final aggregateHistory = await backend.findEventsForAggregateInTxn(
  txn,
  aggregateId,
);
final priorRow = await backend.readEntryInTxn(txn, aggregateId);

if (aggregateHistory.isNotEmpty && priorRow != null) {
  final priorEvent = aggregateHistory.last;
  final priorCheckpointReason = priorEvent.data['checkpoint_reason'] as String?;
  final priorChangeReason =
      (priorEvent.metadata['change_reason'] as String?) ?? 'initial';
  final changeReasonMatches = effectiveChangeReason == priorChangeReason;
  final checkpointReasonMatches = checkpointReason == priorCheckpointReason;

  if (eventType == 'tombstone') {
    if (priorRow.isDeleted && changeReasonMatches) {
      // REQ-d00133-F tombstone no-op: already-tombstoned aggregate,
      // same change_reason.
      return null;
    }
  } else {
    // eventType is 'finalized' or 'checkpoint' (validated above).
    final eventIsComplete = eventType == 'finalized';
    final merged = DiaryEntriesMaterializer.mergeAnswers(
      priorRow.currentAnswers,
      answers,
    );
    final mergeUnchanged = const DeepCollectionEquality()
        .equals(merged, priorRow.currentAnswers);
    final isCompleteMatches = eventIsComplete == priorRow.isComplete;
    if (mergeUnchanged &&
        isCompleteMatches &&
        checkpointReasonMatches &&
        changeReasonMatches) {
      // REQ-d00133-F merge-aware no-op: merging the delta produces
      // unchanged current_answers AND the lifecycle/reason fields match.
      return null;
    }
  }
}
```

Imports needed at the top of `entry_service.dart`:

```dart
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:event_sourcing_datastore/src/materialization/diary_entries_materializer.dart'
    show DiaryEntriesMaterializer;
```

Check existing imports — the file may already import DeepCollectionEquality and/or the materializer; merge accordingly.

Update the `// Implements: REQ-d00133-F` marker comment to read:

```
// Implements: REQ-d00133-F — merge-aware no-op detection. A candidate
// is a duplicate when merging its delta produces an unchanged
// current_answers AND the lifecycle (is_complete / is_deleted) and
// reason fields match the prior event.
```

Remove `_contentHash` and `_canonicalAnswers` helpers (and their imports of `canonical_json_jcs` / `crypto` if they become unused). Verify via grep:

```bash
grep -n "_contentHash\|_canonicalAnswers\|candidateHash" apps/common-dart/event_sourcing_datastore/lib/src/entry_service.dart
```

Expected: zero remaining references after removal.

Update the doc comment on `EntryService.record` — the paragraph that describes no-op detection as a canonical-content-hash comparison — to describe the merge-aware rule.

#### Step 5: Run tests to verify pass

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/entry_service_test.dart)
```

Expected: all merge-aware tests pass.

#### Step 6: Run the full suite + analyze

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
```

Expected: all green across the package.

#### Step 7: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.8 Task 4: EntryService merge-aware no-op detection (REQ-d00133-F)"
```

---

### Task 5: Integration test — delta sequence folds correctly end-to-end

**TASK_FILE**: `PHASE4.8_TASK_5.md`

**Files:**
- Create or extend: `apps/common-dart/event_sourcing_datastore/test/integration/end_to_end_test.dart` — add a group covering merge composition across multiple events.

**Implements**: regression coverage for REQ-d00121 composition and REQ-d00133-F under a realistic sequence (several checkpoint events with deltas, then a finalized, confirming `current_answers` matches expected at each stage).

#### Step 1: Write the integration test

```dart
group('merge composition end-to-end (REQ-d00121-B+C+J, REQ-d00133-F)', () {
  test('checkpoint deltas compose via fold; finalized locks in', () async {
    final backend = await _openBackend();
    addTearDown(backend.close);
    final registry = EntryTypeRegistry();
    final def = const EntryTypeDefinition(
      id: 'diary',
      version: '1',
      name: 'Diary',
      widgetId: 'w',
      widgetConfig: {},
    );
    registry.register(def);
    final svc = EntryService(
      backend: backend,
      entryTypeRegistry: registry,
      deviceInfo: const DeviceInfo(userId: 'u1', deviceId: 'd1'),
    );
    final aggId = 'agg-${const Uuid().v7()}';

    // 1. First checkpoint sets {a: 1}.
    final e1 = await svc.record(
      entryType: 'diary',
      aggregateId: aggId,
      eventType: 'checkpoint',
      answers: const {'a': 1},
    );
    expect(e1, isNotNull);

    // 2. Second checkpoint adds {b: 2}, leaves a untouched.
    final e2 = await svc.record(
      entryType: 'diary',
      aggregateId: aggId,
      eventType: 'checkpoint',
      answers: const {'b': 2},
    );
    expect(e2, isNotNull);

    // After two checkpoints, view should show {a: 1, b: 2}, is_complete=false.
    final row2 = await backend.readEntry(aggId);
    expect(row2!.currentAnswers, equals(<String, Object?>{'a': 1, 'b': 2}));
    expect(row2.isComplete, isFalse);

    // 3. Explicit-clear checkpoint: {a: null}.
    final e3 = await svc.record(
      entryType: 'diary',
      aggregateId: aggId,
      eventType: 'checkpoint',
      answers: const {'a': null},
    );
    expect(e3, isNotNull);

    final row3 = await backend.readEntry(aggId);
    expect(row3!.currentAnswers.containsKey('a'), isTrue);
    expect(row3.currentAnswers['a'], isNull);
    expect(row3.currentAnswers['b'], equals(2));

    // 4. Redundant checkpoint: {a: null} again. No-op.
    final e4 = await svc.record(
      entryType: 'diary',
      aggregateId: aggId,
      eventType: 'checkpoint',
      answers: const {'a': null},
    );
    expect(e4, isNull);  // no-op detected

    final row4 = await backend.readEntry(aggId);
    expect(row4, equals(row3));  // unchanged

    // 5. Finalize with empty delta: answers unchanged, is_complete flips to true.
    final e5 = await svc.record(
      entryType: 'diary',
      aggregateId: aggId,
      eventType: 'finalized',
      answers: const {},
    );
    expect(e5, isNotNull);  // is_complete transition is a real change

    final row5 = await backend.readEntry(aggId);
    expect(row5!.currentAnswers, equals(row3.currentAnswers));
    expect(row5.isComplete, isTrue);

    // 6. Rebuild-from-scratch yields the same final row.
    final rebuilt = await rebuildMaterializedView(backend, registry);
    expect(rebuilt, greaterThan(0));  // at least one aggregate materialized
    final row6 = await backend.readEntry(aggId);
    expect(row6, equals(row5));
  });
});
```

Adapt the test-setup helpers (`_openBackend`, `DeviceInfo`, etc.) to whatever patterns `end_to_end_test.dart` already uses.

#### Step 2: Run the integration test

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/integration/end_to_end_test.dart)
```

Expected: PASS.

#### Step 3: Run the full suite + analyze

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
```

Expected: all green. Note the test count delta from baseline (~+1 integration test plus the Task-3 and Task-4 additions).

#### Step 4: Commit

```bash
git add apps/common-dart/event_sourcing_datastore/
git commit -m "[CUR-1154] Phase 4.8 Task 5: merge-composition integration test"
```

---

### Task 6: Final verification + worklog close

**TASK_FILE**: `PHASE4.8_TASK_6.md`

**No file changes** — verification only, plus worklog update.

- [ ] **Full test suite**:

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test && flutter analyze)
(cd apps/common-dart/event_sourcing_datastore/example && flutter pub get && flutter analyze)
```

Expected: all green on both lib and example.

- [ ] **Grep for stale whole-replace references in the library**:

```bash
grep -rn "whole-replace\|whole replacement\|whole-replacement" \
  apps/common-dart/event_sourcing_datastore/lib/ \
  apps/common-dart/event_sourcing_datastore/test/
```

Expected: zero matches in code comments and test descriptions, or only matches that are explicitly contrasting with merge (e.g., "unlike the prior whole-replace rule" — preferred to delete per the final-state voice discipline, but acceptable if it's within a rationale that frames the current design).

- [ ] **Grep for stale content-hash references**:

```bash
grep -rn "_contentHash\|_canonicalAnswers\|candidateHash" \
  apps/common-dart/event_sourcing_datastore/lib/
```

Expected: zero matches.

- [ ] **Verify spec consistency**:

```bash
grep -n "whole-replace\|whole-replacement" spec/dev-event-sourcing-mobile.md
```

Expected: zero matches in REQ-d00121's current text (post Task 2).

- [ ] **Update `PHASE_4.8_WORKLOG.md`** at repo root with the completion checklist and commit SHAs. Format mirrors Phase 4.7's worklog close.

- [ ] **Commit**:

```bash
git add PHASE_4.8_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.8 Task 6: final verification + worklog close"
```

Phase 4.8 complete. The user is squash-merging at PR time, so no phase-boundary squash is required; Phase 4.9 picks up on HEAD from here.

---

## Self-review of this plan

**Spec coverage** (checked against `docs/superpowers/specs/2026-04-23-merge-materialization-design.md`):

- §2.1 merge rule → Task 3 (materializer) + Task 4 (no-op detection uses same rule).
- §2.2 `is_complete` unchanged → verified in Task 3 tombstone test and Task 5 finalized test.
- §2.3 tombstone unchanged → Task 3 regression test.
- §2.4 hash-chain identity unchanged → no task; this is a non-change the plan preserves by not touching hash computation.
- §2.5 no-op detection merge-aware → Task 4.
- §2.6 rebuild semantics unchanged (fold implementation) → Task 5's `rebuildMaterializedView` regression at the end of the integration test.
- §2.7 caller API shape unchanged → no task; plan preserves signature by design.
- §2.8 sync-through compatibility → no task directly (this phase doesn't implement ingest); the purity of `foldPure` is what §2.8 depends on and that's preserved by Task 3.
- §4.1 REQ-d00121 assertion rewrites → Task 2.
- §4.2 REQ-d00133 assertion rewrite → Task 2.
- §5.1 code delta enumeration → Tasks 3 + 4.
- §5.2 tests to add → Tasks 3 + 4 + 5.
- §5.3 tests to update → Task 3 Step 5 and Task 4 Step 1 audits.
- §5.4 tests to delete → Task 3 Step 5 (identified during the audit).
- §6 risks → Task 4 step comments cover Risk 2 (no-op cost implicitly acceptable); Risk 1 (caller discipline) is doc-level, covered by the rewritten doc comment on `EntryService.record`; Risk 3 (null preservation on wire) is unchanged by Phase 4.8 and is a Phase 4.9+ concern.

All design requirements have a task.

**Placeholder scan**: No TBDs. `_fakeEvent` in Task 3 is noted as "helper already present in this test file (or use the existing `_makeEvent`-style helper; check the file for the name)" — this is intentional ambiguity because I can't guarantee the helper name; the implementer resolves it in the first few seconds of reading the file. Not a placeholder in the spec-failure sense.

**Type consistency**: `mergeAnswers(Map<String, Object?> prior, Map<String, Object?> delta) → Map<String, Object?>` used in Task 3 (definition) and Task 4 (call site). Signatures match. `DeepCollectionEquality().equals(...)` used in Task 4; import added. `StoredEvent`, `DiaryEntry`, `EntryTypeDefinition` signatures are unchanged and match existing code.
