// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Integration tests for authentication endpoints
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

  group('Auth Integration Tests', () {
    final testUsername = 'testuser_${DateTime.now().millisecondsSinceEpoch}';
    // SHA-256 of 'testpassword123'
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';
    const testAppUuid = 'test-app-uuid-12345';

    String? authToken;
    String? userId;

    test('POST /api/v1/auth/register creates new user', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': testUsername,
          'passwordHash': testPasswordHash,
          'appUuid': testAppUuid,
        }),
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['jwt'], isNotNull);
      expect(body['userId'], isNotNull);
      expect(body['username'], equals(testUsername.toLowerCase()));

      authToken = body['jwt'] as String;
      userId = body['userId'] as String;
    });

    test('POST /api/v1/auth/register rejects duplicate username', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': testUsername,
          'passwordHash': testPasswordHash,
          'appUuid': 'different-app-uuid',
        }),
      );

      expect(response.statusCode, equals(409));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('already taken'));
    });

    test('POST /api/v1/auth/register rejects short username', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'short',
          'passwordHash': testPasswordHash,
          'appUuid': testAppUuid,
        }),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('6 characters'));
    });

    test('POST /api/v1/auth/register rejects username with @', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'user@email.com',
          'passwordHash': testPasswordHash,
          'appUuid': testAppUuid,
        }),
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('@'));
    });

    test('POST /api/v1/auth/register rejects invalid password hash', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'newuser123456',
          'passwordHash': 'not-a-valid-hash',
          'appUuid': testAppUuid,
        }),
      );

      expect(response.statusCode, equals(400));
    });

    test('POST /api/v1/auth/login authenticates valid credentials', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': testUsername,
          'passwordHash': testPasswordHash,
        }),
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['jwt'], isNotNull);
      expect(body['userId'], equals(userId));
      expect(body['username'], equals(testUsername.toLowerCase()));
    });

    test('POST /api/v1/auth/login rejects wrong password', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': testUsername,
          'passwordHash': 'wrongpasswordhash'.padRight(64, '0'),
        }),
      );

      expect(response.statusCode, equals(401));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid'));
    });

    test('POST /api/v1/auth/login rejects unknown username', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'nonexistent_user_12345',
          'passwordHash': testPasswordHash,
        }),
      );

      expect(response.statusCode, equals(401));
    });

    test('POST /api/v1/auth/change-password updates password', () async {
      // New password hash
      const newPasswordHash =
          '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b';

      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'currentPasswordHash': testPasswordHash,
          'newPasswordHash': newPasswordHash,
        }),
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);

      // Verify new password works
      final loginResponse = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': testUsername,
          'passwordHash': newPasswordHash,
        }),
      );

      expect(loginResponse.statusCode, equals(200));
    });

    test('POST /api/v1/auth/change-password rejects without auth', () async {
      final response = await client.post(
        Uri.parse('${server.baseUrl}/api/v1/auth/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'currentPasswordHash': testPasswordHash,
          'newPasswordHash': 'newhash'.padRight(64, '0'),
        }),
      );

      expect(response.statusCode, equals(401));
    });
  });

  group('Health Check', () {
    test('GET /health returns ok status', () async {
      final response = await client.get(Uri.parse('${server.baseUrl}/health'));

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['status'], equals('ok'));
      expect(body['service'], equals('diary-server'));
    });
  });
}
