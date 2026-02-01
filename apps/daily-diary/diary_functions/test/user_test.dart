// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//
// Unit tests for user handlers (non-database aspects)

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

  group('enrollHandler deprecation', () {
    // enrollHandler is deprecated and always returns 410 Gone
    // Use /api/v1/user/link with sponsor portal linking codes instead

    test('returns 410 Gone for all requests (deprecated endpoint)', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: jsonEncode({'code': 'CUREHHT1'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await enrollHandler(request);
      expect(response.statusCode, equals(410));

      final json = await getResponseJson(response);
      expect(json['error'], contains('deprecated'));
    });

    test('returns 410 regardless of HTTP method', () async {
      for (final method in ['GET', 'PUT', 'DELETE']) {
        final request = Request(
          method,
          Uri.parse('http://localhost/api/v1/user/enroll'),
        );

        final response = await enrollHandler(request);
        expect(response.statusCode, equals(410));
      }
    });

    test('response mentions /api/v1/user/link as replacement', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: jsonEncode({'code': 'CUREHHT1'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await enrollHandler(request);
      final json = await getResponseJson(response);
      expect(json['error'], contains('/api/v1/user/link'));
    });
  });

  group('linkHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/link'),
      );

      final response = await linkHandler(request);
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 405 for PUT request', () async {
      final request = Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/user/link'),
        body: jsonEncode({'code': 'CAXXXXXXXX'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await linkHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 405 for DELETE request', () async {
      final request = Request(
        'DELETE',
        Uri.parse('http://localhost/api/v1/user/link'),
      );

      final response = await linkHandler(request);
      expect(response.statusCode, equals(405));
    });

    // Note: linkHandler no longer requires Authorization - the linking code IS the auth
    // JWT is returned upon successful linking (REQ-p70007)

    test('returns 400 for missing code', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/link'),
        body: jsonEncode({}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await linkHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('code'));
    });

    test('returns 400 for invalid code format (too short)', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/link'),
        body: jsonEncode({'code': 'SHORT'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await linkHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('10 characters'));
    });

    test('returns 400 for invalid code format (too long)', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/link'),
        body: jsonEncode({'code': 'CATOOLONG12345'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await linkHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('10 characters'));
    });

    test('normalizes code format (removes dash, uppercases)', () async {
      // This test verifies normalization works - the actual DB lookup
      // will fail in unit tests without a real database, but we verify
      // the code doesn't fail before the DB lookup due to format issues
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/link'),
        body: jsonEncode({'code': 'caxxx-xxxxx'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await linkHandler(request);
      // Will be 500 because DB not available, but at least validates format
      // The code should normalize to CAXXXXXXXXX (10 chars) before DB call
      expect(response.statusCode, isNot(equals(400)));
    });
  });

  group('syncHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/sync'),
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 405 for PUT request', () async {
      final request = Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/user/sync'),
        body: jsonEncode({'events': []}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 401 for missing Authorization', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/sync'),
        body: jsonEncode({'events': []}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for expired JWT', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
        expiresIn: const Duration(seconds: -10), // Already expired
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/sync'),
        body: jsonEncode({'events': []}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(401));
    });
  });

  group('getRecordsHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/records'),
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 405 for PUT request', () async {
      final request = Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/user/records'),
        body: jsonEncode({}),
        headers: {'Content-Type': 'application/json'},
      );

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

    test('returns 401 for missing Authorization', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/records'),
        body: jsonEncode({}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for malformed JWT', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/records'),
        body: jsonEncode({}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer abc.def.ghi',
        },
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(401));
    });
  });
}
