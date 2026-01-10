/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// Signals adapter for authentication state management.
///
/// Wraps AuthStateNotifier in a Signals-compatible interface.

import 'package:signals_core/signals_core.dart';
import 'package:hht_auth_client/src/state/auth_state.dart';
import 'package:hht_auth_client/src/state/auth_state_notifier.dart';
import 'package:hht_auth_client/src/services/web_auth_service.dart';
import 'package:hht_auth_client/src/services/sponsor_config_loader.dart';
import 'package:hht_auth_client/src/session/web_session_manager.dart';
import 'package:hht_auth_client/src/storage/web_token_storage.dart';
import 'package:hht_auth_core/hht_auth_core.dart';

/// Signals-based authentication state manager.
///
/// Provides reactive authentication state using Signals.
class SignalsAuthAdapter extends AuthStateNotifier {
  final Signal<AuthState> _stateSignal = signal(AuthState.initial());

  SignalsAuthAdapter({
    required super.authService,
    required super.configLoader,
    required super.sessionManager,
    required super.tokenStorage,
  });

  /// Reactive authentication state signal.
  Signal<AuthState> get stateSignal => _stateSignal;

  @override
  AuthState get state => _stateSignal.value;

  @override
  void updateState(AuthState newState) {
    _stateSignal.value = newState;
  }

  /// Disposes of the adapter and cleans up resources.
  void dispose() {
    // Signals automatically handle cleanup
  }
}

/// Creates a Signals auth adapter with all dependencies.
SignalsAuthAdapter createSignalsAuthAdapter({
  required WebAuthService authService,
  required SponsorConfigLoader configLoader,
  required WebSessionManager sessionManager,
  required WebTokenStorage tokenStorage,
}) {
  return SignalsAuthAdapter(
    authService: authService,
    configLoader: configLoader,
    sessionManager: sessionManager,
    tokenStorage: tokenStorage,
  );
}
