// Verifies: DIARY-DEV-schema-version-check/A+B+C
//
// Unit tests for checkSchemaVersion — no DB or network required.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-functions-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );
  });

  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  setUp(resetDbVersionCheckState);
  tearDown(resetDbVersionCheckState);

  group('checkSchemaVersion', () {
    test('not stale when found == expected', () async {
      var alertCount = 0;
      await checkSchemaVersion(
        expectedMinVersion: 42,
        readDbVersion: () async => 42,
        sendAlert: (_) async => alertCount++,
      );

      expect(isSchemaStale, isFalse);
      expect(foundDbVersion, equals(42));
      expect(alertCount, equals(0));
    });

    test('not stale when found > expected', () async {
      var alertCount = 0;
      await checkSchemaVersion(
        expectedMinVersion: 10,
        readDbVersion: () async => 99,
        sendAlert: (_) async => alertCount++,
      );

      expect(isSchemaStale, isFalse);
      expect(alertCount, equals(0));
    });

    test('stale when found < expected', () async {
      var alertCount = 0;
      await checkSchemaVersion(
        expectedMinVersion: 50,
        readDbVersion: () async => 30,
        sendAlert: (_) async => alertCount++,
      );

      expect(isSchemaStale, isTrue);
      expect(foundDbVersion, equals(30));
      expect(expectedMinDbVersion, equals(50));
      expect(alertCount, equals(1));
    });

    test(
      'alert is sent exactly once even if called twice with stale schema',
      () async {
        var alertCount = 0;
        Future<void> fakeAlert(String _) async => alertCount++;

        await checkSchemaVersion(
          expectedMinVersion: 50,
          readDbVersion: () async => 1,
          sendAlert: fakeAlert,
        );
        // Call again (e.g. a retry path) — alert must NOT fire again.
        await checkSchemaVersion(
          expectedMinVersion: 50,
          readDbVersion: () async => 1,
          sendAlert: fakeAlert,
        );

        expect(alertCount, equals(1));
      },
    );

    test('alert message includes expected and found versions', () async {
      String? capturedMessage;
      await checkSchemaVersion(
        expectedMinVersion: 77,
        readDbVersion: () async => 5,
        sendAlert: (msg) async => capturedMessage = msg,
      );

      expect(capturedMessage, isNotNull);
      expect(capturedMessage, contains('77'));
      expect(capturedMessage, contains('5'));
    });

    test('not stale with default expected (0) and found 0', () async {
      var alertCount = 0;
      await checkSchemaVersion(
        expectedMinVersion: 0,
        readDbVersion: () async => 0,
        sendAlert: (_) async => alertCount++,
      );

      expect(isSchemaStale, isFalse);
      expect(alertCount, equals(0));
    });
  });

  group('setSchemaStaleForTesting', () {
    test('forces stale flag for middleware testing', () {
      expect(isSchemaStale, isFalse);
      setSchemaStaleForTesting(stale: true);
      expect(isSchemaStale, isTrue);
    });
  });
}
