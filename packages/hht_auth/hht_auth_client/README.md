# hht_auth_client

Flutter Web client authentication library for HHT Diary.

## Features

- **User Authentication**: Registration, login, token refresh, password change
- **Session Management**: Automatic timeout with configurable duration (1-30 minutes)
- **Inactivity Tracking**: Monitors mouse, keyboard, and touch events
- **Password Security**: Client-side Argon2id hashing with OWASP parameters
- **Token Management**: In-memory storage (no localStorage for security)
- **Browser Storage Clearing**: Complete cleanup on logout (localStorage, sessionStorage, cookies, IndexedDB, Cache Storage)
- **State Management**: Supports both Signals and Riverpod
- **HTTP Client**: Automatic JWT token injection

## Requirements

- **REQ-d00078**: HHT Diary Auth Service interfaces
- **REQ-d00080**: Web Session Management Implementation
- **REQ-d00082**: Password Hashing Implementation (Argon2id)
- **REQ-d00083**: Browser Storage Clearing
- **REQ-d00084**: Sponsor Configuration Loading

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  hht_auth_client:
    path: ../packages/hht_auth/hht_auth_client
```

## Usage

### With Signals

```dart
import 'package:hht_auth_client/hht_auth_client.dart';

// Create dependencies
final tokenStorage = WebTokenStorage();
final sessionManager = WebSessionManager();
final httpClient = AuthHttpClient(
  baseUrl: 'https://auth.example.com',
  tokenStorage: tokenStorage,
);
final authService = WebAuthService(httpClient);
final configLoader = SponsorConfigLoader(httpClient);

// Create Signals adapter
final authAdapter = createSignalsAuthAdapter(
  authService: authService,
  configLoader: configLoader,
  sessionManager: sessionManager,
  tokenStorage: tokenStorage,
);

// Login
await authAdapter.login('username', 'password');

// Watch state reactively
effect(() {
  print('Authenticated: ${authAdapter.stateSignal.value.isAuthenticated}');
});

// Logout
await authAdapter.logout();
```

### With Riverpod

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hht_auth_client/hht_auth_client.dart';

// Configure auth provider with base URL
final myAuthProvider = authProvider('https://auth.example.com');

// In your widget
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(myAuthProvider);
    final authNotifier = ref.read(myAuthProvider.notifier);

    if (authState.isAuthenticated) {
      return HomeScreen();
    }

    return ElevatedButton(
      onPressed: () async {
        await authNotifier.login('username', 'password');
      },
      child: Text('Login'),
    );
  }
}
```

## Architecture

### Components

1. **WebTokenStorage**: In-memory token storage (implements `TokenStorage`)
2. **Argon2PasswordHasher**: Client-side password hashing (implements `PasswordHasher`)
3. **WebSessionManager**: Session lifecycle management (implements `SessionManager`)
4. **InactivityTracker**: User activity monitoring
5. **StorageClearer**: Browser storage cleanup utility
6. **WebAuthService**: HTTP-based auth service client (implements `AuthService`)
7. **SponsorConfigLoader**: Loads and caches sponsor configuration
8. **AuthHttpClient**: HTTP client with automatic token injection

### State Management

- **AuthState**: Immutable state model
- **AuthStateNotifier**: Base class with common logic
- **SignalsAuthAdapter**: Signals integration
- **RiverpodAuthAdapter**: Riverpod integration

## Security

- **No localStorage**: Tokens stored in memory only, cleared on page refresh
- **Client-side hashing**: Passwords hashed with Argon2id before network transmission
- **Complete cleanup**: All browser storage cleared on logout (localStorage, sessionStorage, cookies, IndexedDB, Cache Storage)
- **Session timeout**: Configurable inactivity timeout (default 2 minutes)
- **Warning before expiry**: 30-second warning before session timeout
- **Automatic token injection**: JWT tokens automatically added to HTTP requests

## Testing

```dart
import 'package:hht_auth_client/testing.dart';
import 'package:test/test.dart';

void main() {
  test('session timeout', () {
    final sessionManager = FakeWebSessionManager();
    sessionManager.startSession(5);
    
    // Manually trigger timeout
    sessionManager.triggerExpired();
    
    expect(sessionManager.currentState, equals(SessionState.expired));
  });

  test('mock HTTP responses', () {
    final mockClient = MockHttpClient();
    mockClient.mockJsonResponse('/auth/login', {
      'token': 'test-token',
      'user': {
        'id': 'user-123',
        'username': 'testuser',
        // ...
      },
    });
    
    // Use mockClient in your tests
  });
}
```

## Browser Compatibility

- Chrome (latest 2 versions)
- Firefox (latest 2 versions)
- Safari (latest 2 versions)
- Edge (latest 2 versions)

## License

Internal use only - Not published to pub.dev
