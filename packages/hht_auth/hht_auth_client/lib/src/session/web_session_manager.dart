/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// Web-based session manager with inactivity tracking.
///
/// Manages user session lifecycle with configurable timeout,
/// inactivity detection, and warning notifications.

import 'dart:async';
import 'package:hht_auth_core/hht_auth_core.dart';

/// Web session manager implementation.
///
/// Tracks user inactivity and manages session state transitions.
/// Requires integration with InactivityTracker for activity monitoring.
class WebSessionManager implements SessionManager {
  static const int warningSeconds = 30;

  int _timeoutMinutes = 2;
  Timer? _timeoutTimer;
  Timer? _warningTimer;
  
  final StreamController<SessionState> _stateController = 
      StreamController<SessionState>.broadcast();
  
  SessionState _currentState = SessionState.inactive;
  
  void Function()? _onExpired;
  void Function()? _onWarning;

  @override
  SessionState get currentState => _currentState;

  @override
  Stream<SessionState> get stateChanges => _stateController.stream;

  @override
  Duration get remainingTime {
    // TODO: Implement precise remaining time tracking
    if (_currentState == SessionState.active) {
      return Duration(minutes: _timeoutMinutes);
    }
    return Duration.zero;
  }

  @override
  void startSession(int timeoutMinutes) {
    _timeoutMinutes = timeoutMinutes;
    _updateState(SessionState.active);
    _resetTimers();
  }

  @override
  Future<void> endSession() async {
    _cancelTimers();
    _updateState(SessionState.inactive);
  }

  @override
  void extendSession() {
    if (_currentState == SessionState.active || 
        _currentState == SessionState.warning) {
      _resetTimers();
      _updateState(SessionState.active);
    }
  }

  @override
  void onSessionExpired(void Function() callback) {
    _onExpired = callback;
  }

  @override
  void onSessionWarning(void Function() callback) {
    _onWarning = callback;
  }

  void _resetTimers() {
    _cancelTimers();
    
    // Set warning timer (timeout - 30 seconds)
    final warningDuration = Duration(
      minutes: _timeoutMinutes,
      seconds: -warningSeconds,
    );
    
    if (warningDuration.inSeconds > 0) {
      _warningTimer = Timer(warningDuration, () {
        _updateState(SessionState.warning);
        _onWarning?.call();
      });
    }

    // Set timeout timer
    _timeoutTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      _updateState(SessionState.expired);
      _onExpired?.call();
    });
  }

  void _cancelTimers() {
    _timeoutTimer?.cancel();
    _warningTimer?.cancel();
    _timeoutTimer = null;
    _warningTimer = null;
  }

  void _updateState(SessionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  void dispose() {
    _cancelTimers();
    _stateController.close();
  }
}
