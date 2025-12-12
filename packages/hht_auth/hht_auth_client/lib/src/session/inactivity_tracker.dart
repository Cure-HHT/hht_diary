/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// User inactivity tracking for web browsers.
///
/// Monitors user interactions (mouse, keyboard, touch) and notifies
/// when user activity is detected.
///
/// NOTE: This file uses dart:html and is web-only.

import 'dart:html' as html;
import 'dart:async';

/// Tracks user activity on web pages.
///
/// Listens for mouse, keyboard, and touch events to detect user activity.
class InactivityTracker {
  final StreamController<void> _activityController = 
      StreamController<void>.broadcast();
  
  final List<StreamSubscription> _subscriptions = [];
  bool _isTracking = false;

  /// Stream of user activity events.
  ///
  /// Emits an event whenever user activity is detected.
  Stream<void> get onActivity => _activityController.stream;

  /// Whether the tracker is currently active.
  bool get isTracking => _isTracking;

  /// Starts tracking user activity.
  void startTracking() {
    if (_isTracking) return;
    
    _isTracking = true;
    _registerEventListeners();
  }

  /// Stops tracking user activity.
  void stopTracking() {
    if (!_isTracking) return;
    
    _isTracking = false;
    _unregisterEventListeners();
  }

  void _registerEventListeners() {
    // Mouse events
    _subscriptions.add(
      html.document.onMouseMove.listen((_) => _notifyActivity())
    );
    _subscriptions.add(
      html.document.onClick.listen((_) => _notifyActivity())
    );
    _subscriptions.add(
      html.document.onMouseDown.listen((_) => _notifyActivity())
    );

    // Keyboard events
    _subscriptions.add(
      html.document.onKeyDown.listen((_) => _notifyActivity())
    );
    _subscriptions.add(
      html.document.onKeyPress.listen((_) => _notifyActivity())
    );

    // Touch events (for mobile browsers)
    _subscriptions.add(
      html.document.onTouchStart.listen((_) => _notifyActivity())
    );
    _subscriptions.add(
      html.document.onTouchMove.listen((_) => _notifyActivity())
    );

    // Scroll events
    _subscriptions.add(
      html.window.onScroll.listen((_) => _notifyActivity())
    );
  }

  void _unregisterEventListeners() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _notifyActivity() {
    if (_isTracking) {
      _activityController.add(null);
    }
  }

  /// Disposes of the tracker and cleans up resources.
  void dispose() {
    stopTracking();
    _activityController.close();
  }
}
