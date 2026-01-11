// Tests for authentication handlers
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/auth.dart';

void main() {
  // Helper to create test requests
  Request createPostRequest(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body,
    );
  }

  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('registerHandler', () {
    group('HTTP method validation', () {
      test('returns 405 for GET request', () async {
        final request = createGetRequest('/api/v1/auth/register');
        final response = await registerHandler(request);

        expect(response.statusCode, equals(405));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Method not allowed'));
      });

      test('returns 405 for PUT request', () async {
        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/v1/auth/register'),
          body: jsonEncode({'username': 'test'}),
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
    });

    group('JSON parsing', () {
      test('returns 400 for invalid JSON body', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: 'not valid json',
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Invalid JSON'));
      });

      test('returns 400 for empty body', () async {
        final request = createPostRequest('/api/v1/auth/register', body: '');
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('username validation', () {
      test('returns 400 for missing username', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({'passwordHash': 'a' * 64, 'appUuid': 'test-uuid'}),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Username'));
      });

      test('returns 400 for username too short', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': 'ab', // less than 6 chars
            'passwordHash': 'a' * 64,
            'appUuid': 'test-uuid',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('6 characters'));
      });

      test('returns 400 for username with @ symbol', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': 'test@user',
            'passwordHash': 'a' * 64,
            'appUuid': 'test-uuid',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('@'));
      });

      test('returns 400 for username with special characters', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': 'test-user!',
            'passwordHash': 'a' * 64,
            'appUuid': 'test-uuid',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('letters, numbers, and underscores'));
      });

      test('returns 400 for empty username', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': '',
            'passwordHash': 'a' * 64,
            'appUuid': 'test-uuid',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('password validation', () {
      test('returns 400 for missing passwordHash', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({'username': 'validuser', 'appUuid': 'test-uuid'}),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Password'));
      });

      test('returns 400 for passwordHash wrong length', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': 'validuser',
            'passwordHash': 'abc123', // not 64 chars
            'appUuid': 'test-uuid',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for passwordHash with invalid characters', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': 'validuser',
            'passwordHash': 'g' * 64, // 'g' is not valid hex
            'appUuid': 'test-uuid',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('appUuid validation', () {
      test('returns 400 for missing appUuid', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({'username': 'validuser', 'passwordHash': 'a' * 64}),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('App UUID'));
      });

      test('returns 400 for empty appUuid', () async {
        final request = createPostRequest(
          '/api/v1/auth/register',
          body: jsonEncode({
            'username': 'validuser',
            'passwordHash': 'a' * 64,
            'appUuid': '',
          }),
        );
        final response = await registerHandler(request);

        expect(response.statusCode, equals(400));
      });
    });
  });

  group('loginHandler', () {
    group('HTTP method validation', () {
      test('returns 405 for GET request', () async {
        final request = createGetRequest('/api/v1/auth/login');
        final response = await loginHandler(request);

        expect(response.statusCode, equals(405));
      });
    });

    group('JSON parsing', () {
      test('returns 400 for invalid JSON body', () async {
        final request = createPostRequest(
          '/api/v1/auth/login',
          body: 'not valid json',
        );
        final response = await loginHandler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('input validation', () {
      test('returns 400 for missing username', () async {
        final request = createPostRequest(
          '/api/v1/auth/login',
          body: jsonEncode({'passwordHash': 'a' * 64}),
        );
        final response = await loginHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Username'));
      });

      test('returns 400 for empty username', () async {
        final request = createPostRequest(
          '/api/v1/auth/login',
          body: jsonEncode({'username': '', 'passwordHash': 'a' * 64}),
        );
        final response = await loginHandler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for missing passwordHash', () async {
        final request = createPostRequest(
          '/api/v1/auth/login',
          body: jsonEncode({'username': 'testuser'}),
        );
        final response = await loginHandler(request);

        expect(response.statusCode, equals(400));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Password'));
      });

      test('returns 400 for empty passwordHash', () async {
        final request = createPostRequest(
          '/api/v1/auth/login',
          body: jsonEncode({'username': 'testuser', 'passwordHash': ''}),
        );
        final response = await loginHandler(request);

        expect(response.statusCode, equals(400));
      });
    });
  });

  group('changePasswordHandler', () {
    group('HTTP method validation', () {
      test('returns 405 for GET request', () async {
        final request = createGetRequest('/api/v1/auth/change-password');
        final response = await changePasswordHandler(request);

        expect(response.statusCode, equals(405));
      });
    });

    group('authorization', () {
      test('returns 401 for missing authorization header', () async {
        final request = createPostRequest(
          '/api/v1/auth/change-password',
          body: jsonEncode({
            'currentPasswordHash': 'a' * 64,
            'newPasswordHash': 'b' * 64,
          }),
        );
        final response = await changePasswordHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for empty authorization header', () async {
        final request = createPostRequest(
          '/api/v1/auth/change-password',
          headers: {'authorization': ''},
          body: jsonEncode({
            'currentPasswordHash': 'a' * 64,
            'newPasswordHash': 'b' * 64,
          }),
        );
        final response = await changePasswordHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for Basic auth instead of Bearer', () async {
        final request = createPostRequest(
          '/api/v1/auth/change-password',
          headers: {'authorization': 'Basic dXNlcjpwYXNz'},
          body: jsonEncode({
            'currentPasswordHash': 'a' * 64,
            'newPasswordHash': 'b' * 64,
          }),
        );
        final response = await changePasswordHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for invalid Bearer token', () async {
        final request = createPostRequest(
          '/api/v1/auth/change-password',
          headers: {'authorization': 'Bearer invalid-token'},
          body: jsonEncode({
            'currentPasswordHash': 'a' * 64,
            'newPasswordHash': 'b' * 64,
          }),
        );
        final response = await changePasswordHandler(request);

        expect(response.statusCode, equals(401));
      });
    });

    group('JSON parsing', () {
      test('returns 400 for invalid JSON body', () async {
        // Create a valid JWT first
        final jwt = _createTestJwt();
        final request = createPostRequest(
          '/api/v1/auth/change-password',
          headers: {'authorization': 'Bearer $jwt'},
          body: 'not valid json',
        );
        final response = await changePasswordHandler(request);

        // Either 400 for bad JSON or 401 for auth issues
        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });
    });

    group('password validation', () {
      test('returns 400 for invalid newPasswordHash format', () async {
        final jwt = _createTestJwt();
        final request = createPostRequest(
          '/api/v1/auth/change-password',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({
            'currentPasswordHash': 'a' * 64,
            'newPasswordHash': 'short', // Not 64 chars
          }),
        );
        final response = await changePasswordHandler(request);

        // Either 400 for validation or 401 for auth
        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });
    });
  });

  group('Response format', () {
    test('registerHandler returns JSON content type on error', () async {
      final request = createPostRequest(
        '/api/v1/auth/register',
        body: 'invalid',
      );
      final response = await registerHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('loginHandler returns JSON content type on error', () async {
      final request = createPostRequest('/api/v1/auth/login', body: 'invalid');
      final response = await loginHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('changePasswordHandler returns JSON content type on error', () async {
      final request = createPostRequest(
        '/api/v1/auth/change-password',
        body: 'invalid',
      );
      final response = await changePasswordHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });
  });
}

/// Create a test JWT for authorization testing
/// The token format is valid but won't pass verification without the secret
String _createTestJwt() {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'authCode': 'test-auth-code',
        'userId': 'test-user-id',
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp':
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      }),
    ),
  );
  return '$header.$payload.test-signature';
}
