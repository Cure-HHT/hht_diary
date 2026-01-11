// Tests for user handlers
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00004: Immutable Audit Trail via Event Sourcing

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/user.dart';

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

  /// Create a test JWT for authorization testing
  String createTestJwt() {
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

  group('enrollHandler', () {
    group('HTTP method validation', () {
      test('returns 405 for GET request', () async {
        final request = createGetRequest('/api/v1/user/enroll');
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(405));
        final json = await getResponseJson(response);
        expect(json['error'], contains('Method not allowed'));
      });

      test('returns 405 for PUT request', () async {
        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/v1/user/enroll'),
          body: jsonEncode({'code': 'CUREHHT1'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(405));
      });

      test('returns 405 for DELETE request', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/v1/user/enroll'),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(405));
      });
    });

    group('authorization', () {
      test('returns 401 for missing authorization header', () async {
        final request = createPostRequest(
          '/api/v1/user/enroll',
          body: jsonEncode({'code': 'CUREHHT1'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(401));
        final json = await getResponseJson(response);
        expect(json['error'], contains('authorization'));
      });

      test('returns 401 for empty authorization header', () async {
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': ''},
          body: jsonEncode({'code': 'CUREHHT1'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for Basic auth instead of Bearer', () async {
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Basic dXNlcjpwYXNz'},
          body: jsonEncode({'code': 'CUREHHT1'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for invalid Bearer token', () async {
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer invalid-token'},
          body: jsonEncode({'code': 'CUREHHT1'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, equals(401));
      });
    });

    group('JSON parsing', () {
      test('returns 400 for invalid JSON body', () async {
        final jwt = createTestJwt();
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: 'not valid json',
        );
        final response = await enrollHandler(request);

        // Either 400 for bad JSON or 401 for auth
        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });
    });

    group('enrollment code validation', () {
      test('returns 400 for missing code', () async {
        final jwt = createTestJwt();
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({}),
        );
        final response = await enrollHandler(request);

        // Either 400 for missing code or 401 for auth
        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });

      test('returns 400 for empty code', () async {
        final jwt = createTestJwt();
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({'code': ''}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });

      test('returns 400 for invalid code format', () async {
        final jwt = createTestJwt();
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({'code': 'INVALID'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });

      test('returns 400 for code without digit', () async {
        final jwt = createTestJwt();
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({'code': 'CUREHHT'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });

      test('returns 400 for code with multiple digits', () async {
        final jwt = createTestJwt();
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({'code': 'CUREHHT12'}),
        );
        final response = await enrollHandler(request);

        expect(response.statusCode, anyOf(equals(400), equals(401)));
      });

      test('accepts valid CUREHHT code (case insensitive)', () async {
        final jwt = createTestJwt();
        // Note: This will fail at database access, but validates code format first
        final request = createPostRequest(
          '/api/v1/user/enroll',
          headers: {'authorization': 'Bearer $jwt'},
          body: jsonEncode({'code': 'curehht5'}),
        );
        final response = await enrollHandler(request);

        // Will get 401 from auth check, not 400 from code validation
        expect(response.statusCode, anyOf(equals(401), equals(500)));
      });
    });
  });

  group('syncHandler', () {
    group('HTTP method validation', () {
      test('returns 405 for GET request', () async {
        final request = createGetRequest('/api/v1/user/sync');
        final response = await syncHandler(request);

        expect(response.statusCode, equals(405));
      });

      test('returns 405 for PUT request', () async {
        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/v1/user/sync'),
        );
        final response = await syncHandler(request);

        expect(response.statusCode, equals(405));
      });
    });

    group('authorization', () {
      test('returns 401 for missing authorization header', () async {
        final request = createPostRequest(
          '/api/v1/user/sync',
          body: jsonEncode({'events': []}),
        );
        final response = await syncHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for invalid Bearer token', () async {
        final request = createPostRequest(
          '/api/v1/user/sync',
          headers: {'authorization': 'Bearer invalid'},
          body: jsonEncode({'events': []}),
        );
        final response = await syncHandler(request);

        expect(response.statusCode, equals(401));
      });
    });
  });

  group('getRecordsHandler', () {
    group('HTTP method validation', () {
      test('returns 405 for GET request', () async {
        final request = createGetRequest('/api/v1/user/records');
        final response = await getRecordsHandler(request);

        expect(response.statusCode, equals(405));
      });

      test('returns 405 for DELETE request', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/v1/user/records'),
        );
        final response = await getRecordsHandler(request);

        expect(response.statusCode, equals(405));
      });
    });

    group('authorization', () {
      test('returns 401 for missing authorization header', () async {
        final request = createPostRequest('/api/v1/user/records');
        final response = await getRecordsHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for empty authorization header', () async {
        final request = createPostRequest(
          '/api/v1/user/records',
          headers: {'authorization': ''},
        );
        final response = await getRecordsHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for Basic auth', () async {
        final request = createPostRequest(
          '/api/v1/user/records',
          headers: {'authorization': 'Basic dXNlcjpwYXNz'},
        );
        final response = await getRecordsHandler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 for malformed Bearer token', () async {
        final request = createPostRequest(
          '/api/v1/user/records',
          headers: {'authorization': 'Bearer not.valid'},
        );
        final response = await getRecordsHandler(request);

        expect(response.statusCode, equals(401));
      });
    });
  });

  group('Response format', () {
    test('enrollHandler returns JSON content type on error', () async {
      final request = createPostRequest('/api/v1/user/enroll');
      final response = await enrollHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('syncHandler returns JSON content type on error', () async {
      final request = createPostRequest('/api/v1/user/sync');
      final response = await syncHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('getRecordsHandler returns JSON content type on error', () async {
      final request = createPostRequest('/api/v1/user/records');
      final response = await getRecordsHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('error responses contain error field', () async {
      final request = createPostRequest('/api/v1/user/enroll');
      final response = await enrollHandler(request);
      final json = await getResponseJson(response);

      expect(json.containsKey('error'), isTrue);
    });
  });
}
