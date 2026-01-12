// Tests for ApiClient and ApiResponse
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: User Management API

import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';

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
}
