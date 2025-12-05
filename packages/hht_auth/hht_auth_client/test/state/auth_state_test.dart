/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation

import 'package:test/test.dart';
import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_client/src/state/auth_state.dart';

void main() {
  group('AuthState', () {
    test('initial state should be unauthenticated', () {
      const state = AuthState.initial();
      
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.user, isNull);
      expect(state.token, isNull);
      expect(state.sponsorConfig, isNull);
      expect(state.error, isNull);
      expect(state.sessionState, equals(SessionState.inactive));
    });

    test('should create authenticated state', () {
      const testToken = 'test-jwt-token';
      final testUser = WebUser(
        id: 'user-123',
        username: 'testuser',
        passwordHash: 'hash',
        sponsorId: 'sponsor-1',
        linkingCode: 'ABC-123',
        appUuid: 'app-uuid',
        createdAt: DateTime.now(),
        failedAttempts: 0,
      );
      final testConfig = SponsorConfig(
        sponsorId: 'sponsor-1',
        sponsorName: 'Test Sponsor',
        portalUrl: 'https://portal.test',
        firestoreProjectId: 'test-project',
        firestoreApiKey: 'api-key',
        sessionTimeoutMinutes: 5,
        branding: const SponsorBranding(
          logoUrl: 'https://logo.test',
          primaryColor: 0xFF0000FF,
          secondaryColor: 0xFF00FF00,
          welcomeMessage: 'Welcome',
        ),
      );

      final state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: testUser,
        token: testToken,
        sponsorConfig: testConfig,
        sessionState: SessionState.active,
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.user, equals(testUser));
      expect(state.token, equals(testToken));
      expect(state.sponsorConfig, equals(testConfig));
      expect(state.sessionState, equals(SessionState.active));
    });

    test('should create loading state', () {
      const state = AuthState(
        isAuthenticated: false,
        isLoading: true,
        sessionState: SessionState.inactive,
      );

      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('should create error state', () {
      const errorMessage = 'Authentication failed';
      const state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: errorMessage,
        sessionState: SessionState.inactive,
      );

      expect(state.error, equals(errorMessage));
      expect(state.isAuthenticated, isFalse);
    });

    test('should support session state changes', () {
      const activeState = AuthState(
        isAuthenticated: true,
        isLoading: false,
        sessionState: SessionState.active,
      );

      const warningState = AuthState(
        isAuthenticated: true,
        isLoading: false,
        sessionState: SessionState.warning,
      );

      expect(activeState.sessionState, equals(SessionState.active));
      expect(warningState.sessionState, equals(SessionState.warning));
    });

    test('copyWith should create new state with updated fields', () {
      final originalState = AuthState.initial();
      final newState = originalState.copyWith(
        isAuthenticated: true,
        token: 'new-token',
      );

      expect(newState.isAuthenticated, isTrue);
      expect(newState.token, equals('new-token'));
      expect(newState.isLoading, equals(originalState.isLoading));
      expect(newState.sessionState, equals(originalState.sessionState));
    });

    test('copyWith should preserve unmodified fields', () {
      const originalToken = 'original-token';
      final originalState = AuthState(
        isAuthenticated: true,
        isLoading: false,
        token: originalToken,
        sessionState: SessionState.active,
      );

      final newState = originalState.copyWith(
        sessionState: SessionState.warning,
      );

      expect(newState.token, equals(originalToken));
      expect(newState.isAuthenticated, equals(originalState.isAuthenticated));
      expect(newState.sessionState, equals(SessionState.warning));
    });

    test('equality should compare all fields', () {
      final state1 = AuthState.initial();
      final state2 = AuthState.initial();
      final state3 = AuthState.initial().copyWith(isAuthenticated: true);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
