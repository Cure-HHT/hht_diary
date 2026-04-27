import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/sync/drain.dart';
import 'package:event_sourcing_datastore/src/sync/sync_policy.dart';

/// Top-level sync orchestrator.
///
/// One `SyncCycle` instance lives for the process lifetime. Its [call]
/// method is the single entry point that every trigger — app-lifecycle
/// resume, the 15-minute foreground timer, connectivity-restored event,
/// post-`record()` fire-and-forget, FCM message receipt — routes into.
/// Centralizing on one entry point is how the reentrancy guard works:
/// concurrent triggers race into [call] but only one drives the cycle.
///
/// Phase-4 deliverable is the orchestrator itself; the trigger wiring
/// lives in `clinical_diary` and is introduced in Phase 5. Phase-4 also
/// ships `portalInboundPoll` as a no-op stub per the plan — its real body
/// (§11.1 inbound tombstone polling) is Phase-5 work.
// Implements: REQ-d00125-A+B+C+E — concurrent per-destination drain,
// post-drain inbound poll, single-isolate reentrancy guard, no background
// isolate.
class SyncCycle {
  // Implements: REQ-d00126-A+B+D — optional SyncPolicy? policy parameter
  // (null falls back to SyncPolicy.defaults inside drain()), or a
  // SyncPolicy Function()? policyResolver invoked once per call() for
  // hot-swap scenarios. The two are mutually exclusive (D).
  SyncCycle({
    required StorageBackend backend,
    required DestinationRegistry registry,
    ClockFn? clock,
    SyncPolicy? policy,
    SyncPolicy? Function()? policyResolver,
  }) : _backend = backend,
       _registry = registry,
       _clock = clock,
       _policy = policy,
       _policyResolver = policyResolver {
    // REQ-d00126-D: mutual exclusivity. Both supplied → ArgumentError.
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
  final SyncPolicy? Function()? _policyResolver;

  bool _inFlight = false;

  /// True while a prior [call] invocation has not yet completed. Exposed
  /// for tests to assert the guard's internal state.
  bool get inFlight => _inFlight;

  /// Run one drain-and-poll cycle. Returns immediately (without side
  /// effects) when a prior [call] is still running (REQ-d00125-C).
  // Implements: REQ-d00125-A+B+C, REQ-d00126-B+D — concurrent drain +
  // inbound poll + reentrancy guard + per-cycle policy resolution.
  Future<void> call() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      // Resolve once per cycle, after the reentrancy guard. The same
      // SyncPolicy value is forwarded to every destination's drain in
      // this cycle.
      // Implements: REQ-d00126-B+D.
      final cyclePolicy = _policyResolver != null ? _policyResolver() : _policy;

      final destinations = _registry.all();
      // REQ-d00125-A: concurrent per-destination drain. A thrown
      // exception from one drain does not cancel the others. See
      // `_drainOrSwallow` for how exceptions are handled on a per-
      // destination basis (currently swallowed, not re-thrown).
      await Future.wait(
        destinations.map((d) => _drainOrSwallow(d, cyclePolicy)),
      );
      // REQ-d00125-B: inbound poll happens AFTER outbound drains complete.
      await portalInboundPoll();
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _drainOrSwallow(
    Destination destination,
    SyncPolicy? cyclePolicy,
  ) async {
    try {
      await drain(
        destination,
        backend: _backend,
        clock: _clock,
        policy: cyclePolicy,
      );
    } catch (_) {
      // Per REQ-d00125-A, one destination's failure does not cancel
      // another's drain. We swallow here so Future.wait does not abort;
      // the drain loop itself has already recorded the attempt via its
      // internal try/catch on `destination.send`, so the exception is
      // not silently lost — it is still surfaced via the entry's
      // `attempts[].error_message`.
    }
  }

  /// Poll the portal read-side API for inbound tombstones authored on the
  /// portal (clinician-initiated deletions) and apply them locally. Phase
  /// 4 ships this as a no-op stub so the call site is in place; Phase 5
  /// implements the polling body per design doc §11.1.
  // TODO(CUR-1154, Phase 5): implement inbound tombstone polling per
  // design §11.1.
  Future<void> portalInboundPoll() async {
    // Intentionally empty. Phase 5.
  }
}
