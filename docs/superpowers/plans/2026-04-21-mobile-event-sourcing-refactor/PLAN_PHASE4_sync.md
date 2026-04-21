# Master Plan Phase 4: `Destination`, FIFO drain, and `sync_cycle()`

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 4 of 5
**Status**: Not Started
**Depends on**: Phase 3 squashed and phase-reviewed

## Scope

Add the per-destination fan-out machinery: the `Destination` interface, `SubscriptionFilter`, `DestinationRegistry`, `SyncPolicy` constants with backoff curve, the `drain()` loop, and the `sync_cycle()` orchestrator. All unit-tested with a scripted `_FakeDestination` test double. No concrete production destination exists after Phase 4 — `PrimaryDiaryServerDestination` is Phase 5.

**Produces:**
- `apps/common-dart/append_only_datastore/lib/src/destinations/` — `destination.dart`, `subscription_filter.dart`, `wire_payload.dart`, `destination_registry.dart`.
- `apps/common-dart/append_only_datastore/lib/src/sync/` — `sync_policy.dart`, `drain.dart`, `sync_cycle.dart`.

**Does not produce:**
- No production code calls `sync_cycle()`. Phase 5 wires triggers in `clinical_diary/services/triggers.dart`.
- No HTTP. Concrete destinations that speak HTTP come in Phase 5.
- `portalInboundPoll()` exists as a stub returning immediately; Phase 5 implements the polling body (§11.1 tombstone inbound path).

## Execution Rules

Read [README.md](README.md), design doc §8 (sync architecture) in full. `SendResult`, `SendOk`, `SendTransient`, `SendPermanent`, `FinalStatus`, `AttemptResult`, `FifoEntry` all come from Phase 2 — do not redefine. `StorageBackend.readFifoHead / enqueueFifo / appendAttempt / markFinal / exhaustedFifos / anyFifoExhausted` all come from Phase 2.

---

## Plan

### Task 1: Baseline verification

**TASK_FILE**: `PHASE4_TASK_1.md`

- [ ] **Confirm Phase 3 complete**: `git log --oneline` shows Phase 3's squashed commit as HEAD (or immediately behind review fixups).
- [ ] **Stay on shared branch**.
- [ ] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`.
- [ ] **Baseline tests** — green across all touched packages.
- [ ] **Create TASK_FILE** with Phase 3 completion SHA.

---

### Task 2: Spec additions — Destination, FIFO drain, SyncPolicy, sync_cycle

**TASK_FILE**: `PHASE4_TASK_2.md`

Four REQs added to `spec/dev-event-sourcing-mobile.md`. Numbers claimed via `discover_requirements("next available REQ-d")`. Also run `discover_requirements("sync queue destination FIFO retry backoff")` and record existing applicable assertions in TASK_FILE.

**REQ-DEST — `Destination` contract** (assertions A-G):
- A: A `Destination` SHALL expose a stable `id: String` used as the FIFO store identifier.
- B: A `Destination` SHALL expose a `SubscriptionFilter` that deterministically selects which events to enqueue.
- C: A `Destination` SHALL declare a `wire_format: String` identifier (e.g., `"json-v1"`).
- D: `Destination.transform(event)` SHALL produce a `WirePayload` with `bytes`, `content_type`, and `transform_version`. The `transform_version` SHALL be recorded on the `FifoEntry` and appended to `ProvenanceEntry.transform_version` downstream.
- E: `Destination.send(payload)` SHALL return a `SendResult` in `{SendOk, SendTransient, SendPermanent}`. Its categorization of underlying failures (HTTP codes, network errors, timeouts) is a per-destination concern.
- F: `SubscriptionFilter` SHALL support allow-listing by `entry_type` and/or `event_type`, plus an optional `predicate` escape-hatch function.
- G: Destinations SHALL be registered at boot via `DestinationRegistry.register(...)`. The registry SHALL not mutate after boot-time registration completes.

**REQ-POLICY — `SyncPolicy` constants** (assertions A-E):
- A: `SyncPolicy.initialBackoff` SHALL be 60 seconds.
- B: `SyncPolicy.backoffMultiplier` SHALL be 5.0.
- C: `SyncPolicy.maxBackoff` SHALL be 2 hours (cap).
- D: `SyncPolicy.jitterFraction` SHALL be 0.1 (±10% jitter applied to each backoff).
- E: `SyncPolicy.maxAttempts` SHALL be 20 (aggregate lifetime retry count over the backoff curve, approximately one week total).

**REQ-DRAIN — FIFO drain loop** (assertions A-H):
- A: `drain(destination)` SHALL read the head of `fifo/{destination.id}` via `backend.readFifoHead(destination.id)`. If the head is absent, SHALL return.
- B: If the head's backoff (computed from `attempts.length` via `SyncPolicy.backoffFor(attempts.length)` plus the most recent `attempts[last].attempted_at`) has not elapsed, SHALL return without calling `destination.send()`.
- C: On `SendOk`, SHALL call `backend.markFinal(id, entry_id, FinalStatus.sent)` and continue the loop.
- D: On `SendPermanent`, SHALL call `backend.markFinal(id, entry_id, FinalStatus.exhausted)` and return. The FIFO is now wedged (REQ-p01001-H synchronization visibility).
- E: On `SendTransient` with `attempts.length + 1 >= SyncPolicy.maxAttempts`, SHALL call `backend.markFinal(id, entry_id, FinalStatus.exhausted)` and return.
- F: On `SendTransient` otherwise, SHALL call `backend.appendAttempt(id, entry_id, attempt)` and return (backoff applied on next trigger).
- G: `drain` SHALL always call `backend.appendAttempt(id, entry_id, attempt)` with the `AttemptResult` derived from the `SendResult` before either marking final or returning. The attempt log is append-only and SHALL record every call to `destination.send`.
- H: `drain` SHALL preserve strict FIFO order within a destination: no entry SHALL be attempted while an earlier entry is still `pending` or `exhausted`.

**REQ-SYNC — `sync_cycle()` orchestrator** (assertions A-E):
- A: `syncCycle()` SHALL drain every registered destination concurrently (via `Future.wait` over `DestinationRegistry.all().map(drain)`).
- B: After outbound drains complete, `syncCycle()` SHALL call `portalInboundPoll()` (whose implementation is Phase 5).
- C: `syncCycle()` SHALL have a single-isolate reentrancy guard: if invoked while a prior invocation is still in flight, the second call SHALL return immediately without side effects.
- D: `syncCycle()` SHALL be callable from: app-lifecycle resume, a foreground 15-minute periodic timer, post-`record()` fire-and-forget, connectivity-restored event, FCM message receipt. The implementations of these trigger sites live in `clinical_diary` (Phase 5).
- E: `syncCycle()` SHALL NOT run from a background isolate. No WorkManager or BGTaskScheduler is registered.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write the four REQs** into `spec/dev-event-sourcing-mobile.md`.
- [ ] **Update `spec/INDEX.md`**.
- [ ] **Commit**: "Add Destination/SyncPolicy/drain/sync_cycle spec (CUR-1154)".

---

### Task 3: `WirePayload` value type and `Destination` abstract class

**TASK_FILE**: `PHASE4_TASK_3.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/destinations/wire_payload.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/destinations/destination.dart`
- Create: `apps/common-dart/append_only_datastore/test/destinations/wire_payload_test.dart`

**Applicable assertions:** REQ-DEST-A, C, D, E.

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** for `WirePayload`: immutable value type with fields `bytes: Uint8List`, `content_type: String`, `transform_version: String`. Round-trip via `toJson`/`fromJson` if needed for FIFO storage — actually, `FifoEntry.wire_payload` stores just the bytes, `wire_format` stores content_type as a string, `transform_version` is its own column. So `WirePayload` doesn't need JSON serialization; it's a transport type between `Destination.transform` and `enqueueFifo`. Test just: constructor, getters, equality.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `WirePayload`**.
- [ ] **Implement `Destination`** abstract class per design §8.1. All four members (`id`, `filter`, `wireFormat`, `transform`, `send`) abstract. Per-method `// Implements:` markers.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add WirePayload and Destination abstract class (CUR-1154)".

---

### Task 4: `SubscriptionFilter`

**TASK_FILE**: `PHASE4_TASK_4.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/destinations/subscription_filter.dart`
- Create: `apps/common-dart/append_only_datastore/test/destinations/subscription_filter_test.dart`

**Applicable assertions:** REQ-DEST-F.

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - Filter with `entryTypes = ["epistaxis_event"]` matches events with `entry_type == "epistaxis_event"`, rejects others.
  - Filter with `entryTypes = null` (any) matches all entry types.
  - Filter with `eventTypes = ["finalized"]` matches only finalized events.
  - Intersection: `entryTypes = ["epistaxis_event"]` AND `eventTypes = ["finalized"]` — both must match.
  - Optional `predicate` — when non-null, called after allow-lists pass; must return `true` for the overall filter to match.
  - `predicate` short-circuits: if allow-lists fail, predicate is not invoked.
  - An empty list (e.g., `entryTypes = []`) matches nothing. Document this distinction from null; cover with a test.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `SubscriptionFilter`** with a `bool matches(Event e)` method. Per-method `// Implements: REQ-DEST-F`.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add SubscriptionFilter (CUR-1154)".

---

### Task 5: `DestinationRegistry`

**TASK_FILE**: `PHASE4_TASK_5.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/destinations/destination_registry.dart`
- Create: `apps/common-dart/append_only_datastore/test/destinations/destination_registry_test.dart`

**Applicable assertions:** REQ-DEST-G.

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `register(d)` adds `d` to the list; `all()` returns it.
  - Registering two destinations with the same `id` throws `ArgumentError` (ids must be unique).
  - `freeze()` is called implicitly on first `all()` read. Post-freeze, `register(d2)` throws `StateError`. (Enforces REQ-DEST-G "SHALL not mutate after boot-time registration completes.")
  - `matchingDestinations(event)` returns only destinations whose filter matches.
  - The registry is a singleton for the app lifecycle but tests reset it via `reset()` (test-only method gated behind `@visibleForTesting`).
- [ ] **Run tests**; expect failures.
- [ ] **Implement `DestinationRegistry`**:
  - Private constructor; `static final DestinationRegistry _instance = DestinationRegistry._();`
  - `register(Destination d)` asserts not frozen and id-uniqueness.
  - `all()` freezes and returns an unmodifiable view.
  - `matchingDestinations(Event e)` — filtered view.
  - `@visibleForTesting void reset()` — nukes the list and unfreezes. Used in test setUp.
  - Annotation: `// Implements: REQ-DEST-G — boot-time registration; immutable post-freeze.`
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add DestinationRegistry (CUR-1154)".

---

### Task 6: `SyncPolicy` constants and backoff curve

**TASK_FILE**: `PHASE4_TASK_6.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart`
- Create: `apps/common-dart/append_only_datastore/test/sync/sync_policy_test.dart`

**Applicable assertions:** REQ-POLICY-A, B, C, D, E.

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `SyncPolicy.initialBackoff == Duration(seconds: 60)`.
  - `SyncPolicy.backoffMultiplier == 5.0`.
  - `SyncPolicy.maxBackoff == Duration(hours: 2)`.
  - `SyncPolicy.jitterFraction == 0.1`.
  - `SyncPolicy.maxAttempts == 20`.
  - `SyncPolicy.periodicInterval == Duration(minutes: 15)`.
  - `backoffFor(0) ≈ 60s ± 10% jitter`.
  - `backoffFor(1) ≈ 300s (60*5) ± 10%`.
  - `backoffFor(2) ≈ 1500s (5m*5 = 25m) ± 10%`.
  - `backoffFor(3) ≈ capped at 7200s (2h) ± 10%`.
  - `backoffFor(n)` for large n stays at the cap.
  - Jitter is seeded deterministically when a seed is supplied via an optional test-only parameter; without the seed, it uses `Random()`. Test with a fixed seed to verify the ±10% bound.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `SyncPolicy`** as a class with `static const` durations and a `static Duration backoffFor(int attemptCount, {Random? random})`. The jitter calculation: `baseDuration * (1 + (random.nextDouble() * 2 - 1) * jitterFraction)`.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add SyncPolicy with backoff curve (CUR-1154)".

---

### Task 7: `drain()` loop

**TASK_FILE**: `PHASE4_TASK_7.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart`
- Create: `apps/common-dart/append_only_datastore/test/sync/drain_test.dart`
- Create: `apps/common-dart/append_only_datastore/test/test_support/fake_destination.dart` (scripted test double)

**Applicable assertions:** REQ-DRAIN-A through H; REQ-p01001-D (FIFO order), REQ-p01001-E (exponential backoff), REQ-p01001-M (log failed sync with error messages).

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write `_FakeDestination` test double** in `test/test_support/fake_destination.dart`:
  - Accepts a scripted queue of `SendResult` values; pops one per `send()` call.
  - Records every `send()` invocation (payload + timestamp).
  - Simulates `transform()` as identity over the event's JSON representation.
- [ ] **Write failing tests** (`drain_test.dart`). Fixture: a `SembastBackend` over in-memory Sembast, one enqueued entry, one `_FakeDestination` with a scripted outcome.
  - **Empty FIFO**: `drain(d)` returns immediately without calling `d.send`.
  - **SendOk**: head is marked `sent`; `appendAttempt` was called; a subsequent `drain` call advances to the next entry.
  - **SendPermanent**: head is marked `exhausted`; subsequent `drain` does not advance (FIFO wedged).
  - **SendTransient below maxAttempts**: attempt is appended; `final_status` remains `pending`; a subsequent `drain` applies backoff — if backoff has not elapsed, it returns without calling `d.send` again.
  - **SendTransient at maxAttempts**: after the Nth transient failure, head is marked `exhausted`.
  - **Backoff not elapsed**: after a transient, immediately re-run `drain`; expect `d.send` NOT called.
  - **Backoff elapsed** (simulate via injectable clock): `d.send` is called again and its scripted next outcome applies.
  - **Strict FIFO order**: enqueue three entries in order A, B, C. Script A's first call as SendOk; drain — A marked sent, B becomes head. Script B as SendPermanent; drain — B marked exhausted, C is NOT attempted (wedged behind B).
  - **Multi-destination independence**: d1 wedged on its head does not block d2 from draining normally.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `drain(destination, {required StorageBackend backend, Clock? clock})`**. Pseudocode in design §8.3 is the canonical algorithm. The clock parameter allows tests to advance time deterministically; production passes `null` (real clock).
  - Per-function: `// Implements: REQ-DRAIN-A+B+C+D+E+F+G+H — strict-order drain with backoff.`
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Implement drain loop (CUR-1154)".

---

### Task 8: `sync_cycle()` orchestrator

**TASK_FILE**: `PHASE4_TASK_8.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/sync/sync_cycle.dart`
- Create: `apps/common-dart/append_only_datastore/test/sync/sync_cycle_test.dart`

**Applicable assertions:** REQ-SYNC-A, B, C, D, E; REQ-p01001-B (auto sync when connectivity returns — trigger in Phase 5).

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `syncCycle()` with two registered destinations calls `drain` on both (concurrently — verify via a race where one `_FakeDestination` blocks briefly and the other completes).
  - `syncCycle()` calls `portalInboundPoll()` after drains complete.
  - Reentrancy: call `syncCycle()` while a prior call is still running (the first is held by a scripted `_FakeDestination.send` that awaits a completer) — verify the second call returns immediately without triggering new drains.
  - After the first call finishes, a new `syncCycle()` call does drain normally.
  - Exception in one destination's drain does not cancel the other destination's drain — `Future.wait` should continue; verify both destinations' `send` was called.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `SyncCycle` class** with:
  - Constructor takes `StorageBackend backend`, `DestinationRegistry registry`.
  - `Future<void> call()` — the `syncCycle` entry point.
  - Reentrancy flag: `bool _inFlight = false`.
  - `portalInboundPoll()` — empty async method returning immediately. Add a `// TODO(CUR-1154, Phase 5): implement inbound tombstone polling per design §11.1.` comment.
  - Per-method citations.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Implement sync_cycle orchestrator (CUR-1154)".

---

### Task 9: Public library exports

**TASK_FILE**: `PHASE4_TASK_9.md`

- [ ] **Export** `Destination`, `SubscriptionFilter`, `WirePayload`, `DestinationRegistry`, `SyncPolicy`, `drain`, `SyncCycle` from the top-level barrel.
- [ ] `_FakeDestination` stays in `test/test_support/` — not exported.
- [ ] **Commit**: "Export sync public surface (CUR-1154)".

---

### Task 10: Version bump + CHANGELOG

**TASK_FILE**: `PHASE4_TASK_10.md`

- [ ] **Bump `append_only_datastore` version** (minor).
- [ ] **Update `CHANGELOG.md`** with the new public surface.
- [ ] **Full verification**.
- [ ] **Commit**: "Bump append_only_datastore for Phase 4 (CUR-1154)".

---

### Task 11: Phase-boundary squash and request phase review

**TASK_FILE**: `PHASE4_TASK_11.md`

- [ ] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`. Phases 1-3 squashed commits remain.
- [ ] **Full verification**: `flutter test` / `flutter analyze`.
- [ ] **Interactive rebase to squash Phase 4 commits**: `git rebase -i origin/main` — keep Phases 1-3 `pick`, squash Phase 4 commits into one with message:

  ```
  [CUR-1154] Phase 4: Add Destination, FIFO drain, and sync_cycle

  - Destination interface, SubscriptionFilter, WirePayload
  - DestinationRegistry with boot-time registration and post-freeze immutability
  - SyncPolicy constants and exponential backoff curve with jitter
  - drain() loop implementing strict-FIFO semantics with exhausted wedge
  - SyncCycle orchestrator with reentrancy guard
  - spec/dev-event-sourcing-mobile.md: REQ-DEST, REQ-POLICY, REQ-DRAIN, REQ-SYNC

  No production caller of sync_cycle() yet — Phase 5 wires the triggers.
  ```

- [ ] **Force-push with lease**.
- [ ] **Comment on PR**: "Phase 4 ready for review — commit `<sha>`. Review focus: drain loop correctness under scripted transient/permanent outcomes, strict-FIFO-order invariant, sync_cycle reentrancy guard, SyncPolicy backoff math. No concrete destination exists yet."
- [ ] **Wait for phase review**. Address feedback via fixups + in-place rebase.
- [ ] **Record phase-completion SHA** in TASK_FILE before starting Phase 5.

---

## Recovery

1. Read this file.
2. Read [README.md](README.md).
3. Find first unchecked box.
4. Read matching `PHASE4_TASK_N.md`.

Archive procedure is whole-ticket (after rebase-merge) — see [README.md](README.md) Archive section.
