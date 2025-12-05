/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// Base authentication state notifier.
///
/// Provides common state management logic that can be used with both
/// Signals and Riverpod.

import 'dart:async';
import 'package:hht_auth_client/src/state/auth_state.dart';
import 'package:hht_auth_client/src/services/web_auth_service.dart';
import 'package:hht_auth_client/src/services/sponsor_config_loader.dart';
import 'package:hht_auth_client/src/session/web_session_manager.dart';
import 'package:hht_auth_client/src/storage/web_token_storage.dart';
import 'package:hht_auth_core/hht_auth_core.dart';

/// Base authentication state notifier.
///
/// Contains common logic for managing authentication state across
/// different state management solutions.
abstract class AuthStateNotifier {
  final WebAuthService _authService;
  final SponsorConfigLoader _configLoader;
  final WebSessionManager _sessionManager;
  final WebTokenStorage _tokenStorage;

  AuthStateNotifier({
    required WebAuthService authService,
    required SponsorConfigLoader configLoader,
    required WebSessionManager sessionManager,
    required WebTokenStorage tokenStorage,
  })  : _authService = authService,
        _configLoader = configLoader,
        _sessionManager = sessionManager,
        _tokenStorage = tokenStorage {
    _initializeSessionListeners();
  }

  /// Current authentication state.
  AuthState get state;

  /// Updates the state.
  void updateState(AuthState newState);

  void _initializeSessionListeners() {
    _sessionManager.onSessionExpired(() {
      logout();
    });

    _sessionManager.onSessionWarning(() {
      updateState(state.copyWith(
        sessionState: SessionState.warning,
      ));
    });
  }

  /// Attempts to log in with credentials.
  Future<void> login(String username, String password) async {
    updateState(state.copyWith(isLoading: true, error: null));

    try {
      final request = LoginRequest(
        username: username,
        password: password,
      );

      final result = await _authService.login(request);

      if (result is AuthSuccess) {
        await _tokenStorage.saveToken(result.token);
        
        // Load sponsor config
        final config = await _configLoader.loadConfig(result.token);
        
        // Start session
        _sessionManager.startSession(config.sessionTimeoutMinutes);

        updateState(AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: result.user,
          token: result.token,
          sponsorConfig: config,
          sessionState: SessionState.active,
        ));
      } else if (result is AuthFailure) {
        updateState(state.copyWith(
          isLoading: false,
          error: result.message,
        ));
      }
    } catch (e) {
      updateState(state.copyWith(
        isLoading: false,
        error: 'Login failed: $e',
      ));
    }
  }

  /// Logs out the current user.
  Future<void> logout() async {
    await _sessionManager.endSession();
    await _tokenStorage.deleteToken();
    _configLoader.clearCache();
    
    updateState(AuthState.initial());
  }

  /// Extends the current session.
  void extendSession() {
    _sessionManager.extendSession();
    updateState(state.copyWith(
      sessionState: SessionState.active,
    ));
  }

  /// Validates a linking code.
  Future<LinkingCodeValidation> validateLinkingCode(String code) async {
    return _authService.validateLinkingCode(code);
  }

  /// Registers a new user.
  Future<void> register(RegistrationRequest request) async {
    updateState(state.copyWith(isLoading: true, error: null));

    try {
      final result = await _authService.register(request);

      if (result is AuthSuccess) {
        await _tokenStorage.saveToken(result.token);
        
        final config = await _configLoader.loadConfig(result.token);
        _sessionManager.startSession(config.sessionTimeoutMinutes);

        updateState(AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: result.user,
          token: result.token,
          sponsorConfig: config,
          sessionState: SessionState.active,
        ));
      } else if (result is AuthFailure) {
        updateState(state.copyWith(
          isLoading: false,
          error: result.message,
        ));
      }
    } catch (e) {
      updateState(state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      ));
    }
  }
}
