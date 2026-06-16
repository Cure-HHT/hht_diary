// Verifies: DIARY-DEV-portal-emulator-bootstrap/A+B+C — the auth-mode bootstrap
// resolves the login UI from /config/identity and, in an emulator deployment,
// WIPES the Firebase Auth IndexedDB (firebaseLocalStorageDb) BEFORE initializing
// Firebase. That pre-init wipe is the fix for flutterfire #9528: with no stored
// user to auto-restore, the SDK never "uses" the Auth instance before
// useAuthEmulator binds, so the emulator connect applies cleanly and auth never
// silently falls through to production. Production deployments (no emulator host)
// must NOT be wiped — that would log every user out on each load.
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/auth_bootstrap.dart';

void main() {
  test('null config -> dev (no init, no wipe)', () async {
    var initCalls = 0;
    var wipeCalls = 0;
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => null,
      initFirebase: (_) async {
        initCalls++;
        return false;
      },
      clearAuthDb: () async => wipeCalls++,
    );
    expect(outcome, AuthBootstrapOutcome.dev);
    expect(initCalls, 0);
    expect(wipeCalls, 0);
  });

  test('authMode != session -> dev (no firebase init, no wipe)', () async {
    var initCalls = 0;
    var wipeCalls = 0;
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{'authMode': 'dev'},
      initFirebase: (_) async {
        initCalls++;
        return false;
      },
      clearAuthDb: () async => wipeCalls++,
    );
    expect(outcome, AuthBootstrapOutcome.dev);
    expect(initCalls, 0);
    expect(wipeCalls, 0);
  });

  test(
    'production session (no emulator host) -> sessionReady, NEVER wipes',
    () async {
      var wipeCalls = 0;
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async => false,
        clearAuthDb: () async => wipeCalls++,
      );
      expect(outcome, AuthBootstrapOutcome.sessionReady);
      expect(
        wipeCalls,
        0,
        reason: 'wiping prod firebaseLocalStorageDb would log users out',
      );
    },
  );

  test(
    'emulator session -> wipes Auth IndexedDB BEFORE init, then sessionReady',
    () async {
      final order = <String>[];
      final outcome = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{
          'authMode': 'session',
          'emulatorHost': 'localhost:9099',
        },
        initFirebase: (_) async {
          order.add('init');
          return true;
        },
        clearAuthDb: () async => order.add('wipe'),
      );
      expect(outcome, AuthBootstrapOutcome.sessionReady);
      expect(
        order,
        <String>['wipe', 'init'],
        reason:
            'the pre-init wipe must happen before Firebase.initializeApp '
            '(flutterfire #9528) — otherwise the IndexedDB restore uses the '
            'Auth instance and useAuthEmulator is silently dropped',
      );
    },
  );

  test('init throws -> failed', () async {
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{
        'authMode': 'session',
        'emulatorHost': 'localhost:9099',
      },
      initFirebase: (_) async => throw StateError('init blew up'),
      clearAuthDb: () async {},
    );
    expect(outcome, AuthBootstrapOutcome.failed);
  });
}
