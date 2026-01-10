// Tests for portal user management - unit tests for validation logic
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: Create User Dialog Implementation

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Import the source file directly to access internal functions for testing
import 'package:portal_functions/src/portal_user.dart';

void main() {
  // Helper to create test requests
  Request createPostRequest(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: body is String ? body : jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  Request createPatchRequest(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'PATCH',
      Uri.parse('http://localhost$path'),
      body: body is String ? body : jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
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

  group('getPortalUsersHandler', () {
    test('returns 403 without authorization header', () async {
      final request = createGetRequest('/api/v1/portal/users');
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Unauthorized'));
    });

    test('returns 403 with invalid authorization header', () async {
      final request = createGetRequest(
        '/api/v1/portal/users',
        headers: {'authorization': 'Invalid token'},
      );
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with empty Bearer token', () async {
      final request = createGetRequest(
        '/api/v1/portal/users',
        headers: {'authorization': 'Bearer '},
      );
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with malformed JWT', () async {
      final request = createGetRequest(
        '/api/v1/portal/users',
        headers: {'authorization': 'Bearer not.a.valid.jwt'},
      );
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('createPortalUserHandler', () {
    test('returns 403 without authorization', () async {
      final request = createPostRequest('/api/v1/portal/users', {
        'name': 'Test User',
        'email': 'test@example.com',
        'role': 'Investigator',
      });
      final response = await createPortalUserHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with expired token structure', () async {
      // Create a token with valid structure but will fail verification
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'fake-key-id'}),
        ),
      );
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': '123',
            'exp': 0, // Expired
          }),
        ),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/users',
        {'name': 'Test', 'email': 'test@test.com', 'role': 'Investigator'},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await createPortalUserHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('updatePortalUserHandler', () {
    test('returns 403 without authorization', () async {
      final request = createPatchRequest('/api/v1/portal/users/some-user-id', {
        'status': 'revoked',
      });
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with invalid token structure', () async {
      final request = createPatchRequest(
        '/api/v1/portal/users/some-user-id',
        {'status': 'revoked'},
        headers: {'authorization': 'Bearer invalid'},
      );
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with Basic auth', () async {
      final request = createPatchRequest(
        '/api/v1/portal/users/some-user-id',
        {'status': 'revoked'},
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
      );
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });
  });

  group('getPortalSitesHandler', () {
    test('returns 403 without authorization', () async {
      final request = createGetRequest('/api/v1/portal/sites');
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with invalid token', () async {
      final request = createGetRequest(
        '/api/v1/portal/sites',
        headers: {'authorization': 'Bearer invalid-token'},
      );
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with two-part token', () async {
      final request = createGetRequest(
        '/api/v1/portal/sites',
        headers: {'authorization': 'Bearer part1.part2'},
      );
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('Request body handling', () {
    test('createPortalUserHandler handles malformed JSON body', () async {
      final request = createPostRequest(
        '/api/v1/portal/users',
        'not valid json {{{',
      );
      final response = await createPortalUserHandler(request);

      // Should return 403 for auth failure, not 400 for bad JSON
      // because auth check happens first
      expect(response.statusCode, equals(403));
    });

    test('updatePortalUserHandler handles empty body', () async {
      final request = createPatchRequest('/api/v1/portal/users/user-id', '');
      final response = await updatePortalUserHandler(request, 'user-id');

      expect(response.statusCode, equals(403));
    });
  });

  group('Response format', () {
    test('error responses are JSON', () async {
      final request = createGetRequest('/api/v1/portal/users');
      final response = await getPortalUsersHandler(request);

      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('error responses contain error field', () async {
      final request = createGetRequest('/api/v1/portal/sites');
      final response = await getPortalSitesHandler(request);

      final json = await getResponseJson(response);
      expect(json.containsKey('error'), isTrue);
      expect(json['error'], isA<String>());
    });
  });
}
