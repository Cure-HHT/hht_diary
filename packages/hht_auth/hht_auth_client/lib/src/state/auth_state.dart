/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// Authentication state model.
///
/// Represents the current authentication status of the application,
/// including user information, session state, and any errors.

import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:meta/meta.dart';

/// Immutable authentication state.
///
/// Contains all information about the current authentication status,
/// including user data, token, sponsor configuration, and session state.
@immutable
class AuthState {
  /// Whether the user is currently authenticated.
  final bool isAuthenticated;

  /// Whether an authentication operation is in progress.
  final bool isLoading;

  /// The authenticated user, or null if not authenticated.
  final WebUser? user;

  /// The current JWT authentication token, or null if not authenticated.
  final String? token;

  /// The sponsor configuration, or null if not loaded.
  final SponsorConfig? sponsorConfig;

  /// The current session state.
  final SessionState sessionState;

  /// An error message, or null if no error.
  final String? error;

  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    required this.sessionState,
    this.user,
    this.token,
    this.sponsorConfig,
    this.error,
  });

  /// Creates an initial unauthenticated state.
  const AuthState.initial()
      : isAuthenticated = false,
        isLoading = false,
        user = null,
        token = null,
        sponsorConfig = null,
        sessionState = SessionState.inactive,
        error = null;

  /// Creates a copy of this state with the given fields replaced.
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    WebUser? user,
    String? token,
    SponsorConfig? sponsorConfig,
    SessionState? sessionState,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      token: token ?? this.token,
      sponsorConfig: sponsorConfig ?? this.sponsorConfig,
      sessionState: sessionState ?? this.sessionState,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthState &&
        other.isAuthenticated == isAuthenticated &&
        other.isLoading == isLoading &&
        other.user == user &&
        other.token == token &&
        other.sponsorConfig == sponsorConfig &&
        other.sessionState == sessionState &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      isAuthenticated,
      isLoading,
      user,
      token,
      sponsorConfig,
      sessionState,
      error,
    );
  }

  @override
  String toString() {
    return 'AuthState('
        'isAuthenticated: $isAuthenticated, '
        'isLoading: $isLoading, '
        'sessionState: $sessionState, '
        'hasUser: ${user != null}, '
        'hasToken: ${token != null}, '
        'hasConfig: ${sponsorConfig != null}, '
        'error: $error'
        ')';
  }
}
