// IMPLEMENTS REQUIREMENTS:
//   REQ-d00080-G: beforeunload handler
//   REQ-d00080-K: visibilitychange handler
//   REQ-d00080-P: back-button prevention
//   REQ-p01044-D: session terminated on tab/window close

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'auth_service.dart';

/// Registers browser-level event listeners for session lifecycle management.
///
/// Instantiated once in main.dart. Call [register] after [AuthService] is
/// ready, and [dispose] when the app widget is torn down.
class BrowserLifecycleService {
  web.EventListener? _beforeUnloadListener;
  web.EventListener? _visibilityChangeListener;
  web.EventListener? _popStateListener;

  /// Register browser-level event listeners.
  void register(AuthService authService) {
    // REQ-d00080-G, REQ-d00080-H/I/J, REQ-p01044-D: clear storage and sign
    // out when the tab or window is closed.
    _beforeUnloadListener = ((web.Event _) {
      // Synchronous clearing runs to completion before the page unloads.
      // REQ-d00083-K: localStorage
      web.window.localStorage.clear();
      // REQ-d00083-L: sessionStorage
      web.window.sessionStorage.clear();
      // REQ-d00083-M: cookies
      _clearCookiesSync();
      // REQ-d00083-N/O: IndexedDB and Cache Storage are async; initiate best-effort.
      _clearIndexedDBAsync();
      _clearCacheStorageAsync();
      // Fire-and-forget sign-out; the page will unload before it completes,
      // but Firebase persists the sign-out in localStorage which we just cleared.
      authService.signOut();
    }).toJS;

    // REQ-d00080-K: register visibilitychange handler.
    // REQ-d00080-L: switching tabs MUST NOT trigger logout.
    _visibilityChangeListener = ((web.Event _) {
      if (web.document.visibilityState == 'hidden') {
        debugPrint('BrowserLifecycleService: tab hidden (not logging out)');
      }
    }).toJS;

    // REQ-d00080-P, REQ-p01044-N: intercept browser back/forward navigation.
    // When the user is not authenticated, push /login back onto the stack so
    // pressing back never reveals authenticated content.
    _popStateListener = ((web.Event _) {
      if (!authService.isAuthenticated) {
        web.window.history.pushState(null, '', '/login');
      }
    }).toJS;

    web.window.addEventListener('beforeunload', _beforeUnloadListener!);
    web.document.addEventListener(
      'visibilitychange',
      _visibilityChangeListener!,
    );
    web.window.addEventListener('popstate', _popStateListener!);
  }

  /// Remove all event listeners.
  void dispose() {
    if (_beforeUnloadListener != null) {
      web.window.removeEventListener('beforeunload', _beforeUnloadListener!);
      _beforeUnloadListener = null;
    }
    if (_visibilityChangeListener != null) {
      web.document.removeEventListener(
        'visibilitychange',
        _visibilityChangeListener!,
      );
      _visibilityChangeListener = null;
    }
    if (_popStateListener != null) {
      web.window.removeEventListener('popstate', _popStateListener!);
      _popStateListener = null;
    }
  }
}

// ── Synchronous helpers (safe to call inside beforeunload) ────────────────────

void _clearCookiesSync() {
  final cookieStr = web.document.cookie;
  if (cookieStr.isEmpty) return;
  for (final cookie in cookieStr.split(';')) {
    final name = cookie.split('=').first.trim();
    if (name.isEmpty) continue;
    web.document.cookie = '$name=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/';
    web.document.cookie =
        '$name=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=${web.window.location.hostname}';
  }
}

// ── Async helpers (best-effort on beforeunload) ───────────────────────────────

void _clearIndexedDBAsync() {
  web.window.indexedDB.databases().toDart.then((dbs) {
    for (final db in dbs.toDart) {
      final name = db.name;
      if (name.isNotEmpty) web.window.indexedDB.deleteDatabase(name);
    }
  }).ignore();
}

void _clearCacheStorageAsync() {
  web.window.caches.keys().toDart.then((keys) async {
    for (final key in keys.toDart) {
      await web.window.caches.delete(key.toDart).toDart;
    }
  }).ignore();
}
