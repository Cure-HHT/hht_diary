// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//
// Tests for questionnaire handlers (get, send, delete, unlock, finalize).
// These tests verify authorization requirements (401/403) without
// requiring a live database, following the pattern of patient_linking_test.dart.

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/questionnaire.dart';

void main() {
  group('getQuestionnaireStatusHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires',
          ),
        );

        final response = await getQuestionnaireStatusHandler(request, 'p1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires',
          ),
          headers: {'authorization': ''},
        );

        final response = await getQuestionnaireStatusHandler(request, 'p1');

        expect(response.statusCode, 401);
      });

      test('returns JSON content type on error', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires',
          ),
        );

        final response = await getQuestionnaireStatusHandler(request, 'p1');

        expect(response.headers['content-type'], 'application/json');
      });
    });
  });

  group('sendQuestionnaireHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/nose_hht/send',
          ),
        );

        final response = await sendQuestionnaireHandler(
          request,
          'p1',
          'nose_hht',
        );

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/nose_hht/send',
          ),
          headers: {'authorization': ''},
        );

        final response = await sendQuestionnaireHandler(
          request,
          'p1',
          'nose_hht',
        );

        expect(response.statusCode, 401);
      });

      test('returns JSON content type on error', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/nose_hht/send',
          ),
        );

        final response = await sendQuestionnaireHandler(
          request,
          'p1',
          'nose_hht',
        );

        expect(response.headers['content-type'], 'application/json');
      });
    });
  });

  group('deleteQuestionnaireHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1',
          ),
        );

        final response = await deleteQuestionnaireHandler(request, 'p1', 'q1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1',
          ),
          headers: {'authorization': ''},
        );

        final response = await deleteQuestionnaireHandler(request, 'p1', 'q1');

        expect(response.statusCode, 401);
      });

      test('returns JSON content type on error', () async {
        final request = Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1',
          ),
        );

        final response = await deleteQuestionnaireHandler(request, 'p1', 'q1');

        expect(response.headers['content-type'], 'application/json');
      });
    });
  });

  group('unlockQuestionnaireHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/unlock',
          ),
        );

        final response = await unlockQuestionnaireHandler(request, 'p1', 'q1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/unlock',
          ),
          headers: {'authorization': ''},
        );

        final response = await unlockQuestionnaireHandler(request, 'p1', 'q1');

        expect(response.statusCode, 401);
      });

      test(
        'returns 401 when authorization header has no Bearer prefix',
        () async {
          final request = Request(
            'POST',
            Uri.parse(
              'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/unlock',
            ),
            headers: {'authorization': 'some-token'},
          );

          final response = await unlockQuestionnaireHandler(
            request,
            'p1',
            'q1',
          );

          expect(response.statusCode, 401);
        },
      );

      test('returns JSON content type on error', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/unlock',
          ),
        );

        final response = await unlockQuestionnaireHandler(request, 'p1', 'q1');

        expect(response.headers['content-type'], 'application/json');
      });
    });
  });

  group('finalizeQuestionnaireHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/finalize',
          ),
        );

        final response = await finalizeQuestionnaireHandler(
          request,
          'p1',
          'q1',
        );

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/finalize',
          ),
          headers: {'authorization': ''},
        );

        final response = await finalizeQuestionnaireHandler(
          request,
          'p1',
          'q1',
        );

        expect(response.statusCode, 401);
      });

      test(
        'returns 401 when authorization header has no Bearer prefix',
        () async {
          final request = Request(
            'POST',
            Uri.parse(
              'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/finalize',
            ),
            headers: {'authorization': 'some-token'},
          );

          final response = await finalizeQuestionnaireHandler(
            request,
            'p1',
            'q1',
          );

          expect(response.statusCode, 401);
        },
      );

      test('returns JSON content type on error', () async {
        final request = Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/finalize',
          ),
        );

        final response = await finalizeQuestionnaireHandler(
          request,
          'p1',
          'q1',
        );

        expect(response.headers['content-type'], 'application/json');
      });
    });
  });
}
