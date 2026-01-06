// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//
// Unit tests for diary server routes

import 'package:diary_server/diary_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('createRouter', () {
    late Handler handler;

    setUp(() {
      final router = createRouter();
      handler = router.call;
    });

    test('health endpoint returns 200', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
    });

    test('sponsor config endpoint returns 400 without sponsorId', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config'),
      );
      final response = await handler(request);

      expect(response.statusCode, equals(400));
    });

    test('sponsor config endpoint returns 200 with sponsorId', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );
      final response = await handler(request);

      expect(response.statusCode, equals(200));
    });

    test('unknown route returns 404', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/unknown'),
      );
      final response = await handler(request);

      expect(response.statusCode, equals(404));
    });

    test('auth register endpoint is routed', () async {
      // Without valid body, we expect 400 (bad request) not 404 (not found)
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      // Should not be 404 - route exists
      expect(response.statusCode, isNot(equals(404)));
    });

    test('auth login endpoint is routed', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      expect(response.statusCode, isNot(equals(404)));
    });

    test('user enroll endpoint is routed', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/enroll'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      // Should return 401 (unauthorized) not 404
      expect(response.statusCode, isNot(equals(404)));
    });

    test('user sync endpoint is routed', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/sync'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      expect(response.statusCode, isNot(equals(404)));
    });

    test('user records endpoint is routed', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/user/records'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      expect(response.statusCode, isNot(equals(404)));
    });
  });
}
