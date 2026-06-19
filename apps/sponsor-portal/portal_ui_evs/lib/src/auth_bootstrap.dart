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

typedef IdentityConfigFetcher = Future<Map<String, Object?>?> Function();

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
/// production deployment (no `emulatorHost`) is never wiped. All I/O is injected
/// so the sequencing is unit-testable without Firebase, a server, or a browser.
Future<AuthBootstrapOutcome> resolveAuthBootstrap({
  required IdentityConfigFetcher fetchConfig,
  required FirebaseInitializer initFirebase,
  required AuthDbCleaner clearAuthDb,
}) async {
  final cfg = await fetchConfig();
  if (cfg == null || cfg['authMode'] != 'session') {
    return AuthBootstrapOutcome.dev;
  }
  final emulatorHost = (cfg['emulatorHost'] as String?) ?? '';
  try {
    // #9528: the wipe MUST precede initializeApp (inside initFirebase). Only on
    // emulator deployments — never wipe a production session.
    if (emulatorHost.isNotEmpty) await clearAuthDb();
    await initFirebase(cfg);
  } catch (_) {
    return AuthBootstrapOutcome.failed;
  }
  return AuthBootstrapOutcome.sessionReady;
}
