// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Unit tests for tasks handler (non-database aspects)

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

  group('getTasksHandler HTTP validation', () {
    test('returns 405 for POST request', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/tasks'),
        body: jsonEncode({}),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 405 for PUT request', () async {
      final request = Request(
        'PUT',
        Uri.parse('http://localhost/api/v1/user/tasks'),
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 405 for DELETE request', () async {
      final request = Request(
        'DELETE',
        Uri.parse('http://localhost/api/v1/user/tasks'),
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 401 for missing Authorization', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/tasks'),
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(401));

      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 for malformed JWT', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/tasks'),
        headers: {'Authorization': 'Bearer abc.def.ghi'},
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for expired JWT', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
        expiresIn: const Duration(seconds: -10),
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/tasks'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for Bearer prefix missing', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/tasks'),
        headers: {'Authorization': token},
      );

      final response = await getTasksHandler(request);
      expect(response.statusCode, equals(401));
    });
  });
}
