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
class FakeDestination extends Destination {
  FakeDestination({
    this.id = 'fake',
    SubscriptionFilter? filter,
    this.wireFormat = 'fake-v1',
    List<SendResult>? script,
    Future<void> Function()? blockBeforeSend,
  }) : _script = script ?? <SendResult>[],
       _filter = filter ?? const SubscriptionFilter(),
       _blockBeforeSend = blockBeforeSend;

  @override
  final String id;

  @override
  final String wireFormat;

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

  @override
  WirePayload transform(StoredEvent event) {
    // Identity transform over event.data JSON. Not actually used by the
    // drain tests because enqueue-side population is driven by fixtures,
    // but provided so a test can opt into transform()-and-send() flow if
    // they want to.
    final json = jsonEncode(<String, Object?>{
      'event_id': event.eventId,
      'data': event.data,
    });
    return WirePayload(
      bytes: Uint8List.fromList(utf8.encode(json)),
      contentType: 'application/json',
      transformVersion: 'fake-v1',
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
