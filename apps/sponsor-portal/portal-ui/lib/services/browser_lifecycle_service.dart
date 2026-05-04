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
    //
    // CUR-1118: beforeunload fires on BOTH page refresh (F5/Cmd+R) and tab
    // close. We must not destroy the Firebase Auth session on a refresh or
    // the user will be redirected to login after every reload.
    //
    // Strategy: set a sessionStorage flag before unloading.
    //   - On page refresh: the flag survives (sessionStorage persists
    //     across same-tab reloads) → startup detects a refresh, keeps session.
    //   - On tab close: the browser destroys sessionStorage → startup sees no
    //     flag, treats it as a fresh load and signs out any stale session.
    _beforeUnloadListener = ((web.Event _) {
      // Mark the upcoming unload as a potential refresh.
      // main.dart checks and removes this flag on the next page load.
      web.window.sessionStorage.setItem('_portalRefreshing', 'true');

      // NOTE: No storage is cleared here. Firebase Auth persists its session
      // in IndexedDB, and clearing any storage would destroy the session
      // before the page has a chance to reload.
      // Session teardown on genuine tab close is handled by AuthService._init()
      // which detects the missing flag and signs out stale sessions.
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
