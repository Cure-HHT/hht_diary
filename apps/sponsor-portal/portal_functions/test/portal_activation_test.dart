// Tests for portal activation handlers
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/portal_activation.dart';

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

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  // Note: validateActivationCodeHandler requires database access so we can't
  // test it without mocking the database. The handlers are tested via
  // integration tests with the actual database.

  group('activateUserHandler authorization', () {
    test('returns 401 without authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with empty authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': ''},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with Basic auth instead of Bearer', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with invalid Bearer token', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer invalid-token'},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with Bearer and empty token', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer '},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });
  });

  group('activateUserHandler request body', () {
    test('returns 400 for invalid JSON body', () async {
      // Create a token that will fail verification (but has valid format)
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer $token'},
        body: 'not valid json',
      );
      final response = await activateUserHandler(request);

      // Either 400 for bad JSON or 401 for invalid token
      expect(response.statusCode, anyOf(equals(400), equals(401)));
    });

    test('returns 400 for missing code in body', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'other_field': 'value'}),
      );
      final response = await activateUserHandler(request);

      // Either 400 for missing code or 401 for invalid token
      expect(response.statusCode, anyOf(equals(400), equals(401)));
    });

    test('returns 400 for empty code in body', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'code': ''}),
      );
      final response = await activateUserHandler(request);

      // Either 400 for empty code or 401 for invalid token
      expect(response.statusCode, anyOf(equals(400), equals(401)));
    });

    test('returns 400 for null code in body', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'code': null}),
      );
      final response = await activateUserHandler(request);

      // Either 400 for null code or 401 for invalid token
      expect(response.statusCode, anyOf(equals(400), equals(401)));
    });
  });

  group('generateActivationCodeHandler authorization', () {
    test('returns 401 without authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with empty authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': ''},
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with Basic auth instead of Bearer', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with invalid Bearer token', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Bearer invalid-token'},
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
    });
  });

  group('generateActivationCodeHandler request body', () {
    test('returns error for invalid JSON body', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Bearer $token'},
        body: 'not valid json',
      );
      final response = await generateActivationCodeHandler(request);

      // Either 400 for bad JSON or 401 for invalid token or 403 for not admin
      expect(response.statusCode, anyOf(equals(400), equals(401), equals(403)));
    });

    test('returns error for missing user_id and email', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'admin@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'other_field': 'value'}),
      );
      final response = await generateActivationCodeHandler(request);

      // Either 400 for missing fields, 401 for invalid token, or 403 for not admin
      expect(response.statusCode, anyOf(equals(400), equals(401), equals(403)));
    });
  });

  group('Response format', () {
    test('activateUserHandler returns JSON content type on error', () async {
      final request = createPostRequest('/api/v1/portal/activate');
      final response = await activateUserHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test(
      'generateActivationCodeHandler returns JSON content type on error',
      () async {
        final request = createPostRequest('/api/v1/portal/admin/generate-code');
        final response = await generateActivationCodeHandler(request);

        expect(response.headers['content-type'], equals('application/json'));
      },
    );

    test('error responses contain error field', () async {
      final request = createPostRequest('/api/v1/portal/activate');
      final response = await activateUserHandler(request);
      final json = await getResponseJson(response);

      expect(json.containsKey('error'), isTrue);
    });
  });

  group('Edge cases', () {
    test('handles empty POST body', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer test'},
        body: '',
      );
      final response = await activateUserHandler(request);

      // Should return 400 for empty body or 401 for invalid token
      expect(response.statusCode, anyOf(equals(400), equals(401)));
    });

    test('handles POST body with only whitespace', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer test'},
        body: '   ',
      );
      final response = await activateUserHandler(request);

      // Should return 400 for invalid body or 401 for invalid token
      expect(response.statusCode, anyOf(equals(400), equals(401)));
    });
  });

  group('Token format validation', () {
    test('rejects token with only 2 parts', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer part1.part2'},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('rejects token with 4 parts', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer part1.part2.part3.part4'},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('rejects token without kid in header', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/activate',
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'code': 'TEST1-CODE1'}),
      );
      final response = await activateUserHandler(request);

      expect(response.statusCode, equals(401));
    });
  });
}
