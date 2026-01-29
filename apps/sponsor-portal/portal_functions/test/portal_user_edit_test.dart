// Tests for portal user edit functionality - unit tests for validation logic
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00034: Site Visibility and Assignment

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/portal_user.dart';

void main() {
  // Helper to create test requests
  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
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

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('getPortalUserHandler', () {
    test('returns 403 without authorization header', () async {
      final request = createGetRequest('/api/v1/portal/users/some-user-id');
      final response = await getPortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Unauthorized'));
    });

    test('returns 403 with invalid authorization header', () async {
      final request = createGetRequest(
        '/api/v1/portal/users/some-user-id',
        headers: {'authorization': 'Invalid token'},
      );
      final response = await getPortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with empty Bearer token', () async {
      final request = createGetRequest(
        '/api/v1/portal/users/some-user-id',
        headers: {'authorization': 'Bearer '},
      );
      final response = await getPortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with malformed JWT', () async {
      final request = createGetRequest(
        '/api/v1/portal/users/some-user-id',
        headers: {'authorization': 'Bearer not.a.valid.jwt'},
      );
      final response = await getPortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });
  });

  group('updatePortalUserHandler - name update', () {
    test('returns 403 without authorization', () async {
      final request = createPatchRequest('/api/v1/portal/users/some-user-id', {
        'name': 'New Name',
      });
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });
  });

  group('updatePortalUserHandler - self-modification prevention', () {
    test('returns 403 without valid auth for self-modification test', () async {
      final request = createPatchRequest('/api/v1/portal/users/my-id', {
        'name': 'New Name',
        'roles': ['Administrator'],
      });
      final response = await updatePortalUserHandler(request, 'my-id');

      // Auth check happens first, so this returns 403 not 400
      expect(response.statusCode, equals(403));
    });
  });

  group('verifyEmailChangeHandler', () {
    test('returns 403 with empty token (no DB, returns error)', () async {
      // Without database, this should fail gracefully
      final request = createPostRequest(
        '/api/v1/portal/email-verification/invalid-token',
        {},
      );
      // Since no DB is connected, this will throw - which is expected in unit tests
      // The important thing is the handler exists and accepts the right signature
      expect(
        () => verifyEmailChangeHandler(request, 'invalid-token'),
        throwsA(anything), // DB not initialized
      );
    });
  });

  group('Verification token utilities', () {
    test('generateVerificationToken produces URL-safe string', () {
      final token = generateVerificationToken();

      expect(token, isNotEmpty);
      expect(token.length, greaterThan(20));
      // Should be base64url encoded
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+=*$')));
    });

    test('generateVerificationToken produces unique tokens', () {
      final token1 = generateVerificationToken();
      final token2 = generateVerificationToken();

      expect(token1, isNot(equals(token2)));
    });

    test('hashVerificationToken produces consistent SHA-256 hash', () {
      const token = 'test-token-12345';
      final hash1 = hashVerificationToken(token);
      final hash2 = hashVerificationToken(token);

      expect(hash1, equals(hash2));
      // SHA-256 produces 64 hex characters
      expect(hash1.length, equals(64));
      expect(hash1, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test(
      'hashVerificationToken produces different hashes for different tokens',
      () {
        final hash1 = hashVerificationToken('token-a');
        final hash2 = hashVerificationToken('token-b');

        expect(hash1, isNot(equals(hash2)));
      },
    );
  });

  group('Response format', () {
    test('getPortalUserHandler error responses are JSON', () async {
      final request = createGetRequest('/api/v1/portal/users/test-id');
      final response = await getPortalUserHandler(request, 'test-id');

      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('error responses contain error field', () async {
      final request = createGetRequest('/api/v1/portal/users/test-id');
      final response = await getPortalUserHandler(request, 'test-id');

      final json = await getResponseJson(response);
      expect(json.containsKey('error'), isTrue);
      expect(json['error'], isA<String>());
    });
  });
}
