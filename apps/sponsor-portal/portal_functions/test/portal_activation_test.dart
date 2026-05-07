// Tests for portal activation handlers
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00166: Server-owned portal activation; {code, password} body; no bearer required

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/database.dart';
import 'package:portal_functions/src/identity_admin.dart';
import 'package:portal_functions/src/portal_activation.dart';

void main() {
  // Helper to create test requests
  Request createPostRequest(
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body,
    );
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  // Note: validateActivationCodeHandler requires database access so we can't
  // test it without mocking the database. The handlers are tested via
  // integration tests with the actual database.

  /// Verifies REQ-d00166-A, REQ-d00166-B, REQ-d00166-E
  group('activateUserHandler — CUR-1296 server-owned shape', () {
    tearDown(() {
      databaseQueryOverride = null;
    });

    // Verifies: REQ-d00166-A
    test(
      'REQ-d00166-A: accepts {code, password} body without bearer token',
      () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('activation_code')) {
            // Return a valid pending user row
            return [
              [
                '11111111-1111-1111-1111-111111111111',
                'pending@example.com',
                'Pending User',
                'pending',
                DateTime.now().add(const Duration(days: 14)),
              ],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }
          if (query.contains('UPDATE portal_users') &&
              query.contains('firebase_uid')) {
            // RETURNING id — handler treats empty list as 409 conflict.
            return [
              ['11111111-1111-1111-1111-111111111111'],
            ];
          }
          return [];
        };

        IdentityAdminTestOverride.lookupOrProvision =
            ({
              required String email,
              required String displayName,
              required String password,
            }) async => const LookupOrProvisionResult(
              uid: 'TEST_UID_PENDING',
              created: true,
            );
        addTearDown(() => IdentityAdminTestOverride.lookupOrProvision = null);

        final response = await activateUserHandler(
          createPostRequest(
            '/api/v1/portal/activate',
            body: jsonEncode({
              'code': 'ABCDE-12345',
              'password': 'newSecretPw1',
            }),
          ),
        );

        expect(response.statusCode, equals(200));
        final body = await getResponseJson(response);
        expect(body['ok'], isTrue);
      },
    );

    // Verifies: REQ-d00166-B
    test('REQ-d00166-B: returns 400 code_invalid for unknown code', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM portal_users') &&
            query.contains('activation_code')) {
          return []; // No user found
        }
        return [];
      };

      final response = await activateUserHandler(
        createPostRequest(
          '/api/v1/portal/activate',
          body: jsonEncode({'code': 'NOPE-NOTREAL', 'password': 'x'}),
        ),
      );
      expect(response.statusCode, equals(400));
      final body = await getResponseJson(response);
      expect(body['code'], equals('code_invalid'));
    });

    // Verifies: REQ-d00166-B
    test(
      'REQ-d00166-B: returns 400 code_expired when activation_code_expires_at is in the past',
      () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('activation_code')) {
            return [
              [
                '22222222-2222-2222-2222-222222222222',
                'expired@example.com',
                'Expired User',
                'pending',
                DateTime.now().subtract(const Duration(days: 1)), // expired
              ],
            ];
          }
          return [];
        };

        final response = await activateUserHandler(
          createPostRequest(
            '/api/v1/portal/activate',
            body: jsonEncode({'code': 'EXPRD-00001', 'password': 'x'}),
          ),
        );
        expect(response.statusCode, equals(400));
        final body = await getResponseJson(response);
        expect(body['code'], equals('code_expired'));
      },
    );

    // Verifies: REQ-d00166-E (idempotent retry-after-success)
    test(
      'REQ-d00166-E: returns 200 already_active=true when row is already active',
      () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('activation_code')) {
            return [
              [
                '44444444-4444-4444-4444-444444444444',
                'active@example.com',
                'Active User',
                'active', // already active
                DateTime.now().add(const Duration(days: 14)),
              ],
            ];
          }
          return [];
        };

        final response = await activateUserHandler(
          createPostRequest(
            '/api/v1/portal/activate',
            body: jsonEncode({'code': 'ALDYACT-001', 'password': 'whatever'}),
          ),
        );
        expect(response.statusCode, equals(200));
        final body = await getResponseJson(response);
        expect(body['ok'], isTrue);
        expect(body['already_active'], isTrue);
      },
    );

    // Verifies: REQ-d00166-C, REQ-d00166-D, REQ-d00166-F
    test(
      'REQ-d00166-C+D: happy path calls IdentityAdmin once, stamps firebase_uid, flips status',
      () async {
        // Track what the handler would have written to DB via the UPDATE.
        String? capturedUid;
        String? capturedUserId;
        bool updateCalled = false;

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('activation_code')) {
            return [
              [
                '77777777-7777-7777-7777-777777777777',
                'happy@example.com',
                'Happy',
                'pending',
                DateTime.now().add(const Duration(days: 14)),
              ],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }
          if (query.contains('UPDATE portal_users') &&
              query.contains('firebase_uid')) {
            updateCalled = true;
            capturedUid = parameters?['uid'] as String?;
            capturedUserId = parameters?['id'] as String?;
            // RETURNING id — handler treats empty list as a race conflict.
            return [
              ['77777777-7777-7777-7777-777777777777'],
            ];
          }
          return [];
        };

        // Inject a mock IdentityAdmin via the test seam.
        final calls = <Map<String, String>>[];
        IdentityAdminTestOverride.lookupOrProvision =
            ({
              required String email,
              required String displayName,
              required String password,
            }) async {
              calls.add({
                'email': email,
                'displayName': displayName,
                'password': password,
              });
              return const LookupOrProvisionResult(
                uid: 'TEST_UID_HAPPY',
                created: true,
              );
            };
        addTearDown(() => IdentityAdminTestOverride.lookupOrProvision = null);

        final response = await activateUserHandler(
          createPostRequest(
            '/api/v1/portal/activate',
            body: jsonEncode({'code': 'HAPPY-00001', 'password': 'pw1'}),
          ),
        );

        expect(response.statusCode, equals(200));
        final body = await getResponseJson(response);
        expect(body['ok'], isTrue);

        // IdentityAdmin called exactly once with correct email.
        expect(calls.length, equals(1));
        expect(calls.single['email'], equals('happy@example.com'));

        // DB UPDATE was called with the uid from IdP and the correct user id.
        expect(updateCalled, isTrue);
        expect(capturedUid, equals('TEST_UID_HAPPY'));
        expect(capturedUserId, equals('77777777-7777-7777-7777-777777777777'));
      },
    );

    // Verifies: REQ-d00166-D — UPDATE is gated by both status='pending'
    // AND activation_code, with RETURNING to detect the 0-row case
    // deterministically. Simulates a concurrent code rotation between the
    // pre-check SELECT and the UPDATE: SELECT sees pending+code, but by
    // the time UPDATE fires the activation_code has changed, so the WHERE
    // matches 0 rows. The IdP write already happened, so the handler
    // returns 409 activation_conflict rather than a misleading 200.
    test(
      'REQ-d00166-D: returns 409 activation_conflict when UPDATE matches 0 rows',
      () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('activation_code')) {
            return [
              [
                '77777777-7777-7777-7777-777777777777',
                'race@example.com',
                'Race',
                'pending',
                DateTime.now().add(const Duration(days: 14)),
              ],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }
          if (query.contains('UPDATE portal_users') &&
              query.contains('firebase_uid')) {
            // Simulate the race: WHERE clause matched nothing.
            return [];
          }
          return [];
        };

        IdentityAdminTestOverride.lookupOrProvision =
            ({
              required String email,
              required String displayName,
              required String password,
            }) async {
              return const LookupOrProvisionResult(
                uid: 'TEST_UID_RACE',
                created: true,
              );
            };
        addTearDown(() => IdentityAdminTestOverride.lookupOrProvision = null);

        final response = await activateUserHandler(
          createPostRequest(
            '/api/v1/portal/activate',
            body: jsonEncode({'code': 'RACE-00001', 'password': 'pw1'}),
          ),
        );

        expect(response.statusCode, equals(409));
        final body = await getResponseJson(response);
        expect(body['code'], equals('activation_conflict'));
      },
    );

    // Verifies: REQ-d00166-F (idp_unavailable; DB unchanged)
    test(
      'REQ-d00166-F: 502 idp_unavailable when IdentityAdmin throws; no DB write',
      () async {
        bool updateCalled = false;

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM portal_users') &&
              query.contains('activation_code')) {
            return [
              [
                '88888888-8888-8888-8888-888888888888',
                'idpdown@example.com',
                'IdP Down',
                'pending',
                DateTime.now().add(const Duration(days: 14)),
              ],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            return [
              ['Administrator'],
            ];
          }
          if (query.contains('UPDATE portal_users') &&
              query.contains('firebase_uid')) {
            updateCalled = true;
            return [];
          }
          return [];
        };

        IdentityAdminTestOverride.lookupOrProvision =
            ({
              required String email,
              required String displayName,
              required String password,
            }) async =>
                throw IdentityAdminException('upstream sad', statusCode: 503);
        addTearDown(() => IdentityAdminTestOverride.lookupOrProvision = null);

        final response = await activateUserHandler(
          createPostRequest(
            '/api/v1/portal/activate',
            body: jsonEncode({'code': 'IDPDN-00001', 'password': 'pw1'}),
          ),
        );

        expect(response.statusCode, equals(502));
        final body = await getResponseJson(response);
        expect(body['code'], equals('idp_unavailable'));

        // No DB UPDATE was called (IdP-first, DB-second ordering).
        expect(updateCalled, isFalse);
      },
    );
  });

  group('activateUserHandler — input validation', () {
    // Body-level validation happens before DB, so no override needed.
    test('returns 400 for invalid JSON body', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        body: 'not valid json',
      );
      final response = await activateUserHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for missing code in body', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        body: jsonEncode({'password': 'secret'}),
      );
      final response = await activateUserHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for empty code in body', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        body: jsonEncode({'code': '', 'password': 'secret'}),
      );
      final response = await activateUserHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for missing password in body', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        body: jsonEncode({'code': 'ABCDE-12345'}),
      );
      final response = await activateUserHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns 400 for empty password in body', () async {
      final request = createPostRequest(
        '/api/v1/portal/activate',
        body: jsonEncode({'code': 'ABCDE-12345', 'password': ''}),
      );
      final response = await activateUserHandler(request);
      expect(response.statusCode, equals(400));
    });
  });

  group('generateActivationCodeHandler authorization', () {
    test('returns 401 without authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with empty authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': ''},
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with Basic auth instead of Bearer', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('returns 401 with invalid Bearer token', () async {
      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Bearer invalid-token'},
        body: jsonEncode({'email': 'test@example.com'}),
      );
      final response = await generateActivationCodeHandler(request);

      expect(response.statusCode, equals(401));
    });
  });

  group('generateActivationCodeHandler request body', () {
    test('returns error for invalid JSON body', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Bearer $token'},
        body: 'not valid json',
      );
      final response = await generateActivationCodeHandler(request);

      // Either 400 for bad JSON or 401 for invalid token or 403 for not admin
      expect(response.statusCode, anyOf(equals(400), equals(401), equals(403)));
    });

    test('returns error for missing user_id and email', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test'})),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'admin@example.com'})),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'other_field': 'value'}),
      );
      final response = await generateActivationCodeHandler(request);

      // Either 400 for missing fields, 401 for invalid token, or 403 for not admin
      expect(response.statusCode, anyOf(equals(400), equals(401), equals(403)));
    });
  });

  group('Response format', () {
    test('activateUserHandler returns JSON content type on error', () async {
      final request = createPostRequest('/api/v1/portal/activate');
      final response = await activateUserHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test(
      'generateActivationCodeHandler returns JSON content type on error',
      () async {
        final request = createPostRequest('/api/v1/portal/admin/generate-code');
        final response = await generateActivationCodeHandler(request);

        expect(response.headers['content-type'], equals('application/json'));
      },
    );

    test('error responses contain error field', () async {
      final request = createPostRequest('/api/v1/portal/activate');
      final response = await activateUserHandler(request);
      final json = await getResponseJson(response);

      expect(json.containsKey('error'), isTrue);
    });
  });

  group('getPortalBaseUrl - CUR-997', () {
    // Helper to create a GET request with specific headers
    Request createGetRequest(String path, {Map<String, String>? headers}) {
      return Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: headers,
      );
    }

    test('PORTAL_URL env var takes priority over Origin header', () {
      // BUG: In QA, the Origin header contains the raw Cloud Run service URL
      // (e.g., portal-server-421945483876.europe-west9.run.app) instead of
      // the DNS alias (portal-qa.callisto.anspar.org). The activation email
      // should use the configured PORTAL_URL, not the Origin header.
      final request = createGetRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {
          'origin': 'https://portal-server-421945483876.europe-west9.run.app',
        },
      );

      final result = getPortalBaseUrl(
        request,
        portalUrlEnv: 'https://portal-qa.callisto.anspar.org',
      );

      expect(result, equals('https://portal-qa.callisto.anspar.org'));
    });

    test('PORTAL_URL env var takes priority over Referer header', () {
      final request = createGetRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {
          'referer':
              'https://portal-server-421945483876.europe-west9.run.app/dev-admin',
        },
      );

      final result = getPortalBaseUrl(
        request,
        portalUrlEnv: 'https://portal-qa.callisto.anspar.org',
      );

      expect(result, equals('https://portal-qa.callisto.anspar.org'));
    });

    test('falls back to Origin when PORTAL_URL is not set', () {
      final request = createGetRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'origin': 'https://portal-qa.callisto.anspar.org'},
      );

      final result = getPortalBaseUrl(request);

      expect(result, equals('https://portal-qa.callisto.anspar.org'));
    });

    test('falls back to Referer when PORTAL_URL and Origin are not set', () {
      final request = createGetRequest(
        '/api/v1/portal/admin/generate-code',
        headers: {'referer': 'https://portal-qa.callisto.anspar.org/dev-admin'},
      );

      final result = getPortalBaseUrl(request);

      expect(result, equals('https://portal-qa.callisto.anspar.org'));
    });

    test('falls back to localhost when nothing is set', () {
      final request = createGetRequest('/api/v1/portal/admin/generate-code');

      final result = getPortalBaseUrl(request);

      expect(result, equals('http://localhost:8081'));
    });
  });

  group('Edge cases', () {
    // These tests verify body-level validation only — no DB needed.
    test('handles empty POST body', () async {
      final request = createPostRequest('/api/v1/portal/activate', body: '');
      final response = await activateUserHandler(request);

      // Empty body is invalid JSON — returns 400
      expect(response.statusCode, equals(400));
    });

    test('handles POST body with only whitespace', () async {
      final request = createPostRequest('/api/v1/portal/activate', body: '   ');
      final response = await activateUserHandler(request);

      // Whitespace-only body is invalid JSON — returns 400
      expect(response.statusCode, equals(400));
    });
  });
}
