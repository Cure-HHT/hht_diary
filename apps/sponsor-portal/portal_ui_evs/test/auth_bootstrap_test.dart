// Verifies: DIARY-DEV-portal-second-factor-toggle/C — the auth-mode bootstrap
// gates readiness on a successful Firebase/emulator init: a session-mode login
// surface is only reached once init succeeds (retried), never against a
// silently-failed emulator connect.
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/auth_bootstrap.dart';

void main() {
  // No real delays in tests: the injected sleep is a no-op.
  Future<void> noSleep(Duration _) async {}

  test('null config -> dev', () async {
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => null,
      initFirebase: (_) async => false,
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.dev);
  });

  test('authMode != session -> dev (no firebase init attempted)', () async {
    var initCalls = 0;
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{'authMode': 'dev'},
      initFirebase: (_) async {
        initCalls++;
        return false;
      },
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.dev);
    expect(initCalls, 0, reason: 'dev mode never touches Firebase');
  });

  test('session + init succeeds first try -> sessionReady', () async {
    var initCalls = 0;
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{
        'authMode': 'session',
        'emulatorHost': 'localhost:9099',
      },
      initFirebase: (_) async {
        initCalls++;
        return true;
      },
      sleep: noSleep,
    );
    expect(outcome, AuthBootstrapOutcome.sessionReady);
    expect(initCalls, 1);
  });

  test(
    'session + init fails twice then succeeds -> sessionReady (retried)',
    () async {
      var initCalls = 0;
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async {
          initCalls++;
          if (initCalls < 3) throw StateError('useAuthEmulator transient');
          return true;
        },
        maxAttempts: 3,
        sleep: noSleep,
      );
      expect(outcome, AuthBootstrapOutcome.sessionReady);
      expect(initCalls, 3);
    },
  );

  test(
    'session + init always fails -> failed (NOT a prod-pointed login)',
    () async {
      var initCalls = 0;
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async {
          initCalls++;
          throw StateError('useAuthEmulator down');
        },
        maxAttempts: 3,
        sleep: noSleep,
      );
      expect(outcome, AuthBootstrapOutcome.failed);
      expect(initCalls, 3, reason: 'exhausts the retry budget before failing');
    },
  );
}
