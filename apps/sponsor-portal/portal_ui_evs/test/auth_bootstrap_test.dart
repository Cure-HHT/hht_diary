// Verifies: DIARY-DEV-portal-emulator-bootstrap/A+B+C — the auth-mode bootstrap
// resolves the login UI from /config/identity and, in an emulator deployment,
// WIPES the Firebase Auth IndexedDB (firebaseLocalStorageDb) BEFORE initializing
// Firebase. That pre-init wipe is the fix for flutterfire #9528: with no stored
// user to auto-restore, the SDK never "uses" the Auth instance before
// useAuthEmulator binds, so the emulator connect applies cleanly and auth never
// silently falls through to production. Production deployments (no emulator host)
// must NOT be wiped — that would log every user out on each load.
//
// Verifies: DIARY-DEV-portal-emulator-bootstrap/B — on a production deployment
// the persisted Firebase User is rehydrated into a portal session: the restored
// ID token is exchanged at POST /login and the resulting session token is
// surfaced on the bootstrap result so a hard reload lands on the dashboard. No
// persisted user, a rejected exchange, or an OTP challenge falls through to the
// login screen; the emulator wipe path attempts no restore.
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/auth_bootstrap.dart';

void main() {
  test('null config -> dev (no init, no wipe)', () async {
    var initCalls = 0;
    var wipeCalls = 0;
    final result = await resolveAuthBootstrap(
      fetchConfig: () async => null,
      initFirebase: (_) async {
        initCalls++;
        return false;
      },
      clearAuthDb: () async => wipeCalls++,
    );
    expect(result.outcome, AuthBootstrapOutcome.dev);
    expect(initCalls, 0);
    expect(wipeCalls, 0);
  });

  test('authMode != session -> dev (no firebase init, no wipe)', () async {
    var initCalls = 0;
    var wipeCalls = 0;
    final result = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{'authMode': 'dev'},
      initFirebase: (_) async {
        initCalls++;
        return false;
      },
      clearAuthDb: () async => wipeCalls++,
    );
    expect(result.outcome, AuthBootstrapOutcome.dev);
    expect(initCalls, 0);
    expect(wipeCalls, 0);
  });

  test(
    'production session (no emulator host) -> sessionReady, NEVER wipes',
    () async {
      var wipeCalls = 0;
      final result = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async => false,
        clearAuthDb: () async => wipeCalls++,
      );
      expect(result.outcome, AuthBootstrapOutcome.sessionReady);
      expect(result.restoredSessionToken, isNull);
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
      final result = await resolveAuthBootstrap(
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
      expect(result.outcome, AuthBootstrapOutcome.sessionReady);
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
    final result = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{
        'authMode': 'session',
        'emulatorHost': 'localhost:9099',
      },
      initFirebase: (_) async => throw StateError('init blew up'),
      clearAuthDb: () async {},
    );
    expect(result.outcome, AuthBootstrapOutcome.failed);
  });

  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  test(
    'production + persisted idToken + /login returns session -> restores '
    'session token',
    () async {
      var exchangedToken = '';
      final result = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async => false,
        clearAuthDb: () async {},
        readPersistedIdToken: () async => 'persisted-id-token',
        exchangeSession: (idToken) async {
          exchangedToken = idToken;
          return <String, Object?>{
            'sessionToken': 'restored-session-tok',
            'displayName': 'Ada Lovelace',
          };
        },
      );
      expect(result.outcome, AuthBootstrapOutcome.sessionReady);
      expect(exchangedToken, 'persisted-id-token');
      expect(result.restoredSessionToken, 'restored-session-tok');
      expect(result.restoredDisplayName, 'Ada Lovelace');
    },
  );

  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  test('production + no persisted user -> no restore, normal login', () async {
    var exchangeCalls = 0;
    final result = await resolveAuthBootstrap(
      fetchConfig: () async => <String, Object?>{'authMode': 'session'},
      initFirebase: (_) async => false,
      clearAuthDb: () async {},
      readPersistedIdToken: () async => null,
      exchangeSession: (_) async {
        exchangeCalls++;
        return <String, Object?>{'sessionToken': 'should-not-happen'};
      },
    );
    expect(result.outcome, AuthBootstrapOutcome.sessionReady);
    expect(result.restoredSessionToken, isNull);
    expect(exchangeCalls, 0, reason: 'no persisted user -> no /login exchange');
  });

  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  test(
    'production + /login returns OTP challenge -> no token, falls through to '
    'login',
    () async {
      final result = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async => false,
        clearAuthDb: () async {},
        readPersistedIdToken: () async => 'persisted-id-token',
        exchangeSession: (_) async =>
            <String, Object?>{'maskedEmail': 'a***@example.com'},
      );
      expect(result.outcome, AuthBootstrapOutcome.sessionReady);
      expect(
        result.restoredSessionToken,
        isNull,
        reason: 'an OTP challenge must not force a loud re-login; fall through',
      );
    },
  );

  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  test(
    'production + /login rejects the exchange -> no token, normal login',
    () async {
      final result = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{'authMode': 'session'},
        initFirebase: (_) async => false,
        clearAuthDb: () async {},
        readPersistedIdToken: () async => 'persisted-id-token',
        exchangeSession: (_) async => null, // non-200 / transport failure
      );
      expect(result.outcome, AuthBootstrapOutcome.sessionReady);
      expect(result.restoredSessionToken, isNull);
    },
  );

  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  test(
    'emulator session -> wipe path unchanged, no restore attempted',
    () async {
      var readCalls = 0;
      var exchangeCalls = 0;
      final result = await resolveAuthBootstrap(
        fetchConfig: () async => <String, Object?>{
          'authMode': 'session',
          'emulatorHost': 'localhost:9099',
        },
        initFirebase: (_) async => true,
        clearAuthDb: () async {},
        readPersistedIdToken: () async {
          readCalls++;
          return 'should-not-be-read';
        },
        exchangeSession: (_) async {
          exchangeCalls++;
          return <String, Object?>{'sessionToken': 'should-not-happen'};
        },
      );
      expect(result.outcome, AuthBootstrapOutcome.sessionReady);
      expect(result.restoredSessionToken, isNull);
      expect(
        readCalls,
        0,
        reason: 'emulator wipe path leaves nothing to restore',
      );
      expect(exchangeCalls, 0);
    },
  );
}
