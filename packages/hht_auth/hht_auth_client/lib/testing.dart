/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///   REQ-d00080: Web Session Management Implementation
///
/// Testing utilities for hht_auth_client.
///
/// This library provides fakes and mocks for testing authentication
/// functionality without making real network requests or managing actual sessions.
///
/// ## Usage
///
/// ```dart
/// import 'package:hht_auth_client/testing.dart';
///
/// void main() {
///   test('session timeout', () {
///     final sessionManager = FakeWebSessionManager();
///     sessionManager.startSession(5);
///     
///     // Manually trigger timeout
///     sessionManager.triggerExpired();
///     
///     expect(sessionManager.currentState, equals(SessionState.expired));
///   });
///
///   test('auth service', () {
///     final mockClient = MockHttpClient();
///     mockClient.mockJsonResponse('/auth/login', {
///       'token': 'test-token',
///       'user': {...},
///     });
///     
///     // Use mockClient in your tests
///   });
/// }
/// ```
library hht_auth_client_testing;

// Re-export core testing utilities
export 'package:hht_auth_core/testing.dart';

// Client testing utilities
export 'testing/fake_web_session_manager.dart';
export 'testing/mock_http_client.dart';
