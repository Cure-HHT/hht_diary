import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/send_result.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';

/// Test-support [Destination] that declares `serializesNatively == true`,
/// modelling a destination that consumes the library's canonical
/// `esd/batch@1` batch format. `fillBatch` SHALL bypass [transform] for
/// such destinations and instead build a `BatchEnvelopeMetadata` from the
/// library's source identity (REQ-d00152-A+B).
///
/// `wireFormat` is fixed to `"esd/batch@1"` and `transform` throws if
/// invoked — calling `transform` on a native destination is a contract
/// violation by `fillBatch` (REQ-d00152-B).
///
/// Records every `send` invocation in [sent] and pops one [SendResult] per
/// call from a script supplied at construction.
// Implements: REQ-d00152-A — concrete destination overriding
// serializesNatively to true.
class NativeDestination extends Destination {
  NativeDestination({
    this.id = 'native',
    SubscriptionFilter? filter,
    List<SendResult>? script,
    this.batchCapacity = 1,
    this.maxAccumulateTime = Duration.zero,
    this.allowHardDelete = false,
  }) : _script = script ?? <SendResult>[],
       _filter = filter ?? const SubscriptionFilter();

  @override
  final String id;

  @override
  String get wireFormat => 'esd/batch@1';

  // Implements: REQ-d00152-A — declares native serialization; library
  // produces envelope metadata, this destination provides no transform.
  @override
  bool get serializesNatively => true;

  /// Cap on events accepted into a single batch by [canAddToBatch].
  final int batchCapacity;

  // Implements: REQ-d00128-F — maxAccumulateTime declared on the test double.
  @override
  final Duration maxAccumulateTime;

  // Implements: REQ-d00129-B — explicit override (default false).
  @override
  final bool allowHardDelete;

  final SubscriptionFilter _filter;
  final List<SendResult> _script;

  /// Every send() call: the payload handed in.
  final List<WirePayload> sent = <WirePayload>[];

  /// Every send() call: the SendResult that was returned, in order.
  final List<SendResult> returned = <SendResult>[];

  @override
  SubscriptionFilter get filter => _filter;

  // Implements: REQ-d00128-E — canAddToBatch admits up to batchCapacity.
  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.length < batchCapacity;

  /// Native destinations do not own a transform — `fillBatch` is required
  /// to produce envelope metadata from the library's source identity
  /// (REQ-d00152-B). Any call here is a contract violation.
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) {
    throw StateError(
      'NativeDestination($id).transform invoked: fillBatch must build '
      'envelope metadata from source identity instead (REQ-d00152-B)',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    sent.add(payload);
    if (_script.isEmpty) {
      throw StateError(
        'NativeDestination($id): send() called but script is exhausted',
      );
    }
    final result = _script.removeAt(0);
    returned.add(result);
    return result;
  }

  /// Push [result] onto the tail of the script.
  void enqueueScript(SendResult result) => _script.add(result);
}
