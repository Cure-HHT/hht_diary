// Auth-mode bootstrap: resolve the login UI mode from the server's identity
// config and, in an emulator deployment, wire Firebase + the auth emulator
// reliably BEFORE the login surface is presented.
//
// Why the pre-init wipe exists (flutterfire #9528): on web, the Firebase JS SDK
// auto-restores any persisted user from IndexedDB (`firebaseLocalStorageDb`)
// during `Firebase.initializeApp`. That restore "uses" the Auth instance before
// `useAuthEmulator` can run (it requires the initialized app), so the later
// `connectAuthEmulator` is silently rejected (`auth/emulator-config-failed`,
// swallowed by firebase_auth_web). The Dart `useAuthEmulator` returns success
// while the JS binding never applied, and every sign-in then hits PRODUCTION and
// fails with `api-key-not-valid` — the flaky local-stack login (intermittent
// because the restore races the bind; "reload/clear-site-data recovers").
//
// The fix is to delete `firebaseLocalStorageDb` BEFORE `initializeApp` on
// emulator deployments: with no stored user there is nothing to restore, the
// instance is never used early, and the emulator connect binds cleanly every
// load. Production deployments (no emulator host) are never wiped — that would
// log every user out on each load — so a real restored session is left intact
// and the server's 401 path remains the staleness gate.
//
// Implements: DIARY-DEV-portal-emulator-bootstrap/A+B+C

import 'login_logic.dart';

/// The resolved bootstrap outcome the app shell renders from.
enum AuthBootstrapOutcome {
  /// No config, or `authMode != session` — render the dev ConnectScreen.
  dev,

  /// Session mode and Firebase (+ emulator, if reported) is wired — render
  /// the Firebase login surface.
  sessionReady,

  /// Session mode but Firebase/emulator init failed — render an explicit error
  /// (do NOT fall back to a prod-pointed login).
  failed,
}

/// The result of resolving the auth bootstrap: the render [outcome] plus, when
/// a persisted production *Session* was successfully rehydrated on reload, the
/// freshly-minted session token (and optional display name) to hand straight to
/// the app so it lands back on the dashboard instead of the login screen.
// Implements: DIARY-DEV-portal-emulator-bootstrap/B
class AuthBootstrapResult {
  const AuthBootstrapResult(
    this.outcome, {
    this.restoredSessionToken,
    this.restoredDisplayName,
  });

  final AuthBootstrapOutcome outcome;

  /// The portal session token re-derived from the persisted Firebase *User* on
  /// a hard reload, or null when there was nothing to restore, the server
  /// rejected the exchange, or an OTP challenge was returned (fall through to
  /// the normal login screen in those cases).
  final String? restoredSessionToken;

  /// The restored user's display name from the login response, threaded onto
  /// the session callback for welcome-by-name. Null when none was supplied.
  final String? restoredDisplayName;
}

typedef IdentityConfigFetcher = Future<Map<String, Object?>?> Function();

/// Reads a fresh Identity Platform ID token for the *User* the SDK auto-restored
/// from persistence on load, or null when no *User* is persisted. Injected so
/// the restore sequencing is unit-testable without Firebase.
typedef PersistedIdTokenReader = Future<String?> Function();

/// Exchanges a persisted ID token at `POST /login` for a portal session,
/// returning the decoded login response body, or null when the exchange failed
/// (non-200 / transport error). Injected so the exchange is unit-testable
/// without a server. The decoded body is interpreted with [loginNextStep].
typedef SessionExchanger = Future<Map<String, Object?>?> Function(String idToken);

/// Initializes Firebase from the config and, when the deployment reports an
/// emulator host, connects the auth emulator. Returns whether an emulator was
/// wired (informational); THROWS on failure so the caller surfaces an explicit
/// error rather than a prod-pointed login.
typedef FirebaseInitializer = Future<bool> Function(Map<String, Object?> cfg);

/// Deletes the Firebase Auth persistence DB (`firebaseLocalStorageDb`). Injected
/// so the ordering logic is unit-testable without `package:web`; the real impl
/// lives on the `WebPlatform` web seam (a no-op off web / on the test VM).
typedef AuthDbCleaner = Future<void> Function();

/// Resolves the auth bootstrap outcome.
///
/// In an emulator deployment the persisted Firebase Auth IndexedDB is wiped via
/// [clearAuthDb] BEFORE [initFirebase] runs, so the SDK has no user to
/// auto-restore and `useAuthEmulator` binds cleanly (flutterfire #9528). A
/// production deployment (no `emulatorHost`) is never wiped — instead the
/// persisted *User* the SDK auto-restores is rehydrated into a portal session:
/// [readPersistedIdToken] yields its fresh ID token and [exchangeSession]
/// re-mints the portal session token at `POST /login` (the same exchange the
/// login screen runs), so a hard page reload lands back on the dashboard rather
/// than the login screen. All I/O is injected so the sequencing is
/// unit-testable without Firebase, a server, or a browser.
///
/// The restore is best-effort and PRODUCTION-ONLY (never attempted when an
/// emulator host is reported, mirroring the wipe guard): if there is no
/// persisted user, the server rejects the exchange, or the server returns an
/// OTP challenge rather than a direct session, [AuthBootstrapResult] carries no
/// token and the app falls through to the normal login screen.
// Implements: DIARY-DEV-portal-emulator-bootstrap/B
Future<AuthBootstrapResult> resolveAuthBootstrap({
  required IdentityConfigFetcher fetchConfig,
  required FirebaseInitializer initFirebase,
  required AuthDbCleaner clearAuthDb,
  PersistedIdTokenReader? readPersistedIdToken,
  SessionExchanger? exchangeSession,
}) async {
  final cfg = await fetchConfig();
  if (cfg == null || cfg['authMode'] != 'session') {
    return const AuthBootstrapResult(AuthBootstrapOutcome.dev);
  }
  final emulatorHost = (cfg['emulatorHost'] as String?) ?? '';
  try {
    // #9528: the wipe MUST precede initializeApp (inside initFirebase). Only on
    // emulator deployments — never wipe a production session.
    if (emulatorHost.isNotEmpty) await clearAuthDb();
    await initFirebase(cfg);
  } catch (_) {
    return const AuthBootstrapResult(AuthBootstrapOutcome.failed);
  }
  // Production session restore (never on emulator — there the DB was wiped, so
  // there is nothing to restore). Rehydrate the persisted Firebase user into a
  // fresh portal session token before the login surface is ever shown.
  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  if (emulatorHost.isEmpty &&
      readPersistedIdToken != null &&
      exchangeSession != null) {
    final restored = await _restoreSession(
      readPersistedIdToken: readPersistedIdToken,
      exchangeSession: exchangeSession,
    );
    if (restored != null) return restored;
  }
  return const AuthBootstrapResult(AuthBootstrapOutcome.sessionReady);
}

/// Attempts the production session rehydration; returns a sessionReady result
/// carrying the restored token on success, or null to fall through to the
/// normal login screen (no persisted user, rejected exchange, transport
/// failure, or an OTP challenge instead of a direct session). Best-effort: any
/// error resolves to null rather than blocking the login surface.
// Implements: DIARY-DEV-portal-emulator-bootstrap/B
Future<AuthBootstrapResult?> _restoreSession({
  required PersistedIdTokenReader readPersistedIdToken,
  required SessionExchanger exchangeSession,
}) async {
  try {
    final idToken = await readPersistedIdToken();
    if (idToken == null) return null; // logged out — nothing persisted.
    final body = await exchangeSession(idToken);
    if (body == null) return null; // server rejected / transport failed.
    // A still-valid post-2FA persisted session returns a direct session token;
    // an OTP challenge means we must NOT force re-login loudly — fall through.
    switch (loginNextStep(body)) {
      case LoginNextSession(:final token, :final displayName):
        return AuthBootstrapResult(
          AuthBootstrapOutcome.sessionReady,
          restoredSessionToken: token,
          restoredDisplayName: displayName,
        );
      case LoginNextOtp():
        return null;
    }
  } catch (_) {
    return null;
  }
}
