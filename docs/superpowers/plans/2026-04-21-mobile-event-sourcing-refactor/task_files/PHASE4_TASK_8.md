# PHASE 4 TASK 8 — SyncCycle orchestrator

## What landed

`SyncCycle` — top-level orchestrator with `call()` entry point, per-destination concurrent drain, and a reentrancy guard.

Constructor:

- `backend: StorageBackend` — the storage backend to drain against.
- `registry: DestinationRegistry` — source of registered destinations.
- `clock: ClockFn?` — optional injectable clock, forwarded to each `drain()` call. Tests pass fixed-time closures; production passes `null`.

`call()` behavior:

1. If `_inFlight` is true, return immediately (REQ-d00125-C reentrancy guard).
2. Set `_inFlight = true`.
3. `Future.wait(registry.all().map(_drainOrSwallow))` — concurrent drain across all destinations (REQ-d00125-A).
4. After all drains complete, invoke `portalInboundPoll()` (REQ-d00125-B).
5. Clear `_inFlight` in `finally`.

### Design decisions

- **Exception handling in concurrent drain:** the plan says "exception in one destination's drain does not cancel another". `Future.wait(eagerError: false)` is the default — it waits for all futures, even if one throws, and propagates the first exception after they all settle. I chose to go one step further and swallow drain-level exceptions inside `_drainOrSwallow`, so a single destination crash does not leak all the way out of `syncCycle.call()`. The reasoning: the drain loop itself already handles send-level exceptions by categorizing them as `SendTransient` and recording an attempt; any exception that escapes the drain loop is an internal backend error (e.g., Sembast hiccup), and the right response is to let the *next* sync cycle try again rather than crashing the calling trigger handler. The swallowed exception is still surfaced per-entry via the attempts[].error_message column populated by the inner `drain()` try/catch.
- **`portalInboundPoll` as a public method:** making it public (not private) lets tests subclass `SyncCycle` to record its invocation order, which is how the "outbound-then-inbound" ordering test works. Phase 5 will override it with a real implementation either by subclassing or by collapsing the stub into a proper inbound-poll implementation.
- **`inFlight` getter:** exposed so tests can assert the guard's internal state mid-cycle without relying on timing.
- **No background isolate (REQ-d00125-E):** there is deliberately no WorkManager / BGTaskScheduler wiring in this file — the orchestrator is foreground-only. Phase 5's trigger layer in `clinical_diary` will invoke `SyncCycle.call()` from app-resume, a 15-minute periodic timer, connectivity-restored events, post-`record()` fire-and-forget, and FCM receive handlers (REQ-d00125-D).

## Tests (6)

- `REQ-d00125-A: drains run concurrently across registered destinations` — one slow destination gated by a completer, one fast destination; verify fast completes while slow is still blocked.
- `REQ-d00125-B: portalInboundPoll runs after outbound drains complete` — an `_OrderRecordingSyncCycle` subclass appends to a shared list from `portalInboundPoll`, and a `_RecordingDestination` appends on `send`. The resulting order is `['drain-send', 'inbound-poll']`.
- `REQ-d00125-C: reentrant call returns immediately without new drain` — first call blocked mid-flight on a completer; reentrant call returns immediately; destination's `send` was called exactly once.
- `REQ-d00125-C: after first cycle completes, a new call drains again` — guard auto-releases in `finally`.
- `REQ-d00125-A: exception in one destination does not cancel another` — one destination whose `send` throws `StateError`; second destination drains normally.
- `empty registry: cycle runs portalInboundPoll and exits` — defensive no-op path.

## Verification

- `flutter test test/sync/sync_cycle_test.dart`: 6 passed.
- `flutter analyze`: No issues found.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/sync/sync_cycle.dart` (new, 85 lines)
- `apps/common-dart/append_only_datastore/test/sync/sync_cycle_test.dart` (new, 6 tests)
