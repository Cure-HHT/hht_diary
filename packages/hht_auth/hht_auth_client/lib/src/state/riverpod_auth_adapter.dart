/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// Riverpod adapter for authentication state management.
///
/// Provides Riverpod providers for authentication state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hht_auth_client/src/state/auth_state.dart';
import 'package:hht_auth_client/src/state/auth_state_notifier.dart';
import 'package:hht_auth_client/src/services/web_auth_service.dart';
import 'package:hht_auth_client/src/services/sponsor_config_loader.dart';
import 'package:hht_auth_client/src/session/web_session_manager.dart';
import 'package:hht_auth_client/src/storage/web_token_storage.dart';
import 'package:hht_auth_client/src/http/auth_http_client.dart';
import 'package:hht_auth_core/hht_auth_core.dart';

/// Riverpod-based authentication state notifier.
class RiverpodAuthNotifier extends StateNotifier<AuthState> 
    implements AuthStateNotifier {
  final WebAuthService _authService;
  final SponsorConfigLoader _configLoader;
  final WebSessionManager _sessionManager;
  final WebTokenStorage _tokenStorage;

  RiverpodAuthNotifier({
    required WebAuthService authService,
    required SponsorConfigLoader configLoader,
    required WebSessionManager sessionManager,
    required WebTokenStorage tokenStorage,
  })  : _authService = authService,
        _configLoader = configLoader,
        _sessionManager = sessionManager,
        _tokenStorage = tokenStorage,
        super(AuthState.initial()) {
    _initializeSessionListeners();
  }

  void _initializeSessionListeners() {
    _sessionManager.onSessionExpired(() {
      logout();
    });

    _sessionManager.onSessionWarning(() {
      state = state.copyWith(
        sessionState: SessionState.warning,
      );
    });
  }

  @override
  void updateState(AuthState newState) {
    state = newState;
  }

  @override
  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = LoginRequest(
        username: username,
        password: password,
      );

      final result = await _authService.login(request);

      if (result is AuthSuccess) {
        await _tokenStorage.saveToken(result.token);
        
        final config = await _configLoader.loadConfig(result.token);
        _sessionManager.startSession(config.sessionTimeoutMinutes);

        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: result.user,
          token: result.token,
          sponsorConfig: config,
          sessionState: SessionState.active,
        );
      } else if (result is AuthFailure) {
        state = state.copyWith(
          isLoading: false,
          error: result.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: $e',
      );
    }
  }

  @override
  Future<void> logout() async {
    await _sessionManager.endSession();
    await _tokenStorage.deleteToken();
    _configLoader.clearCache();
    
    state = AuthState.initial();
  }

  @override
  void extendSession() {
    _sessionManager.extendSession();
    state = state.copyWith(
      sessionState: SessionState.active,
    );
  }

  @override
  Future<LinkingCodeValidation> validateLinkingCode(String code) async {
    return _authService.validateLinkingCode(code);
  }

  @override
  Future<void> register(RegistrationRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.register(request);

      if (result is AuthSuccess) {
        await _tokenStorage.saveToken(result.token);
        
        final config = await _configLoader.loadConfig(result.token);
        _sessionManager.startSession(config.sessionTimeoutMinutes);

        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: result.user,
          token: result.token,
          sponsorConfig: config,
          sessionState: SessionState.active,
        );
      } else if (result is AuthFailure) {
        state = state.copyWith(
          isLoading: false,
          error: result.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      );
    }
  }
}

/// Provider for token storage.
final tokenStorageProvider = Provider<WebTokenStorage>((ref) {
  return WebTokenStorage();
});

/// Provider for session manager.
final sessionManagerProvider = Provider<WebSessionManager>((ref) {
  return WebSessionManager();
});

/// Provider for HTTP client (requires baseUrl configuration).
Provider<AuthHttpClient> authHttpClientProvider(String baseUrl) {
  return Provider<AuthHttpClient>((ref) {
    final tokenStorage = ref.watch(tokenStorageProvider);
    return AuthHttpClient(
      baseUrl: baseUrl,
      tokenStorage: tokenStorage,
    );
  });
}

/// Provider for auth service (requires baseUrl configuration).
Provider<WebAuthService> authServiceProvider(String baseUrl) {
  return Provider<WebAuthService>((ref) {
    final httpClient = ref.watch(authHttpClientProvider(baseUrl));
    return WebAuthService(httpClient);
  });
}

/// Provider for config loader.
final configLoaderProvider = Provider<SponsorConfigLoader>((ref) {
  return SponsorConfigLoader.create();
});

/// Provider for authentication state (requires baseUrl configuration).
StateNotifierProvider<RiverpodAuthNotifier, AuthState> authProvider(String baseUrl) {
  return StateNotifierProvider<RiverpodAuthNotifier, AuthState>((ref) {
    return RiverpodAuthNotifier(
      authService: ref.watch(authServiceProvider(baseUrl)),
      configLoader: ref.watch(configLoaderProvider),
      sessionManager: ref.watch(sessionManagerProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    );
  });
}
