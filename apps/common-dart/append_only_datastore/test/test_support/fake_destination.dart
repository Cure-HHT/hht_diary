import 'dart:convert';
import 'dart:typed_data';

import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/subscription_filter.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';

/// Scripted Destination used by drain- and sync-cycle tests.
///
/// Accepts a queue of SendResult values via `script` and pops one per
/// `send` call. Records every `send` invocation with its payload and the
/// wall-clock time it was observed (for assertions about call ordering
/// and payload shape).
///
/// Batching: [batchCapacity] controls the size at which
/// [canAddToBatch] returns `false`; default is `1`, matching legacy
/// single-event behavior for the drain tests that do not exercise
/// batching.
class FakeDestination extends Destination {
  FakeDestination({
    this.id = 'fake',
    SubscriptionFilter? filter,
    this.wireFormat = 'fake-v1',
    List<SendResult>? script,
    Future<void> Function()? blockBeforeSend,
    this.batchCapacity = 1,
    this.maxAccumulateTime = Duration.zero,
    this.allowHardDelete = false,
  }) : _script = script ?? <SendResult>[],
       _filter = filter ?? const SubscriptionFilter(),
       _blockBeforeSend = blockBeforeSend;

  @override
  final String id;

  @override
  final String wireFormat;

  /// Cap on events accepted into a single batch by [canAddToBatch].
  /// Default `1` preserves single-event FIFO semantics for tests that
  /// do not care about batching.
  final int batchCapacity;

  // Implements: REQ-d00128-F — maxAccumulateTime declared on the fake.
  @override
  final Duration maxAccumulateTime;

  // Implements: REQ-d00129-B — explicit override (default false) so the
  // abstract-class default is exercised on other destinations.
  @override
  final bool allowHardDelete;

  final SubscriptionFilter _filter;
  final List<SendResult> _script;
  final Future<void> Function()? _blockBeforeSend;

  /// Every send() call: the payload handed in.
  final List<WirePayload> sent = <WirePayload>[];

  /// Every send() call: the index into [sent] and what SendResult was
  /// returned, in order. Handy for tests that need to correlate call
  /// order with returned outcomes.
  final List<SendResult> returned = <SendResult>[];

  @override
  SubscriptionFilter get filter => _filter;

  // Implements: REQ-d00128-E — canAddToBatch admits up to batchCapacity.
  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.length < batchCapacity;

  // Implements: REQ-d00128-D / REQ-d00122-D — batch-aware transform.
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) {
    if (batch.isEmpty) {
      throw ArgumentError(
        'FakeDestination($id).transform called with empty batch',
      );
    }
    // Identity transform over the batch. Not actually used by the drain
    // tests because enqueue-side population is driven by fixtures, but
    // provided so a test can opt into transform()-and-send() flow if it
    // wants to.
    final json = jsonEncode(<String, Object?>{
      'event_ids': batch.map((e) => e.eventId).toList(),
      'data': batch.map((e) => e.data).toList(),
    });
    return Future<WirePayload>.value(
      WirePayload(
        bytes: Uint8List.fromList(utf8.encode(json)),
        contentType: 'application/json',
        transformVersion: 'fake-v1',
      ),
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    sent.add(payload);
    if (_blockBeforeSend != null) {
      await _blockBeforeSend();
    }
    if (_script.isEmpty) {
      throw StateError(
        'FakeDestination($id): send() called but script is exhausted',
      );
    }
    final result = _script.removeAt(0);
    returned.add(result);
    return result;
  }

  /// Push [result] onto the tail of the script. Lets tests extend the
  /// scripted outcomes mid-run.
  void enqueueScript(SendResult result) => _script.add(result);
}
