# Master Plan Phase 4.12: Reactive Read Layer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two reactive APIs to `event_sourcing_datastore` — `watchEvents({afterSequence})` and `watchFifo(destinationId)` — and migrate the example app's three polling panels off `Timer.periodic`.

**Architecture:** Library-owned broadcast `StreamController` for events and FIFO mutations on `SembastBackend`. Write paths (`appendEvent`, `appendIngestedEvent`, all FIFO mutators) emit AFTER successful commit. `watchEvents` does replay-then-live with a held-cursor filter for race safety. `watchFifo` emits a snapshot on subscribe and re-fetches on each FIFO change. Two new REQs (REQ-d00149, REQ-d00150). No new "DataStore" coordination primitive — consumers share a single backend instance.

**Tech Stack:** Dart `Stream.broadcast`, `package:flutter_test/flutter_test.dart` matchers (`emitsInOrder`, `emitsThrough`, `expectLater`), existing `event_sourcing_datastore` primitives.

**Design spec:** `docs/superpowers/specs/2026-04-25-phase4.12-reactive-read-layer-design.md`.

**Decisions log:** `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (Phase 4.12 section §4.12.A–E pinned; do not re-litigate).

**Branch:** `mobile-event-sourcing-refactor` (shared). **Ticket:** CUR-1154 (continuation). **Phase:** 4.12 (after 4.11). **Depends on:** Phase 4.11 complete on HEAD.

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00149 (NEW) | `StorageBackend.watchEvents` — broadcast Stream of `StoredEvent`, replay-then-live, monotone, fires on append + ingest, error/lifecycle. | Task 2 (spec); Task 4 (failing tests); Task 5 (impl) |
| REQ-d00150 (NEW) | `StorageBackend.watchFifo` — broadcast Stream of FIFO snapshots, snapshot-on-subscribe + change-driven re-emission. | Task 2 (spec); Task 6 (failing tests); Task 7 (impl) |

REQ-d00149 and REQ-d00150 are the next two free REQ-d numbers (post-4.11 ceiling = REQ-d00148). Task 2 verifies via grep.

---

## Execution rules

Read `README.md` in the plans directory for TDD cadence and REQ-citation conventions. Each task = one commit on the branch. No per-phase squash (squash-merge at PR time).

Read the design spec end-to-end before Task 1. Re-read §2.3 + §2.6 before Tasks 4–5. Re-read §2.4 + §2.6 before Tasks 6–7. Re-read §2.7 before Task 3. Re-read §4 before Task 8.

**Project conventions:**

- Explicit `git add <files>`. NEVER `git add <directory>` or `git add -A`. User has parallel WIP under `apps/common-dart/event_sourcing_datastore/example/`.
- Pre-commit hook regenerates `spec/INDEX.md` REQ hashes — let it run. New REQ sections in Task 2 use `| **Hash**: 00000000` placeholder per decisions log §XP.3.
- Test framework `package:flutter_test/flutter_test.dart` — use its stream matchers (`emitsInOrder`, `emitsThrough`, `expectLater`). Avoid `Future.delayed` waits.
- Project lints: `prefer_constructors_over_static_methods`. Stream tests close subscriptions in `tearDown`.
- Per-function `// Implements: REQ-xxx-Y — <prose>` markers; per-test `// Verifies: REQ-xxx-Y` + assertion ID at start of `test(...)` description.
- Greenfield (decisions log §XP.1): final-state voice; no "previously / no longer / removed" wording.
- TDD-vs-analyze tension (encountered in Phase 4.11 Tasks 3 + 5): failing tests reference methods that don't yet exist. Use `// ignore: undefined_method` at each call site to satisfy pre-commit `dart analyze --fatal-infos`. Implementer in the corresponding implementation task removes the ignores in the same commit.

**Phase invariants** (must be true at end of phase):

1. `flutter test` clean in `apps/common-dart/event_sourcing_datastore`. Pass count: ≥ 573 + N (N depends on test cases added across Tasks 4 and 6 — minimum 10).
2. `flutter analyze` clean in `apps/common-dart/event_sourcing_datastore` AND `apps/common-dart/event_sourcing_datastore/example`.
3. `flutter test` clean in `apps/common-dart/provenance` (38 unchanged).
4. `grep -rn "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/` returns ZERO hits.
5. `grep -rn "watchEvents\|watchFifo" apps/common-dart/event_sourcing_datastore/example/lib/` returns at least 3 hits (one per migrated panel).

---

## Plan

### Task 1: Baseline + worklog

**Files:** Create `PHASE_4.12_WORKLOG.md`.

- [ ] **Step 1: Confirm Phase 4.11 is committed on HEAD**

```bash
git log --oneline -3
```

Expected: top includes `[CUR-1154] Phase 4.12 design spec: reactive read layer` and below it the Phase 4.11 closing commit + `[CUR-1154] Phase 4.11 Task 9: close worklog`.

- [ ] **Step 2: Run baseline checks**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: event_sourcing_datastore +573, provenance +38, all analyze clean.

- [ ] **Step 3: Snapshot the BEFORE state of `Timer.periodic` in example/lib/**

```bash
grep -rn "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: 3 hits (`detail_panel.dart`, `event_stream_panel.dart`, `fifo_panel.dart`). Capture into the worklog as the BEFORE state.

- [ ] **Step 4: Write `PHASE_4.12_WORKLOG.md`**

```markdown
# Phase 4.12 Worklog — Reactive Read Layer (CUR-1154)

**Spec:** docs/superpowers/specs/2026-04-25-phase4.12-reactive-read-layer-design.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.12 section)
**Branch:** mobile-event-sourcing-refactor

## Baseline (Task 1)

- event_sourcing_datastore: <FILL IN>
- provenance: <FILL IN>
- analyze (lib + example + provenance): clean

### Timer.periodic BEFORE state (example/lib)

<paste Step 3 output — 3 hits expected>

## Tasks

- [ ] Task 1: Baseline + worklog
- [ ] Task 2: Spec REQ-d00149 + REQ-d00150
- [ ] Task 3: Foundation — broadcast controllers on SembastBackend; close lifecycle
- [ ] Task 4: Failing tests for watchEvents (REQ-d00149)
- [ ] Task 5: Implement watchEvents (abstract + concrete + emission hooks)
- [ ] Task 6: Failing tests for watchFifo (REQ-d00150)
- [ ] Task 7: Implement watchFifo (abstract + concrete + FIFO emission hooks)
- [ ] Task 8: Migrate three example panels off Timer.periodic
- [ ] Task 9: Final verification + close worklog
```

- [ ] **Step 5: Commit**

```bash
git add PHASE_4.12_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.12 Task 1: baseline + worklog"
```

---

### Task 2: Spec — add REQ-d00149 (watchEvents) + REQ-d00150 (watchFifo)

**Files:** Modify `spec/dev-event-sourcing-mobile.md`.

- [ ] **Step 1: Confirm REQ numbers free**

```bash
grep -n "^# REQ-d00149\|^# REQ-d00150" spec/dev-event-sourcing-mobile.md
```

Expected: empty. If either is taken, surface to orchestrator and pick next free numbers.

- [ ] **Step 2: Find insertion point** — after REQ-d00148's `*End*` line.

```bash
grep -n "^# REQ-d\|^\*End\*" spec/dev-event-sourcing-mobile.md | tail -10
```

- [ ] **Step 3: Append REQ-d00149**

After REQ-d00148's `*End*` line, insert (with `| **Hash**: 00000000` placeholder per XP.3):

```markdown

---

# REQ-d00149: watchEvents Reactive Read

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

Read paths that need fresh event-log state today either poll on `Timer.periodic` and re-scan the log per tick or wire bespoke change detection at the application layer. Both approaches scale poorly: per-tick re-scans grow with log size; bespoke change detection multiplies the wiring work per consumer. The library is the only component that knows when an event landed; exposing a reactive primitive lets every consumer (UI panels, hash-chain walkers, future ops dashboards) subscribe without re-implementing the polling loop.

`watchEvents` returns a Dart `Stream<StoredEvent>` because Stream is the broadest pure-Dart concurrency primitive — broadcast-friendly, no Flutter dependency on the library, and consumers in the Flutter widget tree wrap with `StreamBuilder` cheaply. Replay-then-live semantics ("tail -F") is the well-understood pattern: caller passes the last-seen sequence and gets caught up + live updates seamlessly. The library does not retain per-subscriber state across pause/resume — slow consumers recover by canceling and re-subscribing with the last-seen sequence.

The library owns the broadcast (rather than relying on sembast's `onSnapshots`) so that future non-sembast backends implement the same contract via their own write paths without leaking storage-specific types into `StorageBackend`.

## Assertions

A. `StorageBackend.watchEvents({int? afterSequence})` SHALL return a broadcast `Stream<StoredEvent>` that, on subscribe, first emits every event currently in the log with `sequence_number > afterSequence` (or every event when `afterSequence` is null), in `sequence_number` ascending order, then transitions to live emission of events appended via `appendEvent` or ingested via `appendIngestedEvent`.

B. The replay-to-live transition SHALL be monotone: every replayed event SHALL have a strictly smaller `sequence_number` than every live event subsequently emitted to that subscriber. Implementations SHALL guard against the race where an event is appended between the replay read and the live-stream subscription by filtering live emissions to `event.sequenceNumber > lastReplayedSequenceNumber` per subscriber.

C. The stream SHALL be broadcast: multiple subscribers attached to the same backend SHALL receive identical event sequences. Subscribers attached at different wall-clock times each receive their own replay-then-live sequence per subscription parameters.

D. Storage errors observed during a snapshot read inside the stream's machinery SHALL propagate via `Stream.addError` without closing the stream. Fatal lifecycle errors (`SembastBackend.close` was called) SHALL close the underlying controllers, sending `done` to all subscribers. Calling `watchEvents` after `close` SHALL throw `StateError`.

E. Consumers SHALL share a single `StorageBackend` instance per database; constructing multiple backends over the same database file is undefined behavior. The broadcast deduplication is the coordination mechanism.

*End* *watchEvents Reactive Read* | **Hash**: 00000000

```

- [ ] **Step 4: Append REQ-d00150**

```markdown

---

# REQ-d00150: watchFifo Reactive Read

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

A destination's FIFO mutates via paths separate from the event log: drain appends attempts, marks rows final, the operator tombstones, and `fillBatch` enqueues fresh rows. None of these write to the event log; an `watchEvents` subscriber learns nothing about FIFO state changes. UI panels that render FIFO contents need their own change-notification path, otherwise they fall back to polling on `Timer.periodic`.

`watchFifo` returns a `Stream<List<FifoEntry>>` — each emission is a fresh snapshot of the destination's queue, ordered by `sequence_in_queue` ascending (matching `listFifoEntries` and `readFifoHead`). Snapshot-on-subscribe means a `StreamBuilder` shows correct state immediately without a one-tick delay. Each subsequent FIFO mutation triggers a re-fetch and re-emission. Whole-snapshot emission (rather than per-row deltas) keeps the contract simple; consumers that want deltas diff against the prior emission.

Like `watchEvents`, the library owns the broadcast — the `StorageBackend` interface declares the abstract method without sembast types. Backend implementations emit on every internal FIFO write path so the contract is consistent across backends.

## Assertions

A. `StorageBackend.watchFifo(String destinationId)` SHALL return a broadcast `Stream<List<FifoEntry>>` that emits the current queue snapshot on subscribe (an empty list when `destinationId` has no registered FIFO store) and re-emits a fresh snapshot on every mutation to that destination's FIFO. Mutations include enqueue (`enqueueFifo`, `enqueueFifoTxn`), `appendAttempt`, `markFinal`, `setFinalStatusTxn`, `deleteNullRowsAfterSequenceInQueueTxn`, and `deleteFifoStoreTxn`.

B. Each emission SHALL be ordered by `sequence_in_queue` ascending. The emission SHALL contain `FifoEntry` objects with the same field population as `listFifoEntries`; raw maps SHALL NOT be exposed.

C. The stream SHALL be broadcast: multiple subscribers per `destinationId` SHALL receive identical snapshot sequences. Cross-destination isolation is enforced — a mutation on destination A SHALL NOT cause an emission to a `watchFifo(B)` subscriber.

D. Storage errors observed during a snapshot fetch SHALL propagate via `Stream.addError`; the stream stays open. Fatal lifecycle errors (`close`) SHALL close the underlying controllers. Calling `watchFifo` after `close` SHALL throw `StateError`.

E. Consumers SHALL share a single `StorageBackend` instance per database (REQ-d00149-E).

*End* *watchFifo Reactive Read* | **Hash**: 00000000

```

- [ ] **Step 5: Run analyze (sanity)**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean. Spec edits don't affect Dart analyze.

- [ ] **Step 6: Commit**

```bash
git add spec/dev-event-sourcing-mobile.md
git commit -m "[CUR-1154] Phase 4.12 Task 2: spec REQ-d00149 (watchEvents) + REQ-d00150 (watchFifo)"
```

The pre-commit hook populates the `00000000` hash placeholders and updates `spec/INDEX.md` in the same commit.

---

### Task 3: Foundation — broadcast controllers on SembastBackend; close lifecycle

**Files:** Modify `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`.

This task ONLY adds the private `StreamController` fields and updates `close()`. It does NOT add public methods (those land in Tasks 5 and 7) and does NOT add emission calls (those land in Tasks 5 and 7 too). Splitting this lets Task 4 / Task 6 verify failing-test wiring before the implementation hooks land.

- [ ] **Step 1: Read current `close` implementation**

```bash
grep -n "^  Future<void> close\|^class SembastBackend" apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart | head
```

- [ ] **Step 2: Add private fields and update `close`**

In `SembastBackend` (search for the class declaration), add to the field list:

```dart
  // Broadcast controllers — feed reactive APIs added in Phase 4.12.
  // _eventsController fed after each successful appendEvent /
  // appendIngestedEvent commit (REQ-d00149). _fifoChangesController fed
  // after each successful FIFO mutation; payload is the destinationId
  // (REQ-d00150).
  final StreamController<StoredEvent> _eventsController =
      StreamController<StoredEvent>.broadcast();
  final StreamController<String> _fifoChangesController =
      StreamController<String>.broadcast();
```

Add `import 'dart:async';` if not present.

- [ ] **Step 3: Update `close` to drain the controllers BEFORE closing the database**

Replace the existing close method body with:

```dart
  /// Close the underlying sembast database AND the reactive broadcast
  /// controllers used by [watchEvents] / [watchFifo]. After close,
  /// further calls to those reactive methods SHALL throw
  /// `StateError`. Active subscribers receive `done`.
  ///
  /// Not safe to call concurrently with an in-flight [transaction]. The
  /// caller is responsible for awaiting outstanding work before closing.
  Future<void> close() async {
    await _eventsController.close();
    await _fifoChangesController.close();
    await _db.close();
  }
```

(The existing close method body just calls `await _db.close()`; you're prepending the two controller closes.)

- [ ] **Step 4: Run the existing test suite; verify no regression**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: still `+573 All tests passed!`. Adding private fields without using them changes nothing observable to existing tests.

- [ ] **Step 5: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `No issues found!`. If analyze flags `unused_field` on the new controllers, that's ACCEPTABLE for this task since they will be used in Tasks 5 and 7 — but Dart analyze typically does NOT flag private fields as unused. If it does, suppress with `// ignore: unused_field` on each field declaration.

- [ ] **Step 6: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart
git commit -m "[CUR-1154] Phase 4.12 Task 3: foundation — broadcast controllers + close lifecycle"
```

---

### Task 4: Failing tests for watchEvents (REQ-d00149)

**Files:** Create `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_events_test.dart`.

- [ ] **Step 1: Read an existing test for the boilerplate pattern**

```bash
sed -n '1,50p' apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_event_by_id_test.dart
```

Reuse the `_openBackend` and `_appendEvent` patterns.

- [ ] **Step 2: Write the test file**

```dart
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

Future<StoredEvent> _appendEvent(
  SembastBackend backend, {
  required String eventId,
  String aggregateId = 'agg-1',
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: 'DiaryEntry',
      entryType: 'epistaxis_event',
      eventType: 'finalized',
      sequenceNumber: seq,
      data: const <String, dynamic>{},
      metadata: const <String, dynamic>{},
      initiator: const UserInitiator('u'),
      clientTimestamp: DateTime.utc(2026, 4, 22, 10),
      eventHash: 'hash-$eventId',
    );
    await backend.appendEvent(txn, event);
    return event;
  });
}

void main() {
  group('SembastBackend.watchEvents', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('watch-events-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00149-A — replay-then-live: pre-existing events
    // emit on subscribe, then a live append produces the next emission.
    test(
      'REQ-d00149-A: watchEvents replays then transitions to live',
      () async {
        await _appendEvent(backend, eventId: 'e1');
        await _appendEvent(backend, eventId: 'e2');

        // ignore: undefined_method
        final stream = backend.watchEvents();
        // First two replayed; then live append surfaces.
        final fut = expectLater(
          stream,
          emitsInOrder([
            predicate<StoredEvent>((e) => e.eventId == 'e1'),
            predicate<StoredEvent>((e) => e.eventId == 'e2'),
            predicate<StoredEvent>((e) => e.eventId == 'e3'),
          ]),
        );
        // Give the replay tick to flush, then append live.
        await Future<void>.delayed(Duration.zero);
        await _appendEvent(backend, eventId: 'e3');
        await fut;
      },
    );

    // Verifies: REQ-d00149-A — afterSequence filters replay.
    test(
      'REQ-d00149-A: watchEvents skips replay events at or below afterSequence',
      () async {
        final e1 = await _appendEvent(backend, eventId: 'e1');
        await _appendEvent(backend, eventId: 'e2');

        // ignore: undefined_method
        final stream = backend.watchEvents(afterSequence: e1.sequenceNumber);
        await expectLater(
          stream,
          emitsThrough(predicate<StoredEvent>((e) => e.eventId == 'e2')),
        );
      },
    );

    // Verifies: REQ-d00149-C — broadcast: two subscribers see identical
    // sequences.
    test(
      'REQ-d00149-C: watchEvents is broadcast (multiple subscribers)',
      () async {
        // ignore: undefined_method
        final stream = backend.watchEvents();
        final sub1 = <String>[];
        final sub2 = <String>[];
        final s1 = stream.listen((e) => sub1.add(e.eventId));
        final s2 = stream.listen((e) => sub2.add(e.eventId));

        await _appendEvent(backend, eventId: 'e1');
        await _appendEvent(backend, eventId: 'e2');
        await Future<void>.delayed(Duration.zero);

        await s1.cancel();
        await s2.cancel();
        expect(sub1, ['e1', 'e2']);
        expect(sub2, ['e1', 'e2']);
      },
    );

    // Verifies: REQ-d00149-D — close() sends done to active subscribers
    // and subsequent watchEvents throws StateError.
    test(
      'REQ-d00149-D: watchEvents closes on backend close, then throws',
      () async {
        // ignore: undefined_method
        final stream = backend.watchEvents();
        final completer = expectLater(stream, emitsDone);
        await backend.close();
        await completer;
        expect(
          () => backend.watchEvents(),
          throwsStateError,
        );
        // Re-open a fresh backend so tearDown's close doesn't double-close.
        backend = await _openBackend('watch-events-reopen-$dbCounter.db');
      },
    );
  });
}
```

- [ ] **Step 3: Run the new tests; verify FAILURE on missing method**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_watch_events_test.dart 2>&1 | tail -10)
```

Expected: compile-time failure on `backend.watchEvents(...)` ("The method 'watchEvents' isn't defined for the type 'SembastBackend'."). Proves the wiring.

- [ ] **Step 4: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_events_test.dart
git commit -m "[CUR-1154] Phase 4.12 Task 4: failing tests for REQ-d00149 (watchEvents)"
```

---

### Task 5: Implement watchEvents (abstract + concrete + emission hooks)

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart` (abstract method)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` (concrete + emission)
- Modify: hand-rolled `StorageBackend` subclasses in test files (`_DelegatingBackend`, `_SpyBackend`, `_InMemoryBackend` per Phase 4.11 patterns) — add `watchEvents` overrides.

- [ ] **Step 1: Add abstract method to `StorageBackend`**

In `lib/src/storage/storage_backend.dart`, near the events section, add:

```dart
  /// Reactive event stream. See REQ-d00149.
  ///
  /// Returns a broadcast Stream that, on subscribe, first emits every
  /// event in the log with `sequence_number > afterSequence` (or every
  /// event when `afterSequence` is null) in ascending order, then
  /// transitions to live emission of events appended or ingested while
  /// the subscription is open. Multiple subscribers receive identical
  /// sequences. The stream closes when the backend is closed; calling
  /// this method after close SHALL throw `StateError`.
  ///
  /// Consumers SHALL share a single backend instance per database
  /// (REQ-d00149-E) — broadcast deduplication is the coordination
  /// mechanism.
  // Implements: REQ-d00149-A+B+C+D+E.
  Stream<StoredEvent> watchEvents({int? afterSequence});
```

- [ ] **Step 2: Implement on `SembastBackend`**

Add the method (uses the `_eventsController` from Task 3):

```dart
  // Implements: REQ-d00149-A+B+C+D+E — replay-then-live with
  // race-safe live-filter via held-cursor; broadcast; close-aware.
  @override
  Stream<StoredEvent> watchEvents({int? afterSequence}) {
    if (_eventsController.isClosed) {
      throw StateError(
        'SembastBackend.close has been called; watchEvents unavailable',
      );
    }
    final lowerBound = afterSequence ?? 0;
    final controller = StreamController<StoredEvent>();
    var lastReplayed = lowerBound;
    StreamSubscription<StoredEvent>? liveSub;
    var liveAttached = false;

    Future<void> startReplay() async {
      try {
        final replay = await findAllEvents(afterSequence: lowerBound);
        for (final e in replay) {
          if (controller.isClosed) return;
          controller.add(e);
          lastReplayed = e.sequenceNumber;
        }
      } catch (err, st) {
        if (!controller.isClosed) controller.addError(err, st);
      }
      if (controller.isClosed) return;
      liveSub = _eventsController.stream.listen(
        (e) {
          if (e.sequenceNumber > lastReplayed) controller.add(e);
        },
        onError: (Object err, StackTrace st) => controller.addError(err, st),
        onDone: () => controller.close(),
      );
      liveAttached = true;
    }

    controller.onListen = () {
      // Kick off replay asynchronously so the subscriber is fully
      // attached when emissions start.
      scheduleMicrotask(startReplay);
    };
    controller.onCancel = () async {
      if (liveAttached) await liveSub?.cancel();
    };
    return controller.stream;
  }
```

- [ ] **Step 3: Hook event-broadcast emission into `appendEvent` and `appendIngestedEvent`**

Find the existing implementations of `appendEvent` and `appendIngestedEvent` in `sembast_backend.dart`. Both currently look something like:

```dart
@override
Future<AppendResult> appendEvent(Txn txn, StoredEvent event) async {
  // ... existing body that writes to the store ...
  return AppendResult(...);
}
```

The emission must happen AFTER the transaction commits. Two patterns are possible:

- (a) Move emission OUT of the in-txn method and INTO the wrapping `transaction()` callsite — but appendEvent is called by EntryService inside its own transaction, so we can't reach the outer transaction completion from inside `appendEvent`.
- (b) Use a per-transaction "post-commit" queue. The `transaction()` method already commits/rolls back atomically; modify it to accept and run post-commit callbacks.

Pattern (b) is the right answer. Implementation:

- Add a private list `final List<void Function()> _pendingPostCommit = [];` to `SembastBackend`. (Not thread-safe; sembast is single-isolate so this is fine.)
- In `transaction<T>(body)`: capture the current `_pendingPostCommit`, run the body, on success run all queued callbacks then clear; on error clear without running.
- In `appendEvent`: after the in-txn write succeeds, push `() => _eventsController.add(event)` onto `_pendingPostCommit`.
- Same in `appendIngestedEvent`.

Concretely, replace `transaction` with:

```dart
  @override
  Future<T> transaction<T>(Future<T> Function(Txn txn) body) async {
    final outerPending = _pendingPostCommit;
    final innerPending = <void Function()>[];
    _pendingPostCommit = innerPending;
    try {
      final result = await _db.transaction((sembastTxn) async {
        return body(_SembastTxn(sembastTxn));
      });
      // Commit succeeded — fire post-commit callbacks.
      for (final cb in innerPending) {
        if (!_eventsController.isClosed && !_fifoChangesController.isClosed) {
          cb();
        }
      }
      return result;
    } finally {
      _pendingPostCommit = outerPending;
    }
  }
```

(The outer-pending capture preserves nesting in case `transaction` is ever called re-entrantly — a defensive guard; sembast doesn't support nested transactions but the field-level state is preserved cleanly.)

In `appendEvent` and `appendIngestedEvent`, after the existing in-txn write, append:

```dart
  _pendingPostCommit.add(() => _eventsController.add(event));
```

(Where `event` is the `StoredEvent` parameter or the constructed event.)

- [ ] **Step 4: Add `watchEvents` overrides to test-helper subclasses**

```bash
grep -rn "extends StorageBackend\|implements StorageBackend" apps/common-dart/event_sourcing_datastore/test/
```

For each subclass (typically `_DelegatingBackend`, `_SpyBackend`, `_InMemoryBackend`):

```dart
@override
Stream<StoredEvent> watchEvents({int? afterSequence}) {
  // Delegating: forward.
  return _inner.watchEvents(afterSequence: afterSequence);
}
```

For in-memory test-only subclasses with no inner backend:

```dart
@override
Stream<StoredEvent> watchEvents({int? afterSequence}) =>
    Stream<StoredEvent>.empty();
```

- [ ] **Step 5: Remove the 4 `// ignore: undefined_method` lines from Task 4's test file**

```bash
grep -n "ignore: undefined_method" apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_events_test.dart
```

Delete the 4 ignore lines.

- [ ] **Step 6: Run the watchEvents tests; verify PASS**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_watch_events_test.dart 2>&1 | tail -10)
```

Expected: `+4: All tests passed!`.

- [ ] **Step 7: Run full suite; confirm no regression**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+577` (573 + 4 new).

- [ ] **Step 8: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean.

- [ ] **Step 9: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart \
        apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_events_test.dart \
        apps/common-dart/event_sourcing_datastore/test/storage/storage_backend_contract_test.dart \
        apps/common-dart/event_sourcing_datastore/test/entry_service_test.dart \
        apps/common-dart/event_sourcing_datastore/test/event_repository_test.dart
git commit -m "[CUR-1154] Phase 4.12 Task 5: implement REQ-d00149 (watchEvents) end-to-end"
```

(Adjust the test-file list above to match what your grep in Step 4 actually finds. NEVER `git add -A`.)

---

### Task 6: Failing tests for watchFifo (REQ-d00150)

**Files:** Create `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_fifo_test.dart`.

- [ ] **Step 1: Reuse the `enqueueSingle` helper from `test/test_support/fifo_entry_helpers.dart`**

```bash
head -30 apps/common-dart/event_sourcing_datastore/test/test_support/fifo_entry_helpers.dart
```

Confirm the helper signature used by `sembast_backend_fifo_test.dart`.

- [ ] **Step 2: Write the test file**

```dart
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fifo_entry_helpers.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

void main() {
  group('SembastBackend.watchFifo', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('watch-fifo-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00150-A — snapshot-on-subscribe is empty for an
    // unknown destination.
    test(
      'REQ-d00150-A: watchFifo emits empty snapshot for unknown destination',
      () async {
        // ignore: undefined_method
        final stream = backend.watchFifo('unknown-dest');
        await expectLater(
          stream,
          emits(isA<List<FifoEntry>>().having((l) => l.length, 'length', 0)),
        );
      },
    );

    // Verifies: REQ-d00150-A — enqueue triggers a new snapshot emission.
    test(
      'REQ-d00150-A: watchFifo emits a new snapshot on enqueue',
      () async {
        // ignore: undefined_method
        final stream = backend.watchFifo('dest');
        // Buffer emissions; then enqueue.
        final emissions = <List<FifoEntry>>[];
        final sub = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero); // initial empty snapshot
        await enqueueSingle(backend, 'dest', eventId: 'e1', sequenceNumber: 1);
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last, hasLength(1));
        expect(emissions.last.first.eventIds, ['e1']);
      },
    );

    // Verifies: REQ-d00150-A — markFinal triggers a re-emission.
    test(
      'REQ-d00150-A: watchFifo emits a snapshot on markFinal',
      () async {
        final entry =
            await enqueueSingle(backend, 'dest', eventId: 'e1', sequenceNumber: 1);

        // ignore: undefined_method
        final stream = backend.watchFifo('dest');
        final emissions = <List<FifoEntry>>[];
        final sub = stream.listen(emissions.add);
        await Future<void>.delayed(Duration.zero);

        await backend.markFinal('dest', entry.entryId, FinalStatus.sent);
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.last.first.finalStatus, FinalStatus.sent);
      },
    );

    // Verifies: REQ-d00150-C — cross-destination isolation.
    test(
      'REQ-d00150-C: watchFifo is per-destination (no cross-destination noise)',
      () async {
        // ignore: undefined_method
        final streamA = backend.watchFifo('dest-A');
        final emA = <List<FifoEntry>>[];
        final sa = streamA.listen(emA.add);
        await Future<void>.delayed(Duration.zero);
        emA.clear();

        await enqueueSingle(backend, 'dest-B', eventId: 'b1', sequenceNumber: 1);
        await Future<void>.delayed(Duration.zero);

        await sa.cancel();
        // Mutating dest-B did not emit to dest-A.
        expect(emA, isEmpty);
      },
    );

    // Verifies: REQ-d00150-D — close() sends done; subsequent throws.
    test(
      'REQ-d00150-D: watchFifo closes on backend close, then throws',
      () async {
        // ignore: undefined_method
        final stream = backend.watchFifo('dest');
        final fut = expectLater(stream, emitsThrough(emitsDone));
        await backend.close();
        await fut;
        expect(
          () => backend.watchFifo('dest'),
          throwsStateError,
        );
        backend = await _openBackend('watch-fifo-reopen-$dbCounter.db');
      },
    );
  });
}
```

- [ ] **Step 3: Run; verify failure on missing method**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_watch_fifo_test.dart 2>&1 | tail -10)
```

Expected: compile-time failure on `backend.watchFifo(...)`.

- [ ] **Step 4: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_fifo_test.dart
git commit -m "[CUR-1154] Phase 4.12 Task 6: failing tests for REQ-d00150 (watchFifo)"
```

---

### Task 7: Implement watchFifo (abstract + concrete + FIFO emission hooks)

**Files:** Modify `storage_backend.dart`, `sembast_backend.dart`, test-helper subclasses, and remove the 5 `// ignore: undefined_method` lines from Task 6's test file.

- [ ] **Step 1: Add abstract method**

In `storage_backend.dart`, after `listFifoEntries`:

```dart
  /// Reactive snapshot stream of a destination's FIFO. See REQ-d00150.
  ///
  /// Emits the current queue snapshot on subscribe and on every
  /// mutation to the destination's FIFO. Snapshots are
  /// `List<FifoEntry>` ordered by `sequence_in_queue` ascending.
  /// Multiple subscribers per destination receive identical sequences.
  /// The stream closes when the backend is closed; calling this method
  /// after close SHALL throw `StateError`.
  // Implements: REQ-d00150-A+B+C+D+E.
  Stream<List<FifoEntry>> watchFifo(String destinationId);
```

- [ ] **Step 2: Implement on `SembastBackend`**

```dart
  // Implements: REQ-d00150-A+B+C+D+E — snapshot-on-subscribe + change-
  // driven re-emission filtered by destinationId; broadcast;
  // close-aware.
  @override
  Stream<List<FifoEntry>> watchFifo(String destinationId) {
    if (_fifoChangesController.isClosed) {
      throw StateError(
        'SembastBackend.close has been called; watchFifo unavailable',
      );
    }
    final controller = StreamController<List<FifoEntry>>();
    StreamSubscription<String>? changesSub;

    Future<void> emitSnapshot() async {
      try {
        final snap = await listFifoEntries(destinationId);
        if (!controller.isClosed) controller.add(snap);
      } catch (err, st) {
        if (!controller.isClosed) controller.addError(err, st);
      }
    }

    controller.onListen = () {
      scheduleMicrotask(emitSnapshot);
      changesSub = _fifoChangesController.stream.listen(
        (changedDest) {
          if (changedDest == destinationId) {
            scheduleMicrotask(emitSnapshot);
          }
        },
        onError: (Object err, StackTrace st) => controller.addError(err, st),
        onDone: () => controller.close(),
      );
    };
    controller.onCancel = () async {
      await changesSub?.cancel();
    };
    return controller.stream;
  }
```

- [ ] **Step 3: Hook FIFO-broadcast emission into every FIFO mutator**

For each method that mutates a destination's FIFO, add a post-commit callback `_pendingPostCommit.add(() => _fifoChangesController.add(destinationId))` after the in-txn write succeeds. The mutators (find via `grep -n` in `sembast_backend.dart`):

- `enqueueFifo` — wraps `enqueueFifoTxn` in its own transaction; the post-commit callback should be added inside `enqueueFifoTxn` so both wrappers benefit.
- `enqueueFifoTxn` — add `_pendingPostCommit.add(() => _fifoChangesController.add(destinationId))`.
- `appendAttempt` — opens its own transaction; add `_pendingPostCommit.add(() => _fifoChangesController.add(destinationId))` inside.
- `markFinal` — same.
- `setFinalStatusTxn` — same.
- `deleteNullRowsAfterSequenceInQueueTxn` — same.
- `deleteFifoStoreTxn` — same.

For methods that take a `Txn` argument, the post-commit callback runs when the surrounding `transaction()` commits — so `_pendingPostCommit` (the field set up in Task 5) handles them automatically. For methods that open their own transaction internally, ensure the callback is appended inside the transaction body so the outer-pending logic in `transaction()` catches it.

- [ ] **Step 4: Add `watchFifo` overrides to test-helper subclasses**

Same pattern as Task 5 Step 4 — for each `extends StorageBackend` subclass, add an override (delegate or `Stream.empty()`).

- [ ] **Step 5: Remove the 5 `// ignore: undefined_method` lines from Task 6's test file**

```bash
grep -n "ignore: undefined_method" apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_fifo_test.dart
```

Delete them.

- [ ] **Step 6: Run watchFifo tests; verify PASS**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_watch_fifo_test.dart 2>&1 | tail -10)
```

Expected: `+5: All tests passed!`.

- [ ] **Step 7: Run full suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+582` (577 + 5 new).

- [ ] **Step 8: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean.

- [ ] **Step 9: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart \
        apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_watch_fifo_test.dart \
        <test files with subclass overrides — same as Task 5 list>
git commit -m "[CUR-1154] Phase 4.12 Task 7: implement REQ-d00150 (watchFifo) end-to-end"
```

---

### Task 8: Migrate three example panels off Timer.periodic

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart`

User has parallel WIP under `apps/common-dart/event_sourcing_datastore/example/` — be careful with `git status` and stage ONLY the three panel files.

- [ ] **Step 1: Read each panel's polling structure**

```bash
grep -n "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart
grep -n "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart
grep -n "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart
```

Note the polling cadence and the load function each timer triggers.

- [ ] **Step 2: Migrate `detail_panel.dart`**

In the State class:

- Remove the `_timer` field and its `cancel()` in `dispose`.
- Remove the `_refresh()` method's `findAllEvents(limit: 100000)` call (or keep it as a fallback if other UI paths use it; check the existing usage).
- Add a `StreamSubscription<StoredEvent>? _eventsSub` field.
- In `initState`:

  ```dart
  _eventsSub = widget.backend.watchEvents().listen((_) {
    if (mounted) setState(() {/* triggers rebuild */});
  });
  ```

- In `dispose`:

  ```dart
  _eventsSub?.cancel();
  super.dispose();
  ```

- The build method continues to use whatever async data fetcher it has today; the difference is that `setState` is now triggered by event arrivals instead of by a 500ms timer.

If the existing pattern uses `_AsyncJson` (per the snippet from Phase 4.11 Task 8), the rebuild flow stays the same — only the trigger changes.

- [ ] **Step 3: Migrate `event_stream_panel.dart`**

Same pattern: remove `Timer.periodic`, add `StreamSubscription<StoredEvent>` listening to `watchEvents()`, trigger rebuild on each emission. The existing sort-descending logic stays.

- [ ] **Step 4: Migrate `fifo_panel.dart`**

Replace the `Timer.periodic` + `_refresh()` pattern with a `StreamSubscription<List<FifoEntry>>` listening to `widget.backend.watchFifo(widget.destination.id)`. Each emission updates `_rows` and triggers `setState`. The per-row `findEventById(row.eventIds.last)` lookup from Phase 4.11 Task 8 stays.

- [ ] **Step 5: Run example analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -5)
```

Expected: clean. Likely first-attempt failures: missing import for `StreamSubscription` (it's in `dart:async`), missing import for `FifoEntry` (in `package:event_sourcing_datastore/src/storage/fifo_entry.dart` — already imported in fifo_panel after Phase 4.11).

- [ ] **Step 6: Run lib analyze + tests; confirm no regression**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
```

Expected: clean and `+582`.

- [ ] **Step 7: Verify `Timer.periodic` is gone from example/lib**

```bash
grep -rn "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: empty (zero hits).

```bash
grep -rn "watchEvents\|watchFifo" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: at least 3 hits (one per migrated panel).

- [ ] **Step 8: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart
git commit -m "[CUR-1154] Phase 4.12 Task 8: migrate example panels onto watchEvents/watchFifo"
```

---

### Task 9: Final verification + close worklog

**Files:** Modify `PHASE_4.12_WORKLOG.md`, `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md`.

- [ ] **Step 1: Run the FULL phase invariant set**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

All five clean. Required:
- event_sourcing_datastore: +582
- provenance: +38

- [ ] **Step 2: Final greps**

```bash
grep -rn "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/
grep -rn "watchEvents\|watchFifo" apps/common-dart/event_sourcing_datastore/example/lib/
```

Capture for the worklog.

- [ ] **Step 3: Mark all tasks complete in `PHASE_4.12_WORKLOG.md`**; add Final-verification section.

- [ ] **Step 4: Append `**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +582, provenance +38, all analyze clean. Example fully off Timer.periodic.` to the Phase 4.12 section of the decisions log.

- [ ] **Step 5: Commit**

```bash
git add PHASE_4.12_WORKLOG.md docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md
git commit -m "[CUR-1154] Phase 4.12 Task 9: close worklog (final verify clean)"
```

- [ ] **Step 6: Surface phase-end summary** — phase commits range, final test counts, judgment calls beyond pinned decisions.

---

## What does NOT change in this phase

- `EntryService`, `EventStore`, materializer, sync machinery — untouched.
- `watchEntry(aggregateId)` — deferred to mobile cutover (CUR-1169) per decisions log §4.12.D.
- Sembast `onSnapshots` — explicitly NOT used (decisions log §4.12.B).
- New "DataStore" coordination primitive — explicitly NOT added (decisions log §4.12.E).
- Any consumer app outside the example — unchanged.
- REQ-d00132 broken cross-references and `debugDatabase`'s `queryAudit` survivor — untouched (Phase 4.10/4.11 surfaced; out of scope here).
