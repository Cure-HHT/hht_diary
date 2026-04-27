import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/send_result.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal concrete Destination used only to verify the abstract surface
/// type-checks and dispatches correctly. The production destination
/// (`PrimaryDiaryServerDestination`) is Phase-5 work.
class _EchoDestination extends Destination {
  _EchoDestination({required this.result});

  final SendResult result;
  final List<WirePayload> sent = [];

  @override
  String get id => 'echo';

  @override
  SubscriptionFilter get filter => const SubscriptionFilter();

  @override
  String get wireFormat => 'echo-v1';

  // Implements: REQ-d00128-F — maxAccumulateTime declared by subclass.
  @override
  Duration get maxAccumulateTime => Duration.zero;

  // Implements: REQ-d00128-E — destination-owned batching rule. Echo
  // fixture admits at most one event per batch so the REQ-d00128-E test
  // can assert the false-at-capacity branch.
  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.isEmpty;

  // Implements: REQ-d00128-D / REQ-d00122-D — batch transform.
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    if (batch.isEmpty) {
      throw ArgumentError('_EchoDestination.transform called with empty batch');
    }
    final joined = batch.map((e) => e.eventId).join(',');
    return WirePayload(
      bytes: Uint8List.fromList(joined.codeUnits),
      contentType: 'text/plain',
      transformVersion: 'echo-v1',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    sent.add(payload);
    return result;
  }
}

/// Destination that relies on the abstract-class default for
/// `allowHardDelete`. Used to verify REQ-d00129-B's default-false contract
/// without the subclass overriding the getter.
class _DefaultDestination extends Destination {
  _DefaultDestination();

  @override
  String get id => 'defaults';

  @override
  SubscriptionFilter get filter => const SubscriptionFilter();

  @override
  String get wireFormat => 'defaults-v1';

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      false;

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    if (batch.isEmpty) {
      throw ArgumentError(
        '_DefaultDestination.transform called with empty batch',
      );
    }
    return WirePayload(
      bytes: Uint8List.fromList(const <int>[]),
      contentType: 'application/octet-stream',
      transformVersion: 'defaults-v1',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async => const SendOk();
}

StoredEvent _mkEvent(String eventId) => StoredEvent(
  key: 1,
  eventId: eventId,
  aggregateId: 'agg-1',
  aggregateType: 'DiaryEntry',
  entryType: 'epistaxis_event',
  entryTypeVersion: 1,
  libFormatVersion: 1,
  eventType: 'finalized',
  sequenceNumber: 1,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  initiator: const UserInitiator('u1'),
  clientTimestamp: DateTime.utc(2026, 4, 22),
  eventHash: 'hash',
);

void main() {
  group('Destination abstract contract', () {
    // Verifies: REQ-d00122-A+C — id is stable, wireFormat is declared.
    test('REQ-d00122-A+C: id and wireFormat are declared by the subclass', () {
      final dest = _EchoDestination(result: const SendOk());
      expect(dest.id, 'echo');
      expect(dest.wireFormat, 'echo-v1');
    });

    // Verifies: REQ-d00122-D — transform produces a WirePayload whose
    // fields come straight from the subclass implementation. The batch
    // shape means a single-event batch is a batch of length one.
    test(
      'REQ-d00122-D: transform returns subclass-produced WirePayload',
      () async {
        final dest = _EchoDestination(result: const SendOk());
        final payload = await dest.transform([_mkEvent('ev-abc')]);
        expect(payload.bytes, 'ev-abc'.codeUnits);
        expect(payload.contentType, 'text/plain');
        expect(payload.transformVersion, 'echo-v1');
      },
    );

    // Verifies: REQ-d00122-E — send returns the subclass-scripted SendResult.
    test('REQ-d00122-E: send returns SendOk when scripted', () async {
      final dest = _EchoDestination(result: const SendOk());
      final payload = await dest.transform([_mkEvent('ev-1')]);
      final result = await dest.send(payload);
      expect(result, const SendOk());
      expect(dest.sent, hasLength(1));
      expect(dest.sent.single.bytes, 'ev-1'.codeUnits);
    });

    test('REQ-d00122-E: send returns SendTransient when scripted', () async {
      final dest = _EchoDestination(
        result: const SendTransient(error: 'HTTP 503', httpStatus: 503),
      );
      final result = await dest.send(await dest.transform([_mkEvent('ev-2')]));
      expect(result, isA<SendTransient>());
      expect((result as SendTransient).httpStatus, 503);
    });

    test('REQ-d00122-E: send returns SendPermanent when scripted', () async {
      final dest = _EchoDestination(
        result: const SendPermanent(error: 'HTTP 400'),
      );
      final result = await dest.send(await dest.transform([_mkEvent('ev-3')]));
      expect(result, isA<SendPermanent>());
      expect((result as SendPermanent).error, 'HTTP 400');
    });

    // Verifies: REQ-d00122-B — filter is exposed and dispatches to the
    // subclass's SubscriptionFilter. (Real filtering semantics land in
    // Task 4.)
    test('REQ-d00122-B: filter dispatches to the subclass implementation', () {
      final dest = _EchoDestination(result: const SendOk());
      expect(dest.filter.matches(_mkEvent('ev-1')), isTrue);
    });

    // Verifies: REQ-d00128-D — transform takes a batch and produces one
    // WirePayload covering every event in the batch.
    test('REQ-d00128-D: Destination.transform(List<Event>) produces one '
        'WirePayload covering the whole batch', () async {
      final dest = _EchoDestination(result: const SendOk());
      final payload = await dest.transform([
        _mkEvent('ev-1'),
        _mkEvent('ev-2'),
        _mkEvent('ev-3'),
      ]);
      expect(payload.bytes, 'ev-1,ev-2,ev-3'.codeUnits);
      expect(payload.contentType, 'text/plain');
      expect(payload.transformVersion, 'echo-v1');
    });

    // Verifies: REQ-d00128-D — transform SHALL NOT be called with an
    // empty batch; the subclass guards against it with ArgumentError.
    test('REQ-d00128-D: Destination.transform rejects empty batch with '
        'ArgumentError', () async {
      final dest = _EchoDestination(result: const SendOk());
      await expectLater(dest.transform(<StoredEvent>[]), throwsArgumentError);
    });

    // Verifies: REQ-d00128-E — canAddToBatch returning false ends the
    // current batch.
    test('REQ-d00128-E: canAddToBatch returns true when batch is empty and '
        'false once capacity is reached', () {
      final dest = _EchoDestination(result: const SendOk());
      // Capacity of this echo fixture is 1 — an empty batch accepts
      // the first candidate; a one-element batch refuses the next.
      expect(dest.canAddToBatch(<StoredEvent>[], _mkEvent('ev-1')), isTrue);
      expect(dest.canAddToBatch([_mkEvent('ev-1')], _mkEvent('ev-2')), isFalse);
    });

    // Verifies: REQ-d00128-F — maxAccumulateTime is declared on the
    // destination surface and defaults to Duration.zero for this fixture.
    test('REQ-d00128-F: Destination.maxAccumulateTime is declared on the '
        'destination surface', () {
      final dest = _EchoDestination(result: const SendOk());
      expect(dest.maxAccumulateTime, Duration.zero);
    });

    // Verifies: REQ-d00129-B — allowHardDelete defaults to false in the
    // abstract contract so concrete destinations opt in explicitly.
    test('REQ-d00129-B: Destination.allowHardDelete defaults to false in the '
        'abstract contract', () {
      final dest = _DefaultDestination();
      expect(dest.allowHardDelete, isFalse);
    });
  });
}
