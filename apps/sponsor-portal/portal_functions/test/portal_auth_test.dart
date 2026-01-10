// Tests for portal authentication
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-p00024: Portal User Roles and Permissions

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/portal_auth.dart';

void main() {
  group('PortalUser construction', () {
    test('creates user with all fields', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: 'firebase-456',
        email: 'test@example.com',
        name: 'Test User',
        role: 'Administrator',
        status: 'active',
        sites: [
          {'site_id': 'site-1', 'site_name': 'Test Site'},
        ],
      );

      expect(user.id, equals('user-123'));
      expect(user.firebaseUid, equals('firebase-456'));
      expect(user.email, equals('test@example.com'));
      expect(user.name, equals('Test User'));
      expect(user.role, equals('Administrator'));
      expect(user.status, equals('active'));
      expect(user.sites, hasLength(1));
    });

    test('creates user with minimal required fields', () {
      final user = PortalUser(
        id: 'user-min',
        email: 'min@example.com',
        name: 'Minimal',
        role: 'Investigator',
        status: 'active',
      );

      expect(user.id, equals('user-min'));
      expect(user.firebaseUid, isNull);
      expect(user.sites, isEmpty);
    });

    test('sites defaults to empty list when not provided', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test',
        role: 'Auditor',
        status: 'active',
      );

      expect(user.sites, isEmpty);
      expect(user.sites, isA<List<Map<String, dynamic>>>());
    });
  });

  group('PortalUser', () {
    test('toJson includes all required fields', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: 'firebase-456',
        email: 'test@example.com',
        name: 'Test User',
        role: 'Administrator',
        status: 'active',
        sites: [],
      );

      final json = user.toJson();

      expect(json['id'], equals('user-123'));
      expect(json['email'], equals('test@example.com'));
      expect(json['name'], equals('Test User'));
      expect(json['role'], equals('Administrator'));
      expect(json['status'], equals('active'));
      expect(json['sites'], isEmpty);
    });

    test('toJson includes sites when present', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'investigator@example.com',
        name: 'Test Investigator',
        role: 'Investigator',
        status: 'active',
        sites: [
          {'site_id': 'site-1', 'site_name': 'Site One', 'site_number': 'S001'},
          {'site_id': 'site-2', 'site_name': 'Site Two', 'site_number': 'S002'},
        ],
      );

      final json = user.toJson();

      expect(json['sites'], hasLength(2));
      expect(json['sites'][0]['site_id'], equals('site-1'));
      expect(json['sites'][1]['site_name'], equals('Site Two'));
    });

    test('toJson does not include firebaseUid', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: 'secret-firebase-uid',
        email: 'test@example.com',
        name: 'Test User',
        role: 'Administrator',
        status: 'active',
      );

      final json = user.toJson();

      // firebaseUid should NOT be in the JSON response (security)
      expect(json.containsKey('firebaseUid'), isFalse);
      expect(json.containsKey('firebase_uid'), isFalse);
    });

    test('firebaseUid can be null', () {
      final user = PortalUser(
        id: 'user-123',
        firebaseUid: null,
        email: 'test@example.com',
        name: 'Test User',
        role: 'Administrator',
        status: 'active',
      );

      expect(user.firebaseUid, isNull);
    });

    test('sites defaults to empty list', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        role: 'Administrator',
        status: 'active',
      );

      expect(user.sites, isEmpty);
    });

    test('all role values are supported', () {
      final roles = [
        'Investigator',
        'Sponsor',
        'Auditor',
        'Analyst',
        'Administrator',
        'Developer Admin',
      ];

      for (final role in roles) {
        final user = PortalUser(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          role: role,
          status: 'active',
        );

        expect(user.role, equals(role));
        expect(user.toJson()['role'], equals(role));
      }
    });

    test('status values are supported', () {
      final statuses = ['active', 'revoked'];

      for (final status in statuses) {
        final user = PortalUser(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          role: 'Administrator',
          status: status,
        );

        expect(user.status, equals(status));
        expect(user.toJson()['status'], equals(status));
      }
    });
  });

  // Helper to create test requests
  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('portalMeHandler authorization', () {
    test('returns 401 without authorization header', () async {
      final request = createGetRequest('/api/v1/portal/me');
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with empty authorization header', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': ''},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test(
      'returns 401 with malformed Bearer token (no space after Bearer)',
      () async {
        final request = createGetRequest(
          '/api/v1/portal/me',
          headers: {'authorization': 'BearerNoSpace'},
        );
        final response = await portalMeHandler(request);

        expect(response.statusCode, equals(401));
      },
    );

    test('returns 401 with Bearer and empty token', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer '},
      );
      final response = await portalMeHandler(request);

      // Empty token should fail validation
      expect(response.statusCode, equals(401));
    });

    test('returns 401 with Basic auth instead of Bearer', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with invalid token format', () async {
      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer not-a-valid-jwt'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with token missing kid', () async {
      // Token with valid structure but no kid in header
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createGetRequest(
        '/api/v1/portal/me',
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await portalMeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], isNotNull);
    });
  });

  group('PortalUser toJson edge cases', () {
    test('toJson with complex site data', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        role: 'Investigator',
        status: 'active',
        sites: [
          {
            'site_id': 'site-1',
            'site_name': 'Hospital A',
            'site_number': 'S001',
            'extra_data': {'key': 'value'},
          },
        ],
      );

      final json = user.toJson();
      expect(json['sites'], hasLength(1));
      expect(json['sites'][0]['site_id'], equals('site-1'));
      expect(json['sites'][0]['extra_data'], isA<Map>());
    });

    test('toJson with empty string values', () {
      final user = PortalUser(
        id: '',
        email: '',
        name: '',
        role: '',
        status: '',
      );

      final json = user.toJson();
      expect(json['id'], isEmpty);
      expect(json['email'], isEmpty);
      expect(json['name'], isEmpty);
      expect(json['role'], isEmpty);
      expect(json['status'], isEmpty);
    });

    test('toJson with unicode characters', () {
      final user = PortalUser(
        id: 'user-日本語',
        email: 'tëst@ëxämplé.com',
        name: '测试用户 こんにちは',
        role: 'Administrator',
        status: 'active',
      );

      final json = user.toJson();
      expect(json['id'], equals('user-日本語'));
      expect(json['name'], contains('测试用户'));
    });

    test('toJson can be serialized to JSON string', () {
      final user = PortalUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        role: 'Administrator',
        status: 'active',
        sites: [
          {'site_id': 'site-1'},
        ],
      );

      final jsonStr = jsonEncode(user.toJson());
      expect(jsonStr, contains('"id":"user-123"'));
      expect(jsonStr, contains('"sites":['));

      // Verify it can be decoded back
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['email'], equals('test@example.com'));
    });
  });
}
