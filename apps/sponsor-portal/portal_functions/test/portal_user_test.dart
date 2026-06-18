// Tests for portal user management - unit tests for validation logic
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: Create User Dialog Implementation
//   REQ-d00168: Pre-authorized email uniqueness — case-insensitive 409 pre-flight
//   REQ-d00169: Pending row cleanup endpoint

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Import the source file directly to access internal functions for testing
import 'package:portal_functions/src/database.dart';
import 'package:portal_functions/src/portal_auth.dart';
import 'package:portal_functions/src/portal_user.dart';

void main() {
  // Helper to create test requests
  Request createPostRequest(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: body is String ? body : jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  Request createPatchRequest(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'PATCH',
      Uri.parse('http://localhost$path'),
      body: body is String ? body : jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('getPortalUsersHandler', () {
    test('returns 403 without authorization header', () async {
      final request = createGetRequest('/api/v1/portal/users');
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
      final json = await getResponseJson(response);
      expect(json['error'], equals('Unauthorized'));
    });

    test('returns 403 with invalid authorization header', () async {
      final request = createGetRequest(
        '/api/v1/portal/users',
        headers: {'authorization': 'Invalid token'},
      );
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with empty Bearer token', () async {
      final request = createGetRequest(
        '/api/v1/portal/users',
        headers: {'authorization': 'Bearer '},
      );
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with malformed JWT', () async {
      final request = createGetRequest(
        '/api/v1/portal/users',
        headers: {'authorization': 'Bearer not.a.valid.jwt'},
      );
      final response = await getPortalUsersHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('createPortalUserHandler', () {
    test('returns 403 without authorization', () async {
      final request = createPostRequest('/api/v1/portal/users', {
        'name': 'Test User',
        'email': 'test@example.com',
        'role': 'Investigator',
      });
      final response = await createPortalUserHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with expired token structure', () async {
      // Create a token with valid structure but will fail verification
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'fake-key-id'}),
        ),
      );
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': '123',
            'exp': 0, // Expired
          }),
        ),
      );
      final token = '$header.$payload.signature';

      final request = createPostRequest(
        '/api/v1/portal/users',
        {'name': 'Test', 'email': 'test@test.com', 'role': 'Investigator'},
        headers: {'authorization': 'Bearer $token'},
      );
      final response = await createPortalUserHandler(request);

      expect(response.statusCode, equals(403));
    });

    /// Verifies REQ-d00168-A, REQ-d00168-B
    group('REQ-d00168 — case-insensitive duplicate email pre-flight', () {
      setUp(() {
        // Bypass Identity Platform token verification for these unit tests.
        requirePortalAuthOverride = (_) async => PortalUser(
          id: 'admin-00000000-0000-0000-0000-000000000001',
          email: 'admin@example.com',
          name: 'Test Admin',
          roles: ['Administrator'],
          activeRole: 'Administrator',
          status: 'active',
        );
      });

      tearDown(() {
        requirePortalAuthOverride = null;
        databaseQueryOverride = null;
      });

      // Verifies: REQ-d00168-A
      test(
        'REQ-d00168-A: returns 409 when email already exists (exact match)',
        () async {
          databaseQueryOverride =
              (query, {parameters, required context}) async {
                // Duplicate-email pre-flight query — return an existing row.
                if (query.contains('portal_users') &&
                    query.contains('LOWER(email)')) {
                  return [
                    ['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
                  ];
                }
                return [];
              };

          final request = createPostRequest('/api/v1/portal/users', {
            'name': 'Dup User',
            'email': 'dup@example.com',
            'roles': ['Administrator'],
          });
          final response = await createPortalUserHandler(request);

          expect(response.statusCode, equals(409));
          final body = await getResponseJson(response);
          expect(body['code'], equals('email_already_known'));
        },
      );

      // Verifies: REQ-d00168-B
      test(
        'REQ-d00168-B: returns 409 for case-insensitive duplicate (mixed-case email)',
        () async {
          databaseQueryOverride =
              (query, {parameters, required context}) async {
                // Simulate the DB returning a row for LOWER(email) match on
                // 'DUP@EXAMPLE.COM' vs existing 'dup@example.com'.
                if (query.contains('portal_users') &&
                    query.contains('LOWER(email)')) {
                  return [
                    ['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'],
                  ];
                }
                return [];
              };

          final request = createPostRequest('/api/v1/portal/users', {
            'name': 'Dup Upper',
            'email': 'DUP@EXAMPLE.COM',
            'roles': ['Administrator'],
          });
          final response = await createPortalUserHandler(request);

          expect(response.statusCode, equals(409));
          final body = await getResponseJson(response);
          expect(body['code'], equals('email_already_known'));
        },
      );

      // REQ-d00168 race-loss path (concurrent INSERT both pass the
      // pre-check; one wins, the other hits portal_users_email_lower_key)
      // is not unit-testable: package:postgres's UniqueViolationException
      // has a private constructor (postgres-3.5.9/exceptions.dart:232).
      // The catch block in createPortalUserHandler is exercised by the
      // integration tests against a real database. Same pattern as
      // questionnaire.dart's race-catch, which is also integration-only.
    });
  });

  group('updatePortalUserHandler', () {
    test('returns 403 without authorization', () async {
      final request = createPatchRequest('/api/v1/portal/users/some-user-id', {
        'status': 'revoked',
      });
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with invalid token structure', () async {
      final request = createPatchRequest(
        '/api/v1/portal/users/some-user-id',
        {'status': 'revoked'},
        headers: {'authorization': 'Bearer invalid'},
      );
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with Basic auth', () async {
      final request = createPatchRequest(
        '/api/v1/portal/users/some-user-id',
        {'status': 'revoked'},
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
      );
      final response = await updatePortalUserHandler(request, 'some-user-id');

      expect(response.statusCode, equals(403));
    });

    /// State-machine guard: only active<->revoked transitions and noops
    /// are legitimate via this handler. Pending users must go through
    /// activateUserHandler (binds firebase_uid) or
    /// deletePendingPortalUserHandler (cancels invite). PATCHing
    /// pending->active here would skip activation and leave firebase_uid
    /// NULL, breaking sign-in permanently.
    group('updatePortalUserHandler — state-machine guard', () {
      const targetId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
      const adminId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

      setUp(() {
        requirePortalAuthOverride = (_) async => PortalUser(
          id: adminId,
          email: 'admin@example.com',
          name: 'Test Admin',
          roles: ['Administrator'],
          activeRole: 'Administrator',
          status: 'active',
        );
      });

      tearDown(() {
        requirePortalAuthOverride = null;
        databaseQueryOverride = null;
      });

      Future<Response> patchStatus({
        required String fromStatus,
        required String toStatus,
      }) async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains(
            'SELECT id, name, email, status FROM portal_users',
          )) {
            return [
              [targetId, 'Target', 'target@example.com', fromStatus],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            // Handler does `array_agg(...) as roles` and casts the first
            // column to List<String>. Mock a one-row, one-column result
            // whose value is the roles array itself.
            return [
              [
                <String>['Investigator'],
              ],
            ];
          }
          if (query.contains('FROM portal_user_site_access')) {
            // Same array_agg shape — empty list of site_ids.
            return [
              [<String>[]],
            ];
          }
          // Audit-log INSERTs and other writes — return empty.
          return [];
        };
        return updatePortalUserHandler(
          createPatchRequest(
            '/api/v1/portal/users/$targetId',
            {'status': toStatus},
            headers: {'authorization': 'Bearer test'},
          ),
          targetId,
        );
      }

      test(
        'rejects pending -> active (would leave firebase_uid NULL)',
        () async {
          final response = await patchStatus(
            fromStatus: 'pending',
            toStatus: 'active',
          );
          expect(response.statusCode, equals(400));
          final body = await getResponseJson(response);
          expect(body['code'], equals('invalid_transition'));
        },
      );

      test('rejects pending -> revoked (use deletePending instead)', () async {
        final response = await patchStatus(
          fromStatus: 'pending',
          toStatus: 'revoked',
        );
        expect(response.statusCode, equals(400));
        final body = await getResponseJson(response);
        expect(body['code'], equals('invalid_transition'));
      });

      test('rejects active -> pending (would lock the user out)', () async {
        final response = await patchStatus(
          fromStatus: 'active',
          toStatus: 'pending',
        );
        expect(response.statusCode, equals(400));
        final body = await getResponseJson(response);
        expect(body['code'], equals('invalid_transition'));
      });

      test('allows active -> revoked (deactivation)', () async {
        final response = await patchStatus(
          fromStatus: 'active',
          toStatus: 'revoked',
        );
        expect(response.statusCode, isNot(equals(400)));
      });

      // The regenerate_activation body flag is a separate code path inside
      // updatePortalUserHandler that doesn't go through the body['status']
      // guard above. It would silently flip an active user to 'pending'
      // (locking them out of /portal/me) without an explicit guard, so it
      // mirrors generateActivationCodeHandler's active-user 409 reject.
      test(
        'rejects regenerate_activation on an active user (409 already_active)',
        () async {
          databaseQueryOverride =
              (query, {parameters, required context}) async {
                if (query.contains(
                  'SELECT id, name, email, status FROM portal_users',
                )) {
                  return [
                    [targetId, 'Target', 'target@example.com', 'active'],
                  ];
                }
                if (query.contains('FROM portal_user_roles')) {
                  return [
                    [
                      <String>['Investigator'],
                    ],
                  ];
                }
                if (query.contains('FROM portal_user_site_access')) {
                  return [
                    [<String>[]],
                  ];
                }
                return [];
              };
          final response = await updatePortalUserHandler(
            createPatchRequest(
              '/api/v1/portal/users/$targetId',
              {'regenerate_activation': true},
              headers: {'authorization': 'Bearer test'},
            ),
            targetId,
          );
          expect(response.statusCode, equals(409));
          final body = await getResponseJson(response);
          expect(body['code'], equals('already_active'));
        },
      );
    });

    /// Resend Activation Email (REQ-CAL-p00033). The `regenerate_activation`
    /// branch must (a) rotate the code with a fresh 14-day expiry, (b) try
    /// to send the activation email via EmailService, and (c) write an
    /// immutable audit row with action='resend_activation'. In unit-test
    /// scope EmailService is not initialized so the send returns failure
    /// — the response surfaces email_sent=false plus email_error, and the
    /// caller must still get a 200 with the new code so the admin can
    /// share it manually.
    group('updatePortalUserHandler — resend activation', () {
      const targetId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
      const adminId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

      setUp(() {
        requirePortalAuthOverride = (_) async => PortalUser(
          id: adminId,
          email: 'admin@example.com',
          name: 'Test Admin',
          roles: ['Administrator'],
          activeRole: 'Administrator',
          status: 'active',
        );
      });

      tearDown(() {
        requirePortalAuthOverride = null;
        databaseQueryOverride = null;
      });

      /// Stubs every query updatePortalUserHandler issues on the
      /// regenerate_activation path, captures whether the audit-log INSERT
      /// fired with action='resend_activation', and returns the response.
      ///
      /// [targetRoles] controls whether the target row carries the
      /// Administrator/Developer Admin role — used by the carve-out
      /// tests that pin "Administrator can resend for pending admin
      /// target without 403".
      ///
      /// Verifies: REQ-CAL-p00033/<audit-trail assertion>
      Future<({Response response, bool auditLogged, String? auditAction})>
      callResend({
        required String fromStatus,
        List<String> targetRoles = const ['Investigator'],
      }) async {
        bool auditLogged = false;
        String? auditAction;

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains(
            'SELECT id, name, email, status FROM portal_users',
          )) {
            return [
              [targetId, 'Target', 'target@example.com', fromStatus],
            ];
          }
          if (query.contains('FROM portal_user_roles')) {
            return [
              [targetRoles],
            ];
          }
          if (query.contains('FROM portal_user_site_access')) {
            return [
              [<String>[]],
            ];
          }
          // UPDATE portal_users ... RETURNING id — non-empty means success.
          if (query.contains('UPDATE portal_users') &&
              query.contains('RETURNING id')) {
            return [
              [targetId],
            ];
          }
          // INSERT INTO portal_user_audit_log — capture the action label.
          if (query.contains('INSERT INTO portal_user_audit_log')) {
            auditLogged = true;
            auditAction = parameters?['action'] as String?;
            return [];
          }
          return [];
        };

        final response = await updatePortalUserHandler(
          createPatchRequest(
            '/api/v1/portal/users/$targetId',
            {'regenerate_activation': true},
            headers: {'authorization': 'Bearer test'},
          ),
          targetId,
        );
        return (
          response: response,
          auditLogged: auditLogged,
          auditAction: auditAction,
        );
      }

      test(
        'pending user: rotates code, returns activation_url + expires_at',
        () async {
          final result = await callResend(fromStatus: 'pending');
          expect(result.response.statusCode, equals(200));
          final body = await getResponseJson(result.response);
          expect(body['success'], isTrue);
          // Code in XXXXX-XXXXX format
          expect(
            body['activation_code'],
            matches(RegExp(r'^[A-Z2-9]{5}-[A-Z2-9]{5}$')),
          );
          expect(body['activation_url'], isA<String>());
          expect(body['activation_url'] as String, contains('/activate?code='));
          expect(body['expires_at'], isA<String>());
        },
      );

      test('writes audit row with action=resend_activation', () async {
        final result = await callResend(fromStatus: 'pending');
        expect(result.response.statusCode, equals(200));
        expect(result.auditLogged, isTrue);
        expect(result.auditAction, equals('resend_activation'));
      });

      test('email_sent=false surfaces in response when EmailService is not '
          'initialized (manual-share fallback)', () async {
        final result = await callResend(fromStatus: 'pending');
        expect(result.response.statusCode, equals(200));
        final body = await getResponseJson(result.response);
        expect(body['email_sent'], isFalse);
        expect(body['email_error'], isNotNull);
      });

      test(
        'revoked user: re-invite path also rotates + audits (revoked->pending)',
        () async {
          final result = await callResend(fromStatus: 'revoked');
          expect(result.response.statusCode, equals(200));
          expect(result.auditLogged, isTrue);
          expect(result.auditAction, equals('resend_activation'));
        },
      );

      // Implements: DIARY-PRD-user-account-edit/A
      // A regular Administrator may resend activation for a pending
      // Administrator target — the role assignment is unchanged and
      // only the activation code rotates.
      test(
        'Administrator can resend for pending Administrator target (no 403)',
        () async {
          final result = await callResend(
            fromStatus: 'pending',
            targetRoles: ['Administrator'],
          );
          expect(result.response.statusCode, equals(200));
          expect(result.auditAction, equals('resend_activation'));
        },
      );

      // Implements: DIARY-PRD-user-account-edit/A
      // CUR-1121: a regular Administrator may re-invite a revoked
      // Administrator. Previously this returned 403 because the
      // isTargetAdmin guard required Developer Admin for any change
      // restoring access. The guard now applies only to Developer
      // Admin targets (assertion H), exercised in the separate
      // Developer-Admin protection tests.
      test('Administrator can re-invite a revoked Administrator', () async {
        final result = await callResend(
          fromStatus: 'revoked',
          targetRoles: ['Administrator'],
        );
        expect(result.response.statusCode, equals(200));
        expect(result.auditAction, equals('resend_activation'));
      });

      // Implements: DIARY-BASE-system-operator-role/D
      // The Developer Admin tier remains protected — only a Developer
      // Admin may re-invite a revoked Developer Admin.
      test(
        'Administrator CANNOT re-invite a revoked Developer Admin (403)',
        () async {
          final result = await callResend(
            fromStatus: 'revoked',
            targetRoles: ['Developer Admin'],
          );
          expect(result.response.statusCode, equals(403));
          final body = await getResponseJson(result.response);
          expect(body['error'], contains('Developer Admin'));
        },
      );
    });
  });

  group('getPortalSitesHandler', () {
    test('returns 403 without authorization', () async {
      final request = createGetRequest('/api/v1/portal/sites');
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with invalid token', () async {
      final request = createGetRequest(
        '/api/v1/portal/sites',
        headers: {'authorization': 'Bearer invalid-token'},
      );
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });

    test('returns 403 with two-part token', () async {
      final request = createGetRequest(
        '/api/v1/portal/sites',
        headers: {'authorization': 'Bearer part1.part2'},
      );
      final response = await getPortalSitesHandler(request);

      expect(response.statusCode, equals(403));
    });
  });

  group('Request body handling', () {
    test('createPortalUserHandler handles malformed JSON body', () async {
      final request = createPostRequest(
        '/api/v1/portal/users',
        'not valid json {{{',
      );
      final response = await createPortalUserHandler(request);

      // Should return 403 for auth failure, not 400 for bad JSON
      // because auth check happens first
      expect(response.statusCode, equals(403));
    });

    test('updatePortalUserHandler handles empty body', () async {
      final request = createPatchRequest('/api/v1/portal/users/user-id', '');
      final response = await updatePortalUserHandler(request, 'user-id');

      expect(response.statusCode, equals(403));
    });
  });

  group('Response format', () {
    test('error responses are JSON', () async {
      final request = createGetRequest('/api/v1/portal/users');
      final response = await getPortalUsersHandler(request);

      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('error responses contain error field', () async {
      final request = createGetRequest('/api/v1/portal/sites');
      final response = await getPortalSitesHandler(request);

      final json = await getResponseJson(response);
      expect(json.containsKey('error'), isTrue);
      expect(json['error'], isA<String>());
    });
  });

  /// Verifies REQ-d00169-A, REQ-d00169-B, REQ-d00169-C
  group('deletePendingPortalUserHandler — CUR-1296 (REQ-d00169)', () {
    setUp(() {
      requirePortalAuthOverride = (_) async => PortalUser(
        id: 'admin-user-id',
        email: 'admin@example.com',
        name: 'Admin',
        roles: ['Administrator'],
        activeRole: 'Administrator',
        status: 'active',
      );
    });

    tearDown(() {
      requirePortalAuthOverride = null;
      databaseQueryOverride = null;
    });

    // Verifies: REQ-d00169-A
    // Verifies: REQ-d00169-B
    test(
      'REQ-d00169-A+B: deletes a pending row and cascades to dependents',
      () async {
        const id = 'aaaaaaaa-1111-1111-1111-111111111111';
        final captured = <Map<String, Object?>>[];
        databaseQueryOverride = (query, {parameters, required context}) async {
          captured.add({'sql': query, 'parameters': parameters});
          if (query.contains('SELECT status FROM portal_users')) {
            return [
              ['pending'],
            ];
          }
          if (query.startsWith('DELETE FROM')) {
            // RETURNING id — handler treats empty list as 400 not_pending.
            return [
              [id],
            ];
          }
          throw 'unexpected SQL in test: $query';
        };

        final response = await deletePendingPortalUserHandler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/v1/portal/users/$id'),
          ),
          id,
        );

        expect(response.statusCode, equals(200));
        final body = await getResponseJson(response);
        expect(body['ok'], isTrue);
        // Captured queries: SELECT status, then a single DELETE on
        // portal_users. portal_user_roles and portal_user_site_access
        // are removed via ON DELETE CASCADE FKs (schema.sql:751,778),
        // so the handler issues exactly one DELETE.
        expect(captured.length, equals(2));
        expect(captured[0]['sql'], contains('SELECT status'));
        expect(captured[1]['sql'], contains('DELETE FROM portal_users'));
        // The DELETE is gated by status='pending' to defend against a
        // race where the row transitions pending -> active between the
        // pre-check SELECT and this statement.
        expect(captured[1]['sql'], contains("status = 'pending'"));
      },
    );

    // Verifies: REQ-d00169-B race-loss path
    test(
      'REQ-d00169-B: 400 not_pending when row goes active between SELECT and DELETE',
      () async {
        const id = 'aaaaaaaa-3333-3333-3333-333333333333';
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('SELECT status FROM portal_users')) {
            // Pre-check sees pending — admin proceeds.
            return [
              ['pending'],
            ];
          }
          if (query.startsWith('DELETE FROM')) {
            // ...but by the time DELETE fires, a concurrent activate
            // flipped the row to 'active'; WHERE status='pending' matches
            // 0 rows, RETURNING returns empty.
            return [];
          }
          throw 'unexpected SQL in test: $query';
        };

        final response = await deletePendingPortalUserHandler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/v1/portal/users/$id'),
          ),
          id,
        );

        expect(response.statusCode, equals(400));
        final body = await getResponseJson(response);
        expect(body['code'], equals('not_pending'));
      },
    );

    // Verifies: REQ-d00169-B
    test(
      'REQ-d00169-B: refuses to delete an active row (returns 400 not_pending)',
      () async {
        const id = 'aaaaaaaa-2222-2222-2222-222222222222';
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('SELECT status FROM portal_users')) {
            return [
              ['active'],
            ];
          }
          throw 'no DELETE expected when status != pending';
        };

        final response = await deletePendingPortalUserHandler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/v1/portal/users/$id'),
          ),
          id,
        );

        expect(response.statusCode, equals(400));
        final body = await getResponseJson(response);
        expect(body['code'], equals('not_pending'));
      },
    );

    // Verifies: REQ-d00169-C
    test('REQ-d00169-C: returns 404 for unknown id', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('SELECT status FROM portal_users')) {
          return [];
        }
        throw 'no DELETE expected for missing row';
      };

      final response = await deletePendingPortalUserHandler(
        Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/v1/portal/users/99999999-9999-9999-9999-999999999999',
          ),
        ),
        '99999999-9999-9999-9999-999999999999',
      );

      expect(response.statusCode, equals(404));
    });
  });
}
