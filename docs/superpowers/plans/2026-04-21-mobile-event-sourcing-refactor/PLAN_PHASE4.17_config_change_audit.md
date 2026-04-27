# Phase 4.17 Implementation Plan: Config-Change Audit Events

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every runtime mutation to lib-controlled configuration emits a system audit event in the same backend transaction as the mutation. Per-resource aggregate IDs (`destination:<id>`, `security-retention`).

**Architecture:** Six new reserved system entry types. `DestinationRegistry` constructor gains `EventStore + Source` deps. Every mutation method gains required `Initiator` parameter and emits a system event in the same `backend.transaction` as the mutation. `tombstoneAndRefill` relocates from top-level function to `DestinationRegistry` method. `EventStore.applyRetentionPolicy` emits `system.retention_policy_applied` per sweep with `AutomationInitiator`.

**Tech Stack:** Dart 3.10 / Flutter 3.38, sembast.

**Spec:** `docs/superpowers/specs/2026-04-25-phase4.17-config-change-audit-design.md`

**Depends on:** Phase 4.16 must be landed first (audit events stamp `entry_type_version: 1` and `lib_format_version` via `EventStore.append`).

**Working tree root for all paths below:** `/home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor`

---

## Task 1: Spec amendments via elspais MCP

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md`

- [ ] **Step 1: Load mutator tools.**

- [ ] **Step 2: REQ-d00129 amendments**

`mutate_update_assertion` for A, C, F, G, H to add `{required Initiator initiator}` to documented signatures. Full text in spec §Requirements §REQ-d00129.

`mutate_add_assertion` for J, K, L, M, N (audit emissions per mutation method + atomicity).

- [ ] **Step 3: REQ-d00138 amendment**

`mutate_add_assertion` for H (per-sweep `system.retention_policy_applied` emission).

- [ ] **Step 4: REQ-d00144 amendments**

`mutate_update_assertion` for A (relocate to `DestinationRegistry.tombstoneAndRefill` method + add `initiator`).

`mutate_add_assertion` for G (audit emission).

- [ ] **Step 5: Save + refresh + commit**

```bash
mcp__elspais__save_mutations()
mcp__elspais__refresh_graph()
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "[CUR-1154] spec: amend REQs for phase 4.17 config-change audit events

REQ-d00129-A,C,F,G,H amended for required Initiator param.
REQ-d00129-J,K,L,M,N (new): per-mutation audit emission + atomicity.
REQ-d00138-H (new): per-sweep system.retention_policy_applied.
REQ-d00144-A amended (relocate to DestinationRegistry method + initiator).
REQ-d00144-G (new): tombstoneAndRefill audit emission.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Add six new reserved system entry type constants

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/security/system_entry_types.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart` (export new constants)

- [ ] **Step 1: Edit `system_entry_types.dart`**

Add six new constants alongside the existing `kSecurityContextRedactedEntryType` etc.:

```dart
// Implements: REQ-d00129-J — destination registration audit.
const String kDestinationRegisteredEntryType = 'system.destination_registered';

// Implements: REQ-d00129-K — destination start_date set audit.
const String kDestinationStartDateSetEntryType = 'system.destination_start_date_set';

// Implements: REQ-d00129-L — destination end_date set audit (covers deactivate).
const String kDestinationEndDateSetEntryType = 'system.destination_end_date_set';

// Implements: REQ-d00129-M — destination deletion audit.
const String kDestinationDeletedEntryType = 'system.destination_deleted';

// Implements: REQ-d00144-G — wedge recovery audit.
const String kDestinationWedgeRecoveredEntryType = 'system.destination_wedge_recovered';

// Implements: REQ-d00138-H — retention policy applied audit (per-sweep).
const String kRetentionPolicyAppliedEntryType = 'system.retention_policy_applied';
```

Update `kReservedSystemEntryTypeIds` (currently a `Set<String>` containing the four existing security-context entry types) to include all six new entries.

Update `kSystemEntryTypes` (a `List<EntryTypeDefinition>` for lib-controlled types). Each new entry:

```dart
const EntryTypeDefinition(
  id: kDestinationRegisteredEntryType,
  registeredVersion: 1,                 // Phase 4.16 field
  name: 'Destination Registered',
  widgetId: '',                         // not user-rendered
  widgetConfig: <String, Object?>{},
  materialize: false,                   // REQ-d00140-C
),
// ... six total ...
```

- [ ] **Step 2: Update exports**

In `event_sourcing_datastore.dart`'s `show` clause for `system_entry_types.dart`, add the six new constants alphabetically.

- [ ] **Step 3: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add apps/common-dart/event_sourcing_datastore/lib/src/security/system_entry_types.dart apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "[CUR-1154] phase 4.17a — six new reserved system entry types

Six new entry types added to kReservedSystemEntryTypeIds and kSystemEntryTypes
with materialize: false:
- system.destination_registered
- system.destination_start_date_set
- system.destination_end_date_set
- system.destination_deleted
- system.destination_wedge_recovered
- system.retention_policy_applied

Implements: REQ-d00129-J+K+L+M, REQ-d00138-H, REQ-d00144-G.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `EventStore.appendInTxn` — split `append` for transactional participation

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`

`DestinationRegistry`'s mutations open their own `backend.transaction(...)` — the audit event must land inside the SAME transaction. So `EventStore.append` (which today opens its own txn) needs a companion `appendInTxn(txn, ...)` that does the same work but participates in a caller-supplied txn.

- [ ] **Step 1: Refactor `append` to delegate**

Find the existing `Future<StoredEvent?> append({...}) async { ... }`. Move its body into a new method `appendInTxn(Txn txn, {...})`. The public `append` becomes a thin wrapper that opens a txn and calls `appendInTxn`:

```dart
Future<StoredEvent?> append({
  // ... all existing required params plus phase-4.16 entryTypeVersion ...
}) async {
  return backend.transaction((txn) => appendInTxn(
    txn,
    entryType: entryType,
    entryTypeVersion: entryTypeVersion,
    aggregateId: aggregateId,
    // ... etc ...
  ));
}

/// Transactional companion to [append]. Use when the caller is already
/// inside a `backend.transaction` and wants the append to participate.
/// Implements: REQ-d00141-B (delegated transactional half).
Future<StoredEvent?> appendInTxn(
  Txn txn, {
  required String entryType,
  required int entryTypeVersion,
  // ... same parameter list as append ...
}) async {
  // Existing append body, but using the supplied `txn` instead of opening one.
}
```

- [ ] **Step 2: Verify no regressions**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze && flutter test)
```

Behavior is unchanged for existing callers; only the internal structure changed. All existing tests should pass.

- [ ] **Step 3: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "[CUR-1154] phase 4.17b — split EventStore.append into appendInTxn companion

append now thin-wraps backend.transaction(...) around appendInTxn(...).
Lets DestinationRegistry mutations emit audit events in the same txn as
their underlying mutations.

No behavior change for existing callers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `DestinationRegistry` constructor + required `Initiator` on mutation methods

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination_registry.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/bootstrap.dart` (wire EventStore + Source into registry construction)

This is the bulk of Phase 4.17. Add `EventStore + Source` constructor deps; add `required Initiator initiator` to each mutation method; emit the corresponding system event inside each method's transaction.

- [ ] **Step 1: Update `DestinationRegistry` constructor**

```dart
class DestinationRegistry {
  DestinationRegistry({
    required StorageBackend backend,
    required EventStore eventStore,         // NEW
    required Source source,                 // NEW
  })  : _backend = backend,
        _eventStore = eventStore,
        _source = source;

  final StorageBackend _backend;
  final EventStore _eventStore;
  final Source _source;
  // ... rest ...
}
```

- [ ] **Step 2: Update `bootstrapAppendOnlyDatastore` to wire deps**

In `bootstrap.dart`, the construction order today is roughly: backend → entryTypes → eventStore → destinationRegistry. The eventStore is constructed before the registry; thread it (and `source`) into the registry's constructor.

- [ ] **Step 3: Update each mutation method**

For each method, three steps: (a) add `required Initiator initiator` param, (b) wrap the existing body in `backend.transaction((txn) async { ... })`, (c) call `_eventStore.appendInTxn(...)` after the mutation's existing side effects.

#### `addDestination`

```dart
// Implements: REQ-d00129-A+J+N.
Future<void> addDestination(Destination destination, {required Initiator initiator}) async {
  return _backend.transaction((txn) async {
    // existing: register in-memory, write schedule to backend
    await _addDestinationInTxn(txn, destination);
    // NEW: emit audit event
    await _eventStore.appendInTxn(
      txn,
      entryType: kDestinationRegisteredEntryType,
      entryTypeVersion: 1,
      aggregateId: 'destination:${destination.id}',
      aggregateType: 'system_destination',
      eventType: 'finalized',
      data: <String, Object?>{
        'id': destination.id,
        'wire_format': destination.wireFormat,
        'allow_hard_delete': destination.allowHardDelete,
        'serializes_natively': destination.serializesNatively,
        'filter_entry_types': destination.filter.entryTypes,
        'filter_event_types': destination.filter.eventTypes,
        'filter_predicate_description': null,  // SubscriptionFilter has no predicate intro yet
      },
      initiator: initiator,
    );
  });
}
```

(Refactor the existing body into a private `_addDestinationInTxn` helper that takes `txn` so the public method's body is just txn+emit.)

#### `setStartDate`

```dart
// Implements: REQ-d00129-C+D+E+K+N.
Future<void> setStartDate(String id, DateTime startDate, {required Initiator initiator}) async {
  return _backend.transaction((txn) async {
    await _setStartDateInTxn(txn, id, startDate);
    await _eventStore.appendInTxn(
      txn,
      entryType: kDestinationStartDateSetEntryType,
      entryTypeVersion: 1,
      aggregateId: 'destination:$id',
      aggregateType: 'system_destination',
      eventType: 'finalized',
      data: <String, Object?>{
        'id': id,
        'start_date': startDate.toUtc().toIso8601String(),
      },
      initiator: initiator,
    );
  });
}
```

#### `setEndDate`

```dart
// Implements: REQ-d00129-F+L+N.
Future<SetEndDateResult> setEndDate(String id, DateTime endDate, {required Initiator initiator}) async {
  return _backend.transaction((txn) async {
    final priorEndDate = await _readEndDateInTxn(txn, id);
    final result = await _setEndDateInTxn(txn, id, endDate);
    await _eventStore.appendInTxn(
      txn,
      entryType: kDestinationEndDateSetEntryType,
      entryTypeVersion: 1,
      aggregateId: 'destination:$id',
      aggregateType: 'system_destination',
      eventType: 'finalized',
      data: <String, Object?>{
        'id': id,
        'end_date': endDate.toUtc().toIso8601String(),
        'prior_end_date': priorEndDate?.toUtc().toIso8601String(),
        'result': result.name,
      },
      initiator: initiator,
    );
    return result;
  });
}
```

#### `deactivateDestination`

```dart
// Implements: REQ-d00129-G+L+N.
Future<SetEndDateResult> deactivateDestination(String id, {required Initiator initiator}) =>
    setEndDate(id, DateTime.now(), initiator: initiator);
```

#### `deleteDestination`

```dart
// Implements: REQ-d00129-H+M+N.
Future<void> deleteDestination(String id, {required Initiator initiator}) async {
  return _backend.transaction((txn) async {
    await _deleteDestinationInTxn(txn, id);  // throws StateError if !allowHardDelete (existing)
    await _eventStore.appendInTxn(
      txn,
      entryType: kDestinationDeletedEntryType,
      entryTypeVersion: 1,
      aggregateId: 'destination:$id',
      aggregateType: 'system_destination',
      eventType: 'finalized',
      data: <String, Object?>{
        'id': id,
        'allow_hard_delete': true,        // gate already checked
      },
      initiator: initiator,
    );
  });
}
```

- [ ] **Step 4: Tests**

Create `test/destinations/registry_audit_test.dart`:

For each of the 5 methods (addDestination, setStartDate, setEndDate, deactivate, delete):

```dart
test('REQ-d00129-J: addDestination emits system.destination_registered with caller initiator', () async {
  final ds = await _bootstrap();   // helper using identityPromoter materializer
  await ds.destinations.addDestination(
    DemoDestination(id: 'aux'),
    initiator: const UserInitiator('clinician-7'),
  );
  final events = await ds.backend.findAllEvents();
  final auditEvents = events.where((e) => e.entryType == kDestinationRegisteredEntryType).toList();
  expect(auditEvents.length, 1);
  expect(auditEvents.single.aggregateId, 'destination:aux');
  expect(auditEvents.single.data['id'], 'aux');
  expect(auditEvents.single.initiator, isA<UserInitiator>());
  expect((auditEvents.single.initiator as UserInitiator).userId, 'clinician-7');
});
```

(Repeat the pattern for each method's REQ assertion.)

For atomicity: a separate test file `test/destinations/registry_audit_atomicity_test.dart` uses a stub `EventStore` whose `appendInTxn` throws on demand to verify the mutation also rolls back. (See spec §Testing §3 for the pattern.)

- [ ] **Step 5: Don't commit yet — Tasks 4–7 land atomically because the registry constructor change breaks every callsite.**

---

## Task 5: Move `tombstoneAndRefill` to `DestinationRegistry` method

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination_registry.dart` (add method)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/ops/tombstone_and_refill.dart` (delete or convert to private helper)
- Modify: `apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart` (remove top-level export)

- [ ] **Step 1: Move the implementation**

Read the existing `tombstone_and_refill.dart` to confirm signature and body. The function takes `(String destId, String fifoRowId, ...)` and returns `TombstoneAndRefillResult`.

Two clean approaches:

(a) Inline the body into `DestinationRegistry.tombstoneAndRefill` directly (simplest, preserves single-implementation semantics).

(b) Keep `tombstoneAndRefill` as a private file-level helper that the registry method calls. Less invasive to the existing structure.

Pick (a) — inlining keeps the implementation co-located with its REQ traceability comments and removes one layer of indirection.

```dart
class DestinationRegistry {
  // ... existing methods ...

  /// Operator-driven wedge recovery. Tombstones the FIFO head, deletes
  /// pending trail rows, rewinds the fill cursor, and emits an audit event.
  // Implements: REQ-d00144-A+B+C+D+E+F+G.
  Future<TombstoneAndRefillResult> tombstoneAndRefill(
    String destId,
    String fifoRowId, {
    required Initiator initiator,
  }) async {
    return _backend.transaction((txn) async {
      // existing body of tombstoneAndRefill, now operating on `txn` directly
      final result = await _tombstoneAndRefillInTxn(txn, destId, fifoRowId);
      await _eventStore.appendInTxn(
        txn,
        entryType: kDestinationWedgeRecoveredEntryType,
        entryTypeVersion: 1,
        aggregateId: 'destination:$destId',
        aggregateType: 'system_destination',
        eventType: 'finalized',
        data: <String, Object?>{
          'id': destId,
          'target_row_id': result.targetRowId,
          'target_event_id_range_first_seq': result.targetFirstSeq,
          'target_event_id_range_last_seq': result.targetLastSeq,
          'deleted_trail_count': result.deletedTrailCount,
          'rewound_to': result.rewoundTo,
        },
        initiator: initiator,
      );
      return result;
    });
  }
}
```

- [ ] **Step 2: Remove top-level export**

In `event_sourcing_datastore.dart`, find:

```dart
export 'src/ops/tombstone_and_refill.dart' show tombstoneAndRefill;
```

Delete this line. (Keep `TombstoneAndRefillResult` exported if it's also from this file — `TombstoneAndRefillResult` may live in `destination_schedule.dart` or similar; verify and preserve as needed.)

- [ ] **Step 3: Delete (or empty) `tombstone_and_refill.dart`**

If approach (a) inlined the body, this file is no longer needed. Delete it. Update `git rm`.

- [ ] **Step 4: Don't commit yet**

---

## Task 6: `EventStore.applyRetentionPolicy` emits `system.retention_policy_applied`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (or wherever applyRetentionPolicy lives)
- Test: extend retention-policy tests

- [ ] **Step 1: Edit `applyRetentionPolicy`**

Find the existing method. Inside its `backend.transaction` block, after the existing compact/purge sweeps and their conditional `_compacted`/`_purged` emissions, add the unconditional `_applied` emission:

```dart
Future<RetentionResult> applyRetentionPolicy(SecurityRetentionPolicy policy) async {
  return backend.transaction((txn) async {
    // existing: compute cutoffs, truncate, purge, emit _compacted / _purged on non-empty sweeps
    final truncated = ...;
    final purged = ...;
    final cutoffFull = ...;
    final cutoffPurge = ...;
    // existing _compacted / _purged emissions per REQ-d00138-E,F unchanged

    // NEW: per-sweep audit, always emitted.
    // Implements: REQ-d00138-H.
    await appendInTxn(
      txn,
      entryType: kRetentionPolicyAppliedEntryType,
      entryTypeVersion: 1,
      aggregateId: 'security-retention',
      aggregateType: 'system_retention',
      eventType: 'finalized',
      data: <String, Object?>{
        'policy_full_retention_seconds': policy.fullRetention.inSeconds,
        'policy_truncated_retention_seconds': policy.truncatedRetention.inSeconds,
        'events_truncated': truncated,
        'events_purged': purged,
        'cutoff_full': cutoffFull.toUtc().toIso8601String(),
        'cutoff_purge': cutoffPurge.toUtc().toIso8601String(),
      },
      initiator: const AutomationInitiator('retention-policy-sweep'),
    );

    return RetentionResult(...);
  });
}
```

- [ ] **Step 2: Test**

Add to retention tests:

```dart
test('REQ-d00138-H: every applyRetentionPolicy emits system.retention_policy_applied', () async {
  final es = await _bootstrap();
  // Empty sweep — still emits.
  await es.applyRetentionPolicy(SecurityRetentionPolicy.defaults);
  final events = await ...findAllEvents();
  final applied = events.where((e) => e.entryType == kRetentionPolicyAppliedEntryType).toList();
  expect(applied.length, 1);
  expect(applied.single.initiator, isA<AutomationInitiator>());
  expect((applied.single.initiator as AutomationInitiator).source, 'retention-policy-sweep');
});
```

- [ ] **Step 3: Don't commit yet**

---

## Task 7: Mechanical callsite migration + atomic commit of Tasks 4–7

- [ ] **Step 1: Update every callsite calling registry mutations**

Compiler errors point to:
- `bootstrapAppendOnlyDatastore`'s internal `addDestination` calls — supply `initiator: const AutomationInitiator('lib-bootstrap')`.
- `example/lib/main.dart`'s `setStartDate` loop — supply `initiator: const AutomationInitiator('demo-bootstrap')`.
- `example/lib/widgets/top_action_bar.dart`'s `[Add destination]` button — supply `initiator: const UserInitiator('demo-user-1')`.
- `example/lib/widgets/add_destination_dialog.dart` — same.
- All test fixtures' `addDestination`/`setStartDate`/`setEndDate`/`deactivate`/`delete` calls — supply an `Initiator` (typically `AutomationInitiator('test-bootstrap')`).
- All `tombstoneAndRefill(...)` callsites — switch to `registry.tombstoneAndRefill(destId, rowId, initiator: ...)`. Remove the top-level import.

- [ ] **Step 2: Verify**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter analyze && flutter test)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze && flutter test)
```

- [ ] **Step 3: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add apps/common-dart/event_sourcing_datastore
[ -f apps/common-dart/event_sourcing_datastore/lib/src/ops/tombstone_and_refill.dart ] || git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor rm apps/common-dart/event_sourcing_datastore/lib/src/ops/tombstone_and_refill.dart
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "$(cat <<'EOF'
[CUR-1154] phase 4.17c-g — config-change audit emission

DestinationRegistry constructor takes EventStore + Source. Every
mutation method (addDestination, setStartDate, setEndDate,
deactivateDestination, deleteDestination, tombstoneAndRefill) gains
a required Initiator named parameter and emits a system audit event in
the same backend.transaction as the mutation. Audit emission failure
rolls back the mutation per REQ-d00140-E semantics.

tombstoneAndRefill relocates from a top-level function to a method on
DestinationRegistry — operator verbs all live on the registry now.

EventStore.applyRetentionPolicy emits system.retention_policy_applied
on every sweep (zero-effect sweeps included), with
AutomationInitiator('retention-policy-sweep'). Existing
_compacted / _purged emissions per REQ-d00138-E,F unchanged.

Mechanical: every registry mutation callsite gains initiator:; every
tombstoneAndRefill call switches from top-level to registry method.

Implements: REQ-d00129-A+C+F+G+H+J+K+L+M+N, REQ-d00138-H, REQ-d00144-A+G.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- REQ-d00129 — interface + audit emissions → Tasks 4, 5.
- REQ-d00138-H → Task 6.
- REQ-d00144 — relocation + audit → Task 5.
- New reserved entry types → Task 2.
- `appendInTxn` plumbing → Task 3.
- Mechanical migration → Task 7.

**Placeholder scan:** None.

**Type consistency:** All audit emissions use the same field-set structure documented in spec §Components §5 table.

**Cross-task ordering:** Task 3 lands solo (no behavior change). Tasks 4–7 land atomically because the registry constructor change breaks every callsite.
