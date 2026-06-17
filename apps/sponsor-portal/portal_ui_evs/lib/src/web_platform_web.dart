import 'dart:async';
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

  /// Deletes Firebase Auth's persistence DB (`firebaseLocalStorageDb`) so the
  /// next Firebase init starts with NO stored user.
  ///
  /// flutterfire #9528: on web the SDK auto-restores a persisted user during
  /// `Firebase.initializeApp`, which "uses" the Auth instance before
  /// `useAuthEmulator` can run — the emulator connect is then silently rejected
  /// and every auth call hits production. Wiping the DB BEFORE init removes the
  /// user to restore, so the emulator binds cleanly. Called only on emulator
  /// deployments (the bootstrap guards on `emulatorHost`); a production session
  /// is never wiped, so a real restored login survives.
  ///
  /// Best-effort: pre-init no SDK connection holds the DB open, so the delete
  /// completes immediately. The 800ms timeout (and the `blocked`/`error`
  /// fall-throughs) keep boot from stalling in the unexpected case where a
  /// connection is still open — the delete then completes once it closes.
  // Implements: DIARY-DEV-portal-emulator-bootstrap/A
  Future<void> clearFirebaseAuthDb() async {
    final completer = Completer<void>();
    void done(web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }

    try {
      final req = web.window.indexedDB.deleteDatabase('firebaseLocalStorageDb');
      req.onsuccess = done.toJS;
      req.onerror = done.toJS;
      // A connection is still open (unexpected pre-init): log it for
      // diagnosability but do NOT complete — rely on the timeout below so boot
      // never stalls; the delete lands once the connection closes.
      req.onblocked = ((web.Event _) {
        web.console.warn(
          'clearFirebaseAuthDb: deleteDatabase blocked — a connection is '
                  'still open; relying on the timeout'
              .toJS,
        );
      }).toJS;
      await completer.future.timeout(
        const Duration(milliseconds: 800),
        onTimeout: () {},
      );
    } catch (e) {
      // indexedDB unavailable / delete threw — proceed; init may still bind.
      web.console.warn('clearFirebaseAuthDb failed: $e'.toJS);
    }
  }
}
