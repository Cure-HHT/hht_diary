// Verifies: DIARY-DEV-portal-second-factor-toggle/C — the auth-mode bootstrap
// gates a session-mode login on the emulator being GENUINELY reachable: it
// polls a connectivity probe after init (because useAuthEmulator returns before
// the connect lands) and only reaches the login once an auth call hits the
// emulator — never in the gap where a submit would hit production.
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/auth_bootstrap.dart';

void main() {
  Future<void> noSleep(Duration _) async {}
  Future<void> ok() async {}
  Future<void> never() async => throw StateError('not reachable');

  test('null config -> dev', () async {
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => null,
      initFirebase: (_) async => false,
      verifyConnected: ok,
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.dev);
  });

  test('authMode != session -> dev (no firebase init)', () async {
    var initCalls = 0;
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{'authMode': 'dev'},
      initFirebase: (_) async {
        initCalls++;
        return false;
      },
      verifyConnected: ok,
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.dev);
    expect(initCalls, 0);
  });

  test(
    'production session (no emulator) -> sessionReady WITHOUT probing',
    () async {
      var probeCalls = 0;
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async => false, // no emulator wired
        verifyConnected: () async {
          probeCalls++;
        },
        sleep: noSleep,
      );
      expect(outcome, AuthBootstrapOutcome.sessionReady);
      expect(
        probeCalls,
        0,
        reason: 'production must not probe a (missing) emulator',
      );
    },
  );

  test('emulator reachable on first probe -> sessionReady', () async {
    var probeCalls = 0;
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{
        'authMode': 'session',
        'emulatorHost': 'localhost:9099',
      },
      initFirebase: (_) async => true,
      verifyConnected: () async {
        probeCalls++;
      },
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.sessionReady);
    expect(probeCalls, 1);
  });

  test(
    'emulator connect lands late: probe throws then succeeds -> sessionReady',
    () async {
      var probeCalls = 0;
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{
          'authMode': 'session',
          'emulatorHost': 'localhost:9099',
        },
        initFirebase: (_) async => true,
        verifyConnected: () async {
          probeCalls++;
          if (probeCalls < 4) throw StateError('connect not applied yet');
        },
        maxAttempts: 15,
        sleep: noSleep,
      );
      expect(outcome, AuthBootstrapOutcome.sessionReady);
      expect(
        probeCalls,
        4,
        reason: 'polls until an auth call reaches the emulator',
      );
    },
  );

  test(
    'emulator never reachable -> failed (NOT a prod-pointed login)',
    () async {
      var probeCalls = 0;
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{
          'authMode': 'session',
          'emulatorHost': 'localhost:9099',
        },
        initFirebase: (_) async => true,
        verifyConnected: () async {
          probeCalls++;
          await never();
        },
        maxAttempts: 5,
        sleep: noSleep,
      );
      expect(outcome, AuthBootstrapOutcome.failed);
      expect(probeCalls, 5, reason: 'exhausts the probe budget before failing');
    },
  );

  test('init throws -> failed', () async {
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{'authMode': 'session'},
      initFirebase: (_) async => throw StateError('init blew up'),
      verifyConnected: ok,
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.failed);
  });
}
