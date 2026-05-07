import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_knobs.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:flutter/foundation.dart';

/// Native demo destination — declares it speaks `esd/batch@1` so the
/// library handles serialization itself (Phase 4.14 REQ-d00152). FIFO
/// rows for this destination store envelope metadata + null wire_payload
/// (REQ-d00119-K). Used in the example to demonstrate the storage-shape
/// difference vs `DemoDestination` (lossy 3rd-party).
///
/// Implements [DemoKnobs] so the FIFO panel exposes the same live-tunable
/// connection / latency / batch-size / accumulate sliders as the lossy
/// `DemoDestination`. Default knob values preserve the previously-fixed
/// behavior: `batchSize=10` (highlights native multi-event batches),
/// `sendLatency=0` (instant succeed), `connection=ok`,
/// `maxAccumulateTime=0` (no hold).
///
/// Optional [DownstreamBridge] hook: when supplied via the `bridge:`
/// constructor parameter and `connection.value == Connection.ok`,
/// `send()` delegates to the bridge after the latency delay. The bridge
/// forwards the wire bytes to a downstream `EventStore.ingestBatch` and
/// maps the outcome back to a [SendResult]. When `connection != ok`,
/// the bridge is NOT invoked — link failures are simulated upstream of
/// the bridge so the existing `broken`/`rejecting` UX is unchanged.
// Implements: REQ-d00122 — Destination contract surface.
// Implements: REQ-d00152-A — serializesNatively=true: library produces
//   the canonical `esd/batch@1` envelope inside fillBatch and persists
//   envelope_metadata with wire_payload null.
class NativeDemoDestination implements Destination, DemoKnobs {
  NativeDemoDestination({
    this.id = 'Native',
    this.filter = const SubscriptionFilter(),
    this.allowHardDelete = false,
    Duration initialSendLatency = Duration.zero,
    int initialBatchSize = 10,
    Duration initialAccumulate = Duration.zero,
    Connection initialConnection = Connection.ok,
    DownstreamBridge? bridge,
  }) : connection = ValueNotifier<Connection>(initialConnection),
       sendLatency = ValueNotifier<Duration>(initialSendLatency),
       batchSize = ValueNotifier<int>(initialBatchSize),
       maxAccumulateTimeN = ValueNotifier<Duration>(initialAccumulate),
       _bridge = bridge;

  final DownstreamBridge? _bridge;

  @override
  final String id;

  @override
  final SubscriptionFilter filter;

  @override
  final bool allowHardDelete;

  /// Live-tunable network simulation. Drives send() branch selection.
  @override
  final ValueNotifier<Connection> connection;

  /// Live-tunable delay applied when `connection = ok` before returning
  /// `SendOk`. Makes the drain/retry cadence observable in the UI.
  @override
  final ValueNotifier<Duration> sendLatency;

  /// Live-tunable upper bound on current-batch length. fillBatch asks
  /// `canAddToBatch` once per candidate; when the batch reaches this
  /// length, the next candidate is rejected.
  @override
  final ValueNotifier<int> batchSize;

  /// Backing notifier for `maxAccumulateTime`. Named with an `N` suffix
  /// so the interface getter can keep the un-suffixed name.
  @override
  final ValueNotifier<Duration> maxAccumulateTimeN;

  @override
  Duration get maxAccumulateTime => maxAccumulateTimeN.value;

  // Implements: REQ-d00152-A — native destination opts in.
  @override
  bool get serializesNatively => true;

  // Implements: REQ-d00119-K — native rows carry the canonical wire format.
  @override
  String get wireFormat => 'esd/batch@1';

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.length < batchSize.value;

  // Library handles native serialization in fillBatch (REQ-d00152-B); the
  // contract guarantees transform is never invoked when serializesNatively
  // is true, so this throw is defense-in-depth, not a code path.
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) {
    throw StateError(
      'transform must not be called on a native destination '
      '(serializesNatively=true); fillBatch builds the envelope itself.',
    );
  }

  // Demo: routes by `connection.value`. `ok` succeeds after `sendLatency`;
  // `broken` returns SendTransient; `rejecting` returns SendPermanent.
  // Real native destinations would POST the re-encoded `esd/batch@1` bytes
  // (reconstructed by drain from envelope_metadata + the row's events) to
  // a server.
  @override
  Future<SendResult> send(WirePayload payload) async {
    switch (connection.value) {
      case Connection.ok:
        await Future<void>.delayed(sendLatency.value);
        final bridge = _bridge;
        if (bridge != null) {
          return bridge.deliver(payload);
        }
        return const SendOk();
      case Connection.broken:
        return const SendTransient(error: 'simulated disconnect');
      case Connection.rejecting:
        return const SendPermanent(error: 'simulated rejection');
    }
  }
}
