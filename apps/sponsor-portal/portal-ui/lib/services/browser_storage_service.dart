// IMPLEMENTS REQUIREMENTS:
//   REQ-d00083: Client-Side Storage Clearing
//   REQ-p01044-J/K/L/M: clear all client-side storage on logout

import 'dart:js_interop';

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

  void _clearCookies() {
    final cookieStr = web.document.cookie;
    if (cookieStr.isEmpty) return;
    for (final cookie in cookieStr.split(';')) {
      final name = cookie.split('=').first.trim();
      if (name.isEmpty) continue;
      web.document.cookie =
          '$name=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/';
      web.document.cookie =
          '$name=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=${web.window.location.hostname}';
    }
  }

  Future<void> _clearIndexedDB() async {
    try {
      final dbs = await web.window.indexedDB.databases().toDart;
      for (final db in dbs.toDart) {
        final name = db.name;
        if (name.isNotEmpty) {
          web.window.indexedDB.deleteDatabase(name);
        }
      }
    } catch (_) {
      // IndexedDB may not be available or databases() may not be supported.
    }
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
}
