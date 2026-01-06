// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Unit tests for auth handlers (non-database aspects)

import 'dart:convert';

import 'package:diary_functions/diary_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('registerHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/auth/register'),
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 405 for PUT request', () async {
      final request = Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({'username': 'test', 'passwordHash': 'hash'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 405 for DELETE request', () async {
      final request = Request(
        'DELETE',
        Uri.parse('http://localhost/api/v1/auth/register'),
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 400 for invalid JSON body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: 'not valid json',
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid JSON'));
    });

    test('returns 400 for empty body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: '',
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for null username', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'appUuid': 'test-app',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('6 characters'));
    });

    test('returns 400 for username shorter than 6 characters', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'short',
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'appUuid': 'test-app',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('6 characters'));
    });

    test('returns 400 for username with @ symbol', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'test@user',
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'appUuid': 'test-app',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('@'));
    });

    test('returns 400 for username with special characters', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'test-user!',
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'appUuid': 'test-app',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('letters, numbers, and underscores'));
    });

    test('returns 400 for invalid password hash (too short)', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'validuser123',
          'passwordHash': 'tooshort',
          'appUuid': 'test-app',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for invalid password hash (not hex)', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'validuser123',
          'passwordHash':
              'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
          'appUuid': 'test-app',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for missing appUuid', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'validuser123',
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('App UUID'));
    });

    test('returns 400 for empty appUuid', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: jsonEncode({
          'username': 'validuser123',
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'appUuid': '',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));
    });
  });

  group('loginHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/auth/login'),
      );

      final response = await loginHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 400 for invalid JSON body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        body: '{invalid json',
        headers: {'Content-Type': 'application/json'},
      );

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid JSON'));
    });

    test('returns 400 for missing username', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        body: jsonEncode({
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Username'));
    });

    test('returns 400 for empty username', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        body: jsonEncode({
          'username': '',
          'passwordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for missing passwordHash', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        body: jsonEncode({'username': 'testuser'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Password'));
    });

    test('returns 400 for empty passwordHash', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        body: jsonEncode({'username': 'testuser', 'passwordHash': ''}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));
    });
  });

  group('changePasswordHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/auth/change-password'),
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 401 for missing authorization', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/change-password'),
        body: jsonEncode({
          'currentPasswordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'newPasswordHash':
              '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(401));

      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 for invalid JWT', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/change-password'),
        body: jsonEncode({
          'currentPasswordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'newPasswordHash':
              '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer invalid.jwt.token',
        },
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 400 for invalid new password hash format', () async {
      // Create a valid JWT for the test
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/change-password'),
        body: jsonEncode({
          'currentPasswordHash':
              '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57',
          'newPasswordHash': 'invalid-hash',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for invalid JSON body', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/change-password'),
        body: 'not json',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(400));
    });
  });

  group('JwtPayload', () {
    test('toJson includes all required fields', () {
      final payload = JwtPayload(
        authCode: 'test-auth-code',
        userId: 'test-user-id',
        iat: 1234567890,
      );

      final json = payload.toJson();

      expect(json['authCode'], equals('test-auth-code'));
      expect(json['userId'], equals('test-user-id'));
      expect(json['iat'], equals(1234567890));
    });

    test('toJson includes optional fields when set', () {
      final payload = JwtPayload(
        authCode: 'test-auth-code',
        userId: 'test-user-id',
        username: 'testuser',
        iat: 1234567890,
        exp: 1234657890,
        iss: 'test-issuer',
      );

      final json = payload.toJson();

      expect(json['username'], equals('testuser'));
      expect(json['exp'], equals(1234657890));
      expect(json['iss'], equals('test-issuer'));
    });

    test('toJson excludes null optional fields', () {
      final payload = JwtPayload(
        authCode: 'test-auth-code',
        userId: 'test-user-id',
        iat: 1234567890,
      );

      final json = payload.toJson();

      expect(json.containsKey('username'), isFalse);
      expect(json.containsKey('exp'), isFalse);
      expect(json.containsKey('iss'), isFalse);
    });

    test('fromJson creates correct payload', () {
      final json = {
        'authCode': 'auth-123',
        'userId': 'user-456',
        'username': 'testuser',
        'iat': 1000000,
        'exp': 2000000,
        'iss': 'hht-diary-mvp',
      };

      final payload = JwtPayload.fromJson(json);

      expect(payload.authCode, equals('auth-123'));
      expect(payload.userId, equals('user-456'));
      expect(payload.username, equals('testuser'));
      expect(payload.iat, equals(1000000));
      expect(payload.exp, equals(2000000));
      expect(payload.iss, equals('hht-diary-mvp'));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'authCode': 'auth-123',
        'userId': 'user-456',
        'iat': 1000000,
      };

      final payload = JwtPayload.fromJson(json);

      expect(payload.username, isNull);
      expect(payload.exp, isNull);
      expect(payload.iss, isNull);
    });
  });
}
