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
    // Note: linkHandler no longer requires pre-authentication
    // The linking code IS the authentication mechanism (REQ-p70007)
    // These tests verify code validation without prior login

    test('POST /api/v1/user/link returns 405 for GET requests', () async {
      // No auth required - just testing method rejection
      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
      );

      // shelf_router returns 404 for unmatched routes (GET vs POST)
      expect(response.statusCode, anyOf(equals(404), equals(405)));
    });

    // Note: linkHandler no longer requires Authorization - the linking code IS the auth
    // JWT is returned upon successful linking (REQ-p70007)

    test('POST /api/v1/user/link returns 400 for missing code', () async {
      // No auth required - linking code is the authentication
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{}),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('linking code'));
    });

    test(
      'POST /api/v1/user/link returns 400 for invalid code format',
      () async {
        // No auth required - linking code is the authentication
        final response = await client.post(
          Uri.parse('${server.baseUrl}/api/v1/user/link'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': 'SHORT'}),
        );

        expect(response.statusCode, equals(400));

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('10 characters'));
      },
    );

    test('POST /api/v1/user/link returns 400 for non-existent code', () async {
      // No auth required - linking code is the authentication
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': 'CAXXXXXXXX'}),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid linking code'));
    });

    test('POST /api/v1/user/link accepts code with dash formatting', () async {
      // Code with dash should be normalized and validated
      // No auth required - linking code is the authentication
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': 'CAXXX-XXXXX'}),
      );

      // Should fail with invalid code (not format error)
      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid linking code'));
    });
  });
}
