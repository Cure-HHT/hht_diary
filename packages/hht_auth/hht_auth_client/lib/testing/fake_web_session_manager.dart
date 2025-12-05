/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// Fake session manager for testing.
///
/// Provides a controllable session manager implementation for testing
/// without real timers.

import 'dart:async';
import 'package:hht_auth_core/hht_auth_core.dart';

/// Fake session manager for testing.
///
/// Allows manual control of session state transitions for testing purposes.
class FakeWebSessionManager implements SessionManager {
  SessionState _currentState = SessionState.inactive;
  final StreamController<SessionState> _stateController = 
      StreamController<SessionState>.broadcast();
  
  void Function()? _onExpired;
  void Function()? _onWarning;
  
  int? _timeoutMinutes;

  @override
  SessionState get currentState => _currentState;

  @override
  Stream<SessionState> get stateChanges => _stateController.stream;

  @override
  Duration get remainingTime {
    if (_timeoutMinutes != null && _currentState == SessionState.active) {
      return Duration(minutes: _timeoutMinutes!);
    }
    return Duration.zero;
  }

  @override
  void startSession(int timeoutMinutes) {
    _timeoutMinutes = timeoutMinutes;
    _updateState(SessionState.active);
  }

  @override
  Future<void> endSession() async {
    _timeoutMinutes = null;
    _updateState(SessionState.inactive);
  }

  @override
  void extendSession() {
    if (_currentState == SessionState.active || 
        _currentState == SessionState.warning) {
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

  // Test helpers

  /// Manually triggers a warning state transition.
  void triggerWarning() {
    _updateState(SessionState.warning);
    _onWarning?.call();
  }

  /// Manually triggers an expired state transition.
  void triggerExpired() {
    _updateState(SessionState.expired);
    _onExpired?.call();
  }

  /// Manually sets the session state.
  void setState(SessionState state) {
    _updateState(state);
  }

  void _updateState(SessionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  /// Disposes of the fake session manager.
  void dispose() {
    _stateController.close();
  }
}
