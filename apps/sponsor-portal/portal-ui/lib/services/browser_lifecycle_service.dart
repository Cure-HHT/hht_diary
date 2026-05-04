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
    // REQ-d00080-G, REQ-d00080-H/I/J, REQ-p01044-D: detect tab/window close.
    //
    // CUR-1157: We no longer write a sessionStorage refresh flag here.
    // The CUR-1118 implementation used a beforeunload→sessionStorage
    // handshake (set '_portalRefreshing' before unload, read it after
    // load) to tell refresh from tab close. That handshake is unreliable
    // — beforeunload doesn't fire in every browser/context, and
    // sessionStorage writes during unload can be discarded — which left
    // refreshed users falsely classified as "fresh tabs" and signed out.
    //
    // main.dart now uses PerformanceNavigationTiming.type for that check,
    // which doesn't depend on any pre-unload code path having run. The
    // beforeunload listener is kept (no-op) so this class still owns the
    // unload event surface for any future per-unload work, but it must
    // not sign out or clear storage — Firebase Auth persists in
    // IndexedDB and we want refresh to keep the user logged in.
    _beforeUnloadListener = ((web.Event _) {}).toJS;

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
