// Tests for password reset handler validation
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-p00010: FDA 21 CFR Part 11 Compliance

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/portal_password_reset.dart';

void main() {
  group('requestPasswordResetHandler validation', () {
    Request createRequest(Map<String, dynamic> body) {
      return Request(
        'POST',
        Uri.parse('http://localhost/api/v1/portal/auth/password-reset/request'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );
    }

    Future<Map<String, dynamic>> getResponseJson(Response response) async {
      final chunks = await response.read().toList();
      final body = utf8.decode(chunks.expand((c) => c).toList());
      return jsonDecode(body) as Map<String, dynamic>;
    }

    test('returns 400 when email is missing', () async {
      final request = createRequest({});
      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Email is required'));
    });

    test('returns 400 when email is empty', () async {
      final request = createRequest({'email': ''});
      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Email is required'));
    });

    test('returns 400 when email is null', () async {
      final request = createRequest({'email': null});
      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Email is required'));
    });

    test('returns 400 for invalid email format - no @', () async {
      final request = createRequest({'email': 'invalidemail'});
      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Invalid email format'));
    });

    test('returns 400 for invalid email format - too short', () async {
      final request = createRequest({'email': 'a@'});
      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Invalid email format'));
    });

    test('returns JSON content type for all responses', () async {
      final request = createRequest({'email': 'invalid'});
      final response = await requestPasswordResetHandler(request);

      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('returns 500 for malformed JSON body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/portal/auth/password-reset/request'),
        body: 'not json',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await requestPasswordResetHandler(request);

      expect(response.statusCode, equals(500));
      final json = await getResponseJson(response);
      expect(json['error'], contains('error'));
    });
  });
}
