/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Session Management interfaces

/// Session state enumeration.
enum SessionState {
  /// No active session
  inactive,

  /// Session is active and valid
  active,

  /// Session is about to expire (warning period)
  warning,

  /// Session has expired
  expired,
}

/// Interface for managing user session lifecycle.
///
/// Handles inactivity detection, timeout warnings, and session termination.
abstract class SessionManager {
  /// Starts a new session with the specified timeout.
  ///
  /// [timeoutMinutes] specifies the inactivity timeout duration.
  /// User activity (mouse, keyboard, touch) resets the timer.
  void startSession(int timeoutMinutes);

  /// Ends the current session and clears all session data.
  Future<void> endSession();

  /// Extends the current session by resetting the inactivity timer.
  void extendSession();

  /// Returns the current session state.
  SessionState get currentState;

  /// Stream of session state changes.
  ///
  /// Emits events when session transitions between states
  /// (active -> warning -> expired).
  Stream<SessionState> get stateChanges;

  /// Returns the remaining time before session expiry.
  ///
  /// Returns [Duration.zero] if no active session.
  Duration get remainingTime;

  /// Registers a callback for session expiry events.
  void onSessionExpired(void Function() callback);

  /// Registers a callback for session warning events.
  ///
  /// Called 30 seconds before expiry.
  void onSessionWarning(void Function() callback);
}
