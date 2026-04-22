import 'dart:typed_data';

import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/destinations/subscription_filter.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
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

  @override
  WirePayload transform(StoredEvent event) {
    final s = event.eventId.codeUnits;
    return WirePayload(
      bytes: Uint8List.fromList(s),
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

StoredEvent _mkEvent(String eventId) => StoredEvent(
  key: 1,
  eventId: eventId,
  aggregateId: 'agg-1',
  aggregateType: 'DiaryEntry',
  entryType: 'epistaxis_event',
  eventType: 'finalized',
  sequenceNumber: 1,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  userId: 'u1',
  deviceId: 'd1',
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
    // fields come straight from the subclass implementation.
    test('REQ-d00122-D: transform returns subclass-produced WirePayload', () {
      final dest = _EchoDestination(result: const SendOk());
      final payload = dest.transform(_mkEvent('ev-abc'));
      expect(payload.bytes, 'ev-abc'.codeUnits);
      expect(payload.contentType, 'text/plain');
      expect(payload.transformVersion, 'echo-v1');
    });

    // Verifies: REQ-d00122-E — send returns the subclass-scripted SendResult.
    test('REQ-d00122-E: send returns SendOk when scripted', () async {
      final dest = _EchoDestination(result: const SendOk());
      final payload = dest.transform(_mkEvent('ev-1'));
      final result = await dest.send(payload);
      expect(result, const SendOk());
      expect(dest.sent, hasLength(1));
      expect(dest.sent.single.bytes, 'ev-1'.codeUnits);
    });

    test('REQ-d00122-E: send returns SendTransient when scripted', () async {
      final dest = _EchoDestination(
        result: const SendTransient(error: 'HTTP 503', httpStatus: 503),
      );
      final result = await dest.send(dest.transform(_mkEvent('ev-2')));
      expect(result, isA<SendTransient>());
      expect((result as SendTransient).httpStatus, 503);
    });

    test('REQ-d00122-E: send returns SendPermanent when scripted', () async {
      final dest = _EchoDestination(
        result: const SendPermanent(error: 'HTTP 400'),
      );
      final result = await dest.send(dest.transform(_mkEvent('ev-3')));
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
  });
}
