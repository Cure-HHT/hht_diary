// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
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

  group('enrollHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/enroll'),
      );

      final response = await enrollHandler(request);
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 405 for PUT request', () async {
      final request = Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: jsonEncode({'code': 'CUREHHT1'}),
        headers: {'Content-Type': 'application/json'},
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

    test('returns 401 for missing Authorization header', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: jsonEncode({'code': 'CUREHHT1'}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await enrollHandler(request);
      expect(response.statusCode, equals(401));

      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 for invalid JWT token', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: jsonEncode({'code': 'CUREHHT1'}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer invalid.jwt.token',
        },
      );

      final response = await enrollHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for Authorization without Bearer prefix', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: jsonEncode({'code': 'CUREHHT1'}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token, // Missing "Bearer " prefix
        },
      );

      final response = await enrollHandler(request);
      expect(response.statusCode, equals(401));
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
