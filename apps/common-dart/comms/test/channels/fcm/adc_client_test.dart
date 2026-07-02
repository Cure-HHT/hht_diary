import 'package:comms/comms.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// Verifies: DIARY-DEV-pluggable-push-transport/A — token rotation keeps the dispatcher authenticated
void main() {
  group('AdcClient', () {
    test('caches the client across calls within the lifetime', () async {
      var factoryCallCount = 0;
      final adc = AdcClient(
        authFactory: () async {
          factoryCallCount++;
          return MockClient((_) async => http.Response('', 200));
        },
        clock: () => DateTime.utc(2026, 5, 8, 10, 0),
      );

      final first = await adc.getClient();
      final second = await adc.getClient();

      expect(factoryCallCount, equals(1));
      expect(identical(first, second), isTrue);
    });

    test(
      'rotates the client when the token enters the refresh window',
      () async {
        var factoryCallCount = 0;
        var now = DateTime.utc(2026, 5, 8, 10, 0);
        final adc = AdcClient(
          authFactory: () async {
            factoryCallCount++;
            return MockClient((_) async => http.Response('', 200));
          },
          clock: () => now,
        );

        await adc.getClient();
        // 56 minutes in — still inside lifetime, refresh buffer is 5 min
        // so we have not crossed the rotation threshold (1h - 5min = 55m).
        now = now.add(const Duration(minutes: 54));
        await adc.getClient();
        expect(factoryCallCount, equals(1), reason: 'within lifetime');

        // Cross the 55-minute threshold — must rotate.
        now = now.add(const Duration(minutes: 2));
        await adc.getClient();
        expect(factoryCallCount, equals(2), reason: 'past refresh buffer');
      },
    );

    test('dispose resets cache so the next getClient creates fresh', () async {
      var factoryCallCount = 0;
      final adc = AdcClient(
        authFactory: () async {
          factoryCallCount++;
          return MockClient((_) async => http.Response('', 200));
        },
        clock: () => DateTime.utc(2026, 5, 8, 10, 0),
      );

      await adc.getClient();
      adc.dispose();
      await adc.getClient();

      expect(factoryCallCount, equals(2));
    });
  });
}
