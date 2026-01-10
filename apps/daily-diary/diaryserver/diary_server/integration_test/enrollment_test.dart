// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// Integration tests for enrollment and sync endpoints
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

  group('Enrollment Integration Tests', () {
    late String authToken;
    final testUsername = 'enrolltest_${DateTime.now().millisecondsSinceEpoch}';
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';

    setUp(() async {
      // Create a user for enrollment tests
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

    test('POST /api/v1/user/enroll requires authentication', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/enroll'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': 'CUREHHT1'}),
      );

      expect(response.statusCode, equals(401));
    });

    test(
      'POST /api/v1/user/enroll rejects invalid enrollment code format',
      () async {
        final response = await client.post(
          Uri.parse('${server.baseUrl}/api/v1/user/enroll'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'code': 'INVALID'}),
        );

        expect(response.statusCode, equals(400));

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('Invalid enrollment code'));
      },
    );

    test('POST /api/v1/user/enroll rejects empty code', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/enroll'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'code': ''}),
      );

      expect(response.statusCode, equals(400));
    });

    // Note: Successful enrollment test would need a valid unused enrollment code
    // which requires test data setup in the database
  });

  group('Sync Integration Tests', () {
    late String authToken;
    final testUsername = 'synctest_${DateTime.now().millisecondsSinceEpoch}';
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';

    setUp(() async {
      // Create a user for sync tests
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

    test('POST /api/v1/user/sync requires authentication', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'events': []}),
      );

      expect(response.statusCode, equals(401));
    });

    test('POST /api/v1/user/sync rejects non-array events', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'events': 'not-an-array'}),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('array'));
    });

    test('POST /api/v1/user/sync accepts empty events array', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'events': <dynamic>[]}),
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['syncedCount'], equals(0));
    });

    test('POST /api/v1/user/records requires authentication', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/user/records'),
        headers: {'Content-Type': 'application/json'},
      );

      expect(response.statusCode, equals(401));
    });

    test(
      'POST /api/v1/user/records returns empty records for new user',
      () async {
        final response = await client.post(
          Uri.parse('${server.baseUrl}/api/v1/user/records'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        );

        expect(response.statusCode, equals(200));

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['records'], isA<List>());
      },
    );
  });
}
