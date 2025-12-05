/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///   REQ-d00080: Web Session Management Implementation
///   REQ-d00082: Password Hashing Implementation
///   REQ-d00083: Browser Storage Clearing
///   REQ-d00084: Sponsor Configuration Loading
///
/// Flutter Web client authentication library for HHT Diary.
///
/// This package provides client-side authentication functionality for the
/// HHT Diary web application, including:
///
/// - **Authentication**: User registration, login, token management
/// - **Session Management**: Inactivity tracking, timeout warnings, session cleanup
/// - **Password Security**: Client-side Argon2id hashing before transmission
/// - **Storage Management**: In-memory token storage, browser storage clearing
/// - **State Management**: Support for both Signals and Riverpod
/// - **HTTP Client**: Automatic JWT token injection
///
/// ## Usage
///
/// ### With Signals:
///
/// ```dart
/// final authAdapter = createSignalsAuthAdapter(
///   authService: webAuthService,
///   configLoader: sponsorConfigLoader,
///   sessionManager: webSessionManager,
///   tokenStorage: webTokenStorage,
/// );
///
/// // Access reactive state
/// final isAuthenticated = authAdapter.stateSignal.value.isAuthenticated;
///
/// // Perform login
/// await authAdapter.login('username', 'password');
/// ```
///
/// ### With Riverpod:
///
/// ```dart
/// // Configure provider with auth service base URL
/// final authStateProvider = authProvider('https://auth.example.com');
///
/// // In your widget:
/// final authState = ref.watch(authStateProvider);
/// final authNotifier = ref.read(authStateProvider.notifier);
///
/// // Perform login
/// await authNotifier.login('username', 'password');
/// ```
///
/// ## Security Features
///
/// - In-memory token storage (no localStorage for security)
/// - Client-side password hashing with Argon2id
/// - Comprehensive browser storage clearing on logout
/// - Automatic session timeout and warning
/// - JWT token injection in HTTP requests
///
library hht_auth_client;

// Re-export core models and interfaces
export 'package:hht_auth_core/hht_auth_core.dart';

// Storage
export 'src/storage/web_token_storage.dart';

// Services
export 'src/services/web_auth_service.dart';
export 'src/services/argon2_password_hasher.dart';
export 'src/services/sponsor_config_loader.dart';

// Session Management
export 'src/session/web_session_manager.dart';
export 'src/session/inactivity_tracker.dart';
export 'src/session/storage_clearer.dart';

// State Management
export 'src/state/auth_state.dart';
export 'src/state/auth_state_notifier.dart';
export 'src/state/signals_auth_adapter.dart';
export 'src/state/riverpod_auth_adapter.dart';

// HTTP
export 'src/http/auth_http_client.dart';
