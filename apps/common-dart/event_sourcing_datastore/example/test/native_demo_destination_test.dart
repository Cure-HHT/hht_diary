import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_knobs.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter_test/flutter_test.dart';

WirePayload _payload() => WirePayload(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  contentType: BatchEnvelope.wireFormat,
  transformVersion: null,
);

class _SpyBridge implements DownstreamBridge {
  _SpyBridge(this._result);
  final SendResult _result;
  int callCount = 0;

  @override
  Future<SendResult> deliver(WirePayload payload) async {
    callCount++;
    return _result;
  }
}

void main() {
  group('NativeDemoDestination.send with optional bridge', () {
    test('connection=ok, bridge=null → SendOk (regression)', () async {
      final d = NativeDemoDestination();
      final result = await d.send(_payload());
      expect(result, isA<SendOk>());
    });

    test('connection=ok, bridge returns SendOk → SendOk', () async {
      final spy = _SpyBridge(const SendOk());
      final d = NativeDemoDestination(bridge: spy);
      final result = await d.send(_payload());
      expect(result, isA<SendOk>());
      expect(spy.callCount, 1);
    });

    test(
      'connection=ok, bridge returns SendPermanent → SendPermanent',
      () async {
        final spy = _SpyBridge(const SendPermanent(error: 'decode bad'));
        final d = NativeDemoDestination(bridge: spy);
        final result = await d.send(_payload());
        expect(result, isA<SendPermanent>());
        expect((result as SendPermanent).error, 'decode bad');
        expect(spy.callCount, 1);
      },
    );

    test(
      'connection=broken, bridge wired → SendTransient, bridge not called',
      () async {
        final spy = _SpyBridge(const SendOk());
        final d = NativeDemoDestination(
          bridge: spy,
          initialConnection: Connection.broken,
        );
        final result = await d.send(_payload());
        expect(result, isA<SendTransient>());
        expect(spy.callCount, 0);
      },
    );

    test(
      'connection=rejecting, bridge wired → SendPermanent, bridge not called',
      () async {
        final spy = _SpyBridge(const SendOk());
        final d = NativeDemoDestination(
          bridge: spy,
          initialConnection: Connection.rejecting,
        );
        final result = await d.send(_payload());
        expect(result, isA<SendPermanent>());
        expect(spy.callCount, 0);
      },
    );

    test('sendLatency is awaited before bridge is called', () async {
      final spy = _SpyBridge(const SendOk());
      final d = NativeDemoDestination(
        bridge: spy,
        initialSendLatency: const Duration(milliseconds: 40),
      );
      final stopwatch = Stopwatch()..start();
      await d.send(_payload());
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(30));
      expect(spy.callCount, 1);
    });
  });
}
