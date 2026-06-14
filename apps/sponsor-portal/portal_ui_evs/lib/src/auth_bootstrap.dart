// Auth-mode bootstrap: resolve the login UI mode from the server's identity
// config and, in session mode, wire Firebase + the auth emulator BEFORE the
// login surface is presented.
//
// Why this exists: the login screen must never render against production
// Firebase when the deployment reports an emulator host. A silently-failed
// `useAuthEmulator` would leave the SPA pointed at prod — every sign-in then
// fails and the Firebase-injected "Running in emulator mode" banner is absent.
// That made local-stack logins (and any automated test driving them) flaky,
// fixed only by reloading until a load happened to connect. So here the
// emulator connect is RETRIED and its outcome GATES readiness: the caller
// keeps showing the loading state until `sessionReady`, and surfaces an
// explicit failure rather than a prod-pointed login.
//
// Implements: DIARY-DEV-portal-second-factor-toggle/C

/// The resolved bootstrap outcome the app shell renders from.
enum AuthBootstrapOutcome {
  /// No config, or `authMode != session` — render the dev ConnectScreen.
  dev,

  /// Session mode and Firebase (+ emulator, if reported) is wired — render
  /// the Firebase login surface.
  sessionReady,

  /// Session mode but Firebase/emulator init kept failing — render an
  /// explicit error (do NOT fall back to a prod-pointed login).
  failed,
}

typedef IdentityConfigFetcher = Future<Map<String, Object?>?> Function();

/// Initializes Firebase from the config; returns normally on success and
/// THROWS on failure (so the retry loop can react). Returns whether an
/// emulator was wired (informational; callers gate on success/throw).
typedef FirebaseInitializer = Future<bool> Function(Map<String, Object?> cfg);

Future<void> _wait(Duration d) => Future<void>.delayed(d);

/// Resolves the auth bootstrap outcome. Session-mode Firebase init is retried
/// up to [maxAttempts] (with [retryDelay] between tries) because the failure
/// is transient per page-load; only a clean init yields [sessionReady].
///
/// All I/O is injected ([fetchConfig], [initFirebase], [sleep]) so the
/// gating + retry logic is unit-testable without Firebase or a server.
Future<AuthBootstrapOutcome> resolveAuthBootstrap({
  required IdentityConfigFetcher fetchConfig,
  required FirebaseInitializer initFirebase,
  int maxAttempts = 3,
  Duration retryDelay = const Duration(milliseconds: 300),
  Future<void> Function(Duration) sleep = _wait,
}) async {
  final cfg = await fetchConfig();
  if (cfg == null || cfg['authMode'] != 'session') {
    return AuthBootstrapOutcome.dev;
  }
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      await initFirebase(cfg);
      return AuthBootstrapOutcome.sessionReady;
    } catch (_) {
      if (attempt < maxAttempts - 1) await sleep(retryDelay);
    }
  }
  return AuthBootstrapOutcome.failed;
}
