import 'dart:convert';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/foundation.dart';

/// Connection state live-controlled via the destination's `connection`
/// notifier. The send() implementation routes by value.
enum Connection { ok, broken, rejecting }

// Implements: REQ-d00122 — Destination contract surface.
// Implements: REQ-d00128 — batch transform, canAddToBatch,
//   maxAccumulateTime.
// Implements: REQ-d00129-B — allowHardDelete opt-in.
// Design: §7.6.
class DemoDestination implements Destination {
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

  @override
  Duration get maxAccumulateTime => maxAccumulateTimeN.value;

  /// Live-tunable network simulation. Drives send() branch selection.
  final ValueNotifier<Connection> connection;

  /// Live-tunable delay applied when `connection = ok` before returning
  /// `SendOk`. Makes the drain/retry cadence observable in the UI.
  final ValueNotifier<Duration> sendLatency;

  /// Live-tunable upper bound on current-batch length. fillBatch asks
  /// `canAddToBatch` once per candidate; when the batch reaches this
  /// length, the next candidate is rejected.
  final ValueNotifier<int> batchSize;

  /// Backing notifier for `maxAccumulateTime`. Named with an `N` suffix
  /// so the interface getter can keep the un-suffixed name.
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
