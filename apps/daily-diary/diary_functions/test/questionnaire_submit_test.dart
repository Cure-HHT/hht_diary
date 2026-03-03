// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-d00113: Deleted Questionnaire Submission Handling
//
// Unit tests for questionnaire submit handler (non-database aspects)

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

  group('submitQuestionnaireHandler HTTP validation', () {
    test('returns 405 for GET request', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/questionnaires/abc-123/submit'),
      );

      final response = await submitQuestionnaireHandler(request, 'abc-123');
      expect(response.statusCode, equals(405));

      final json = await getResponseJson(response);
      expect(json['error'], contains('Method'));
    });

    test('returns 401 for missing Authorization', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/questionnaires/abc-123/submit'),
        body: jsonEncode({
          'responses': [
            {
              'question_id': 'nose_physical_1',
              'value': 2,
              'display_label': 'Moderate problem',
              'normalized_label': '2',
            },
          ],
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final response = await submitQuestionnaireHandler(request, 'abc-123');
      expect(response.statusCode, equals(401));

      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 for malformed JWT', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/questionnaires/abc-123/submit'),
        body: jsonEncode({
          'responses': [
            {
              'question_id': 'nose_physical_1',
              'value': 2,
              'display_label': 'Moderate problem',
              'normalized_label': '2',
            },
          ],
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer abc.def.ghi',
        },
      );

      final response = await submitQuestionnaireHandler(request, 'abc-123');
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for expired JWT', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
        expiresIn: const Duration(seconds: -10),
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/questionnaires/abc-123/submit'),
        body: jsonEncode({
          'responses': [
            {
              'question_id': 'nose_physical_1',
              'value': 2,
              'display_label': 'Moderate problem',
              'normalized_label': '2',
            },
          ],
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final response = await submitQuestionnaireHandler(request, 'abc-123');
      expect(response.statusCode, equals(401));
    });

    test('returns 401 for Bearer prefix missing', () async {
      final token = createJwtToken(
        authCode: generateAuthCode(),
        userId: generateUserId(),
      );

      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/questionnaires/abc-123/submit'),
        body: jsonEncode({
          'responses': [
            {
              'question_id': 'nose_physical_1',
              'value': 2,
              'display_label': 'Moderate problem',
              'normalized_label': '2',
            },
          ],
        }),
        headers: {'Content-Type': 'application/json', 'Authorization': token},
      );

      final response = await submitQuestionnaireHandler(request, 'abc-123');
      expect(response.statusCode, equals(401));
    });
  });
}
