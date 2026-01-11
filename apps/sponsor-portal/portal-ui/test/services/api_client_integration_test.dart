// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: User Management API

// Service tests for ApiClient
// Uses firebase_auth_mocks and MockClient for HTTP

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

void main() {
  group('ApiClient with mocked dependencies', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUser mockUser;
    late AuthService authService;

    setUp(() async {
      mockUser = MockUser(
        uid: 'test-firebase-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Create auth service that returns a token
      final authHttpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'user-123',
            'email': 'test@example.com',
            'name': 'Test User',
            'role': 'Administrator',
            'status': 'active',
            'sites': [],
          }),
          200,
        );
      });

      authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: authHttpClient,
      );

      // Sign in to get a valid auth state
      await authService.signIn('test@example.com', 'password');
    });

    group('get', () {
      test('makes authenticated GET request', () async {
        final mockHttpClient = MockClient((request) async {
          // Verify authorization header is present
          expect(request.headers['Authorization'], startsWith('Bearer '));
          expect(request.headers['Content-Type'], 'application/json');
          expect(request.method, 'GET');

          return http.Response(jsonEncode({'data': 'test-value'}), 200);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);

        final response = await apiClient.get('/api/test');

        expect(response.isSuccess, isTrue);
        expect(response.statusCode, 200);
        expect(response.data['data'], 'test-value');
      });

      test('returns error for 404', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'Not found'}), 404);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.get('/api/missing');

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, 404);
        expect(response.error, 'Not found');
      });

      test('handles network error', () async {
        final mockHttpClient = MockClient((request) async {
          throw Exception('Network error');
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.get('/api/test');

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, 500);
        expect(response.error, contains('Network error'));
      });
    });

    group('post', () {
      test('makes authenticated POST request with body', () async {
        final mockHttpClient = MockClient((request) async {
          expect(request.headers['Authorization'], startsWith('Bearer '));
          expect(request.method, 'POST');

          // Verify body is sent
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Test');

          return http.Response(
            jsonEncode({'id': 'new-123', 'name': 'Test'}),
            201,
          );
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.post('/api/users', {'name': 'Test'});

        expect(response.isSuccess, isTrue);
        expect(response.statusCode, 201);
        expect(response.data['id'], 'new-123');
      });

      test('returns error for 400 bad request', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'Invalid data'}), 400);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.post('/api/users', {'bad': 'data'});

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, 400);
        expect(response.error, 'Invalid data');
      });

      test('handles network error', () async {
        final mockHttpClient = MockClient((request) async {
          throw Exception('Connection refused');
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.post('/api/test', {});

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, 500);
        expect(response.error, contains('Network error'));
      });
    });

    group('patch', () {
      test('makes authenticated PATCH request', () async {
        final mockHttpClient = MockClient((request) async {
          expect(request.headers['Authorization'], startsWith('Bearer '));
          expect(request.method, 'PATCH');

          return http.Response(jsonEncode({'success': true}), 200);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.patch('/api/users/123', {
          'status': 'revoked',
        });

        expect(response.isSuccess, isTrue);
        expect(response.data['success'], isTrue);
      });

      test('returns error for 403 forbidden', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'Not authorized'}), 403);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.patch('/api/admin', {});

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, 403);
        expect(response.error, 'Not authorized');
      });

      test('handles network error', () async {
        final mockHttpClient = MockClient((request) async {
          throw Exception('Timeout');
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.patch('/api/test', {});

        expect(response.isSuccess, isFalse);
        expect(response.error, contains('Network error'));
      });
    });

    group('response parsing', () {
      test('handles empty response body', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response('', 204);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.get('/api/delete');

        expect(response.isSuccess, isTrue);
        expect(response.statusCode, 204);
      });

      test('handles non-JSON error response', () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final apiClient = ApiClient(authService, httpClient: mockHttpClient);
        final response = await apiClient.get('/api/broken');

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, 500);
        expect(response.error, contains('parse'));
      });
    });
  });

  group('ApiClient without authentication', () {
    test('returns 401 when not authenticated', () async {
      final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
      final authHttpClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: authHttpClient,
      );

      final apiHttpClient = MockClient((request) async {
        return http.Response('OK', 200);
      });

      final apiClient = ApiClient(authService, httpClient: apiHttpClient);
      final response = await apiClient.get('/api/test');

      expect(response.isSuccess, isFalse);
      expect(response.statusCode, 401);
      expect(response.error, 'Not authenticated');
    });
  });
}
