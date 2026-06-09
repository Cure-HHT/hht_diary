import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser implementation of the [WebPlatform] seam. Uses `package:web` +
/// `dart:js_interop` — the current, non-deprecated web-interop stack
/// (`dart:html` is retired). Mirrors the proven pattern already used by the
/// diary app's `web_update_helper` and the legacy `portal-ui` boot path.
class WebPlatform {
  const WebPlatform();

  /// Unregister every service worker registered for this origin.
  ///
  /// Evicts any lingering pre-`--pwa-strategy=none` worker that would otherwise
  /// keep intercepting fetches and serving its own precache, which is the root
  /// cause of the "must hard-reset to pick up a deploy" symptom. Idempotent and
  /// cheap: a no-op when none are registered, and guarded for browsers without
  /// service-worker support (accessing the API throws -> caught).
  // Implements: DIARY-DEV-portal-legacy-sw-eviction/A
  Future<void> unregisterServiceWorkers() async {
    try {
      final regs =
          (await web.window.navigator.serviceWorker.getRegistrations().toDart)
              .toDart;
      for (final reg in regs) {
        try {
          await reg.unregister().toDart;
        } catch (e) {
          // A single registration failing to unregister (security/internal
          // error) must not block boot or the rest of the loop.
          web.console.warn('serviceWorker.unregister failed: $e'.toJS);
        }
      }
    } catch (_) {
      // ServiceWorker API unavailable in this context — nothing to do.
    }
  }

  /// Full-document reload. With the entry bundle's `no-cache, must-revalidate`
  /// headers (nginx) this re-fetches `index.html`/`main.dart.js`, pulling the
  /// new build. No-arg form: the legacy `reload(forceGet)` argument is
  /// non-standard and absent from current `package:web`.
  void reloadPage() => web.window.location.reload();

  static const String _guardKey = 'portal_stale_autoreload_tried';

  /// Whether an automatic reload has already been attempted in THIS browser
  /// session (survives the reload via `sessionStorage`, clears on tab close).
  /// The loop guard reads this to avoid reloading forever when a reload returns
  /// a still-stale bundle.
  // Implements: DIARY-DEV-portal-legacy-sw-eviction/B
  bool get autoReloadAlreadyTried =>
      web.window.sessionStorage.getItem(_guardKey) != null;

  void markAutoReloadTried() =>
      web.window.sessionStorage.setItem(_guardKey, '1');

  void clearAutoReloadGuard() =>
      web.window.sessionStorage.removeItem(_guardKey);
}
