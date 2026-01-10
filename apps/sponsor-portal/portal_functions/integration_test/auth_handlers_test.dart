// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Integration tests for auth handlers
// Requires PostgreSQL database to be running

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    // Initialize database
    // For local dev, default to no SSL (docker container doesn't support it)
    final sslEnv = Platform.environment['DB_SSL'];
    final useSsl = sslEnv == 'true';

    final config = DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          'postgres',
      useSsl: useSsl,
    );

    await Database.instance.initialize(config);
  });

  tearDownAll(() async {
    await Database.instance.close();
  });

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Request createPostRequest(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  group('registerHandler', () {
    final testUsername = 'regtest_${DateTime.now().millisecondsSinceEpoch}';
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';
    const testAppUuid = 'test-app-uuid';

    test('creates new user with valid data', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': testUsername,
        'passwordHash': testPasswordHash,
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['jwt'], isNotNull);
      expect(json['userId'], isNotNull);
      expect(json['username'], equals(testUsername.toLowerCase()));

      // Verify JWT is valid
      final payload = verifyJwtToken(json['jwt'] as String);
      expect(payload, isNotNull);
      expect(payload!.userId, equals(json['userId']));
    });

    test('rejects duplicate username', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': testUsername,
        'passwordHash': testPasswordHash,
        'appUuid': 'different-uuid',
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(409));

      final json = await getResponseJson(response);
      expect(json['error'], contains('already taken'));
    });

    test('rejects short username', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': 'short',
        'passwordHash': testPasswordHash,
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('6 characters'));
    });

    test('rejects username with @ symbol', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': 'user@example.com',
        'passwordHash': testPasswordHash,
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('@'));
    });

    test('rejects username with special characters', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': 'user-name!',
        'passwordHash': testPasswordHash,
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('accepts username with underscore', () async {
      final uniqueUsername =
          'test_user_${DateTime.now().millisecondsSinceEpoch}';
      final request = createPostRequest('/api/v1/auth/register', {
        'username': uniqueUsername,
        'passwordHash': testPasswordHash,
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(200));
    });

    test('rejects invalid password hash format', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': 'newuser_${DateTime.now().millisecondsSinceEpoch}',
        'passwordHash': 'not-a-valid-hash',
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('rejects missing appUuid', () async {
      final request = createPostRequest('/api/v1/auth/register', {
        'username': 'newuser_${DateTime.now().millisecondsSinceEpoch}',
        'passwordHash': testPasswordHash,
      });

      final response = await registerHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('App UUID'));
    });

    test('rejects GET method', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/auth/register'),
      );

      final response = await registerHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('normalizes username to lowercase', () async {
      final mixedCase = 'MixedCase_${DateTime.now().millisecondsSinceEpoch}';
      final request = createPostRequest('/api/v1/auth/register', {
        'username': mixedCase,
        'passwordHash': testPasswordHash,
        'appUuid': testAppUuid,
      });

      final response = await registerHandler(request);
      final json = await getResponseJson(response);

      expect(json['username'], equals(mixedCase.toLowerCase()));
    });
  });

  group('loginHandler', () {
    late String testUsername;
    late String testUserId;
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';

    setUpAll(() async {
      // Create a user for login tests
      testUsername = 'logintest_${DateTime.now().millisecondsSinceEpoch}';
      final request = createPostRequest('/api/v1/auth/register', {
        'username': testUsername,
        'passwordHash': testPasswordHash,
        'appUuid': 'test-app',
      });

      final response = await registerHandler(request);
      final json = await getResponseJson(response);
      testUserId = json['userId'] as String;
    });

    test('authenticates valid credentials', () async {
      final request = createPostRequest('/api/v1/auth/login', {
        'username': testUsername,
        'passwordHash': testPasswordHash,
      });

      final response = await loginHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['jwt'], isNotNull);
      expect(json['userId'], equals(testUserId));
      expect(json['username'], equals(testUsername.toLowerCase()));
    });

    test('rejects wrong password', () async {
      final request = createPostRequest('/api/v1/auth/login', {
        'username': testUsername,
        'passwordHash': 'wrong'.padRight(64, '0'),
      });

      final response = await loginHandler(request);
      expect(response.statusCode, equals(401));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Invalid'));
    });

    test('rejects unknown username', () async {
      final request = createPostRequest('/api/v1/auth/login', {
        'username': 'nonexistent_user_12345',
        'passwordHash': testPasswordHash,
      });

      final response = await loginHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('is case-insensitive for username', () async {
      final request = createPostRequest('/api/v1/auth/login', {
        'username': testUsername.toUpperCase(),
        'passwordHash': testPasswordHash,
      });

      final response = await loginHandler(request);
      expect(response.statusCode, equals(200));
    });

    test('rejects missing username', () async {
      final request = createPostRequest('/api/v1/auth/login', {
        'passwordHash': testPasswordHash,
      });

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('rejects missing password', () async {
      final request = createPostRequest('/api/v1/auth/login', {
        'username': testUsername,
      });

      final response = await loginHandler(request);
      expect(response.statusCode, equals(400));
    });
  });

  group('changePasswordHandler', () {
    late String testAuthToken;
    late String testUsername;
    const testPasswordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';
    const newPasswordHash =
        '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b';

    setUpAll(() async {
      // Create a user for password change tests
      testUsername = 'pwdtest_${DateTime.now().millisecondsSinceEpoch}';
      final request = createPostRequest('/api/v1/auth/register', {
        'username': testUsername,
        'passwordHash': testPasswordHash,
        'appUuid': 'test-app',
      });

      final response = await registerHandler(request);
      final json = await getResponseJson(response);
      testAuthToken = json['jwt'] as String;
    });

    test('changes password with valid credentials', () async {
      final request = createPostRequest(
        '/api/v1/auth/change-password',
        {
          'currentPasswordHash': testPasswordHash,
          'newPasswordHash': newPasswordHash,
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['success'], isTrue);

      // Verify new password works
      final loginRequest = createPostRequest('/api/v1/auth/login', {
        'username': testUsername,
        'passwordHash': newPasswordHash,
      });

      final loginResponse = await loginHandler(loginRequest);
      expect(loginResponse.statusCode, equals(200));
    });

    test('rejects without authorization', () async {
      final request = createPostRequest('/api/v1/auth/change-password', {
        'currentPasswordHash': testPasswordHash,
        'newPasswordHash': newPasswordHash,
      });

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('rejects wrong current password', () async {
      final request = createPostRequest(
        '/api/v1/auth/change-password',
        {
          'currentPasswordHash': 'wrong'.padRight(64, '0'),
          'newPasswordHash': newPasswordHash,
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(401));

      final json = await getResponseJson(response);
      expect(json['error'], contains('incorrect'));
    });

    test('rejects invalid new password format', () async {
      final request = createPostRequest(
        '/api/v1/auth/change-password',
        {'currentPasswordHash': newPasswordHash, 'newPasswordHash': 'invalid'},
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await changePasswordHandler(request);
      expect(response.statusCode, equals(400));
    });
  });
}
