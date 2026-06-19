/// Pure stale-client decision logic for portal version-mismatch handling.
///
/// The portal is a long-lived SPA over a WebSocket: a tab left open keeps
/// running its compiled bundle even after a new build is deployed. The server
/// and the web bundle are built and shipped from the SAME image, which stamps
/// the identical `<semver>+<short_sha>` value into both the bundle's compiled
/// `APP_VERSION` and the server's `/health` `portal_ui_version` field
/// (see `deployment/.../portal-final.Dockerfile`). So a difference between the
/// two is a definitive "this tab is running an older bundle than the deployed
/// server" signal — no separate version axis or snapshot needed.
library;

/// What a stale-client check should do, given the version comparison and the
/// current auth context.
enum StaleClientAction {
  /// Bundle matches the deployed server, or versions are unknown — do nothing.
  none,

  /// Authenticated user mid-session: surface a non-blocking reload banner.
  /// Never yank a user out of an in-progress form.
  banner,

  /// Unauthenticated (login screen): nothing to lose — reload immediately to
  /// pick up the new bundle.
  reload,
}

/// True when this bundle is definitively older than the deployed server.
///
/// Compares the bundle's compiled [clientVersion] (`APP_VERSION`) against the
/// server's `portal_ui_version` from `/health`. Both are stamped from the same
/// build value, so an inequality is a definitive staleness signal. An empty or
/// absent value on either side — a local `flutter run` without the define, or
/// an unreachable `/health` — yields `false`, so dev runs never trip.
// Implements: DIARY-BASE-portal-stale-client-reload/A
bool isClientStale({
  required String clientVersion,
  required Map<String, Object?> serverVersions,
}) {
  final serverUi = serverVersions['portal_ui_version'];
  return clientVersion.isNotEmpty &&
      serverUi is String &&
      serverUi.isNotEmpty &&
      serverUi != clientVersion;
}

/// Decide what to do when a fresh `/health` version manifest arrives.
///
/// * not stale -> [StaleClientAction.none]
/// * stale + authenticated -> [StaleClientAction.banner] (prompt, never auto)
/// * stale + login screen AT BOOT, not yet auto-reloaded this session ->
///   [StaleClientAction.reload] — the page just loaded, nothing can have
///   been typed yet, so the reload is free.
/// * stale + login screen AFTER boot (transport reconnect after a deploy,
///   or a sign-in attempt) -> [StaleClientAction.banner]. The *User* may
///   have credentials in the form or an authentication already in flight;
///   an automatic reload here discards both and makes a deploy look like a
///   failed login. A stale bundle signs in fine — the banner persists into
///   the authenticated session for a reload at the *User*'s convenience.
/// * stale + login screen at boot, auto-reload ALREADY tried this session ->
///   [StaleClientAction.banner] — the loop guard: a reload that returned a
///   still-stale bundle (e.g. a legacy service worker still controlling the
///   page) must surface the manual affordance instead of reloading forever.
// Implements: DIARY-BASE-portal-stale-client-reload/A+B+C
// Implements: DIARY-DEV-portal-legacy-sw-eviction/B
StaleClientAction decideStaleClientAction({
  required String clientVersion,
  required Map<String, Object?> serverVersions,
  required bool authenticated,
  required bool atBoot,
  required bool autoReloadAlreadyTried,
}) {
  final stale = isClientStale(
    clientVersion: clientVersion,
    serverVersions: serverVersions,
  );
  if (!stale) return StaleClientAction.none;
  if (authenticated) return StaleClientAction.banner;
  if (!atBoot) return StaleClientAction.banner;
  if (autoReloadAlreadyTried) return StaleClientAction.banner;
  return StaleClientAction.reload;
}
