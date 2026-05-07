import 'dart:convert';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_knobs.dart';
import 'package:flutter/foundation.dart';

// Implements: REQ-d00122 — Destination contract surface.
// Implements: REQ-d00128 — batch transform, canAddToBatch,
//   maxAccumulateTime.
// Implements: REQ-d00129-B — allowHardDelete opt-in.
// Design: §7.6.
class DemoDestination implements Destination, DemoKnobs {
  DemoDestination({
    required this.id,
    this.allowHardDelete = false,
    this.filter = const SubscriptionFilter(),
    Duration initialSendLatency = const Duration(seconds: 10),
    int initialBatchSize = 1,
    Duration initialAccumulate = Duration.zero,
    Connection initialConnection = Connection.ok,
  }) : connection = ValueNotifier<Connection>(initialConnection),
       sendLatency = ValueNotifier<Duration>(initialSendLatency),
       batchSize = ValueNotifier<int>(initialBatchSize),
       maxAccumulateTimeN = ValueNotifier<Duration>(initialAccumulate);

  @override
  final String id;

  @override
  final bool allowHardDelete;

  @override
  final SubscriptionFilter filter;

  @override
  String get wireFormat => 'demo-json-v1';

  // Implements: REQ-d00152-A — DemoDestination is a lossy 3rd-party-style
  // destination; library invokes transform() and stores the resulting
  // WirePayload verbatim.
  @override
  bool get serializesNatively => false;

  @override
  Duration get maxAccumulateTime => maxAccumulateTimeN.value;

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
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.length < batchSize.value;

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    final payload = <String, Object?>{
      'batch': batch.map((e) => e.toJson()).toList(),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    return WirePayload(
      bytes: bytes,
      contentType: 'application/json',
      transformVersion: 'demo-v1',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    switch (connection.value) {
      case Connection.ok:
        await Future<void>.delayed(sendLatency.value);
        return const SendOk();
      case Connection.broken:
        return const SendTransient(error: 'simulated disconnect');
      case Connection.rejecting:
        return const SendPermanent(error: 'simulated rejection');
    }
  }
}
