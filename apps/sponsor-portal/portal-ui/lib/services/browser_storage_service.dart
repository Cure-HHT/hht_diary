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

  /// Heuristic match for Firebase Auth's persistence DB names.
  /// Format observed: `firebaseLocalStorageDb` and
  /// `firebase-heartbeat-database`. Both are managed by the SDK.
  bool _isFirebaseAuthDb(String name) =>
      name == 'firebaseLocalStorageDb' || name.startsWith('firebase-');

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
}
