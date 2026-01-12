// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00031: Identity Platform Integration
//   REQ-p00024: Portal User Roles and Permissions
//
// Unit tests for portal server routes

import 'package:portal_server/portal_server.dart';
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

    test('portal me endpoint requires authentication', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/portal/me'),
      );
      final response = await handler(request);

      // Should return 401 (unauthorized) without token
      expect(response.statusCode, equals(401));
    });

    test('portal users endpoint requires authentication', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/portal/users'),
      );
      final response = await handler(request);

      // Should return 401 or 403 without token (not 404 - route exists)
      expect(response.statusCode, anyOf(equals(401), equals(403)));
    });

    test('portal sites endpoint requires authentication', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/portal/sites'),
      );
      final response = await handler(request);

      // Should return 401 or 403 without token (not 404 - route exists)
      expect(response.statusCode, anyOf(equals(401), equals(403)));
    });

    // Note: The activation code validation endpoint requires database connection
    // which is not available in unit tests. Integration tests cover this functionality.

    test('activation endpoint requires body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/portal/activate'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      // Should not be 404 - route exists
      expect(response.statusCode, isNot(equals(404)));
    });

    test('generate code endpoint requires authentication', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/portal/admin/generate-code'),
        body: '{}',
        headers: {'Content-Type': 'application/json'},
      );
      final response = await handler(request);

      // Should return 401 (unauthorized) without token
      expect(response.statusCode, equals(401));
    });
  });
}
