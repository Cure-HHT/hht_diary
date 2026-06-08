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

    test(
      'reader throws — schema treated as stale and alert sent once',
      () async {
        // Verifies: DIARY-DEV-schema-version-check/A+B+C
        // DB unreachable / schema_migrations missing at bootstrap.
        // The server must NOT crash; it must set the stale flag and fire the
        // alert exactly once so on-call is notified.
        var alertCount = 0;
        String? capturedMessage;

        await checkSchemaVersion(
          expectedMinVersion: 10,
          readDbVersion: () async =>
              throw Exception('connection refused (test)'),
          sendAlert: (msg) async {
            alertCount++;
            capturedMessage = msg;
          },
        );

        expect(
          isSchemaStale,
          isTrue,
          reason: 'stale flag must be set on error',
        );
        expect(foundDbVersion, equals(-1), reason: 'sentinel -1 on error');
        expect(alertCount, equals(1), reason: 'alert must fire exactly once');
        expect(
          capturedMessage,
          contains('FAILED'),
          reason: 'alert message should indicate failure',
        );
      },
    );

    test('reader throws twice — alert still sent only once', () async {
      // Verifies: DIARY-DEV-schema-version-check/A+B+C
      var alertCount = 0;

      Future<void> call() => checkSchemaVersion(
        expectedMinVersion: 10,
        readDbVersion: () async => throw Exception('connection refused (test)'),
        sendAlert: (_) async => alertCount++,
      );

      await call();
      await call(); // second call must not re-fire the alert

      expect(alertCount, equals(1));
      expect(isSchemaStale, isTrue);
    });
  });

  group('setSchemaStaleForTesting', () {
    test('forces stale flag for middleware testing', () {
      expect(isSchemaStale, isFalse);
      setSchemaStaleForTesting(stale: true);
      expect(isSchemaStale, isTrue);
    });
  });

  group('schemaAlertPrefix', () {
    // Verifies: DIARY-DEV-schema-version-check/D
    test('includes sponsor/env and deploy identity when all vars present', () {
      final prefix = schemaAlertPrefix({
        'SPONSOR_ID': 'callisto',
        'ENVIRONMENT': 'dev',
        'PORTAL_DEPLOY_SEQ': '418',
        'PORTAL_DEPLOY_SHA': 'a1b2c3d',
      });
      expect(
        prefix,
        equals('[portal-server | callisto/DEV | deploy #418 (a1b2c3d)]'),
      );
    });

    test('falls back to bare tag when no identity vars are set', () {
      expect(schemaAlertPrefix(const {}), equals('[portal-server]'));
    });

    test('omits sponsor segment when SPONSOR_ID is unset', () {
      final prefix = schemaAlertPrefix({
        'ENVIRONMENT': 'qa',
        'PORTAL_DEPLOY_SEQ': '12',
        'PORTAL_DEPLOY_SHA': 'deadbee',
      });
      expect(prefix, equals('[portal-server | QA | deploy #12 (deadbee)]'));
    });

    test('omits sha parens when PORTAL_DEPLOY_SHA is unset', () {
      final prefix = schemaAlertPrefix({
        'SPONSOR_ID': 'callisto',
        'ENVIRONMENT': 'uat',
        'PORTAL_DEPLOY_SEQ': '7',
      });
      expect(prefix, equals('[portal-server | callisto/UAT | deploy #7]'));
    });

    test('blank vars are treated as unset', () {
      final prefix = schemaAlertPrefix({
        'SPONSOR_ID': '  ',
        'ENVIRONMENT': '',
        'PORTAL_DEPLOY_SEQ': '',
        'PORTAL_DEPLOY_SHA': '',
      });
      expect(prefix, equals('[portal-server]'));
    });
  });
}
