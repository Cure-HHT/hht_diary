// Tests for ApiClient and ApiResponse
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: User Management API

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

void main() {
  group('ApiResponse', () {
    test('isSuccess returns true for 2xx status codes', () {
      expect(ApiResponse(statusCode: 200).isSuccess, isTrue);
      expect(ApiResponse(statusCode: 201).isSuccess, isTrue);
      expect(ApiResponse(statusCode: 204).isSuccess, isTrue);
      expect(ApiResponse(statusCode: 299).isSuccess, isTrue);
    });

    test('isSuccess returns false for non-2xx status codes', () {
      expect(ApiResponse(statusCode: 100).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 199).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 300).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 400).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 401).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 403).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 404).isSuccess, isFalse);
      expect(ApiResponse(statusCode: 500).isSuccess, isFalse);
    });

    test('stores data correctly', () {
      final response = ApiResponse(
        statusCode: 200,
        data: {'key': 'value', 'count': 42},
      );

      expect(response.data['key'], 'value');
      expect(response.data['count'], 42);
    });

    test('stores error correctly', () {
      final response = ApiResponse(statusCode: 401, error: 'Not authenticated');

      expect(response.error, 'Not authenticated');
      expect(response.isSuccess, isFalse);
    });

    test('can have both data and error', () {
      final response = ApiResponse(
        statusCode: 400,
        data: {'field': 'email'},
        error: 'Invalid email format',
      );

      expect(response.data['field'], 'email');
      expect(response.error, 'Invalid email format');
      expect(response.isSuccess, isFalse);
    });

    test('data and error can be null', () {
      final response = ApiResponse(statusCode: 204);

      expect(response.data, isNull);
      expect(response.error, isNull);
      expect(response.isSuccess, isTrue);
    });
  });

  group('ApiClient.delete', () {
    test('sends DELETE request with body and returns success', () async {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );

      String? capturedMethod;
      String? capturedBody;
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/portal/me') {
          return http.Response(
            jsonEncode({
              'id': 'user-001',
              'email': 'test@example.com',
              'name': 'Test User',
              'status': 'active',
              'roles': ['Investigator'],
              'active_role': 'Investigator',
              'mfa_type': 'email_otp',
              'email_otp_required': true,
              'sites': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        capturedMethod = request.method;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('test@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      final response = await apiClient.delete(
        '/api/v1/portal/patients/p1/questionnaires/q1',
        body: {'reason': 'Test reason'},
      );

      expect(response.isSuccess, isTrue);
      expect(capturedMethod, 'DELETE');
      expect(capturedBody, contains('Test reason'));
    });

    test('returns 401 when not authenticated', () async {
      final mockFirebaseAuth = MockFirebaseAuth(signedIn: false);
      final mockHttpClient = MockClient((_) async => http.Response('', 500));
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      final response = await apiClient.delete('/api/v1/test');

      expect(response.isSuccess, isFalse);
      expect(response.statusCode, 401);
      expect(response.error, 'Not authenticated');
    });
  });
}
