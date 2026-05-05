// IMPLEMENTS REQUIREMENTS:
//   REQ-d00083: Client-Side Storage Clearing
//   REQ-p01044-J/K/L/M: clear all client-side storage on logout

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Clears all client-side browser storage on web.
///
/// Instantiated by main.dart and injected into [AuthService] via the
/// [clearStorage] callback. Never import this file directly from non-web code.
class BrowserStorageService {
  /// Clears localStorage, sessionStorage, cookies, IndexedDB, and Cache
  /// Storage, then rewrites the history entry to /login.
  Future<void> clearStorage() async {
    // REQ-d00083-A, REQ-p01044-K: clear localStorage
    web.window.localStorage.clear();

    // REQ-d00083-B, REQ-p01044-J: clear sessionStorage
    web.window.sessionStorage.clear();

    // REQ-d00083-C, REQ-p01044-L: clear cookies by expiring each one
    _clearCookies();

    // REQ-d00083-D: clear IndexedDB databases
    await _clearIndexedDB();

    // REQ-d00083-E: clear Cache Storage (service worker caches)
    await _clearCacheStorage();

    // NOTE: history.replaceState is intentionally NOT called here.
    // Calling it during beforeunload (tab close) throws in Safari and Firefox
    // because browsers restrict history mutations on an unloading page.
    // Back-navigation is prevented by the popstate listener in
    // BrowserLifecycleService (REQ-d00080-P, REQ-p01044-N).
  }

  // IMPLEMENTS REQUIREMENTS:
  //   REQ-d00083-C/H/M: clear all cookies on logout / timeout / browser close
  //   REQ-p01044-L: clear cookies on logout
  //
  // CUR-1280 (issue 8): cookies set with paths other than `/` (e.g.
  // `/api`, `/api/v1`) won't be cleared by a single `path=/` expiry —
  // each cookie's expiry must match the path it was set with. We don't
  // know which paths the server might use, so we sweep the common
  // roots that the portal could plausibly emit. The /api/v1 form
  // matches the routes in routes.dart; / catches the rest.
  //
  // HttpOnly cookies are NOT visible to document.cookie and cannot be
  // cleared from the page. As of CUR-1280 the portal_server emits no
  // Set-Cookie headers (auth is Bearer-token in the Authorization
  // header), so this gap is theoretical. If a future server feature
  // sets HttpOnly cookies, add a server-side `/api/v1/portal/auth/
  // clear-cookies` POST that the client calls during signOut() before
  // the local cookie sweep.
  void _clearCookies() {
    final cookieStr = web.document.cookie;
    if (cookieStr.isEmpty) return;
    const expiry = 'expires=Thu, 01 Jan 1970 00:00:00 GMT';
    const paths = <String>['/', '/api', '/api/v1'];
    final hostname = web.window.location.hostname;
    for (final cookie in cookieStr.split(';')) {
      final name = cookie.split('=').first.trim();
      if (name.isEmpty) continue;
      for (final path in paths) {
        web.document.cookie = '$name=;$expiry;path=$path';
        web.document.cookie = '$name=;$expiry;path=$path;domain=$hostname';
      }
    }
  }

  // IMPLEMENTS REQUIREMENTS:
  //   REQ-d00083-D/I/N: clear IndexedDB databases on logout/timeout/close
  //   REQ-p01044-M: no patient data recoverable from browser after logout
  //
  // CUR-1280: deleteDatabase returns an IDBOpenDBRequest. The actual
  // delete only happens when all connections to the DB close. Firebase
  // Auth keeps `firebaseLocalStorageDb` open for the lifetime of the
  // SDK, so a naive deleteDatabase() blocks indefinitely. The previous
  // implementation didn't await the request at all, so clearStorage()
  // returned with the IndexedDB unchanged.
  //
  // We now:
  //  1. await each delete with a per-DB timeout,
  //  2. surface "blocked" outcomes via debugPrint so callers know the
  //     delete hasn't actually happened yet,
  //  3. skip Firebase's own DB and let _auth.signOut() handle it — the
  //     SDK closes its connection only after signOut completes, so
  //     mixing manual deletion with Firebase writes is the failure
  //     mode we want to avoid.
  Future<void> _clearIndexedDB() async {
    try {
      final dbs = await web.window.indexedDB.databases().toDart;
      final futures = <Future<void>>[];
      for (final db in dbs.toDart) {
        final name = db.name;
        if (name.isEmpty) continue;
        if (_isFirebaseAuthDb(name)) {
          // Let Firebase clear its own DB on signOut. Manually deleting
          // races the SDK's writes and ends up blocked anyway.
          continue;
        }
        futures.add(_deleteDatabase(name));
      }
      await Future.wait(futures);
    } catch (e) {
      // databases() may not be supported (older Safari). Best-effort.
      debugPrint('[BrowserStorageService] indexedDB.databases() failed: $e');
    }
  }

  /// Match the single Firebase Auth persistence DB that `_auth.signOut()`
  /// already clears for us — `firebaseLocalStorageDb`. We let signOut own
  /// it; manually deleting it here would race signOut's writes and likely
  /// trip the `blocked` path.
  ///
  /// Other Firebase-managed DBs (`firebase-heartbeat-database`,
  /// `firebase-installations-database`, etc.) are NOT skipped — `signOut()`
  /// does not touch them, so REQ-d00083 / REQ-p01044-M (no patient data
  /// recoverable after logout) requires us to delete them through the
  /// normal best-effort path. They may block if the SDK still has handles
  /// open; the timeout/blocked logging in `_deleteDatabase` covers that.
  bool _isFirebaseAuthDb(String name) => name == 'firebaseLocalStorageDb';

  /// Issue a deleteDatabase request and wait for completion or timeout.
  /// Returns when the deletion completes, errors, or the timeout fires.
  /// Logs a warning on `blocked` (a connection is still open).
  Future<void> _deleteDatabase(String name) async {
    final completer = Completer<void>();
    final req = web.window.indexedDB.deleteDatabase(name);
    req.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    req.onerror = ((web.Event _) {
      debugPrint(
        '[BrowserStorageService] deleteDatabase($name) errored — '
        'continuing best-effort',
      );
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    req.onblocked = ((web.Event _) {
      debugPrint(
        '[BrowserStorageService] deleteDatabase($name) blocked — '
        'a connection is still open; deletion will complete when it closes',
      );
      // Don't complete here. We rely on the timeout below so the caller
      // is not stuck if the connection never closes.
    }).toJS;
    return completer.future.timeout(
      const Duration(milliseconds: 800),
      onTimeout: () {
        debugPrint(
          '[BrowserStorageService] deleteDatabase($name) timed out — '
          'deletion will complete asynchronously when no connection holds the DB',
        );
      },
    );
  }

  Future<void> _clearCacheStorage() async {
    try {
      final cacheStorage = web.window.caches;
      final keys = await cacheStorage.keys().toDart;
      for (final key in keys.toDart) {
        await cacheStorage.delete(key.toDart).toDart;
      }
    } catch (_) {
      // Cache API may not be available (no service worker registered).
    }
  }

  /// CUR-1280 auto-recovery: force-delete Firebase Auth's IndexedDB so
  /// the next page load starts with no cached session.
  ///
  /// [clearStorage] deliberately *skips* `firebaseLocalStorageDb` so the
  /// regular signOut path doesn't race against Firebase's own writes.
  /// But when the local-stack emulator is restarted (`./local-stack
  /// down/up`), the emulator wipes its user database and assigns NEW
  /// UIDs to the same seeded emails. The browser's
  /// `firebaseLocalStorageDb` still holds a refresh-token for a UID
  /// that no longer exists. Subsequent page loads either:
  ///   - succeed at restore, then fail server-side with
  ///     "Email already linked to another account" (HTTP 403),
  ///   - fail at refresh with "invalid_grant" / "user-not-found",
  ///   - or simply never resolve, leaving the SPA in a broken state
  ///     (e.g. the `/login/email-otp` reload-into-white-screen).
  ///
  /// Recovery: delete `firebaseLocalStorageDb` outright, alongside the
  /// usual signOut. The delete is best-effort — if Firebase still holds
  /// the connection open, the request transitions to `blocked` and we
  /// time out and let the caller proceed regardless. On the *next* page
  /// load, no connection is open and the deletion completes for real.
  ///
  /// AuthService injects this through a callback (so VM-target unit
  /// tests don't pull in the web-only `package:web` import chain).
  Future<void> forceClearFirebaseAuthDb() async {
    await _deleteDatabase('firebaseLocalStorageDb');
  }
}
