# Phase 4.22 Implementation Plan: Materialize-on-Ingest and System-Event Bridging

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Phase 4.9 deferred materialize-on-ingest path; opt-in bridge system audit events over the wire; add cross-hop discrimination API; demonstrate via dual-pane demo.

**Architecture:** Modify `EventStore._ingestOneInTxn` to fire materializers per-event under the same `def.materialize` + `m.appliesTo` gates as `_appendInTxn`. Lift the Phase 4.17 hard-drop of system entry types in `fillBatch` and `historicalReplay`; defer to a new `SubscriptionFilter.includeSystemEvents` opt-in. All 10 reserved-system audit emission sites switch their `aggregateId` from per-registry strings to `source.identifier` (the install UUID), giving each install a single per-installation hash-chained system aggregate. New API surface: `StoredEvent.originatorHop` getter, `EventStore.isLocallyOriginated(event)` method, `StorageBackend.findAllEvents(originatorHopId:, originatorIdentifier:)` query. `dedupeByContent` semantic refines to compare against the most-recent event of matching `entry_type` within the aggregate.

**Tech Stack:** Dart 3.10 / Flutter 3.41, sembast (file + memory factories), `event_sourcing_datastore` library, `provenance` library, `flutter_test`, `uuid` package (already a transitive dep).

**Spec:** `docs/superpowers/specs/2026-04-26-phase4.22-ingest-materialize-and-bridging-design.md`

**Branch:** `mobile-event-sourcing-refactor` (shared with all CUR-1154 phases)
**Ticket:** CUR-1154
**Phase:** 4.22 — final library work before CUR-1154 closeout
**Depends on:** Phase 4.9 (sync-through ingest), Phase 4.13 (outgoing native wire payload), Phase 4.14 (arch cleanup), Phase 4.16 (event versioning), Phase 4.17 (config-change audit events), Phase 4.18 (syncpolicy hot-swap), portal-pane (dual-pane example).

## Execution Rules

These rules apply to EVERY task below. Do not skip steps. Do not reorder.
If you find yourself writing implementation code without a TASK_FILE and
failing tests, STOP and return to step 1 of the current task.

Read `~/templates/MASTER_PLAN_TEMPLATE_DART.md` if you have not seen the canonical TDD cadence and REQ citation conventions before starting Task 1.

REQ citation convention (per master plan README §"REQ citation convention"):
- Tests: `// Verifies: REQ-xxx-Y — <prose>` immediately above each `test(...)` call AND the assertion ID at the start of the test description string.
- Implementation: `// Implements: REQ-xxx-Y — <prose>` immediately above the function/method/class bearing the responsibility.
- For `group(...)`: `/// Verifies REQ-xxx-A, REQ-xxx-B` doc comment immediately above.

**Per-task controller workflow** (re-read each task — same convention as Phases 4.6 → 4.18):

> After each task:
> - Append to `PHASE_4.22_WORKLOG.md` a brief outline of the work done. Don't say "it was like that before, now it's like this." Just say "it works like this." Don't repeat history; report final-state status.
> - Commit the changes (per-task commits, granular subjects, ticket prefix `[CUR-1154] Phase 4.22 Task N: <summary>`).
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. Get an unbiased review.
> - Decide which review comments to address; log both addressed and dismissed to WORKLOG.
> - Commit again with `[CUR-1154] Phase 4.22 Task N: address review feedback` if changes warranted.
> - Re-read these instructions.
> Then proceed to the next task.

**Order matters**: Task 3 (dedupe semantic refinement) MUST land before Task 4 (system aggregate_id consolidation) because Task 4 puts multiple entry types under one aggregate, and unrefined dedupe would silently break the no-op-reboot property of `entry_type_registry_initialized`.

**Order matters**: Task 6 (SubscriptionFilter.includeSystemEvents + filter lift) MUST land before any test that exercises wire-side bridging of system events; without the lift, system events are dropped at fillBatch and the bridging tests can't verify anything.

---

## Plan

### Task 1: Baseline + worklog

**TASK_FILE**: `PHASE4.22_TASK_1.md`

- [ ] **Step 1: Baseline test run**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/provenance && dart test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore/example && flutter test 2>&1 | tail -5)
```

Expected: all green. Record exact test counts in `PHASE_4.22_WORKLOG.md`.

- [ ] **Step 2: Baseline analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && dart analyze 2>&1 | tail -3)
```

Expected: "No issues found" for all three. Record in WORKLOG.

- [ ] **Step 3: Confirm Phase 4.22 surface absent**

```bash
grep -nE "includeSystemEvents|originatorHop|isLocallyOriginated" apps/common-dart/event_sourcing_datastore/lib/
```

Expected: zero hits. If hits exist, this task has already started — investigate before proceeding.

- [ ] **Step 4: Confirm dedupe code at expected line**

```bash
grep -n "aggregateHistory.last" apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart
```

Expected: one hit around line 385. Record exact line in WORKLOG (will be modified in Task 3).

- [ ] **Step 5: Confirm system entry types ship `materialize: false`**

```bash
grep -B1 "materialize: false" apps/common-dart/event_sourcing_datastore/lib/src/security/system_entry_types.dart | head -30
```

Expected: 10 occurrences of `materialize: false` (one per reserved system entry type). Record count in WORKLOG.

- [ ] **Step 6: Create WORKLOG file**

Create `PHASE_4.22_WORKLOG.md` at repo root with:

```markdown
# Phase 4.22 Worklog — Materialize-on-Ingest and System-Event Bridging (CUR-1154)

**Plan:** docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.22_ingest_materialize_and_bridging.md
**Spec:** docs/superpowers/specs/2026-04-26-phase4.22-ingest-materialize-and-bridging-design.md
**Branch:** mobile-event-sourcing-refactor
**Depends on:** Phase 4.9, 4.13, 4.14, 4.16, 4.17, 4.18, portal-pane

## Baseline (Task 1)

- event_sourcing_datastore: <count> All tests passed
- provenance: <count> All tests passed
- event_sourcing_datastore/example: <count> All tests passed
- analyze (event_sourcing_datastore lib): No issues found
- analyze (event_sourcing_datastore/example): No issues found
- analyze (provenance): No issues found
- Phase 4.22 surface absent: confirmed
- dedupe-by-content code at event_store.dart:<line>
- system entry types with materialize: false: 10 (expected)

## Tasks

- [x] Task 1: Baseline + worklog
- [ ] Task 2: Spec amendments via elspais MCP
- [ ] Task 3: dedupeByContent semantic refinement
- [ ] Task 4: System aggregate_id = source.identifier (10 sites)
- [ ] Task 5: Discrimination API (originatorHop, isLocallyOriginated, findAllEvents filters)
- [ ] Task 6: SubscriptionFilter.includeSystemEvents + lift fill_batch and historical_replay hard-drops
- [ ] Task 7: Materialize-on-ingest in _ingestOneInTxn
- [ ] Task 8: Receiver-stays-passive invariant tests + materialize:false regression test
- [ ] Task 9: Demo - per-pane install UUID
- [ ] Task 10: Demo - second Native (NativeAudit) + hop badge
- [ ] Task 11: Final verification + Source.identifier doc + worklog close
```

- [ ] **Step 7: Commit**

```bash
git add PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.22_ingest_materialize_and_bridging.md docs/superpowers/specs/2026-04-26-phase4.22-ingest-materialize-and-bridging-design.md
git commit -m "$(cat <<'EOF'
[CUR-1154] Phase 4.22 Task 1: baseline + worklog

Captures pre-change test counts and analyze status. Confirms Phase 4.22
surface (includeSystemEvents, originatorHop, isLocallyOriginated) is
absent. Confirms 10 reserved system entry types ship materialize: false.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Note: spec and plan files may already be committed from the brainstorm. Adjust the `git add` list to include only what's actually unstaged.

---

### Task 2: Spec amendments via elspais MCP

**TASK_FILE**: `PHASE4.22_TASK_2.md`

This task edits `spec/dev-event-sourcing-mobile.md` via the elspais MCP. All assertion text changes go through `mcp__elspais__mutate_update_assertion` (or `mutate_add_assertion` for new ones); REQ-d numbers come from `mcp__elspais__discover_requirements`.

- [ ] **Step 1: Claim next REQ-d number**

```text
mcp__elspais__discover_requirements(query="next available REQ-d", scope_id="REQ-p00004")
```

Record the returned number (referred to below as `REQ-dNEW`).

- [ ] **Step 2: Add new REQ-dNEW**

```text
mcp__elspais__mutate_add_requirement(
  parent_id="REQ-p00004",
  edge_kind="implements",
  id=REQ-dNEW,
  title="Cross-Hop Event Discrimination and Bridged System-Event Storage",
  level="dev",
  body="Phase 4.22 introduces the API surface and storage-level conventions ...",
  file_path="spec/dev-event-sourcing-mobile.md",
)
```

The body content comes verbatim from the spec's "Requirements > New REQ to claim" section. Then add a second IMPLEMENTS edge to REQ-p01001:

```text
mcp__elspais__mutate_add_edge(
  source_id=REQ-dNEW, target_id="REQ-p01001", kind="implements"
)
```

- [ ] **Step 3: Add 6 assertions to REQ-dNEW (A through F)**

Use `mcp__elspais__mutate_add_assertion` six times, copying assertion text verbatim from the spec's "Requirements > New REQ to claim > Proposed assertions" subsection (A, B, C, D, E, F).

- [ ] **Step 4: Add REQ-d00121-K (materialize-on-ingest)**

```text
mcp__elspais__mutate_add_assertion(
  req_id="REQ-d00121",
  label="K",
  text="`EventStore.ingestBatch` and `EventStore.ingestEvent` SHALL fire materializers per-event in the same backend transaction as the event append, applying the same `def.materialize` and `m.appliesTo(event)` gates used by `EventStore.append` (REQ-d00121-G's rebuild path is unchanged). A materializer or promoter throw during ingest SHALL roll back the entire batch per REQ-d00145-A."
)
```

- [ ] **Step 5: Add REQ-d00128-J (SubscriptionFilter.includeSystemEvents)**

```text
mcp__elspais__mutate_add_assertion(
  req_id="REQ-d00128",
  label="J",
  text="`SubscriptionFilter.includeSystemEvents: bool` (default `false`) SHALL, when `true`, cause `SubscriptionFilter.matches` to return `true` for any event whose `entry_type` is in `kReservedSystemEntryTypeIds`, bypassing the `entryTypes` list. When `false`, system entry types SHALL be rejected by `matches` regardless of `entryTypes` content. The Phase 4.17 hard-drop in `fillBatch` and `historicalReplay` SHALL be removed in favor of this filter dispatch."
)
```

- [ ] **Step 6: Add REQ-d00142-D (Source.identifier install identity)**

```text
mcp__elspais__mutate_add_assertion(
  req_id="REQ-d00142",
  label="D",
  text="`Source.identifier` SHALL be the per-installation unique identity. Production callers MUST persist a globally-unique value (UUIDv4 recommended) on first install and pass the same value on every subsequent bootstrap. The library SHALL NOT validate format at runtime; callers that violate the global-uniqueness requirement produce data that collides on receivers when bridged."
)
```

- [ ] **Step 7: Add REQ-d00145-N (materialize on ingest path)**

```text
mcp__elspais__mutate_add_assertion(
  req_id="REQ-d00145",
  label="N",
  text="`EventStore.ingestBatch` and `EventStore.ingestEvent` SHALL fire materializers per-event inside the existing ingest transaction, with the same gates as `EventStore.append` (`def.materialize` flag and `m.appliesTo(event)` predicate). A materializer or promoter throw SHALL cause the entire batch transaction to roll back per REQ-d00145-A. Cross-references REQ-d00121-K."
)
```

- [ ] **Step 8: Update REQ-d00129 J/K/L/M (aggregateId change)**

For each of REQ-d00129-J, K, L, M, use `mcp__elspais__mutate_update_assertion` to replace `aggregateId: 'destination:<id>'` with `aggregateId: source.identifier (the local EventStore's install UUID)`. Add `data.id` to the data-payload field list so the destination identity moves from aggregate_id to data. Verbatim text in the spec's REQ-d00129 update section.

Also add a new REQ-d00129-O assertion:

```text
mcp__elspais__mutate_add_assertion(
  req_id="REQ-d00129",
  label="O",
  text="`EventStore.ingestBatch` and `EventStore.ingestEvent` SHALL NOT mutate `DestinationRegistry`, `EntryTypeRegistry`, or any FIFO state on the receiver. Bridged system audit events are stored in `event_log` only; they SHALL NOT trigger any registry-mutation side effect."
)
```

- [ ] **Step 9: Update REQ-d00134 E/F/G (bootstrap aggregateId change)**

Use `mcp__elspais__mutate_update_assertion` to change the `system.entry_type_registry_initialized` aggregateId from a per-registry string to `source.identifier`. Per spec.

Also update the dedupe semantic where it appears (likely under REQ-d00134-E body): "compare against the most-recent event of matching entry_type within the aggregate."

- [ ] **Step 10: Update REQ-d00138 D/E/F/H (security/retention aggregateId change)**

Use `mcp__elspais__mutate_update_assertion` to change each aggregateId from per-purpose strings to `source.identifier`.

- [ ] **Step 11: Save mutations and refresh graph**

```text
mcp__elspais__save_mutations()
mcp__elspais__refresh_graph(full=False)
```

- [ ] **Step 12: Regenerate spec/INDEX.md**

```bash
elspais fix
```

(Or whatever the project's standard regen command is. Check what other phase tasks have run to be safe.)

- [ ] **Step 13: Verify analyze still clean**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: still "No issues found." Spec changes do not touch code yet.

- [ ] **Step 14: Append worklog entry + commit**

WORKLOG entry: list every REQ touched and the new REQ-dNEW number assigned. Mark Task 2 complete in the task list at the top.

```bash
git add spec/dev-event-sourcing-mobile.md spec/INDEX.md PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_2.md
git commit -m "[CUR-1154] Phase 4.22 Task 2: spec changes for materialize-on-ingest + system-event bridging"
```

---

### Task 3: dedupeByContent semantic refinement

**TASK_FILE**: `PHASE4.22_TASK_3.md`

Refines `_appendInTxn`'s dedupe lookup from "last event of any type in aggregate" to "last event of matching entry_type in aggregate." Pre-condition for Task 4 (consolidating system aggregates).

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (line ~385)
- Test: `apps/common-dart/event_sourcing_datastore/test/event_store/dedupe_by_content_entry_type_match_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/event_store/dedupe_by_content_entry_type_match_test.dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:uuid/uuid.dart';

import '../test_support/test_event_store.dart';

void main() {
  /// Verifies REQ-d00134-E (refined dedupe semantic: match by entry_type within aggregate).
  group('dedupeByContent: matches against prior event of same entry_type', () {
    late TestEventStore harness;

    setUp(() async {
      harness = await TestEventStore.create(
        source: const Source(
          hopId: 'test-hop',
          identifier: 'install-aaaa',
          softwareVersion: 'pkg@0.0.1',
        ),
      );
    });

    tearDown(() async => harness.dispose());

    // Verifies: REQ-d00134-E (refined) — same entry_type, same aggregate, same content => skip.
    test('REQ-d00134-E (refined): same entry_type same content same aggregate is no-op', () async {
      final initiator = const AutomationInitiator(service: 'test');
      const aggId = 'install-aaaa'; // same aggregate
      const data = <String, Object?>{'k': 'v'};

      final first = await harness.eventStore.append(
        aggregateId: aggId,
        aggregateType: 'system_thing',
        entryType: 'system.entry_type_registry_initialized',
        entryTypeVersion: 1,
        eventType: 'finalized',
        data: data,
        initiator: initiator,
        dedupeByContent: true,
      );
      expect(first, isNotNull, reason: 'first emission appends');

      final second = await harness.eventStore.append(
        aggregateId: aggId,
        aggregateType: 'system_thing',
        entryType: 'system.entry_type_registry_initialized',
        entryTypeVersion: 1,
        eventType: 'finalized',
        data: data,
        initiator: initiator,
        dedupeByContent: true,
      );
      expect(second, isNull, reason: 'identical re-emission is dedupe-skipped');
    });

    // Verifies: REQ-d00134-E (refined) — different entry_type with same content does NOT trigger dedupe match.
    test('REQ-d00134-E (refined): different entry_type same content same aggregate is NOT a dedupe match', () async {
      final initiator = const AutomationInitiator(service: 'test');
      const aggId = 'install-aaaa';
      const data = <String, Object?>{'k': 'v'};

      // First: an event of entry_type A.
      final first = await harness.eventStore.append(
        aggregateId: aggId,
        aggregateType: 'system_thing',
        entryType: 'system.destination_registered',
        entryTypeVersion: 1,
        eventType: 'finalized',
        data: data,
        initiator: initiator,
        dedupeByContent: false, // not a dedupe path itself
      );
      expect(first, isNotNull);

      // Second: a different entry_type with identical content. Old behavior:
      // dedupe would compare against the destination_registered (last event)
      // and they differ in entry_type so content hashes always differ -> append.
      // Under refined semantic: dedupe looks for prior of matching entry_type
      // (none exists for entry_type_registry_initialized) so first emission fires.
      final second = await harness.eventStore.append(
        aggregateId: aggId,
        aggregateType: 'system_thing',
        entryType: 'system.entry_type_registry_initialized',
        entryTypeVersion: 1,
        eventType: 'finalized',
        data: data,
        initiator: initiator,
        dedupeByContent: true,
      );
      expect(second, isNotNull,
          reason: 'first emission of this entry_type in shared aggregate appends (no prior of same entry_type to compare)');

      // Third: identical re-emission of the second's entry_type. Refined dedupe
      // finds the prior of matching entry_type, content matches -> skip.
      final third = await harness.eventStore.append(
        aggregateId: aggId,
        aggregateType: 'system_thing',
        entryType: 'system.entry_type_registry_initialized',
        entryTypeVersion: 1,
        eventType: 'finalized',
        data: data,
        initiator: initiator,
        dedupeByContent: true,
      );
      expect(third, isNull,
          reason: 'second emission of same entry_type with same content is dedupe-skipped');
    });
  });
}
```

If `TestEventStore` doesn't exist, create a minimal harness in `test/test_support/test_event_store.dart`:

```dart
// test/test_support/test_event_store.dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:sembast/sembast_memory.dart';

class TestEventStore {
  TestEventStore._({required this.datastore, required this.backend});

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;

  EventStore get eventStore => datastore.eventStore;

  static Future<TestEventStore> create({required Source source}) async {
    final db = await newDatabaseFactoryMemory().openDatabase('test-${DateTime.now().microsecondsSinceEpoch}.db');
    final backend = SembastBackend(database: db);
    final datastore = await bootstrapAppendOnlyDatastore(
      backend: backend,
      source: source,
      entryTypes: const <EntryTypeDefinition>[],
      destinations: const <Destination>[],
      materializers: const <Materializer>[],
      initialViewTargetVersions: const <String, Map<String, int>>{},
    );
    return TestEventStore._(datastore: datastore, backend: backend);
  }

  Future<void> dispose() async => backend.database.close();
}
```

(Check first if a similar harness already exists under `test/test_support/`. If yes, use it; this is a fallback.)

- [ ] **Step 2: Run test to verify it fails**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/event_store/dedupe_by_content_entry_type_match_test.dart 2>&1 | tail -10)
```

Expected: the third test (different entry_type same content) currently FAILS because old dedupe logic compares against `aggregateHistory.last` regardless of entry_type, so the second emission gets dedupe-skipped against the first's destination_registered content (which differs from entry_type_registry_initialized's content); actually no, content differs so dedupe fires no skip... wait. Let me re-think — under OLD behavior, candidate vs. prior(any-type) content hash comparison: if both data maps are `{'k': 'v'}` but the event_types differ ('finalized' vs 'finalized'), then `_contentHash` includes event_type and data and change_reason. Both have event_type='finalized', same data, same default change_reason='initial'. Content hashes match → dedupe fires under OLD behavior → second event NOT appended → test second-expect-isNotNull fails.

Confirm this is the failure mode. If different, the test is wrong; revise.

- [ ] **Step 3: Implement the dedupe refinement**

Locate `_appendInTxn` in `event_store.dart` around line 380:

```dart
// existing
final aggregateHistory = await backend.findEventsForAggregateInTxn(
  txn,
  aggregateId,
);
if (dedupeByContent && aggregateHistory.isNotEmpty) {
  final prior = aggregateHistory.last;
  // ...
}
```

Replace with:

```dart
final aggregateHistory = await backend.findEventsForAggregateInTxn(
  txn,
  aggregateId,
);
// Implements: REQ-d00134-E (refined) — dedupeByContent matches against the
// most-recent event of matching entry_type within the aggregate, not the
// last event of any type. Multiple entry types can share an aggregate
// (REQ-dNEW-D system events under source.identifier) without surprising
// dedupe behavior.
StoredEvent? prior;
if (dedupeByContent) {
  for (var i = aggregateHistory.length - 1; i >= 0; i--) {
    if (aggregateHistory[i].entryType == entryType) {
      prior = aggregateHistory[i];
      break;
    }
  }
}
if (dedupeByContent && prior != null) {
  final priorHash = _contentHash(
    eventType: prior.eventType,
    data: prior.data,
    changeReason: (prior.metadata['change_reason'] as String?) ?? 'initial',
  );
  final candidateHash = _contentHash(
    eventType: eventType,
    data: <String, Object?>{
      ...data,
      'checkpoint_reason': ?checkpointReason,
    },
    changeReason: effectiveChangeReason,
  );
  if (candidateHash == priorHash) return null;
}
```

(Substitute the actual claimed `REQ-dNEW` number.)

- [ ] **Step 4: Run test to verify it passes**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/event_store/dedupe_by_content_entry_type_match_test.dart 2>&1 | tail -10)
```

Expected: 2 tests pass.

- [ ] **Step 5: Run full test suite (regression check)**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: previous count + 2 (the two new tests). Anything regressing means an existing test depended on old "dedupe matches last-of-any-type" behavior — investigate; existing usage is only `entry_type_registry_initialized` which is single-purpose, so refinement should not regress.

- [ ] **Step 6: Analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean.

- [ ] **Step 7: Append worklog + commit**

```bash
git add apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart apps/common-dart/event_sourcing_datastore/test/event_store/dedupe_by_content_entry_type_match_test.dart apps/common-dart/event_sourcing_datastore/test/test_support/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_3.md
git commit -m "[CUR-1154] Phase 4.22 Task 3: dedupeByContent matches by entry_type within aggregate (REQ-d00134-E refined)"
```

---

### Task 4: System aggregate_id = source.identifier

**TASK_FILE**: `PHASE4.22_TASK_4.md`

Switches all 10 reserved-system audit emission sites from per-registry-string aggregateIds to `source.identifier`. Adds the destination identity to the audit event's `data` map so callers can still query "all audits for destination X."

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/bootstrap.dart` (1 site: entry_type_registry_initialized)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination_registry.dart` (6 sites: addDestination, setStartDate, setEndDate, deactivateDestination, deleteDestination, tombstoneAndRefill)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (3 sites: applyRetentionPolicy, clearSecurityContext, security context lifecycle audits)
- Test: `apps/common-dart/event_sourcing_datastore/test/destinations/destination_registry_audit_aggregate_id_test.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/bootstrap_audit_aggregate_id_test.dart` (new file or extend existing `bootstrap_registry_initialized_audit_test.dart`)

- [ ] **Step 1: Write failing tests**

Create `test/destinations/destination_registry_audit_aggregate_id_test.dart`:

```dart
// Verifies: REQ-d00129-J/K/L/M/N (revised: aggregateId=source.identifier).
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late SembastBackend backend;
  late AppendOnlyDatastore datastore;
  const installUUID = 'aaaa1111-2222-3333-4444-555566667777';
  const source = Source(
    hopId: 'test-hop',
    identifier: installUUID,
    softwareVersion: 'pkg@0.0.1',
  );

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('reg-test-${DateTime.now().microsecondsSinceEpoch}.db');
    backend = SembastBackend(database: db);
    datastore = await bootstrapAppendOnlyDatastore(
      backend: backend,
      source: source,
      entryTypes: const <EntryTypeDefinition>[],
      destinations: const <Destination>[],
      materializers: const <Materializer>[],
      initialViewTargetVersions: const <String, Map<String, int>>{},
    );
  });

  tearDown(() async => backend.database.close());

  Initiator initiator() => const AutomationInitiator(service: 'test');

  // Verifies: REQ-d00129-J — addDestination audit aggregate_id = source.identifier
  test('REQ-d00129-J: destination_registered audit uses source.identifier as aggregate_id', () async {
    await datastore.destinations.addDestination(
      _NoopDestination(id: 'Primary'),
      initiator: initiator(),
    );
    final events = await backend.findAllEvents();
    final audit = events.firstWhere((e) => e.entryType == 'system.destination_registered');
    expect(audit.aggregateId, installUUID,
        reason: 'aggregate_id MUST be source.identifier, not destination:Primary');
    expect(audit.data['id'], 'Primary',
        reason: 'destination identity moves into data.id');
  });

  // Verifies: REQ-d00129-K — setStartDate audit aggregate_id = source.identifier
  test('REQ-d00129-K: destination_start_date_set audit uses source.identifier as aggregate_id', () async {
    await datastore.destinations.addDestination(_NoopDestination(id: 'Primary'), initiator: initiator());
    await datastore.destinations.setStartDate('Primary', DateTime.utc(2026, 1, 1), initiator: initiator());
    final events = await backend.findAllEvents();
    final audit = events.firstWhere((e) => e.entryType == 'system.destination_start_date_set');
    expect(audit.aggregateId, installUUID);
    expect(audit.data['id'], 'Primary');
  });

  // Add similar tests for L (setEndDate), M (deleteDestination), and tombstoneAndRefill.
}

class _NoopDestination extends Destination {
  _NoopDestination({required this.id});
  @override
  final String id;
  @override
  SubscriptionFilter get filter => const SubscriptionFilter();
  // ... minimal stubs for required overrides
}
```

(Look at existing `_NoopDestination`-style stubs in other tests, e.g. `destination_registry_test.dart`, and reuse if available.)

Create `test/bootstrap_audit_aggregate_id_test.dart`:

```dart
// Verifies: REQ-d00134-E/F/G (revised: aggregateId=source.identifier).
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  // Verifies: REQ-d00134-E (revised) — entry_type_registry_initialized aggregate_id = source.identifier.
  test('REQ-d00134-E (revised): entry_type_registry_initialized audit uses source.identifier', () async {
    const installUUID = 'bbbb2222-3333-4444-5555-666677778888';
    final db = await newDatabaseFactoryMemory().openDatabase('boot-test-${DateTime.now().microsecondsSinceEpoch}.db');
    final backend = SembastBackend(database: db);
    await bootstrapAppendOnlyDatastore(
      backend: backend,
      source: const Source(hopId: 'test-hop', identifier: installUUID, softwareVersion: 'pkg@0.0.1'),
      entryTypes: const <EntryTypeDefinition>[],
      destinations: const <Destination>[],
      materializers: const <Materializer>[],
      initialViewTargetVersions: const <String, Map<String, int>>{},
    );
    final events = await backend.findAllEvents();
    final audit = events.firstWhere((e) => e.entryType == 'system.entry_type_registry_initialized');
    expect(audit.aggregateId, installUUID,
        reason: 'aggregate_id MUST be source.identifier, not the prior per-registry constant');
  });
}
```

Optionally extend `bootstrap_registry_initialized_audit_test.dart` if it covers the old aggregate_id; update its expectations.

- [ ] **Step 2: Run tests to verify they fail**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/destinations/destination_registry_audit_aggregate_id_test.dart test/bootstrap_audit_aggregate_id_test.dart 2>&1 | tail -10)
```

Expected: fail. The new tests assert `aggregateId == installUUID`; current code uses `'destination:Primary'`, `'system:entry-type-registry'`, etc.

- [ ] **Step 3: Implement bootstrap site**

In `lib/src/bootstrap.dart`, find the `entry_type_registry_initialized` emission and change `aggregateId:` argument from its current value to `source.identifier`. Add `// Implements: REQ-d00134-E+F+G (revised: aggregateId=source.identifier), REQ-dNEW-D` annotation immediately above.

- [ ] **Step 4: Implement destination_registry sites (6 sites)**

In `lib/src/destinations/destination_registry.dart`, the helper `_emitDestinationAuditInTxn` (line ~511) is the consolidation point. Change its body to construct `aggregateId: _source.identifier` (where `_source` is the constructor-injected Source — verify the field name; rename/expose as needed).

Ensure the audit event's `data` map carries the destination `id` field (it likely already does — verify per spec). Add `// Implements: REQ-d00129-J+K+L+M+N (revised: aggregateId=source.identifier), REQ-dNEW-D` above `_emitDestinationAuditInTxn`.

- [ ] **Step 5: Implement event_store retention/security sites (3 sites)**

In `lib/src/event_store.dart`, locate the three sites that emit `system.retention_policy_applied`, `system.security_context_set`, and `system.security_context_cleared` (or their actual current names). Change each `aggregateId:` argument to `source.identifier`. Add `// Implements: REQ-d00138-D+E+F+H (revised: aggregateId=source.identifier), REQ-dNEW-D` above each site (or above a helper that wraps them).

- [ ] **Step 6: Run tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: new tests pass. Existing tests that asserted on the old aggregate_ids will fail — find and update them. Search for `'destination:` and `'system:entry-type-registry'` and `'security-retention'` in test files; update expectations to `installUUID` (or the appropriate per-test source identifier).

- [ ] **Step 7: Update worklog summary of test-file changes**

List every test file updated with the line-number range of expectations changed.

- [ ] **Step 8: Analyze + commit**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
```

Expected: clean.

```bash
git add -A apps/common-dart/event_sourcing_datastore/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_4.md
git commit -m "[CUR-1154] Phase 4.22 Task 4: system aggregate_id = source.identifier (10 sites)"
```

---

### Task 5: Discrimination API

**TASK_FILE**: `PHASE4.22_TASK_5.md`

Adds the three new API surfaces: `StoredEvent.originatorHop` getter, `EventStore.isLocallyOriginated(event)` method, `StorageBackend.findAllEvents(originatorHopId:, originatorIdentifier:)` query.

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/stored_event.dart` (extension or method)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (isLocallyOriginated method)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart` (extend findAllEvents abstract signature)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart` (concrete findAllEvents)
- Test: `apps/common-dart/event_sourcing_datastore/test/storage/stored_event_origin_test.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/event_store/event_store_is_locally_originated_test.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/storage/find_all_events_originator_filter_test.dart`

- [ ] **Step 1: Write the three failing tests**

```dart
// test/storage/stored_event_origin_test.dart
// Verifies: REQ-dNEW-A — StoredEvent.originatorHop returns provenance.first.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provenance/provenance.dart';

void main() {
  // Verifies: REQ-dNEW-A
  test('REQ-dNEW-A: originatorHop returns provenance.first', () {
    final originator = ProvenanceEntry(
      hopId: 'mobile-device',
      identifier: 'install-A',
      softwareVersion: 'pkg@0.0.1',
      // ... other required fields, follow ProvenanceEntry signature
    );
    final receiver = ProvenanceEntry(
      hopId: 'portal-server',
      identifier: 'install-B',
      softwareVersion: 'pkg@0.0.1',
    );
    final event = StoredEvent(
      // ... fields with provenance: [originator, receiver]
    );
    expect(event.originatorHop, originator);
    expect(event.originatorHop.identifier, 'install-A');
  });

  // Verifies: REQ-dNEW-A — empty provenance throws StateError.
  test('REQ-dNEW-A: empty provenance throws StateError', () {
    final event = StoredEvent(
      // ... fields with provenance: []
    );
    expect(() => event.originatorHop, throwsStateError);
  });
}
```

```dart
// test/event_store/event_store_is_locally_originated_test.dart
// Verifies: REQ-dNEW-B — isLocallyOriginated compares on identifier.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
// ... harness imports

void main() {
  // Verifies: REQ-dNEW-B
  test('REQ-dNEW-B: locally-appended event is recognized as local', () async {
    final harness = await TestEventStore.create(
      source: const Source(hopId: 'mobile-device', identifier: 'install-A', softwareVersion: 'pkg@0.0.1'),
    );
    // Append a local event.
    final appended = await harness.eventStore.append(
      aggregateId: 'agg-1',
      aggregateType: 'DiaryEntry',
      entryType: 'demo_note',
      entryTypeVersion: 1,
      eventType: 'finalized',
      data: const <String, Object?>{},
      initiator: const AutomationInitiator(service: 'test'),
    );
    expect(harness.eventStore.isLocallyOriginated(appended!), isTrue);
  });

  // Verifies: REQ-dNEW-B — different identifier => not local even if same hopId.
  test('REQ-dNEW-B: different install identifier is NOT locally originated', () async {
    final harness = await TestEventStore.create(
      source: const Source(hopId: 'mobile-device', identifier: 'install-A', softwareVersion: 'pkg@0.0.1'),
    );
    // Construct a StoredEvent whose provenance[0].identifier is 'install-B' (a different mobile install).
    final ingested = StoredEvent(/* ... provenance: [ProvenanceEntry(hopId: 'mobile-device', identifier: 'install-B', ...)] */);
    expect(harness.eventStore.isLocallyOriginated(ingested), isFalse,
        reason: 'two installs of the same role-class are distinct originators');
  });
}
```

```dart
// test/storage/find_all_events_originator_filter_test.dart
// Verifies: REQ-dNEW-C — findAllEvents accepts originator filters.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late SembastBackend backend;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('find-test-${DateTime.now().microsecondsSinceEpoch}.db');
    backend = SembastBackend(database: db);
  });
  tearDown(() async => backend.database.close());

  Future<void> _seed() async {
    // Append 3 events with different (hopId, identifier) provenance origins.
    // Use the lower-level appendEvent path or a harness that lets you control provenance.
    // Example: 1 event from (mobile-device, install-A), 1 from (mobile-device, install-B),
    // 1 from (portal-server, install-P).
  }

  // Verifies: REQ-dNEW-C
  test('REQ-dNEW-C: findAllEvents(originatorIdentifier) filters by install', () async {
    await _seed();
    final res = await backend.findAllEvents(originatorIdentifier: 'install-A');
    expect(res.length, 1);
    expect(res.first.originatorHop.identifier, 'install-A');
  });

  // Verifies: REQ-dNEW-C
  test('REQ-dNEW-C: findAllEvents(originatorHopId) filters by hop class', () async {
    await _seed();
    final res = await backend.findAllEvents(originatorHopId: 'mobile-device');
    expect(res.length, 2);
  });

  // Verifies: REQ-dNEW-C
  test('REQ-dNEW-C: findAllEvents(originatorHopId+originatorIdentifier) AND-filters', () async {
    await _seed();
    final res = await backend.findAllEvents(
      originatorHopId: 'mobile-device',
      originatorIdentifier: 'install-A',
    );
    expect(res.length, 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/storage/stored_event_origin_test.dart test/event_store/event_store_is_locally_originated_test.dart test/storage/find_all_events_originator_filter_test.dart 2>&1 | tail -10)
```

Expected: fail with "originatorHop not defined", "isLocallyOriginated not defined", "originatorIdentifier param not defined."

- [ ] **Step 3: Implement StoredEvent.originatorHop**

In `lib/src/storage/stored_event.dart`, append the extension OR add as instance method:

```dart
extension StoredEventOriginExt on StoredEvent {
  /// First provenance entry — the originator's hop.
  ///
  /// Throws [StateError] if `provenance` is empty (REQ-d00115 requires
  /// every event to carry at least one entry, so an empty provenance
  /// indicates corrupted data).
  // Implements: REQ-dNEW-A — originator hop convenience getter.
  ProvenanceEntry get originatorHop {
    if (provenance.isEmpty) {
      throw StateError(
        'StoredEvent has empty provenance; expected at least originator entry per REQ-d00115',
      );
    }
    return provenance.first;
  }
}
```

(If `StoredEvent` is a sealed class or extension already exists, prefer adding the getter inside the class for consistency. Check for existing `extension StoredEvent` patterns in the file first.)

- [ ] **Step 4: Implement EventStore.isLocallyOriginated**

In `lib/src/event_store.dart`, add a method on the `EventStore` class:

```dart
/// True iff [event] was originated locally on this EventStore's [source].
///
/// Compares originator install identity (`provenance[0].identifier`) against
/// the EventStore's bound [source.identifier] — not [source.hopId], since
/// two installations of the same role class are distinct originators.
// Implements: REQ-dNEW-B — local-vs-upstream discrimination on install UUID.
bool isLocallyOriginated(StoredEvent event) =>
    event.originatorHop.identifier == source.identifier;
```

Place it next to the existing public methods (e.g., after `append`, before `ingestEvent`).

- [ ] **Step 5: Extend StorageBackend.findAllEvents abstract signature**

In `lib/src/storage/storage_backend.dart`, locate the abstract `findAllEvents` signature and add two optional params:

```dart
// Implements: REQ-dNEW-C — originator filters for findAllEvents.
Future<List<StoredEvent>> findAllEvents({
  int? afterSequence,
  int? limit,
  String? originatorHopId,
  String? originatorIdentifier,
});
```

(Preserve any existing optional params; just add the two new ones.)

- [ ] **Step 6: Implement findAllEvents in SembastBackend**

In `lib/src/storage/sembast_backend.dart`, locate the concrete `findAllEvents` and add the filter logic. Two implementation choices documented in the spec:

Option (i) — read all then Dart-side filter (simplest, fine for demo / mobile scale):

```dart
@override
Future<List<StoredEvent>> findAllEvents({
  int? afterSequence,
  int? limit,
  String? originatorHopId,
  String? originatorIdentifier,
}) async {
  final all = await _findAllEventsRaw(afterSequence: afterSequence, limit: limit);
  if (originatorHopId == null && originatorIdentifier == null) return all;
  return all.where((e) {
    final hop = e.originatorHop;
    if (originatorHopId != null && hop.hopId != originatorHopId) return false;
    if (originatorIdentifier != null && hop.identifier != originatorIdentifier) return false;
    return true;
  }).toList();
}
```

Option (ii) — sembast `Filter.custom` on the JSON path. Marginally faster for very large logs, more code. Skip for this iteration unless soak performance demonstrates a need.

Use option (i). Mark with `// Implements: REQ-dNEW-C` annotation.

- [ ] **Step 7: Run tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: previous + 7 new tests, all green.

- [ ] **Step 8: Analyze + commit**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
git add -A apps/common-dart/event_sourcing_datastore/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_5.md
git commit -m "[CUR-1154] Phase 4.22 Task 5: discrimination API (originatorHop, isLocallyOriginated, findAllEvents originator filters)"
```

---

### Task 6: SubscriptionFilter.includeSystemEvents + lift fillBatch and historicalReplay hard-drops

**TASK_FILE**: `PHASE4.22_TASK_6.md`

Adds the new boolean field to SubscriptionFilter; updates `matches`; removes the Phase 4.17 hard-drop guards in `fillBatch` and `historicalReplay`.

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/destinations/subscription_filter.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/sync/fill_batch.dart` (line ~125)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/sync/historical_replay.dart` (line ~111)
- Test: `apps/common-dart/event_sourcing_datastore/test/destinations/subscription_filter_system_events_test.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_system_events_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/destinations/subscription_filter_system_events_test.dart
// Verifies: REQ-d00128-J, REQ-dNEW-F.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StoredEvent _systemEvent() => /* StoredEvent with entryType in kReservedSystemEntryTypeIds */;
  StoredEvent _userEvent(String entryType) => /* StoredEvent with given user entryType */;

  // Verifies: REQ-d00128-J — default false rejects system events.
  test('REQ-d00128-J: includeSystemEvents=false rejects system events regardless of entryTypes', () {
    const f = SubscriptionFilter(entryTypes: ['demo_note']);
    expect(f.includeSystemEvents, isFalse);
    expect(f.matches(_systemEvent()), isFalse);
  });

  // Verifies: REQ-d00128-J — true bypasses entryTypes for system events.
  test('REQ-d00128-J: includeSystemEvents=true admits system events even with empty entryTypes', () {
    const f = SubscriptionFilter(entryTypes: <String>[], includeSystemEvents: true);
    expect(f.matches(_systemEvent()), isTrue);
  });

  // Verifies: REQ-d00128-J — true does not override entryTypes for user events.
  test('REQ-d00128-J: includeSystemEvents=true still applies entryTypes for user events', () {
    const f = SubscriptionFilter(entryTypes: ['demo_note'], includeSystemEvents: true);
    expect(f.matches(_userEvent('demo_note')), isTrue);
    expect(f.matches(_userEvent('red_button_pressed')), isFalse);
  });
}
```

```dart
// test/sync/fill_batch_system_events_test.dart
// Verifies: lifts of Phase 4.17 hard-drop in fillBatch.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Verifies: REQ-d00128-J — fillBatch defers to SubscriptionFilter for system events.
  test('REQ-d00128-J: fillBatch admits system events when destination opts in', () async {
    // 1. Bootstrap a backend.
    // 2. Register a destination with includeSystemEvents: true and empty entryTypes.
    // 3. Trigger a system audit (e.g., addDestination of another destination).
    // 4. Run fillBatch on the audit-subscribed destination.
    // 5. Assert backend.listFifoEntries(<destId>) returns a row covering the audit event.
  });

  // Verifies: REQ-d00128-J — default-false destination still drops system events.
  test('REQ-d00128-J: fillBatch drops system events when destination has includeSystemEvents=false', () async {
    // Symmetric to above; assert FIFO is empty.
  });
}
```

(Use existing `_NoopDestination` / harness patterns.)

- [ ] **Step 2: Run tests to verify they fail**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/destinations/subscription_filter_system_events_test.dart test/sync/fill_batch_system_events_test.dart 2>&1 | tail -10)
```

Expected: fail with "includeSystemEvents not defined."

- [ ] **Step 3: Extend SubscriptionFilter**

In `lib/src/destinations/subscription_filter.dart`:

```dart
class SubscriptionFilter {
  const SubscriptionFilter({
    this.entryTypes = const <String>[],
    this.includeSystemEvents = false,
  });

  final List<String> entryTypes;

  /// When `true`, events whose `entryType` is in [kReservedSystemEntryTypeIds]
  /// pass [matches] regardless of [entryTypes] content. When `false`, system
  /// entry types are rejected before [entryTypes] is consulted.
  // Implements: REQ-d00128-J, REQ-dNEW-F — opt-in system-event bridging.
  final bool includeSystemEvents;

  // Implements: REQ-d00128-J — system entry type dispatch.
  bool matches(StoredEvent event) {
    if (kReservedSystemEntryTypeIds.contains(event.entryType)) {
      return includeSystemEvents;
    }
    return entryTypes.contains(event.entryType);
  }

  // ... existing == and hashCode (extend to include includeSystemEvents)
}
```

Update `==` and `hashCode` to incorporate `includeSystemEvents`. Update `toString` similarly.

- [ ] **Step 4: Lift the hard-drop in fillBatch**

In `lib/src/sync/fill_batch.dart` line ~125, remove the system-event guard:

```dart
// REMOVE THIS BLOCK:
//   if (kReservedSystemEntryTypeIds.contains(e.entryType)) return false;

// The remaining filter chain (time window + destination.filter.matches)
// now handles system events correctly: matches() per REQ-d00128-J
// rejects them when includeSystemEvents is false.
final inWindow = candidates.where((e) {
  if (e.clientTimestamp.isBefore(schedule.startDate!)) return false;
  if (e.clientTimestamp.isAfter(upper)) return false;
  return destination.filter.matches(e);
}).toList();
```

Update the comment block above (currently says "System audit events ... are never enqueued") to reflect new behavior:

```dart
// System audit events (REQ-d00138, REQ-d00129-J/K/L/M, REQ-d00144-G,
// REQ-d00138-H) bridge to destinations that opt in via
// SubscriptionFilter.includeSystemEvents (REQ-d00128-J); destinations
// with the default (false) reject them.
```

Add `// Implements: REQ-d00128-J (revised dispatch)` annotation above the `inWindow` filter block.

- [ ] **Step 5: Lift the hard-drop in historicalReplay**

Same change in `lib/src/sync/historical_replay.dart` line ~111. Remove the `kReservedSystemEntryTypeIds.contains(...)` guard; filter chain defers to `destination.filter.matches`.

- [ ] **Step 6: Run tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: new tests pass; existing tests pass (existing destinations all use `SubscriptionFilter()` defaults which means `includeSystemEvents: false`, so the lift doesn't change behavior for them).

- [ ] **Step 7: Analyze + commit**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
git add -A apps/common-dart/event_sourcing_datastore/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_6.md
git commit -m "[CUR-1154] Phase 4.22 Task 6: SubscriptionFilter.includeSystemEvents opt-in (REQ-d00128-J); lift fillBatch/historicalReplay hard-drops"
```

---

### Task 7: Materialize-on-ingest in `_ingestOneInTxn`

**TASK_FILE**: `PHASE4.22_TASK_7.md`

The big one. Adds the materializer loop to `_ingestOneInTxn` so receivers project ingested events into materialized views identically to local-appended events.

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (add materializer block to `_ingestOneInTxn`)
- Test: `apps/common-dart/event_sourcing_datastore/test/event_store/event_store_ingest_materialize_test.dart`
- Test: extend `apps/common-dart/event_sourcing_datastore/test/ingest/` if a similar harness is convenient

- [ ] **Step 1: Write the failing tests**

```dart
// test/event_store/event_store_ingest_materialize_test.dart
// Verifies: REQ-d00121-K, REQ-d00145-N.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Verifies: REQ-d00121-K, REQ-d00145-N — ingestEvent fires materializers.
  test('REQ-d00121-K + REQ-d00145-N: ingestEvent populates diary_entries view', () async {
    // 1. Bootstrap RECEIVER datastore with DiaryEntriesMaterializer + initialViewTargetVersions for demo_note.
    // 2. Construct a StoredEvent for a demo_note finalized event with provenance from a different originator.
    //    Use SyntheticBatchBuilder or hand-construct.
    // 3. Call receiver.eventStore.ingestEvent(event).
    // 4. Assert receiver.backend.findEntries(entryType: 'demo_note').isNotEmpty.
    // 5. Assert the returned DiaryEntry has the expected current_answers from the event.
  });

  // Verifies: REQ-d00121-K — ingestBatch fires materializers per-event.
  test('REQ-d00121-K: ingestBatch projects each event in batch into diary_entries view', () async {
    // 1. Bootstrap RECEIVER.
    // 2. Build a batch envelope of 3 demo_note events (different aggregateIds, different finalized payloads).
    //    Use SyntheticBatchBuilder.
    // 3. Call receiver.eventStore.ingestBatch(envelope.encode(), wireFormat: 'esd/batch@1').
    // 4. Assert findEntries returns 3 rows, one per aggregateId, with correct current_answers each.
  });

  // Verifies: REQ-d00145-A + REQ-d00121-K — materializer throw rolls back batch.
  test('REQ-d00145-A + REQ-d00121-K: materializer throw rolls back entire ingestBatch', () async {
    // 1. Bootstrap RECEIVER with a custom Materializer that throws on the second event in a batch.
    // 2. Build a 3-event batch.
    // 3. Expect ingestBatch to throw.
    // 4. Assert NO events landed in event_log AND NO rows in diary_entries.
  });

  // Verifies: REQ-dNEW-D — system events with materialize:false do NOT fire materializers on ingest.
  test('REQ-dNEW-D: ingested system events do NOT fire materializers', () async {
    // 1. Bootstrap RECEIVER with a recording-stub Materializer whose appliesTo() always returns true.
    // 2. Build a batch containing a single system audit event (e.g., synthetic system.destination_registered).
    // 3. Call receiver.eventStore.ingestBatch(...).
    // 4. Assert the recording stub's apply count is 0 (materialize:false on system entry types short-circuits).
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/event_store/event_store_ingest_materialize_test.dart 2>&1 | tail -15)
```

Expected: first 3 tests fail (no materializer fires on ingest currently); 4th passes incidentally because the materializer doesn't fire on anything yet.

- [ ] **Step 3: Implement the materializer block in `_ingestOneInTxn`**

In `lib/src/event_store.dart`, locate `_ingestOneInTxn` (around line 602+). After the line that calls `await backend.appendEvent(txn, updatedEvent);` (or equivalent), add the materializer loop modeled after `_appendInTxn:452-473`:

```dart
// (within _ingestOneInTxn, after appendEvent of the receiver-stamped event)

// Implements: REQ-d00121-K, REQ-d00145-N — fire materializers on ingest
// path with same gates as local-append (def.materialize + appliesTo).
// Closes Phase 4.9 deferral (materialize-on-ingest).
final def = registry.byId(updatedEvent.entryType);
if (def != null && def.materialize) {
  final aggregateHistory = await backend.findEventsForAggregateInTxn(
    txn,
    updatedEvent.aggregateId,
  );
  for (final m in materializers) {
    if (!m.appliesTo(updatedEvent)) continue;
    final target = await m.targetVersionFor(txn, backend, updatedEvent.entryType);
    final promoted = m.promoter(
      entryType: updatedEvent.entryType,
      fromVersion: updatedEvent.entryTypeVersion,
      toVersion: target,
      data: updatedEvent.data,
    );
    await m.applyInTxn(
      txn,
      backend,
      event: updatedEvent,
      promotedData: promoted,
      def: def,
      aggregateHistory: List<StoredEvent>.unmodifiable(aggregateHistory),
    );
  }
}
```

(Adapt variable names to match the actual local var names in `_ingestOneInTxn` — likely `event` or `incoming` rather than `updatedEvent`. Look at the `_appendInTxn` materializer block for the exact shape and copy that structure.)

The materializer throw propagates naturally through the transaction; existing batch-rollback semantics in `ingestBatch` (REQ-d00145-A) cover it.

- [ ] **Step 4: Run tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/event_store/event_store_ingest_materialize_test.dart 2>&1 | tail -10)
```

Expected: all 4 pass.

- [ ] **Step 5: Run full test suite**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
```

Expected: previous + 4. Existing portal_sync_test / portal_soak_test may now produce different results because materializers fire on ingest — check if their assertions need updating (probably they don't, because they assert on event counts and FIFO contents, not on materialized view rows).

- [ ] **Step 6: Analyze + commit**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
git add -A apps/common-dart/event_sourcing_datastore/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_7.md
git commit -m "[CUR-1154] Phase 4.22 Task 7: materialize-on-ingest (REQ-d00121-K, REQ-d00145-N) - closes Phase 4.9 deferral"
```

---

### Task 8: Receiver-stays-passive invariant tests + materialize:false regression test

**TASK_FILE**: `PHASE4.22_TASK_8.md`

Verification-only tests proving the receiver-stays-passive property (REQ-dNEW-E) and the materialize:false-on-system-entry-types regression (REQ-dNEW-D). No code change expected; if any of these tests fails, that's a real bug to fix.

**Files:**
- Test: `apps/common-dart/event_sourcing_datastore/test/ingest/ingest_does_not_mutate_local_state_test.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/security/system_entry_types_materialize_false_test.dart`

- [ ] **Step 1: Write tests**

```dart
// test/ingest/ingest_does_not_mutate_local_state_test.dart
// Verifies: REQ-dNEW-E — receiver-stays-passive invariant.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Verifies REQ-dNEW-E — DestinationRegistry, EntryTypeRegistry, FIFO state
  /// SHALL NOT be mutated by ingestEvent or ingestBatch paths.
  group('receiver-stays-passive invariant', () {
    // Verifies: REQ-dNEW-E — ingesting system.destination_registered does NOT add a destination.
    test('REQ-dNEW-E: ingesting system.destination_registered does NOT mutate DestinationRegistry', () async {
      // 1. Bootstrap RECEIVER with destinations: [Primary].
      // 2. Capture pre-ingest registry snapshot (list of destination IDs).
      // 3. Build a batch with a synthetic system.destination_registered audit
      //    naming a destination 'Secondary' (not registered on receiver).
      // 4. Call receiver.eventStore.ingestBatch(...).
      // 5. Assert receiver.destinations.all().map((d) => d.id) is unchanged (still just [Primary]).
      // 6. Assert backend.findAllEvents() includes the bridged audit (it WAS stored in event_log).
    });

    // Verifies: REQ-dNEW-E — ingesting system.entry_type_registry_initialized does NOT mutate EntryTypeRegistry.
    test('REQ-dNEW-E: ingesting system.entry_type_registry_initialized does NOT mutate EntryTypeRegistry', () async {
      // Symmetric to above. Receiver bootstraps with one set of entry types;
      // ingest a registry-init audit listing different entry types; assert
      // receiver's registry is unchanged.
    });

    // Verifies: REQ-dNEW-E — ingesting system.fifo_tombstoned_and_refilled does NOT touch local FIFOs.
    test('REQ-dNEW-E: ingesting system.fifo_tombstoned_and_refilled does NOT mutate local FIFO state', () async {
      // Symmetric. Receiver has its own Primary destination with some FIFO rows;
      // ingest a tombstoneAndRefill audit naming Primary; assert receiver's FIFO
      // rows are byte-identical before vs after ingest.
    });
  });
}
```

```dart
// test/security/system_entry_types_materialize_false_test.dart
// Verifies: REQ-dNEW-D — all 10 reserved system entry types ship materialize:false.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Verifies: REQ-dNEW-D
  test('REQ-dNEW-D: all 10 reserved system entry types have materialize: false', () {
    expect(kReservedSystemEntryTypeIds.length, 10);
    for (final id in kReservedSystemEntryTypeIds) {
      final defn = kReservedSystemEntryTypeDefinitions.firstWhere((d) => d.id == id);
      expect(defn.materialize, isFalse,
          reason: '$id MUST ship materialize:false to keep cross-aggregate '
              'projection deferred per spec §3 / REQ-dNEW-D');
    }
  });
}
```

(If `kReservedSystemEntryTypeDefinitions` is not the exported name, find the actual exported list/map of definitions in `system_entry_types.dart` and use that.)

- [ ] **Step 2: Run tests**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/ingest/ingest_does_not_mutate_local_state_test.dart test/security/system_entry_types_materialize_false_test.dart 2>&1 | tail -10)
```

Expected: ALL PASS on first run (these test invariants that are already true per the existing code; if any fails, that's a real bug to fix before committing).

- [ ] **Step 3: Analyze + commit**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
git add -A apps/common-dart/event_sourcing_datastore/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_8.md
git commit -m "[CUR-1154] Phase 4.22 Task 8: receiver-stays-passive invariant + materialize:false regression tests (REQ-dNEW-D, REQ-dNEW-E)"
```

---

### Task 9: Demo - per-pane install UUID

**TASK_FILE**: `PHASE4.22_TASK_9.md`

Replaces hardcoded `'demo-device'` / `'demo-portal'` in `main.dart` with per-pane persisted UUIDv4s.

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/main.dart`
- (No new test needed — demo behavior validated via existing integration tests + manual eyeball.)

- [ ] **Step 1: Add `uuid` to example pubspec if not already present**

```bash
grep -E "^\s+uuid:" apps/common-dart/event_sourcing_datastore/example/pubspec.yaml
```

If absent, add `uuid: ^4.0.0` (or matching version of the library's already-used uuid). The library uses uuid for aggregate_id minting (`b1f303cb`).

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter pub get)
```

- [ ] **Step 2: Add `_readOrMintUUID` helper + wire into `main()`**

In `apps/common-dart/event_sourcing_datastore/example/lib/main.dart`, add the helper:

```dart
import 'dart:io';
import 'package:uuid/uuid.dart';

/// Reads a persisted install UUID from [path], or mints + persists a new
/// UUIDv4 if the file does not exist.
// Implements: REQ-d00142-D — demo demonstrates per-installation unique
// identity by persisting a UUIDv4 per pane to disk.
Future<String> _readOrMintUUID(String path) async {
  final f = File(path);
  if (await f.exists()) {
    return (await f.readAsString()).trim();
  }
  final id = const Uuid().v4();
  await f.writeAsString(id);
  return id;
}
```

In `Future<void> main()`, after `await demoDir.create(recursive: true);`:

```dart
final mobileInstallUUID = await _readOrMintUUID(
  p.join(demoDir.path, 'MOBILE.install.uuid'),
);
final portalInstallUUID = await _readOrMintUUID(
  p.join(demoDir.path, 'PORTAL.install.uuid'),
);
stdout
  ..writeln('[demo] mobile install UUID: $mobileInstallUUID')
  ..writeln('[demo] portal install UUID: $portalInstallUUID');
```

Then update the two `_bootstrapPane` calls to use the UUIDs as `Source.identifier`:

```dart
final portal = await _bootstrapPane(
  dbPath: portalDbPath,
  source: Source(
    hopId: 'portal-server',
    identifier: portalInstallUUID,    // was 'demo-portal'
    softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
  ),
);

// ... bridge construction ...

final mobile = await _bootstrapPane(
  dbPath: mobileDbPath,
  source: Source(
    hopId: 'mobile-device',
    identifier: mobileInstallUUID,    // was 'demo-device'
    softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
  ),
  bridge: bridge,
);
```

- [ ] **Step 3: Update example tests that hardcoded 'demo-device' / 'demo-portal'**

```bash
grep -rn "demo-device\|demo-portal" apps/common-dart/event_sourcing_datastore/example/test/ apps/common-dart/event_sourcing_datastore/example/integration_test/
```

For each hit, replace the hardcoded identifier with a per-test-mint UUID (`const Uuid().v4()` — keep tests deterministic by passing a fixed UUID where ordering matters; otherwise random is fine).

- [ ] **Step 4: Run tests + analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: all green.

- [ ] **Step 5: Manual smoke (optional, requires desktop)**

```bash
rm -f /home/$USER/.local/share/com.example.event_sourcing_datastore_demo/event_sourcing_datastore_demo/*.db
rm -f /home/$USER/.local/share/com.example.event_sourcing_datastore_demo/event_sourcing_datastore_demo/*.uuid
(cd apps/common-dart/event_sourcing_datastore/example && flutter run -d linux)
```

Expected: stdout prints `[demo] mobile install UUID: <uuid-A>` and `[demo] portal install UUID: <uuid-B>`. Restart the demo; expect the same UUIDs read back from disk.

- [ ] **Step 6: Commit**

```bash
git add -A apps/common-dart/event_sourcing_datastore/example/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_9.md
git commit -m "[CUR-1154] Phase 4.22 Task 9: demo per-pane install UUID (REQ-d00142-D demonstration)"
```

---

### Task 10: Demo - second Native (NativeAudit) + hop badge on EventStreamPanel

**TASK_FILE**: `PHASE4.22_TASK_10.md`

Adds the second `NativeDemoDestination` on the mobile pane subscribed to system audits; adds the `[L]`/`[R]` hop badge on the event stream panel.

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/main.dart` (NativeAudit destination)
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart` (hop badge)
- Test: extend `apps/common-dart/event_sourcing_datastore/example/test/portal_soak_test.dart` (system-event bridging assertion)
- Test: extend `apps/common-dart/event_sourcing_datastore/example/integration_test/dual_pane_test.dart` (hop badge visibility)

- [ ] **Step 1: Add NativeAudit destination in `_bootstrapPane`**

In `main.dart`, modify `_bootstrapPane` to construct two Native destinations instead of one:

```dart
final nativeUser = NativeDemoDestination(
  id: 'NativeUser',
  filter: const SubscriptionFilter(
    entryTypes: <String>[
      'demo_note',
      'red_button_pressed',
      'green_button_pressed',
      'blue_button_pressed',
    ],
    includeSystemEvents: false,
  ),
  bridge: bridge,
);

final nativeAudit = NativeDemoDestination(
  id: 'NativeAudit',
  filter: const SubscriptionFilter(
    entryTypes: <String>[],
    includeSystemEvents: true,
  ),
  bridge: bridge,
);

final datastore = await bootstrapAppendOnlyDatastore(
  // ...
  destinations: <Destination>[primary, secondary, nativeUser, nativeAudit],
  // ...
);
```

Update the `for (final id in <String>['Primary', 'Secondary', 'Native'])` setStartDate loop to include both NativeUser and NativeAudit (replace 'Native' with 'NativeUser' and add 'NativeAudit').

The portal pane's `_bootstrapPane` keeps the symmetric pattern — both NativeUser and NativeAudit on portal too, with `bridge: null` (no-op).

- [ ] **Step 2: Add hop badge to EventStreamPanel**

In `apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart`, modify the row renderer:

```dart
// Add EventStore param to widget constructor (it currently has backend; add eventStore).
class EventStreamPanel extends StatefulWidget {
  const EventStreamPanel({
    required this.backend,
    required this.eventStore,    // NEW
    required this.appState,
    super.key,
  });

  final StorageBackend backend;
  final EventStore eventStore;   // NEW
  final AppState appState;
  // ...
}
```

Inside the row builder:

```dart
// Implements: REQ-dNEW-B — visual hop discrimination per row.
final originBadge = widget.eventStore.isLocallyOriginated(event) ? '[L]' : '[R]';
final shortAggId = event.aggregateId.length >= 8
    ? event.aggregateId.substring(event.aggregateId.length - 8)
    : event.aggregateId;
final label = '$originBadge #${event.sequenceNumber} ${event.eventType} '
    '${event.aggregateType} agg-$shortAggId';
```

Then in `app.dart`, where `EventStreamPanel` is constructed, pass `eventStore: backend == widget.config.backend ? widget.config.datastore.eventStore : ...` — actually, simpler: the panel widget already has access to the backend through the pane config; add `eventStore: widget.config.datastore.eventStore` to the constructor call.

- [ ] **Step 3: Extend portal_soak_test.dart**

In `apps/common-dart/event_sourcing_datastore/example/test/portal_soak_test.dart`, add a NativeAudit destination to the soak's `_mkPane` helper so the soak exercises the multi-Native pattern. After the soak's click loop completes, add an assertion:

```dart
// Verifies: REQ-d00128-J + REQ-dNEW-F — system audits bridge through NativeAudit to portal.
final portalSystemEvents = portalEvents.where(
  (e) => kReservedSystemEntryTypeIds.contains(e.entryType),
).toList();
expect(portalSystemEvents, isNotEmpty,
    reason: 'NativeAudit must bridge mobile system audits to portal');
// Find at least one bridged audit whose originator is mobile.
expect(
  portalSystemEvents.where((e) => e.originatorHop.identifier == mobile.source.identifier),
  isNotEmpty,
  reason: 'at least one portal-stored system event must originate from mobile install',
);
```

- [ ] **Step 4: Extend dual_pane_test.dart**

In `apps/common-dart/event_sourcing_datastore/example/integration_test/dual_pane_test.dart`, add a widget test that:
1. Boots the dual-pane app.
2. Records an event on mobile.
3. Pumps until sync settles.
4. Finds the EventStreamPanel rows on portal.
5. Asserts at least one row's text contains `[R]` (the bridged event).
6. Asserts the corresponding mobile-pane event's row contains `[L]`.

```dart
// Verifies: REQ-dNEW-B — hop badge visible in EventStreamPanel.
testWidgets('REQ-dNEW-B: portal pane shows [R] for ingested events; mobile shows [L] for local', (tester) async {
  // ... boot app, record event, pump, find panels, assert badges
});
```

- [ ] **Step 5: Run tests + analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: all green.

- [ ] **Step 6: Manual eyeball walk-through (per spec §4.5)**

Run the dual-pane demo and walk through the 5 expected behaviors:
1. Boot → 7 system events per pane under the new aggregate_id = pane's install UUID.
2. Mobile Start/Complete → events sync to portal → portal MaterializedPanel populates.
3. tombstoneAndRefill on mobile NativeUser → audit appears on portal stream with `[R]` badge.
4. Break mobile NativeUser; click buttons → NativeUser FIFO wedges; NativeAudit keeps draining.
5. Hop badge: mobile rows all `[L]`; portal rows mix of `[L]` (own bootstrap) and `[R]` (mobile's).

Record results in WORKLOG.

- [ ] **Step 7: Commit**

```bash
git add -A apps/common-dart/event_sourcing_datastore/example/ PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_10.md
git commit -m "[CUR-1154] Phase 4.22 Task 10: demo NativeAudit destination + EventStreamPanel hop badge"
```

---

### Task 11: Final verification + Source.identifier doc + worklog close

**TASK_FILE**: `PHASE4.22_TASK_11.md`

Closes the phase: extends the Source class doc comment with the install-identity requirement; runs full verification; closes the worklog.

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/source.dart` (doc comment update)

- [ ] **Step 1: Update Source class doc comment**

In `lib/src/storage/source.dart`, extend the doc comment block:

```dart
/// Constructor-time identity of the process writing events. Stamps
/// `metadata.provenance[0]` on every event written through `EventStore`.
///
/// Renamed from `DeviceInfo` (Phase 4.4) and narrowed: the old `userId`
/// field moved out to the per-append `Initiator` argument, so one `Source`
/// instance can serve many authenticated users.
///
/// **`identifier` is the per-installation unique identity** (Phase 4.22 /
/// REQ-d00142-D). Production callers MUST persist a globally-unique value
/// (UUIDv4 recommended) on first install and pass the same value on every
/// subsequent bootstrap. The library does NOT validate the format at
/// runtime — callers that violate the global-uniqueness requirement get
/// correct lib behavior on each install in isolation but produce data that
/// collides on receivers when bridged. System audit aggregate_ids equal
/// `source.identifier` (REQ-d00134-E revised, REQ-d00129-J/K/L/M revised,
/// REQ-d00138-D/E/F/H revised), so two installs that share an identifier
/// share a system aggregate on any receiver they both bridge to.
// Implements: REQ-d00142-A, REQ-d00142-B, REQ-d00142-C, REQ-d00142-D.
class Source { ... }
```

- [ ] **Step 2: Run all test suites + analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/provenance && dart test 2>&1 | tail -5)
(cd apps/common-dart/provenance && dart analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter test 2>&1 | tail -5)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

All expected: green / "No issues found."

- [ ] **Step 3: Cleanup-target greps (verify nothing leaked)**

```bash
# Old per-registry system aggregate_id strings should be gone (search lib/, NOT test/, NOT docs/).
grep -rnE "aggregateId: 'destination:|aggregateId: 'system:entry-type-registry|aggregateId: 'security-retention" apps/common-dart/event_sourcing_datastore/lib/
```

Expected: zero hits. If hits exist, Task 4 missed a site.

```bash
# Phase 4.17 hard-drop should be gone from fillBatch and historicalReplay.
grep -nE "kReservedSystemEntryTypeIds.contains" apps/common-dart/event_sourcing_datastore/lib/src/sync/
```

Expected: zero hits in `fill_batch.dart` and `historical_replay.dart`.

```bash
# Phase 4.22 surface present.
grep -rnE "includeSystemEvents|originatorHop|isLocallyOriginated" apps/common-dart/event_sourcing_datastore/lib/ | head -10
```

Expected: hits in subscription_filter.dart, stored_event.dart, event_store.dart.

- [ ] **Step 4: REQ coverage check**

```text
mcp__elspais__get_test_coverage(req_id="REQ-d00121")
mcp__elspais__get_test_coverage(req_id="REQ-d00128")
mcp__elspais__get_test_coverage(req_id="REQ-d00129")
mcp__elspais__get_test_coverage(req_id="REQ-d00134")
mcp__elspais__get_test_coverage(req_id="REQ-d00138")
mcp__elspais__get_test_coverage(req_id="REQ-d00142")
mcp__elspais__get_test_coverage(req_id="REQ-d00145")
mcp__elspais__get_test_coverage(req_id=REQ-dNEW)
```

Expected: every assertion touched by Phase 4.22 has at least one TEST node referencing it. Record any gaps in WORKLOG.

- [ ] **Step 5: Close worklog**

Append to `PHASE_4.22_WORKLOG.md`:

```markdown
## Final verification (Task 11)

- event_sourcing_datastore: <count> tests passing (baseline + ~25 new)
- provenance: <count> tests passing (unchanged)
- example: <count> tests passing (baseline + ~3 new)
- analyze: clean across lib, example, provenance
- Cleanup greps: clean (no stale aggregate_id strings in lib/; Phase 4.17 hard-drop removed; Phase 4.22 surface present)
- REQ coverage: every touched assertion has at least one TEST node

Phase 4.22 closes the Phase 4.9 deferral (materialize-on-ingest) and
adds the system-event bridging mechanism + cross-hop discrimination API.
CUR-1154 library work is complete; remaining for ticket close: pre-PR
review, rebase-merge per master plan README §"Branch, PR, and merge
conventions."

### Phase 4.22 Commit Table

| Task | SHA | Message |
| --- | --- | --- |
| Task 1 | <sha> | [CUR-1154] Phase 4.22 Task 1: baseline + worklog |
| Task 2 | <sha> | [CUR-1154] Phase 4.22 Task 2: spec changes ... |
| ... | ... | ... |

**Phase 4.22 complete. Ready for CUR-1154 closeout.**
```

- [ ] **Step 6: Commit**

```bash
git add -A apps/common-dart/event_sourcing_datastore/lib/src/storage/source.dart PHASE_4.22_WORKLOG.md docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.22_TASK_11.md
git commit -m "[CUR-1154] Phase 4.22 Task 11: final verification + Source doc + worklog close"
```

---

## Recovery

After `/clear` or context compaction:

1. Read `PLAN_PHASE4.22_ingest_materialize_and_bridging.md` (this file).
2. Read `PHASE_4.22_WORKLOG.md` to find the first unchecked task.
3. Read the corresponding `PHASE4.22_TASK_N.md` task file for in-progress notes.
4. Read the spec: `docs/superpowers/specs/2026-04-26-phase4.22-ingest-materialize-and-bridging-design.md`.

## Phase-end consolidation

Phase 4.22 follows the per-task commit cadence used by Phases 4.7+. No phase-boundary squash is needed — the master plan rebase-merges to `main` at PR time, collapsing everything per `feedback_no_commit_history_juggling.md`.

## Notes for elspais integration

- All test files MUST end in `_test.dart` (already enforced by project convention).
- Per-test `// Verifies: REQ-X-Y` comments AND assertion ID at start of test description string per `~/templates/MASTER_PLAN_TEMPLATE_DART.md`.
- Per-implementation `// Implements: REQ-X-Y — prose` comments above every modified or new function/class.
- After spec edits in Task 2, run `mcp__elspais__refresh_graph(full=False)` and `elspais fix` (or whatever the project's standard regen command is) to keep `spec/INDEX.md` in sync.
