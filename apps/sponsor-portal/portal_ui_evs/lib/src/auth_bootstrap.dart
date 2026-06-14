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
/// Initializes Firebase from the config; returns true when an emulator was
/// wired (`useAuthEmulator` called), false for a production deployment.
typedef FirebaseInitializer = Future<bool> Function(Map<String, Object?> cfg);

/// Probes whether an auth call actually REACHES the emulator yet. Throws while
/// the SDK hasn't applied the emulator connect (calls still hit production);
/// returns normally once it has. This is the behavioural readiness signal —
/// `useAuthEmulator()` resolves BEFORE the connect lands, so awaiting it is not
/// enough.
typedef EmulatorConnectivityProbe = Future<void> Function();

Future<void> _wait(Duration d) => Future<void>.delayed(d);

/// Resolves the auth bootstrap outcome, gating a session-mode login on the
/// emulator being genuinely reachable.
///
/// In emulator deployments `useAuthEmulator()` returns before the SDK applies
/// the connect, so [initFirebase] completing is NOT sufficient — a login shown
/// in that window submits against production and fails (the flaky-login race).
/// So after init, [verifyConnected] is POLLED (up to [maxAttempts], [retryDelay]
/// apart) until an auth call reaches the emulator; only then [sessionReady].
/// A production deployment (no emulator) skips the probe. All I/O is injected
/// so the gating + poll logic is unit-testable without Firebase or a server.
Future<AuthBootstrapOutcome> resolveAuthBootstrap({
  required IdentityConfigFetcher fetchConfig,
  required FirebaseInitializer initFirebase,
  required EmulatorConnectivityProbe verifyConnected,
  int maxAttempts = 15,
  Duration retryDelay = const Duration(milliseconds: 200),
  Future<void> Function(Duration) sleep = _wait,
}) async {
  final cfg = await fetchConfig();
  if (cfg == null || cfg['authMode'] != 'session') {
    return AuthBootstrapOutcome.dev;
  }
  final bool emulator;
  try {
    emulator = await initFirebase(cfg);
  } catch (_) {
    return AuthBootstrapOutcome.failed;
  }
  // Production: no emulator to wait on — the login can render immediately.
  if (!emulator) return AuthBootstrapOutcome.sessionReady;
  // Emulator: poll until an auth call actually reaches it (the connect lands
  // after useAuthEmulator returns), so the login is never submittable against
  // production in the gap.
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      await verifyConnected();
      return AuthBootstrapOutcome.sessionReady;
    } catch (_) {
      if (attempt < maxAttempts - 1) await sleep(retryDelay);
    }
  }
  return AuthBootstrapOutcome.failed;
}
