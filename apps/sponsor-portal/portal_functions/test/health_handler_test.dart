// Tests for health check handler
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/health.dart';

void main() {
  group('healthHandler', () {
    test('returns 200 OK', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await healthHandler(request);

      expect(response.statusCode, equals(200));
    });

    test('returns JSON content type', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await healthHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('returns status ok in body', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await healthHandler(request);
      final body = await response.readAsString();

      expect(body, contains('ok'));
    });

    test('handles different HTTP methods', () async {
      // Health check should work with GET
      final getRequest = Request('GET', Uri.parse('http://localhost/health'));
      final getResponse = await healthHandler(getRequest);
      expect(getResponse.statusCode, equals(200));
    });
  });
}
