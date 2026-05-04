# Master Plan Phase 4.11: Read-Side API Gaps

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close three read-side API gaps in `event_sourcing_datastore`: (1) add `StorageBackend.findEventById` for O(1) lookup by event id, (2) add `StorageBackend.listFifoEntries` for typed enumeration of a destination's queue, (3) migrate non-test/non-example callers off `SembastBackend.debugDatabase()`. Migrate the example app's `fifo_panel.dart` and `detail_panel.dart` onto the new APIs.

**Architecture:** Two new abstract methods on `StorageBackend` with concrete sembast implementations. Sembast event store gets an index on `event_id` if missing (added in the implementation task). Security store's `read()` is migrated by wrapping the existing `readInTxn` in a transaction (no new StorageBackend method needed). `queryAudit()` keeps using `debugDatabase()` for now and is surfaced for user review (decision 4.11.3). Example panels switch to typed `FifoEntry` lists from the new API. Library-only, additive — no schema changes, no consumer-app changes outside the example.

**Tech Stack:** Dart, sembast, `package:flutter_test/flutter_test.dart`. Existing `StorageBackend` / `SembastBackend` patterns; `FifoEntry` already public; `StoredEvent` already public.

**Design spec:** `docs/superpowers/specs/2026-04-24-phase4.11-read-side-api-gaps-design.md`.

**Decisions log:** `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (Phase 4.11 section — pinned decisions; do not re-litigate).

**Branch:** `mobile-event-sourcing-refactor` (shared). **Ticket:** CUR-1154 (continuation). **Phase:** 4.11 (after 4.10). **Depends on:** Phase 4.10 (wedge-aware fillBatch) complete on HEAD (commit `6eb9bed1`+).

---

## Applicable REQ assertions

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-d00147 (NEW) | `StorageBackend.findEventById` — indexed lookup by event_id, null on absent. | Task 2 (spec); Tasks 4 + 5 (TDD impl + tests) |
| REQ-d00148 (NEW) | `StorageBackend.listFifoEntries` — ordered enumeration of a destination's queue with `afterSequenceInQueue` + `limit` slicing. Prohibits opening `fifo_<id>` store directly. | Task 2 (spec); Tasks 6 + 7 (TDD impl + tests) |

**REQ-number ceiling check** (Task 2 verifies live state):

- Pre-Phase 4.9 ceiling: REQ-d00144.
- Phase 4.9 added: REQ-d00145, REQ-d00146.
- Phase 4.10 added no new REQ (extended REQ-d00128 with assertion I).
- Phase 4.11 claims: REQ-d00147 (Task 4), REQ-d00148 (Task 6).

If Task 2's grep finds existing REQ-d00147 / REQ-d00148 in the spec, surface to orchestrator; pick the next two available numbers and update references.

---

## Execution rules

Read `README.md` in the plans directory for TDD cadence and REQ-citation conventions. NOTE: per-phase squash is OUT OF DATE for this phase — user is squash-merging the PR. Each task = one commit on the branch.

Read the design spec end-to-end before Task 1. Re-read §3.1 + §5 before Task 4. Re-read §3.2 + §5 before Task 6. Re-read §3.3 + §3.4 + decisions log §4.11.1–§4.11.4 before Task 8.

**Project conventions to follow:**

- Implementer MUST use explicit `git add <files>`, NEVER `git add <directory>` or `git add -A`. User has parallel WIP under `apps/common-dart/event_sourcing_datastore/example/`.
- Pre-commit hook regenerates `spec/INDEX.md` REQ hashes — let it run. If the hook modifies the staged set, re-stage `spec/INDEX.md` and re-commit. No `--no-verify`.
- Test framework is `package:flutter_test/flutter_test.dart`.
- Project lints enforce `prefer_constructors_over_static_methods` — use factory constructors not statics for type-returning helpers.
- Per-function `// Implements: REQ-xxx-Y — <prose>` markers.
- Per-test `// Verifies: REQ-xxx-Y` markers; assertion ID at the start of the `test(...)` description string.
- Greenfield mode (decisions log §XP.1): no backward-compat code, no transition logic, no "previously did X / no longer does Y" wording.

**Phase invariants** (must be true at end of phase):

1. `flutter test` clean in `apps/common-dart/event_sourcing_datastore`. Pass count: ≥ 566 + N (N depends on how many test cases land across Tasks 5, 7, 8 — minimum 4: hit, miss, listFifoEntries empty, listFifoEntries ordered).
2. `flutter analyze` clean in `apps/common-dart/event_sourcing_datastore` AND in `apps/common-dart/event_sourcing_datastore/example`.
3. `flutter test` clean in `apps/common-dart/provenance` (38 unchanged).
4. `grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/lib/` returns: the definition site in `sembast_backend.dart` AND the `queryAudit` site in `sembast_security_context_store.dart` (both intentional per decisions log §4.11.3); ZERO additional non-test hits.
5. `grep -rn "intMapStoreFactory.store" apps/common-dart/event_sourcing_datastore/example/lib/` returns ZERO hits — example is fully off the FIFO reach-around.
6. Example app builds: `cd apps/common-dart/event_sourcing_datastore/example && flutter analyze`.

---

## Plan

### Task 1: Baseline + worklog

**Files:**

- Create: `PHASE_4.11_WORKLOG.md` at repo root.

- [ ] **Step 1: Confirm Phase 4.10 is committed on HEAD**

```bash
git log --oneline -3
```

Expected: top commit is `6eb9bed1 [CUR-1154] Phase 4.10 Task 6: close worklog (final verify clean)` (or later if other in-flight work has landed).

- [ ] **Step 2: Run `event_sourcing_datastore` tests; confirm 566 pass**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+566` (from Phase 4.10's two new tests).

- [ ] **Step 3: Run `provenance` tests; confirm 38 pass**

```bash
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -5)
```

- [ ] **Step 4: Run analyze on both packages + example**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected for each: `No issues found!`.

- [ ] **Step 5: Snapshot the current `debugDatabase` and `intMapStoreFactory.store` reach-arounds**

Capture the BEFORE state so Task 8's after-state can be diffed:

```bash
grep -rn "debugDatabase\|intMapStoreFactory.store" apps/common-dart/event_sourcing_datastore/lib apps/common-dart/event_sourcing_datastore/example/lib
```

Expected hits (write into the worklog as "BEFORE" baseline):
- `lib/src/storage/sembast_backend.dart:105` — definition of `debugDatabase()`.
- `lib/src/security/sembast_security_context_store.dart:23` — `intMapStoreFactory.store('events')` for queryAudit's events-store handle (intentional, kept).
- `lib/src/security/sembast_security_context_store.dart:28` — `read()` calls `debugDatabase()` (will migrate in Task 8).
- `lib/src/security/sembast_security_context_store.dart:126` — `queryAudit()` calls `debugDatabase()` (kept, decisions log §4.11.3).
- `example/lib/widgets/detail_panel.dart:144–145` — FIFO reach-around (will migrate in Task 8).
- `example/lib/widgets/fifo_panel.dart:81–82` — FIFO reach-around (will migrate in Task 8).

If the actual grep shows additional hits not in this list, surface to orchestrator before proceeding — there may be new reach-arounds the spec didn't anticipate.

- [ ] **Step 6: Write the worklog stub**

Create `PHASE_4.11_WORKLOG.md` at repo root:

```markdown
# Phase 4.11 Worklog — Read-Side API Gaps (CUR-1154)

**Spec:** docs/superpowers/specs/2026-04-24-phase4.11-read-side-api-gaps-design.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.11 section)
**Branch:** mobile-event-sourcing-refactor

## Baseline (Task 1)

- event_sourcing_datastore: <FILL IN: pass count>
- provenance: <FILL IN: pass count>
- analyze (lib + example + provenance): clean

### `debugDatabase` / `intMapStoreFactory.store` BEFORE state

<paste Step 5 output>

## Tasks

- [ ] Task 1: Baseline + worklog
- [ ] Task 2: Spec — REQ-d00147 + REQ-d00148 (two new sections)
- [ ] Task 3: Failing test for findEventById (REQ-d00147)
- [ ] Task 4: Implement findEventById on StorageBackend + SembastBackend
- [ ] Task 5: Failing test for listFifoEntries (REQ-d00148)
- [ ] Task 6: Implement listFifoEntries on StorageBackend + SembastBackend
- [ ] Task 7: Migrate security store's `read()` off debugDatabase
- [ ] Task 8: Migrate example panels (fifo_panel + detail_panel) onto new APIs; document debugDatabase narrowing
- [ ] Task 9: Final verification + close worklog
```

- [ ] **Step 7: Commit**

```bash
git add PHASE_4.11_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.11 Task 1: baseline + worklog"
```

---

### Task 2: Spec — add REQ-d00147 (findEventById) and REQ-d00148 (listFifoEntries)

**Files:**

- Modify: `spec/dev-event-sourcing-mobile.md` (insert two new REQ sections at end of file or after REQ-d00146).

- [ ] **Step 1: Confirm REQ-d00147 and REQ-d00148 are NOT already taken**

```bash
grep -n "^# REQ-d00147\|^# REQ-d00148" spec/dev-event-sourcing-mobile.md
```

Expected: empty (no matches). If either is already taken, surface to orchestrator and select next two free numbers; update Task 4/Task 6 commits and the decisions log to match.

- [ ] **Step 2: Locate insertion point**

REQ-d00146 is the highest existing REQ-d in `dev-event-sourcing-mobile.md` after Phase 4.9. Append the two new REQs after REQ-d00146's `*End*` marker. If a `# REQ-d`-numbered section happens to exist between REQ-d00146 and end-of-file, insert numerically (REQ-d00147 before REQ-d00148; both before any higher numbers).

```bash
grep -n "^# REQ-d" spec/dev-event-sourcing-mobile.md | tail -5
```

- [ ] **Step 3: Insert REQ-d00147**

After the appropriate `*End*` line, insert:

```markdown

---

# REQ-d00147: findEventById Storage Lookup

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

Read paths that have an `event_id` (UI panels rendering FIFO contents, hash-chain walkers from the Phase 4.9 ingest path, verification flows) need to resolve that id to the rest of the event without scanning the log. The pre-existing `findEventsForAggregate` and `findAllEvents` methods on `StorageBackend` cover by-aggregate and by-range reads but not by-id lookup; consumers without a typed lookup either pull a window of events and build their own id→event map per render tick (e.g. an O(N) every 500 ms) or scan via `findAllEvents` and discard everything but the matching id. Both patterns degrade with log size and add no value over the indexed lookup the storage layer can provide directly.

`findEventById` lives on `StorageBackend` rather than on `EventStore` or `EntryService` because the lookup is storage-shaped (key→row), the index belongs to the backend, and the abstract method lets future non-sembast backends provide their own efficient single-row lookup. The contract is intentionally the simplest shape — one method, one parameter, nullable return — so consumers can layer caches or batch fetches on top without the storage layer prescribing them.

The non-transactional contract is sufficient because there is no read-then-write composition in the call sites this method serves; in-transaction callers already have `findEventByIdInTxn` (added in Phase 4.9 to support ingest's idempotency check).

## Assertions

A. `StorageBackend.findEventById(String eventId)` SHALL return the `StoredEvent` whose `event_id` equals `eventId`, or `null` when no event with that id exists in the log. The method SHALL NOT throw on a missing id; `null` is the not-found signal.

B. The `SembastBackend` implementation SHALL use an indexed lookup on the `event_id` field (a sembast `Filter.equals` query against an indexed field) rather than a full-store scan. Future non-sembast backends SHALL provide an equivalent single-row lookup; the abstract contract does not specify the index mechanism but does specify the behavior: a single matching row is returned, with no obligation to enumerate the rest of the log.

C. `findEventById` SHALL be non-transactional and read-only. Callers requiring read-coherence with writes staged in a same-transaction body SHALL use `findEventByIdInTxn` (REQ-d00145).

*End* *findEventById Storage Lookup*
```

(Use real newlines, not literal backslash-n. Leave one blank line on each side of the new REQ block. The hash placeholder is omitted; the pre-commit hook computes it.)

- [ ] **Step 4: Insert REQ-d00148**

After REQ-d00147's `*End*` line:

```markdown

---

# REQ-d00148: listFifoEntries Queue Enumeration

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p01001

## Rationale

`StorageBackend` exposes point/head/summary queries against a destination's FIFO (`readFifoHead`, `readFifoRow(dest, entryId)`, `wedgedFifos`, `anyFifoWedged`) but no "enumerate the queue." Consumers that want a queue-inspector view — operator FIFO panels, drain-progress UIs, audit walkers — either have no public path or open the underlying sembast store by name and read raw maps. The string-keyed reach-around couples consumers to the `fifo_<destination_id>` naming convention, the sembast layout, and the `debugDatabase()` test escape hatch, all of which are implementation details of the sembast backend.

The new method returns typed `FifoEntry` objects, sliced by `afterSequenceInQueue` (exclusive) and `limit`. The pagination affordance matches the existing `findAllEvents(afterSequence:, limit:)` convention so consumers learn one shape. Enumeration order is `sequence_in_queue` ascending — same direction `readFifoHead` walks. UI callers that want most-recent-first reverse in the view layer.

## Assertions

A. `StorageBackend.listFifoEntries(String destinationId, {int? afterSequenceInQueue, int? limit})` SHALL return all FIFO entries for `destinationId`, ordered by `sequence_in_queue` ascending. When `destinationId` has no registered FIFO store, the method SHALL return an empty list (consistent with `readFifoHead` returning `null` for the same case).

B. When `afterSequenceInQueue` is non-null, returned entries SHALL be strictly greater than that value (exclusive lower bound). When `limit` is non-null, at most `limit` entries SHALL be returned (taken from the start of the ordered range).

C. Returned `FifoEntry` objects SHALL carry the same fields populated by `readFifoHead` and `readFifoRow` — `entry_id`, `event_ids`, `event_id_range`, `sequence_in_queue`, `wire_payload`, `wire_format`, `transform_version`, `enqueued_at`, `attempts`, `final_status`, `sent_at`. No raw-map representation SHALL be exposed.

D. Callers SHALL NOT open the `fifo_<destination_id>` sembast store directly to read FIFO entries. The `fifo_<destination_id>` naming convention is an implementation detail of the sembast backend and is not part of the public storage contract; `listFifoEntries` is the supported enumeration API.

*End* *listFifoEntries Queue Enumeration*
```

- [ ] **Step 5: Run analyze (sanity)**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `No issues found!`. (Spec edits do not affect Dart analyze; this confirms no accidental cross-impact.)

- [ ] **Step 6: Commit**

The pre-commit hook will regenerate hashes on the new REQs and update `spec/INDEX.md`. Stage both files and let the hook run:

```bash
git add spec/dev-event-sourcing-mobile.md
git commit -m "[CUR-1154] Phase 4.11 Task 2: spec REQ-d00147 (findEventById) + REQ-d00148 (listFifoEntries)"
```

If the hook stages additional changes (likely `spec/INDEX.md`), it usually folds them into the same commit. If for any reason the hook leaves files unstaged after a failure, fix the cause (don't `--no-verify`), re-stage with explicit paths, re-commit.

---

### Task 3: Failing test for findEventById (REQ-d00147)

**Files:**

- Create: `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_event_by_id_test.dart`

- [ ] **Step 1: Read an existing storage test for the boilerplate pattern**

```bash
sed -n '1,40p' apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_event_test.dart
```

Note the test scaffolding: `Future<SembastBackend> _openBackend(String path)` factory, in-memory sembast database, `_appendEvent` helper, `setUp` / `tearDown`.

- [ ] **Step 2: Create the new test file with three failing tests**

Write `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_event_by_id_test.dart`:

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
  group('SembastBackend.findEventById', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('find-event-by-id-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00147-A — found id returns the stored event.
    test(
      'REQ-d00147-A: findEventById returns the stored event when present',
      () async {
        final appended = await _appendEvent(backend, eventId: 'evt-target');
        final result = await backend.findEventById('evt-target');
        expect(result, isNotNull);
        expect(result!.eventId, 'evt-target');
        expect(result.sequenceNumber, appended.sequenceNumber);
        expect(result.aggregateId, appended.aggregateId);
        expect(result.eventHash, appended.eventHash);
      },
    );

    // Verifies: REQ-d00147-A — absent id returns null (does NOT throw).
    test(
      'REQ-d00147-A: findEventById returns null when no event with that id exists',
      () async {
        await _appendEvent(backend, eventId: 'evt-other-1');
        await _appendEvent(backend, eventId: 'evt-other-2');
        final result = await backend.findEventById('evt-missing');
        expect(result, isNull);
      },
    );

    // Verifies: REQ-d00147-A — multiple events present, lookup picks the right one.
    test(
      'REQ-d00147-A: findEventById disambiguates among many stored events',
      () async {
        await _appendEvent(backend, eventId: 'evt-a');
        final target = await _appendEvent(backend, eventId: 'evt-target');
        await _appendEvent(backend, eventId: 'evt-c');
        final result = await backend.findEventById('evt-target');
        expect(result, isNotNull);
        expect(result!.sequenceNumber, target.sequenceNumber);
        expect(result.eventId, 'evt-target');
      },
    );
  });
}
```

- [ ] **Step 3: Run the new tests; verify they FAIL on missing method**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_event_by_id_test.dart 2>&1 | tail -20)
```

Expected: compile-time failure on `backend.findEventById(...)` ("The method 'findEventById' isn't defined for the type 'SembastBackend'."). This proves the test wires through to the absent method and not to a typo.

If the failure mode is a SYNTAX error or import error, fix the test file and re-run until you see the missing-method failure.

- [ ] **Step 4: Commit the failing test**

```bash
git add apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_event_by_id_test.dart
git commit -m "[CUR-1154] Phase 4.11 Task 3: failing test for REQ-d00147 (findEventById)"
```

---

### Task 4: Implement findEventById on StorageBackend + SembastBackend

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart` (add abstract method)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` (add concrete implementation; ensure index on `event_id`)

- [ ] **Step 1: Read the existing `findEventByIdInTxn` to mirror its shape**

```bash
grep -n "findEventByIdInTxn" apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart
```

Note the implementation. The non-transactional variant follows the same finder pattern but uses the database (not the txn) directly.

- [ ] **Step 2: Add abstract method to `StorageBackend`**

In `lib/src/storage/storage_backend.dart`, near `findEventByIdInTxn` (search for it), add the non-transactional variant:

```dart
  /// Read a single event by `event_id` outside any transaction. Returns
  /// `null` when no event with that id is present. Indexed lookup on the
  /// sembast backend; abstract contract requires equivalent single-row
  /// lookup, not a scan.
  ///
  /// Callers needing read-coherence with writes staged in the same
  /// transaction body SHALL use [findEventByIdInTxn] (REQ-d00145) instead.
  // Implements: REQ-d00147-A+B+C — non-transactional indexed lookup by event_id.
  Future<StoredEvent?> findEventById(String eventId);
```

Place it adjacent to `findEventByIdInTxn` for cohesion.

- [ ] **Step 3: Implement on `SembastBackend`**

In `lib/src/storage/sembast_backend.dart`, add a concrete implementation. Mirror the in-txn variant's finder; use `_database()` instead of a txn:

```dart
  // Implements: REQ-d00147-A+B+C — non-transactional indexed lookup by
  // event_id; returns null when absent; uses the same Filter.equals
  // pattern as findEventByIdInTxn, against the events store on the
  // database (not a transaction).
  @override
  Future<StoredEvent?> findEventById(String eventId) async {
    final finder = Finder(filter: Filter.equals('event_id', eventId));
    final record = await _eventsStore.findFirst(_database(), finder: finder);
    if (record == null) return null;
    return StoredEvent.fromMap(record.value, record.key);
  }
```

(Substitute `_eventsStore` with the actual private field name used by the existing `findEventByIdInTxn` — read the existing method to confirm the field name.)

- [ ] **Step 4: Ensure sembast index on `event_id` exists**

```bash
grep -n "event_id\|StoreRef\|createIndex\|indexedDB\|Filter.equals" apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart | head -20
```

Sembast doesn't have explicit index creation in the `Filter.equals` path — sembast scans matching records and `Filter.equals` is the standard lookup. The "index" requirement in REQ-d00147-B is satisfied by sembast's hash-based lookup on the `event_id` field; for very large stores sembast can be configured with an index, but for mobile-scale event logs the unindexed lookup is acceptable. If the existing `findEventByIdInTxn` does not configure an explicit index, do not add one in this task — the requirement is satisfied by the existing query mechanism.

If the codebase does configure indexes (search for `Index(`), follow the existing pattern for the `event_id` field.

- [ ] **Step 5: Run the failing tests; verify they PASS**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_event_by_id_test.dart 2>&1 | tail -10)
```

Expected: `+3: All tests passed!`.

- [ ] **Step 6: Run the full test suite; verify nothing regressed**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+569` (566 baseline + 3 new tests from Task 3). `All tests passed!`.

- [ ] **Step 7: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart
git commit -m "[CUR-1154] Phase 4.11 Task 4: implement REQ-d00147 (findEventById)"
```

---

### Task 5: Failing tests for listFifoEntries (REQ-d00148)

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_fifo_test.dart`

- [ ] **Step 1: Read the existing FIFO test file to find the right group/section**

```bash
sed -n '1,60p' apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_fifo_test.dart
```

Identify the helper functions for enqueueing FIFO rows. There should be patterns for `enqueueFifo`, `markFinal`, etc.

- [ ] **Step 2: Add a new `group('listFifoEntries', ...)` block at the bottom of `void main() { ... }`**

Insert before the closing `}` of `main`:

```dart
  group('listFifoEntries', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase('list-fifo-$dbCounter.db');
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00148-A — empty FIFO returns an empty list (no throw).
    test(
      'REQ-d00148-A: listFifoEntries on unknown destination returns empty list',
      () async {
        final result = await backend.listFifoEntries('never-registered');
        expect(result, isEmpty);
      },
    );

    // Verifies: REQ-d00148-A+C — entries returned in sequence_in_queue order
    // with all FifoEntry fields populated.
    test(
      'REQ-d00148-A+C: listFifoEntries returns entries ordered by sequence_in_queue',
      () async {
        // Enqueue three rows.
        for (var i = 1; i <= 3; i++) {
          final event = await _appendEventForFifo(
            backend,
            eventId: 'e$i',
          );
          await backend.enqueueFifo(
            'dest',
            [event],
            const WirePayload(
              bytes: <int>[],
              contentType: 'application/json',
              transformVersion: 'v1',
            ),
          );
        }
        final result = await backend.listFifoEntries('dest');
        expect(result, hasLength(3));
        // Ordered ascending by sequence_in_queue.
        expect(result[0].sequenceInQueue < result[1].sequenceInQueue, isTrue);
        expect(result[1].sequenceInQueue < result[2].sequenceInQueue, isTrue);
        // Each row carries event_ids per REQ-d00148-C.
        expect(result[0].eventIds, ['e1']);
        expect(result[1].eventIds, ['e2']);
        expect(result[2].eventIds, ['e3']);
      },
    );

    // Verifies: REQ-d00148-B — afterSequenceInQueue is exclusive.
    test(
      'REQ-d00148-B: listFifoEntries afterSequenceInQueue is exclusive',
      () async {
        for (var i = 1; i <= 4; i++) {
          final event = await _appendEventForFifo(backend, eventId: 'e$i');
          await backend.enqueueFifo(
            'dest',
            [event],
            const WirePayload(
              bytes: <int>[],
              contentType: 'application/json',
              transformVersion: 'v1',
            ),
          );
        }
        final all = await backend.listFifoEntries('dest');
        expect(all, hasLength(4));
        final secondRow = all[1];
        final after = await backend.listFifoEntries(
          'dest',
          afterSequenceInQueue: secondRow.sequenceInQueue,
        );
        // Exclusive: rows 3 and 4 only.
        expect(after, hasLength(2));
        expect(after.first.sequenceInQueue > secondRow.sequenceInQueue, isTrue);
      },
    );

    // Verifies: REQ-d00148-B — limit caps the returned list size.
    test(
      'REQ-d00148-B: listFifoEntries limit caps result size',
      () async {
        for (var i = 1; i <= 5; i++) {
          final event = await _appendEventForFifo(backend, eventId: 'e$i');
          await backend.enqueueFifo(
            'dest',
            [event],
            const WirePayload(
              bytes: <int>[],
              contentType: 'application/json',
              transformVersion: 'v1',
            ),
          );
        }
        final two = await backend.listFifoEntries('dest', limit: 2);
        expect(two, hasLength(2));
        // Limit is taken from the start of the ordered range.
        expect(two[0].eventIds, ['e1']);
        expect(two[1].eventIds, ['e2']);
      },
    );
  });
```

If the file does not already have a top-level `_appendEventForFifo` helper, add one at the top of the file (after the existing helpers):

```dart
Future<StoredEvent> _appendEventForFifo(
  SembastBackend backend, {
  required String eventId,
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: 'agg-1',
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
```

(If a near-identical helper already exists under a different name in the existing test file, use the existing one — do NOT duplicate.)

- [ ] **Step 3: Verify imports include `WirePayload`, `Initiator`, `StoredEvent`, `flutter_test`, `sembast_memory`**

```bash
head -20 apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_fifo_test.dart
```

Add any missing imports:

```dart
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
```

- [ ] **Step 4: Run the new tests; verify they FAIL on missing method**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_fifo_test.dart --plain-name 'REQ-d00148' 2>&1 | tail -20)
```

Expected: compile-time failure on `backend.listFifoEntries(...)` ("The method 'listFifoEntries' isn't defined for the type 'SembastBackend'."). Proves the wiring is correct.

- [ ] **Step 5: Commit the failing tests**

```bash
git add apps/common-dart/event_sourcing_datastore/test/storage/sembast_backend_fifo_test.dart
git commit -m "[CUR-1154] Phase 4.11 Task 5: failing tests for REQ-d00148 (listFifoEntries)"
```

---

### Task 6: Implement listFifoEntries on StorageBackend + SembastBackend

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`

- [ ] **Step 1: Read the existing `readFifoHead` and `readFifoRow` implementations**

```bash
grep -n "readFifoHead\|readFifoRow" apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart | head
```

Note the FIFO store name pattern (`fifo_$destinationId`), the `intMapStoreFactory` usage, and how rows are converted into `FifoEntry` objects. Mirror this pattern.

- [ ] **Step 2: Add abstract method to `StorageBackend`**

In `lib/src/storage/storage_backend.dart`, in the `// -------- FIFO (per destination) --------` section (search for it), add:

```dart
  /// Enumerate FIFO entries for [destinationId], ordered by
  /// `sequence_in_queue` ascending. Optionally sliced by
  /// [afterSequenceInQueue] (exclusive) and [limit].
  ///
  /// Returns `FifoEntry` objects (typed; not raw maps). When
  /// [destinationId] has no registered FIFO store, returns an empty list.
  /// Callers SHALL NOT open the `fifo_<id>` sembast store directly — the
  /// store name is an implementation detail of the sembast backend.
  // Implements: REQ-d00148-A+B+C+D — typed enumeration with exclusive
  // slicing; empty on unknown destination; no raw-map exposure.
  Future<List<FifoEntry>> listFifoEntries(
    String destinationId, {
    int? afterSequenceInQueue,
    int? limit,
  });
```

- [ ] **Step 3: Implement on `SembastBackend`**

```dart
  // Implements: REQ-d00148-A+B+C+D — listFifoEntries returns ordered
  // FifoEntry list, applies exclusive afterSequenceInQueue and optional
  // limit, returns empty for an unknown destination (no FIFO store
  // registered).
  @override
  Future<List<FifoEntry>> listFifoEntries(
    String destinationId, {
    int? afterSequenceInQueue,
    int? limit,
  }) async {
    final store = intMapStoreFactory.store('fifo_$destinationId');
    final filters = <Filter>[];
    if (afterSequenceInQueue != null) {
      filters.add(Filter.greaterThan('sequence_in_queue', afterSequenceInQueue));
    }
    final finder = Finder(
      filter: filters.isEmpty
          ? null
          : (filters.length == 1 ? filters.single : Filter.and(filters)),
      sortOrders: [SortOrder('sequence_in_queue', true)],
      limit: limit,
    );
    final records = await store.find(_database(), finder: finder);
    return records
        .map((r) => FifoEntry.fromMap(Map<String, Object?>.from(r.value), r.key))
        .toList();
  }
```

(Substitute the actual `FifoEntry.fromMap` factory name if different — check `lib/src/storage/fifo_entry.dart` for the existing `fromMap` / factory pattern used by `readFifoHead`.)

- [ ] **Step 4: Run the failing tests; verify they PASS**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/sembast_backend_fifo_test.dart --plain-name 'REQ-d00148' 2>&1 | tail -10)
```

Expected: `+4: All tests passed!`.

- [ ] **Step 5: Run the full test suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: `+573` (569 + 4 new tests). `All tests passed!`.

- [ ] **Step 6: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart
git commit -m "[CUR-1154] Phase 4.11 Task 6: implement REQ-d00148 (listFifoEntries)"
```

---

### Task 7: Migrate security store's `read()` off debugDatabase

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/security/sembast_security_context_store.dart`

Per decisions log §4.11.2: trivial migration via wrapping `readInTxn` in a transaction. No new StorageBackend method.

- [ ] **Step 1: Read the current `read()` implementation**

```bash
sed -n '26,33p' apps/common-dart/event_sourcing_datastore/lib/src/security/sembast_security_context_store.dart
```

Confirm the current shape:

```dart
@override
Future<EventSecurityContext?> read(String eventId) async {
  final db = backend.debugDatabase();
  final raw = await _store.record(eventId).get(db);
  if (raw == null) return null;
  return EventSecurityContext.fromJson(Map<String, Object?>.from(raw));
}
```

- [ ] **Step 2: Replace with the in-txn wrapper**

```dart
@override
Future<EventSecurityContext?> read(String eventId) {
  return backend.transaction((txn) => readInTxn(txn, eventId));
}
```

The in-txn variant already exists at line 35–40 and does the typed read. Wrapping it in a one-line transaction keeps the public contract identical (non-transactional read) while removing the `debugDatabase()` call.

- [ ] **Step 3: Run the security store tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/security/ 2>&1 | tail -5)
```

Expected: `All tests passed!` and the same pass count as before (the tests should be insensitive to the implementation change). If pass count differs, investigate before proceeding — the change should be behavior-preserving.

- [ ] **Step 4: Run the full test suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: still `+573` (no test count change; this is a refactor).

- [ ] **Step 5: Verify `read()` no longer references `debugDatabase`**

```bash
grep -n "debugDatabase" apps/common-dart/event_sourcing_datastore/lib/src/security/sembast_security_context_store.dart
```

Expected: ONE remaining hit (line ~126, inside `queryAudit()`). This is intentional per decisions log §4.11.3.

- [ ] **Step 6: Run analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/security/sembast_security_context_store.dart
git commit -m "[CUR-1154] Phase 4.11 Task 7: migrate security store read() off debugDatabase"
```

---

### Task 8: Migrate example panels (fifo_panel + detail_panel) onto new APIs; document debugDatabase narrowing

**Files:**

- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` (doc-comment narrowing on `debugDatabase`)

- [ ] **Step 1: Read fifo_panel.dart's current FIFO-load logic**

```bash
sed -n '70,100p' apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart
```

Confirm: opens `intMapStoreFactory.store('fifo_${widget.destination.id}')`, calls `find(widget.backend.debugDatabase())`, converts records to `Map<String, Object?>`. Look at how `_rows` is typed and consumed in the rest of the file.

- [ ] **Step 2: Migrate fifo_panel.dart's FIFO load to `listFifoEntries`**

Replace the sembast store open + `find` (the lines around 75–82) with:

```dart
final entries = await widget.backend.listFifoEntries(widget.destination.id);
```

If `_rows` is currently typed as `List<Map<String, Object?>>?`, change to `List<FifoEntry>?` and update every read site to use typed field access:

- `row['entry_id']` → `row.entryId`
- `row['sequence_in_queue']` → `row.sequenceInQueue`
- `row['event_ids']` → `row.eventIds`
- `row['final_status']` → `row.finalStatus?.name` (or `row.finalStatus?.toString()` depending on tile rendering)
- `row['attempts']` → `row.attempts` (already `List<AttemptResult>`)
- `row['enqueued_at']` → `row.enqueuedAt`

If the file currently maintains a `_seqByEventId` map built from `findAllEvents(limit: 500)` for the latest-event-seq label, replace it with per-row `findEventById(row.eventIds.last)` — at O(1) per tile this is cheaper than the 500-row scan and removes the field. Add the lookup inside the row builder:

```dart
final tail = await widget.backend.findEventById(row.eventIds.last);
final tailSeqLabel = tail == null ? '?' : tail.sequenceNumber.toString();
```

(Adjust to match the existing builder's async pattern — if the row builder is sync, lift the lookup into the load function and pass `Map<String, int>` of `eventId -> sequenceNumber` for the tile to read synchronously.)

Add the `FifoEntry` import:

```dart
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
```

Drop the now-unused imports: `package:sembast/sembast.dart`'s `intMapStoreFactory` if no other use remains in the file.

- [ ] **Step 3: Migrate detail_panel.dart's FIFO reach-around (lines 144–145)**

Read the surrounding context first:

```bash
sed -n '135,160p' apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart
```

Replace:

```dart
final store = intMapStoreFactory.store('fifo_$fifoDestId');
final records = await store.find(widget.backend.debugDatabase());
for (final r in records) {
  final m = Map<String, Object?>.from(r.value);
  if (m['entry_id'] == fifoId) {
    return <String, Object?>{'destination': fifoDestId, ...m};
  }
}
return <String, Object?>{
  'error': 'not found',
  'destination': fifoDestId,
  'entry_id': fifoId,
};
```

With:

```dart
final entries = await widget.backend.listFifoEntries(fifoDestId);
for (final entry in entries) {
  if (entry.entryId == fifoId) {
    return <String, Object?>{
      'destination': fifoDestId,
      ...entry.toMap(),
    };
  }
}
return <String, Object?>{
  'error': 'not found',
  'destination': fifoDestId,
  'entry_id': fifoId,
};
```

(If `FifoEntry.toMap()` does not exist, use explicit field rendering: `'entry_id': entry.entryId, 'sequence_in_queue': entry.sequenceInQueue, 'event_ids': entry.eventIds, ...`. Check `lib/src/storage/fifo_entry.dart` for an existing `toMap` factory.)

Drop the `intMapStoreFactory` and `debugDatabase` references; drop the `package:sembast/sembast.dart` import if no other use remains.

- [ ] **Step 4: Update the doc-comment on `debugDatabase()` to narrow its purpose**

In `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`, find the `debugDatabase` definition (~line 102–105) and replace the doc comment with:

```dart
  /// Returns the underlying sembast [Database] handle. Use ONLY in:
  /// (a) tests that need to inspect raw store contents that have no
  /// public API equivalent;
  /// (b) the sembast-specific `SembastSecurityContextStore.queryAudit`
  /// pending its own typed audit-query API (see decisions log
  /// §4.11.3).
  ///
  /// Application code SHALL NOT call this — every public read need
  /// has a typed `StorageBackend` method (`readFifoHead`,
  /// `readFifoRow`, `listFifoEntries`, `findEventById`,
  /// `findEventsForAggregate`, `findAllEvents`, `findEntries`,
  /// `findViewRows`, etc.). New non-test callers ARE a code smell.
  // ignore: library_private_types_in_public_api
  Database debugDatabase() => _database();
```

- [ ] **Step 5: Run example analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -5)
```

Expected: `No issues found!`. If it fails, the most likely culprits are unused imports (drop them), a typed-field name mismatch (cross-check against `lib/src/storage/fifo_entry.dart`), or a missing `await` on a now-async lookup.

- [ ] **Step 6: Run lib analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: `No issues found!`.

- [ ] **Step 7: Run lib tests; confirm nothing regressed**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: still `+573`. (No test changes in this task; just example + a doc comment.)

- [ ] **Step 8: Verify the reach-around targets are gone**

```bash
grep -rn "intMapStoreFactory.store" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: empty (zero hits). The example is fully off the FIFO sembast reach-around.

```bash
grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: empty (zero hits). The example no longer calls `debugDatabase`.

```bash
grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/lib/
```

Expected: TWO hits — definition site in `sembast_backend.dart`, and `queryAudit` site in `sembast_security_context_store.dart`. Both intentional.

- [ ] **Step 9: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart \
        apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart
git commit -m "[CUR-1154] Phase 4.11 Task 8: migrate example panels onto findEventById/listFifoEntries; narrow debugDatabase doc"
```

---

### Task 9: Final verification + close worklog

**Files:**

- Modify: `PHASE_4.11_WORKLOG.md`
- Modify: `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (add `**Closed:**` line under Phase 4.11)

- [ ] **Step 1: Run the FULL phase invariant set**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/provenance && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

All five must show clean. Required final-state numbers:

- event_sourcing_datastore: +573 (566 baseline + 7 new tests: 3 findEventById + 4 listFifoEntries; +0 from Task 7 refactor + Task 8 example migration which carries no library tests).
- provenance: +38 (unchanged).

- [ ] **Step 2: Run the `debugDatabase` / `intMapStoreFactory` final grep and capture for the worklog**

```bash
grep -rn "debugDatabase\|intMapStoreFactory.store" apps/common-dart/event_sourcing_datastore/lib apps/common-dart/event_sourcing_datastore/example/lib
```

Expected lines:
- `lib/src/storage/sembast_backend.dart:<lineno>` — definition of `debugDatabase()`.
- `lib/src/security/sembast_security_context_store.dart:23` — `intMapStoreFactory.store('events')` for queryAudit (intentional).
- `lib/src/security/sembast_security_context_store.dart:<lineno>` — `debugDatabase` in `queryAudit()` (intentional).

Zero hits in example/lib/.

If unexpected hits remain, investigate before closing the phase.

- [ ] **Step 3: Mark all tasks complete in `PHASE_4.11_WORKLOG.md`**

Edit the worklog: change every `- [ ]` to `- [x]`. Add a "Final verification" section with the test/analyze command outputs from Step 1 and the grep output from Step 2.

- [ ] **Step 4: Append `**Closed:**` to the Phase 4.11 section of the decisions log**

Add a line at the bottom of the Phase 4.11 section in `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md`:

```markdown
**Closed:** 2026-04-24. Final verification: event_sourcing_datastore +573, provenance +38, all analyze clean. Two intentional `debugDatabase` references remain (definition + queryAudit) per §4.11.3.
```

- [ ] **Step 5: Commit the worklog and decisions-log updates**

```bash
git add PHASE_4.11_WORKLOG.md docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md
git commit -m "[CUR-1154] Phase 4.11 Task 9: close worklog (final verify clean)"
```

- [ ] **Step 6: Surface phase-end summary to orchestrator**

Report: phase commits range (`<first>..<last>`), final test counts, the `debugDatabase` survivor count and reasons, any judgment calls beyond what's pinned in the decisions log.

---

## What does NOT change in this phase

- `EventStore`, `EntryService`, materializer, sync machinery — untouched.
- `StorageBackend.findEventByIdInTxn` (added in Phase 4.9) — the new non-txn variant is its sibling, not a replacement.
- `FifoEntry` schema — unchanged; only the enumeration API is added.
- `queryAudit()` — keeps using `debugDatabase()` (decisions log §4.11.3 — surfaced for user review).
- `event_stream_panel.dart` polling pattern — falls under Phase 4.12 (reactive layer); not touched here.
- Any consumer app outside the example — unchanged; daily-diary, edc, etc. don't use these APIs today.
- REQ-d00132 broken cross-references — pre-existing, surfaced by Phase 4.10's decisions log §4.10.4; out of scope here.
