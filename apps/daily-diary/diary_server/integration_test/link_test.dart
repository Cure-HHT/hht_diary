// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//
// Integration tests for patient linking endpoint
// Requires PostgreSQL database to be running

@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_server.dart';

void main() {
  late TestServer server;
  late http.Client client;

  setUpAll(() async {
    server = TestServer();
    await server.start();
    client = http.Client();
  });

  tearDownAll(() async {
    client.close();
    await server.stop();
  });

  group('Link Handler Integration Tests', () {
    late String authToken;
    final testUsername = 'linktest_${DateTime.now().millisecondsSinceEpoch}';
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';

    setUp(() async {
      // Create a user for link tests
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': testUsername,
          'passwordHash': testPasswordHash,
          'appUuid': 'test-app-${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        authToken = body['jwt'] as String;
      }
    });

    test('POST /api/v1/user/link returns 405 for GET requests', () async {
      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      // shelf_router returns 404 for unmatched routes (GET vs POST)
      expect(response.statusCode, anyOf(equals(404), equals(405)));
    });

    test('POST /api/v1/user/link returns 401 without authorization', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': 'CAXXXXXXXX'}),
      );

      expect(response.statusCode, equals(401));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('authorization'));
    });

    test('POST /api/v1/user/link returns 400 for missing code', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(<String, dynamic>{}),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('linking code'));
    });

    test(
      'POST /api/v1/user/link returns 400 for invalid code format',
      () async {
        final response = await client.post(
          Uri.parse('${server.baseUrl}/api/v1/user/link'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'code': 'SHORT'}),
        );

        expect(response.statusCode, equals(400));

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('10 characters'));
      },
    );

    test('POST /api/v1/user/link returns 400 for non-existent code', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'code': 'CAXXXXXXXX'}),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid linking code'));
    });

    test('POST /api/v1/user/link accepts code with dash formatting', () async {
      // Code with dash should be normalized and validated
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'code': 'CAXXX-XXXXX'}),
      );

      // Should fail with invalid code (not format error)
      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid linking code'));
    });
  });
}
