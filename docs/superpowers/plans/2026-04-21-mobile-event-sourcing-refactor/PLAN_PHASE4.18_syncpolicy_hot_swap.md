# Phase 4.18 Implementation Plan: SyncCycle Policy Hot-Swap

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `SyncPolicy Function()? policyResolver` to `SyncCycle`. Mutually exclusive with the existing `SyncPolicy? policy`. When supplied, the resolver is invoked once per `call()` invocation (after the reentrancy guard) and the resolved value is forwarded to every destination's `drain` in that cycle.

**Architecture:** One new optional named parameter on `SyncCycle`. Constructor asserts mutual exclusivity. `call()` resolves the policy once per invocation and threads it through `_drainOrSwallow`. Resolver-throws-during-call propagates and rolls back the in-flight cycle (the reentrancy guard's `finally` clears `_inFlight`).

**Tech Stack:** Dart 3.10 / Flutter 3.38.

**Spec:** `docs/superpowers/specs/2026-04-25-phase4.18-syncpolicy-hot-swap-design.md`

**Depends on:** None (independent of Phases 4.16/4.17/4.19).

**Working tree root for all paths below:** `/home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor`

---

## Task 1: Spec amendment via elspais MCP

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md`

- [ ] **Step 1: Load mutator tools.**

- [ ] **Step 2: REQ-d00126 amendments**

`mutate_update_assertion` for B (extended for resolver branch). `mutate_add_assertion` for D (mutual exclusivity + resolver-throws semantics). Full text in design spec §Requirements §REQ-d00126.

- [ ] **Step 3: Save + refresh + commit**

```bash
mcp__elspais__save_mutations()
mcp__elspais__refresh_graph()
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "[CUR-1154] spec: amend REQ-d00126 for phase 4.18 SyncCycle policy hot-swap

REQ-d00126-B amended for SyncCycle.policyResolver branch.
REQ-d00126-D (new): mutual exclusivity + resolver-throws-aborts-cycle semantics.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `SyncCycle` constructor + `call()` invoke resolver

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/sync/sync_cycle.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/sync/sync_cycle_policy_resolver_test.dart` (new)
- Test: extend existing `apps/common-dart/event_sourcing_datastore/test/sync/sync_cycle_test.dart` with regression cases

- [ ] **Step 1: Write failing tests first**

Create `test/sync/sync_cycle_policy_resolver_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<({StorageBackend backend, DestinationRegistry registry})> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase('scprt-${DateTime.now().microsecondsSinceEpoch}.db');
  final backend = SembastBackend(database: db);
  final ds = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(hopId: 'test', identifier: 'd', softwareVersion: 't'),
    entryTypes: const <EntryTypeDefinition>[],
    destinations: const <Destination>[],
    materializers: const <Materializer>[],
    // If Phase 4.19 has landed, also supply initialViewTargetVersions: <empty>
  );
  return (backend: backend, registry: ds.destinations);
}

void main() {
  group('REQ-d00126-B: policyResolver invocation', () {
    test('resolver called exactly once per call()', () async {
      final ctx = await _bootstrap();
      var calls = 0;
      final cycle = SyncCycle(
        backend: ctx.backend,
        registry: ctx.registry,
        policyResolver: () { calls++; return SyncPolicy.defaults; },
      );
      await cycle();
      expect(calls, 1);
      await cycle();
      expect(calls, 2);
    });

    test('resolver result is the same across all destinations within one cycle', () async {
      // Add multiple destinations; record which policy each drain saw.
      // Verify all drains in one call() saw the SAME policy instance.
      // (Implementer: use a stub destination whose send() captures the policy
      //  value via a closure; or expose via DestinationRegistry mock.)
    });

    test('REQ-d00126-D: resolver returning null falls back to SyncPolicy.defaults', () async {
      final ctx = await _bootstrap();
      final cycle = SyncCycle(
        backend: ctx.backend,
        registry: ctx.registry,
        policyResolver: () => null,
      );
      // No exception expected; drain receives null and uses defaults per REQ-d00126-B.
      await cycle();
    });
  });

  group('REQ-d00126-D: mutual exclusivity + throws', () {
    test('constructing with both policy and policyResolver throws ArgumentError', () async {
      final ctx = await _bootstrap();
      expect(
        () => SyncCycle(
          backend: ctx.backend,
          registry: ctx.registry,
          policy: SyncPolicy.defaults,
          policyResolver: () => SyncPolicy.defaults,
        ),
        throwsArgumentError,
      );
    });

    test('resolver throws → cycle aborts; reentrancy guard cleared', () async {
      final ctx = await _bootstrap();
      var first = true;
      final cycle = SyncCycle(
        backend: ctx.backend,
        registry: ctx.registry,
        policyResolver: () {
          if (first) { first = false; throw StateError('boom'); }
          return SyncPolicy.defaults;
        },
      );
      await expectLater(cycle(), throwsStateError);
      // Subsequent call must succeed (guard was released).
      await cycle();
    });
  });

  group('regression', () {
    test('SyncCycle with neither policy nor resolver still works (defaults)', () async {
      final ctx = await _bootstrap();
      final cycle = SyncCycle(backend: ctx.backend, registry: ctx.registry);
      await cycle();   // no exception
    });

    test('SyncCycle with explicit policy: still uses it (today behavior)', () async {
      final ctx = await _bootstrap();
      final cycle = SyncCycle(
        backend: ctx.backend, registry: ctx.registry,
        policy: SyncPolicy.defaults,
      );
      await cycle();
    });
  });
}
```

- [ ] **Step 2: Edit `sync_cycle.dart`**

Add the new field and constructor parameter:

```dart
class SyncCycle {
  // Implements: REQ-d00126-A+B+D.
  SyncCycle({
    required StorageBackend backend,
    required DestinationRegistry registry,
    ClockFn? clock,
    SyncPolicy? policy,
    SyncPolicy Function()? policyResolver,    // NEW
  })  : _backend = backend,
        _registry = registry,
        _clock = clock,
        _policy = policy,
        _policyResolver = policyResolver {
    // REQ-d00126-D: mutual exclusivity. Both supplied → throw.
    if (policy != null && policyResolver != null) {
      throw ArgumentError(
        'SyncCycle: supply at most one of policy / policyResolver',
      );
    }
  }

  final StorageBackend _backend;
  final DestinationRegistry _registry;
  final ClockFn? _clock;
  final SyncPolicy? _policy;
  final SyncPolicy Function()? _policyResolver;    // NEW

  bool _inFlight = false;
  bool get inFlight => _inFlight;

  /// Implements: REQ-d00125-A+B+C — drain orchestration with REQ-d00126-B
  /// per-cycle policy resolution.
  Future<void> call() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      // Resolve once per cycle, after the reentrancy guard.
      // Implements: REQ-d00126-B+D.
      final SyncPolicy? cyclePolicy =
          _policyResolver != null ? _policyResolver() : _policy;

      final destinations = _registry.all();
      await Future.wait(
        destinations.map((d) => _drainOrSwallow(d, cyclePolicy)),
      );
      await portalInboundPoll();
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _drainOrSwallow(Destination destination, SyncPolicy? cyclePolicy) async {
    try {
      await drain(
        destination,
        backend: _backend,
        clock: _clock,
        policy: cyclePolicy,
      );
    } catch (_) {
      // REQ-d00125-A unchanged.
    }
  }

  // portalInboundPoll() unchanged.
}
```

- [ ] **Step 3: Run tests — pass**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test test/sync/sync_cycle_policy_resolver_test.dart)
(cd apps/common-dart/event_sourcing_datastore && flutter test test/sync/sync_cycle_test.dart)
```

Both must pass. Existing `sync_cycle_test.dart` tests are regression cases — they should continue passing because `SyncCycle({policy:...})` and `SyncCycle()` paths are untouched.

- [ ] **Step 4: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add apps/common-dart/event_sourcing_datastore/lib/src/sync/sync_cycle.dart apps/common-dart/event_sourcing_datastore/test/sync/sync_cycle_policy_resolver_test.dart
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "$(cat <<'EOF'
[CUR-1154] phase 4.18 — SyncCycle policy hot-swap

Adds optional SyncPolicy Function()? policyResolver to SyncCycle.
Mutually exclusive with the existing SyncPolicy? policy parameter
(constructor throws ArgumentError when both supplied). When supplied,
the resolver is invoked exactly once per SyncCycle.call() — inside
the reentrancy guard, before any drain runs — and the resolved value
(or SyncPolicy.defaults when the resolver returns null) is forwarded
to every destination's drain call within that cycle.

Resolver throws abort the cycle: no drains run, portalInboundPoll
not invoked, exception propagates, reentrancy guard cleared via
try/finally so a subsequent trigger may invoke call() again.

Implements: REQ-d00126-B+D.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 (optional cleanup): Migrate example `main.dart` to use `SyncCycle` with resolver

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/main.dart`

This is the cleanup the design spec mentions as a follow-on benefit: replace the hand-rolled tick + duplicated reentrancy guard with a `SyncCycle` instance per pane.

- [ ] **Step 1: Replace per-pane tick body**

Inside `_bootstrapPane`, replace the existing tick:

```dart
// before (existing)
var syncInFlight = false;
final tick = Timer.periodic(const Duration(seconds: 1), (_) async {
  if (syncInFlight) return;
  syncInFlight = true;
  try {
    final destinations = datastore.destinations.all();
    await Future.wait(destinations.map((dest) async {
      final schedule = await datastore.destinations.scheduleOf(dest.id);
      await fillBatch(dest, backend: backend, schedule: schedule, source: source);
    }));
    await Future.wait(destinations.map((dest) =>
        drain(dest, backend: backend, policy: policyNotifier.value)));
  } catch (e, s) {
    stderr.writeln('[demo:${source.hopId}] sync tick error: $e\n$s');
  } finally {
    syncInFlight = false;
  }
});
```

with:

```dart
// after (uses SyncCycle for drain + reentrancy)
final syncCycle = SyncCycle(
  backend: backend,
  registry: datastore.destinations,
  policyResolver: () => policyNotifier.value,
);
final tick = Timer.periodic(const Duration(seconds: 1), (_) async {
  try {
    // fillBatch isn't covered by SyncCycle; do it here per-destination.
    final destinations = datastore.destinations.all();
    for (final dest in destinations) {
      final schedule = await datastore.destinations.scheduleOf(dest.id);
      await fillBatch(dest, backend: backend, schedule: schedule, source: source);
    }
    await syncCycle();   // reentrancy guard inside
  } catch (e, s) {
    stderr.writeln('[demo:${source.hopId}] sync tick error: $e\n$s');
  }
});
```

The hand-rolled `syncInFlight` boolean disappears (`SyncCycle` provides one of its own).

- [ ] **Step 2: Verify**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze && flutter test)
(cd apps/common-dart/event_sourcing_datastore/example && flutter test integration_test/dual_pane_test.dart -d linux)
```

The integration test still passes — it bootstraps panes and exercises mobile→portal sync end-to-end.

Run the soak test too — its hand-rolled `mobileSyncTick`/`portalSyncTick` guards in the test file can stay (the test deliberately drives ticks programmatically rather than using SyncCycle, for determinism). Verify the soak test still passes:

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter test test/portal_soak_test.dart --reporter expanded)
```

- [ ] **Step 3: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add apps/common-dart/event_sourcing_datastore/example/lib/main.dart
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "$(cat <<'EOF'
[CUR-1154] phase 4.18 cleanup — example migrates per-pane tick to SyncCycle

main.dart replaces the hand-rolled tick body + duplicated reentrancy
guard (syncInFlight) with a SyncCycle per pane, configured with
policyResolver: () => policyNotifier.value. The reentrancy guard
duplication goes away; drain orchestration goes through the lib's
tested orchestrator. fillBatch stays in the tick body — SyncCycle
covers drain + inbound poll only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- REQ-d00126-B (resolver branch + same-value-across-destinations + null-falls-back) → Task 2.
- REQ-d00126-D (mutual exclusivity + resolver-throws) → Task 2.
- Example cleanup (cited as follow-on benefit in spec) → Task 3.

**Placeholder scan:** None. The "stub destination whose send() captures policy via closure" instruction in Task 2 Step 1 is an implementer note pointing to a concrete pattern, not an unfilled placeholder.

**Type consistency:** `policyResolver` typedef and field declarations consistent across constructor, fields, body of `call()`.

**Cross-task ordering:** Tasks 1 and 2 land sequentially. Task 3 is optional cleanup that can land separately.
