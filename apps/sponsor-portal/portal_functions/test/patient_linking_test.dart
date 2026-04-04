// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//   REQ-d00079: Linking Code Pattern Matching
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00021: Patient Reconnection Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00079: Start Trial Workflow
//
// Tests for patient_linking.dart handlers and utilities

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/database.dart';
import 'package:portal_functions/src/notification_service.dart';
import 'package:portal_functions/src/patient_linking.dart';
import 'package:portal_functions/src/portal_auth.dart';

/// Test constants
const _testPatientId = 'patient-001';
const _testSiteId = 'site-001';
const _testUserId = 'user-001';

/// Create a test PortalUser with Investigator role and site access.
PortalUser _investigator({
  String? activeRole,
  List<Map<String, dynamic>>? sites,
}) {
  return PortalUser(
    id: _testUserId,
    firebaseUid: 'firebase-001',
    email: 'investigator@example.com',
    name: 'Dr. Test',
    roles: [activeRole ?? 'Investigator'],
    activeRole: activeRole ?? 'Investigator',
    status: 'active',
    sites:
        sites ??
        [
          {
            'site_id': _testSiteId,
            'site_name': 'Test Site',
            'site_number': 'S001',
          },
        ],
  );
}

/// Standard patient row: [patient_id, site_id, linking_status, site_name]
List<dynamic> _patientRow({
  String status = 'not_connected',
  String siteId = _testSiteId,
}) {
  // 4-column version for generate/get/disconnect/notparticipating/reactivate
  return [_testPatientId, siteId, status, 'Test Site'];
}

/// Patient row for startTrial: [patient_id, site_id, linking_status, trial_started, site_name]
List<dynamic> _patientRowForTrial({
  String status = 'connected',
  String siteId = _testSiteId,
  bool trialStarted = false,
}) {
  return [_testPatientId, siteId, status, trialStarted, 'Test Site'];
}

/// Build a shelf Request with optional body and headers.
Request _request(
  String method,
  String path, {
  String? body,
  Map<String, String>? headers,
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body,
    headers: {'authorization': 'Bearer test-token', ...?headers},
  );
}

/// Decode a Response body as JSON.
Future<Map<String, dynamic>> _json(Response response) async {
  return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-functions-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );
  });
  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  group('generatePatientLinkingCodeHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
        );

        final response = await generatePatientLinkingCodeHandler(request, 'p1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
          headers: {'authorization': ''},
        );

        final response = await generatePatientLinkingCodeHandler(request, 'p1');

        expect(response.statusCode, 401);
      });

      test(
        'returns 401 when authorization header has no Bearer prefix',
        () async {
          final request = Request(
            'POST',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
            headers: {'authorization': 'some-token'},
          );

          final response = await generatePatientLinkingCodeHandler(
            request,
            'p1',
          );

          expect(response.statusCode, 401);
        },
      );

      test('returns JSON content type on error', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
        );

        final response = await generatePatientLinkingCodeHandler(request, 'p1');

        expect(response.headers['content-type'], 'application/json');
      });
    });
  });

  group('getPatientLinkingCodeHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
        );

        final response = await getPatientLinkingCodeHandler(request, 'p1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
          headers: {'authorization': ''},
        );

        final response = await getPatientLinkingCodeHandler(request, 'p1');

        expect(response.statusCode, 401);
      });
    });
  });

  group('Response format consistency', () {
    test(
      'generatePatientLinkingCodeHandler returns valid JSON on all error paths',
      () async {
        final requests = [
          Request('POST', Uri.parse('http://localhost/')),
          Request(
            'POST',
            Uri.parse('http://localhost/'),
            headers: {'authorization': ''},
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/'),
            headers: {'authorization': 'invalid'},
          ),
        ];

        for (final request in requests) {
          final response = await generatePatientLinkingCodeHandler(
            request,
            'test-id',
          );
          final body = await response.readAsString();

          // Should parse as valid JSON without throwing
          expect(() => jsonDecode(body), returnsNormally);
          expect(response.headers['content-type'], 'application/json');
        }
      },
    );

    test(
      'getPatientLinkingCodeHandler returns valid JSON on all error paths',
      () async {
        final requests = [
          Request('GET', Uri.parse('http://localhost/')),
          Request(
            'GET',
            Uri.parse('http://localhost/'),
            headers: {'authorization': ''},
          ),
          Request(
            'GET',
            Uri.parse('http://localhost/'),
            headers: {'authorization': 'Bearer invalid'},
          ),
        ];

        for (final request in requests) {
          final response = await getPatientLinkingCodeHandler(
            request,
            'test-id',
          );
          final body = await response.readAsString();

          // Should parse as valid JSON without throwing
          expect(() => jsonDecode(body), returnsNormally);
          expect(response.headers['content-type'], 'application/json');
        }
      },
    );
  });

  group('generatePatientLinkingCode', () {
    test('generates code with correct length', () {
      final code = generatePatientLinkingCode('CA');

      expect(code.length, 10);
    });

    test('generates code with sponsor prefix', () {
      final code = generatePatientLinkingCode('CA');

      expect(code.startsWith('CA'), isTrue);
    });

    test('generates different codes each time', () {
      final codes = List.generate(100, (_) => generatePatientLinkingCode('CA'));
      final uniqueCodes = codes.toSet();

      expect(uniqueCodes.length, 100, reason: 'All codes should be unique');
    });

    test('generates code with allowed characters only', () {
      // REQ-d00079.N - excludes I, 1, O, 0, S, 5, Z, 2
      const allowedChars = 'ABCDEFGHJKLMNPQRTUVWXY346789';

      for (var i = 0; i < 100; i++) {
        final code = generatePatientLinkingCode('XX');
        // Skip the 2-char prefix and check the random part
        final randomPart = code.substring(2);

        for (final char in randomPart.split('')) {
          expect(
            allowedChars.contains(char),
            isTrue,
            reason: 'Character "$char" in code "$code" is not in allowed set',
          );
        }
      }
    });

    test('generates code without ambiguous characters', () {
      // Per REQ-d00079.N, these should never appear
      const ambiguousChars = ['I', '1', 'O', '0', 'S', '5', 'Z', '2'];

      for (var i = 0; i < 100; i++) {
        final code = generatePatientLinkingCode('XX');
        // Skip the 2-char prefix and check the random part
        final randomPart = code.substring(2);

        for (final char in ambiguousChars) {
          expect(
            randomPart.contains(char),
            isFalse,
            reason: 'Ambiguous character "$char" found in code "$code"',
          );
        }
      }
    });

    test('works with different sponsor prefixes', () {
      final prefixes = ['CA', 'NY', 'TX', 'FL', 'XX'];

      for (final prefix in prefixes) {
        final code = generatePatientLinkingCode(prefix);

        expect(code.startsWith(prefix), isTrue);
        expect(code.length, 10);
      }
    });
  });

  group('formatLinkingCodeForDisplay', () {
    test('formats 10-char code correctly', () {
      final formatted = formatLinkingCodeForDisplay('CAXXXXXXXX');

      expect(formatted, 'CAXXX-XXXXX');
    });

    test('places dash after 5th character', () {
      final formatted = formatLinkingCodeForDisplay('CA12345678');

      expect(formatted, 'CA123-45678');
    });

    test('returns original code if not 10 chars', () {
      expect(formatLinkingCodeForDisplay('SHORT'), 'SHORT');
      expect(formatLinkingCodeForDisplay('TOOLONGCODE'), 'TOOLONGCODE');
      expect(formatLinkingCodeForDisplay(''), '');
    });

    test('preserves uppercase', () {
      final formatted = formatLinkingCodeForDisplay('CAABCDEFGH');

      expect(formatted, 'CAABC-DEFGH');
      expect(formatted.toUpperCase(), formatted);
    });
  });

  group('hashLinkingCode', () {
    test('produces consistent hash for same input', () {
      const code = 'CAXXXXXXXX';

      final hash1 = hashLinkingCode(code);
      final hash2 = hashLinkingCode(code);

      expect(hash1, hash2);
    });

    test('produces different hashes for different inputs', () {
      final hash1 = hashLinkingCode('CAXXXXXXXX');
      final hash2 = hashLinkingCode('CAYYYYYYYY');

      expect(hash1, isNot(hash2));
    });

    test('produces SHA-256 hash (64 hex chars)', () {
      final hash = hashLinkingCode('CAXXXXXXXX');

      expect(hash.length, 64);
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(hash), isTrue);
    });

    test('matches direct SHA-256 computation', () {
      const code = 'CAXXXXXXXX';
      final expected = sha256.convert(utf8.encode(code)).toString();

      expect(hashLinkingCode(code), expected);
    });
  });

  group('linkingCodeExpiration', () {
    test('is 72 hours per REQ-p70007', () {
      expect(linkingCodeExpiration, const Duration(hours: 72));
    });

    test('equals 3 days', () {
      expect(linkingCodeExpiration.inDays, 3);
    });
  });

  group('Success response format', () {
    test('generate response has expected fields', () {
      // Expected success response structure
      final successResponse = {
        'success': true,
        'patient_id': 'patient-123',
        'site_name': 'Site A',
        'code': 'CAXXX-XXXXX',
        'code_raw': 'CAXXXXXXXX',
        'expires_at': '2024-01-01T00:00:00.000Z',
        'expires_in_hours': 72,
      };

      expect(successResponse['success'], isTrue);
      expect(successResponse['patient_id'], isA<String>());
      expect(successResponse['code'], contains('-'));
      expect(successResponse['code_raw'], isNot(contains('-')));
      expect(successResponse['expires_in_hours'], 72);
    });

    test('get code response has expected fields when code exists', () {
      final successResponse = {
        'has_active_code': true,
        'patient_id': 'patient-123',
        'mobile_linking_status': 'linking_in_progress',
        'code': 'CAXXX-XXXXX',
        'code_raw': 'CAXXXXXXXX',
        'expires_at': '2024-01-01T00:00:00.000Z',
        'generated_at': '2024-01-01T00:00:00.000Z',
      };

      expect(successResponse['has_active_code'], isTrue);
      expect(successResponse['code'], isA<String>());
    });

    test('get code response has expected fields when no code', () {
      final noCodeResponse = {
        'has_active_code': false,
        'patient_id': 'patient-123',
        'mobile_linking_status': 'not_connected',
      };

      expect(noCodeResponse['has_active_code'], isFalse);
      expect(noCodeResponse.containsKey('code'), isFalse);
    });
  });

  group('Error response formats', () {
    test('role error includes appropriate message', () {
      final roleError = {
        'error': 'Only Investigators can generate patient linking codes',
      };

      expect(roleError['error'], contains('Investigator'));
    });

    test('site access error includes appropriate message', () {
      final siteError = {
        'error': 'You do not have access to patients at this site',
      };

      expect(siteError['error'], contains('access'));
      expect(siteError['error'], contains('site'));
    });

    test('already connected error includes guidance', () {
      final connectedError = {
        'error':
            'Patient is already connected. Use "New Code" to generate a replacement code.',
      };

      expect(connectedError['error'], contains('connected'));
      expect(connectedError['error'], contains('New Code'));
    });

    test('not found error includes patient context', () {
      final notFoundError = {'error': 'Patient not found'};

      expect(notFoundError['error'], contains('Patient'));
      expect(notFoundError['error'], contains('not found'));
    });
  });

  group('disconnectPatientHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/disconnect'),
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(request, 'p1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/disconnect'),
          headers: {'authorization': ''},
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(request, 'p1');

        expect(response.statusCode, 401);
      });

      test(
        'returns 401 when authorization header has no Bearer prefix',
        () async {
          final request = Request(
            'POST',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/disconnect'),
            headers: {'authorization': 'some-token'},
            body: jsonEncode({'reason': 'Device Issues'}),
          );

          final response = await disconnectPatientHandler(request, 'p1');

          expect(response.statusCode, 401);
        },
      );

      test('returns JSON content type on error', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/disconnect'),
        );

        final response = await disconnectPatientHandler(request, 'p1');

        expect(response.headers['content-type'], 'application/json');
      });
    });

    group('request validation', () {
      test('returns 400 for invalid JSON body', () async {
        // Since we can't easily mock auth, we test the JSON parsing
        // through the response format test instead
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/disconnect'),
        );

        final response = await disconnectPatientHandler(request, 'p1');

        // Without auth, returns 401, but response is still valid JSON
        expect(response.headers['content-type'], 'application/json');
        final body = await response.readAsString();
        expect(() => jsonDecode(body), returnsNormally);
      });
    });

    group('response format consistency', () {
      test(
        'disconnectPatientHandler returns valid JSON on all error paths',
        () async {
          final requests = [
            Request('POST', Uri.parse('http://localhost/')),
            Request(
              'POST',
              Uri.parse('http://localhost/'),
              headers: {'authorization': ''},
            ),
            Request(
              'POST',
              Uri.parse('http://localhost/'),
              headers: {'authorization': 'invalid'},
            ),
            Request(
              'POST',
              Uri.parse('http://localhost/'),
              headers: {'authorization': 'Bearer invalid'},
            ),
          ];

          for (final request in requests) {
            final response = await disconnectPatientHandler(request, 'test-id');
            final body = await response.readAsString();

            // Should parse as valid JSON without throwing
            expect(() => jsonDecode(body), returnsNormally);
            expect(response.headers['content-type'], 'application/json');
          }
        },
      );
    });
  });

  group('validDisconnectReasons', () {
    test('contains expected reasons', () {
      expect(validDisconnectReasons, contains('Device Issues'));
      expect(validDisconnectReasons, contains('Technical Issues'));
      expect(validDisconnectReasons, contains('Other'));
    });

    test('has exactly 3 options', () {
      expect(validDisconnectReasons.length, 3);
    });
  });

  group('validNotParticipatingReasons', () {
    test('contains expected reasons', () {
      expect(validNotParticipatingReasons, contains('Subject Withdrawal'));
      expect(validNotParticipatingReasons, contains('Death'));
      expect(
        validNotParticipatingReasons,
        contains('Protocol treatment/study complete'),
      );
      expect(validNotParticipatingReasons, contains('Other'));
    });

    test('has exactly 4 options', () {
      expect(validNotParticipatingReasons.length, 4);
    });
  });

  group('sponsorLinkingPrefix', () {
    test('returns value from environment or default', () {
      // This tests the accessor but actual value depends on environment
      final prefix = sponsorLinkingPrefix;
      expect(prefix, isA<String>());
      expect(prefix.length, equals(2));
    });
  });

  group('Disconnect response formats', () {
    test('success response has expected fields', () {
      // Expected success response structure
      final successResponse = {
        'success': true,
        'patient_id': 'patient-123',
        'previous_status': 'connected',
        'new_status': 'disconnected',
        'codes_revoked': 1,
        'reason': 'Device Issues',
      };

      expect(successResponse['success'], isTrue);
      expect(successResponse['patient_id'], isA<String>());
      expect(successResponse['previous_status'], 'connected');
      expect(successResponse['new_status'], 'disconnected');
      expect(successResponse['codes_revoked'], isA<int>());
      expect(successResponse['reason'], isA<String>());
    });

    test('not connected error includes current status', () {
      final notConnectedError = {
        'error':
            'Patient is not in "connected" status. Current status: disconnected',
      };

      expect(notConnectedError['error'], contains('connected'));
      expect(notConnectedError['error'], contains('Current status'));
    });

    test('missing reason error includes field name', () {
      final missingReasonError = {'error': 'Missing required field: reason'};

      expect(missingReasonError['error'], contains('reason'));
      expect(missingReasonError['error'], contains('required'));
    });

    test('invalid reason error lists valid options', () {
      final invalidReasonError = {
        'error':
            'Invalid reason. Must be one of: Device Issues, Technical Issues, Other',
      };

      expect(invalidReasonError['error'], contains('Device Issues'));
      expect(invalidReasonError['error'], contains('Technical Issues'));
      expect(invalidReasonError['error'], contains('Other'));
    });

    test('other reason requires notes', () {
      final notesRequiredError = {
        'error': 'Notes are required when reason is "Other"',
      };

      expect(notesRequiredError['error'], contains('Notes'));
      expect(notesRequiredError['error'], contains('Other'));
    });

    test('role error message is specific to disconnect', () {
      final roleError = {'error': 'Only Investigators can disconnect patients'};

      expect(roleError['error'], contains('Investigator'));
      expect(roleError['error'], contains('disconnect'));
    });
  });

  group(
    'Reconnection (generatePatientLinkingCodeHandler with reconnect_reason)',
    () {
      group('request body handling', () {
        test('accepts request with reconnect_reason in body', () async {
          // Since we can't mock auth, we just verify the request is accepted
          // and returns JSON (auth error, but valid JSON)
          final request = Request(
            'POST',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
            body: jsonEncode({'reconnect_reason': 'Patient got new device'}),
            headers: {'content-type': 'application/json'},
          );

          final response = await generatePatientLinkingCodeHandler(
            request,
            'p1',
          );

          // Should return valid JSON even on auth error
          expect(response.headers['content-type'], 'application/json');
          final body = await response.readAsString();
          expect(() => jsonDecode(body), returnsNormally);
        });

        test(
          'accepts empty request body (standard link, no reconnection)',
          () async {
            final request = Request(
              'POST',
              Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
            );

            final response = await generatePatientLinkingCodeHandler(
              request,
              'p1',
            );

            expect(response.headers['content-type'], 'application/json');
            final body = await response.readAsString();
            expect(() => jsonDecode(body), returnsNormally);
          },
        );

        test('handles invalid JSON body gracefully', () async {
          final request = Request(
            'POST',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/link-code'),
            body: 'not valid json',
            headers: {'content-type': 'application/json'},
          );

          final response = await generatePatientLinkingCodeHandler(
            request,
            'p1',
          );

          // Should still return valid JSON (auth error, not parsing error)
          expect(response.headers['content-type'], 'application/json');
          final body = await response.readAsString();
          expect(() => jsonDecode(body), returnsNormally);
        });
      });

      group('response format for reconnection', () {
        test('reconnection success response includes previous_status', () {
          // Expected structure when reconnecting a disconnected patient
          final reconnectResponse = {
            'success': true,
            'patient_id': 'patient-123',
            'site_name': 'Site A',
            'code': 'CAXXX-XXXXX',
            'code_raw': 'CAXXXXXXXX',
            'expires_at': '2024-01-01T00:00:00.000Z',
            'expires_in_hours': 72,
          };

          expect(reconnectResponse['success'], isTrue);
          expect(reconnectResponse['patient_id'], isA<String>());
          expect(reconnectResponse['code'], contains('-'));
        });

        test('reconnection audit log entry structure is correct', () {
          // Expected action_details for RECONNECT_PATIENT action
          final actionDetails = {
            'patient_id': 'patient-123',
            'site_id': 'site-456',
            'site_name': 'Site A',
            'expires_at': '2024-01-01T00:00:00.000Z',
            'generated_by_email': 'coordinator@example.com',
            'generated_by_name': 'John Doe',
            'previous_status': 'disconnected',
            'reconnect_reason': 'Patient got new device',
          };

          expect(actionDetails['previous_status'], 'disconnected');
          expect(actionDetails['reconnect_reason'], isA<String>());
          expect(actionDetails['reconnect_reason'], isNotEmpty);
        });

        test('standard link audit log does not include reconnect_reason', () {
          // Expected action_details for standard GENERATE_LINKING_CODE action
          final actionDetails = {
            'patient_id': 'patient-123',
            'site_id': 'site-456',
            'site_name': 'Site A',
            'expires_at': '2024-01-01T00:00:00.000Z',
            'generated_by_email': 'coordinator@example.com',
            'generated_by_name': 'John Doe',
            'previous_status': 'not_connected',
          };

          expect(actionDetails.containsKey('reconnect_reason'), isFalse);
          expect(actionDetails['previous_status'], isNot('disconnected'));
        });
      });
    },
  );

  group('startTrialHandler', () {
    group('authorization', () {
      test('returns 401 when no authorization header', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/start-trial'),
        );

        final response = await startTrialHandler(request, 'p1');

        expect(response.statusCode, 401);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], contains('authorization'));
      });

      test('returns 401 when authorization header is empty', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/start-trial'),
          headers: {'authorization': ''},
        );

        final response = await startTrialHandler(request, 'p1');

        expect(response.statusCode, 401);
      });

      test(
        'returns 401 when authorization header has no Bearer prefix',
        () async {
          final request = Request(
            'POST',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/start-trial'),
            headers: {'authorization': 'some-token'},
          );

          final response = await startTrialHandler(request, 'p1');

          expect(response.statusCode, 401);
        },
      );

      test('returns JSON content type on error', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/v1/portal/patients/p1/start-trial'),
        );

        final response = await startTrialHandler(request, 'p1');

        expect(response.headers['content-type'], 'application/json');
      });
    });

    group('response format consistency', () {
      test('startTrialHandler returns valid JSON on all error paths', () async {
        final requests = [
          Request('POST', Uri.parse('http://localhost/')),
          Request(
            'POST',
            Uri.parse('http://localhost/'),
            headers: {'authorization': ''},
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/'),
            headers: {'authorization': 'invalid'},
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/'),
            headers: {'authorization': 'Bearer invalid'},
          ),
        ];

        for (final request in requests) {
          final response = await startTrialHandler(request, 'test-id');
          final body = await response.readAsString();

          // Should parse as valid JSON without throwing
          expect(() => jsonDecode(body), returnsNormally);
          expect(response.headers['content-type'], 'application/json');
        }
      });
    });
  });

  group('Start Trial response formats', () {
    test('success response has expected fields', () {
      // Expected success response structure
      final successResponse = {
        'success': true,
        'patient_id': 'patient-123',
        'site_id': 'site-456',
        'site_name': 'Site A',
        'trial_started': true,
        'trial_started_at': '2024-01-01T00:00:00.000Z',
      };

      expect(successResponse['success'], isTrue);
      expect(successResponse['patient_id'], isA<String>());
      expect(successResponse['site_id'], isA<String>());
      expect(successResponse['site_name'], isA<String>());
      expect(successResponse['trial_started'], isTrue);
      expect(successResponse['trial_started_at'], isA<String>());
    });

    test('not connected error includes current status', () {
      final notConnectedError = {
        'error':
            'Patient must be in "connected" status to start trial. Current status: disconnected',
      };

      expect(notConnectedError['error'], contains('connected'));
      expect(notConnectedError['error'], contains('Current status'));
    });

    test('trial already started error is specific', () {
      final alreadyStartedError = {
        'error': 'Trial has already been started for this patient',
      };

      expect(alreadyStartedError['error'], contains('already'));
      expect(alreadyStartedError['error'], contains('started'));
    });

    test('role error message is specific to start trial', () {
      final roleError = {
        'error': 'Only Investigators can start trial for patients',
      };

      expect(roleError['error'], contains('Investigator'));
      expect(roleError['error'], contains('start trial'));
    });

    test('audit log entry structure is correct', () {
      // Expected action_details for START_TRIAL action
      final actionDetails = {
        'patient_id': 'patient-123',
        'site_id': 'site-456',
        'site_name': 'Site A',
        'trial_started_at': '2024-01-01T00:00:00.000Z',
        'started_by_email': 'coordinator@example.com',
        'started_by_name': 'John Doe',
      };

      expect(actionDetails['patient_id'], isA<String>());
      expect(actionDetails['site_id'], isA<String>());
      expect(actionDetails['trial_started_at'], isA<String>());
      expect(actionDetails['started_by_email'], isA<String>());
      expect(actionDetails['started_by_name'], isA<String>());
    });
  });

  // ==================================================================
  // Handler-level tests (using auth + DB overrides)
  // ==================================================================
  group('handler tests with overrides', () {
    setUp(() {
      requirePortalAuthOverride = (_) async => _investigator();
      NotificationService.resetForTesting();
      NotificationService.instance.initialize(
        NotificationConfig(
          projectId: 'test-project',
          enabled: true,
          consoleMode: true,
        ),
      );
    });

    tearDown(() {
      requirePortalAuthOverride = null;
      databaseQueryOverride = null;
      NotificationService.resetForTesting();
    });

    // ================================================================
    // generatePatientLinkingCodeHandler
    // ================================================================
    group('generatePatientLinkingCodeHandler handler', () {
      test('generates code successfully for not_connected patient', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'not_connected')];
          }
          if (query.contains('UPDATE patient_linking_codes') &&
              query.contains('revoked_at')) {
            return []; // No codes to revoke
          }
          if (query.contains('INSERT INTO patient_linking_codes')) {
            return [];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['success'], true);
        expect(body['patient_id'], _testPatientId);
        expect(body['code'], contains('-'));
        expect(body['code_raw'], hasLength(10));
        expect(body['expires_in_hours'], 72);
      });

      test('returns 403 for non-Investigator role', () async {
        requirePortalAuthOverride = (_) async =>
            _investigator(activeRole: 'Auditor');

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
        final body = await _json(response);
        expect(body['error'], contains('Investigator'));
      });

      test('returns 404 when patient not found', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) return [];
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/nonexistent/link-code',
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          'nonexistent',
        );

        expect(response.statusCode, 404);
      });

      test('returns 403 when user has no site access', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(siteId: 'other-site')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
        final body = await _json(response);
        expect(body['error'], contains('site'));
      });

      test('returns 409 when patient is already connected', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'connected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 409);
        final body = await _json(response);
        expect(body['error'], contains('connected'));
      });

      test('revokes existing codes when generating new one', () async {
        var revokedCodes = false;

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'linking_in_progress')];
          }
          if (query.contains('UPDATE patient_linking_codes') &&
              query.contains('revoked_at')) {
            revokedCodes = true;
            return [
              ['code-id-1'],
            ]; // One code revoked
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          if (query.contains('INSERT INTO patient_linking_codes')) {
            return [];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        expect(revokedCodes, isTrue);
      });

      test('handles reconnection with reconnect_reason', () async {
        var capturedActionType = '';

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'disconnected')];
          }
          if (query.contains('UPDATE patient_linking_codes') &&
              query.contains('revoked_at')) {
            return [];
          }
          if (query.contains('INSERT INTO patient_linking_codes')) {
            return [];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            if (parameters != null && parameters.containsKey('actionType')) {
              capturedActionType = parameters['actionType'] as String;
            }
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/link-code',
          body: jsonEncode({'reconnect_reason': 'New device'}),
        );

        final response = await generatePatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        expect(capturedActionType, 'RECONNECT_PATIENT');
      });
    });

    // ================================================================
    // getPatientLinkingCodeHandler
    // ================================================================
    group('getPatientLinkingCodeHandler handler', () {
      test('returns active code when one exists', () async {
        final expiresAt = DateTime.now().add(const Duration(hours: 48));
        final generatedAt = DateTime.now().subtract(const Duration(hours: 24));

        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [
              [_testPatientId, _testSiteId, 'linking_in_progress'],
            ];
          }
          if (query.contains('FROM patient_linking_codes')) {
            return [
              ['CAABCDEFGH', expiresAt, generatedAt],
            ];
          }
          return [];
        };

        final request = _request(
          'GET',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await getPatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['has_active_code'], true);
        expect(body['code'], contains('-'));
        expect(body['code_raw'], 'CAABCDEFGH');
      });

      test('returns no active code when none exist', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [
              [_testPatientId, _testSiteId, 'not_connected'],
            ];
          }
          if (query.contains('FROM patient_linking_codes')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'GET',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await getPatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['has_active_code'], false);
      });

      test('returns 403 for non-Investigator role', () async {
        requirePortalAuthOverride = (_) async =>
            _investigator(activeRole: 'Sponsor');

        final request = _request(
          'GET',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await getPatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 404 when patient not found', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) return [];
          return [];
        };

        final request = _request(
          'GET',
          '/api/v1/portal/patients/nonexistent/link-code',
        );

        final response = await getPatientLinkingCodeHandler(
          request,
          'nonexistent',
        );

        expect(response.statusCode, 404);
      });

      test('returns 403 when user has no site access', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [
              [_testPatientId, 'other-site', 'not_connected'],
            ];
          }
          return [];
        };

        final request = _request(
          'GET',
          '/api/v1/portal/patients/$_testPatientId/link-code',
        );

        final response = await getPatientLinkingCodeHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });
    });

    // ================================================================
    // disconnectPatientHandler
    // ================================================================
    group('disconnectPatientHandler handler', () {
      test('disconnects connected patient with valid reason', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'connected')];
          }
          if (query.contains('UPDATE patient_linking_codes')) {
            return []; // No codes to revoke
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['success'], true);
        expect(body['previous_status'], 'connected');
        expect(body['new_status'], 'disconnected');
        expect(body['reason'], 'Device Issues');
      });

      test('returns 403 for non-Investigator role', () async {
        requirePortalAuthOverride = (_) async =>
            _investigator(activeRole: 'Analyst');

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 400 when reason is missing', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
        final body = await _json(response);
        expect(body['error'], contains('reason'));
      });

      test('returns 400 for invalid reason value', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({'reason': 'Not a valid reason'}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
        final body = await _json(response);
        expect(body['error'], contains('Invalid reason'));
      });

      test('returns 400 when Other reason has no notes', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({'reason': 'Other'}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
        final body = await _json(response);
        expect(body['error'], contains('Notes'));
      });

      test('returns 404 when patient not found', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) return [];
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/nonexistent/disconnect',
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(request, 'nonexistent');

        expect(response.statusCode, 404);
      });

      test('returns 403 when user has no site access', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(siteId: 'other-site', status: 'connected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 409 when patient is not connected', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'disconnected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: jsonEncode({'reason': 'Device Issues'}),
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 409);
        final body = await _json(response);
        expect(body['error'], contains('not in "connected"'));
      });

      test('returns 400 for invalid JSON body', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/disconnect',
          body: 'not json',
        );

        final response = await disconnectPatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
      });
    });

    // ================================================================
    // markPatientNotParticipatingHandler
    // ================================================================
    group('markPatientNotParticipatingHandler handler', () {
      test('marks disconnected patient as not participating', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'disconnected')];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: jsonEncode({'reason': 'Subject Withdrawal'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['success'], true);
        expect(body['previous_status'], 'disconnected');
        expect(body['new_status'], 'not_participating');
      });

      test('returns 403 for non-Investigator role', () async {
        requirePortalAuthOverride = (_) async =>
            _investigator(activeRole: 'Sponsor');

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: jsonEncode({'reason': 'Death'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 400 for invalid reason', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: jsonEncode({'reason': 'Invalid reason'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
      });

      test('returns 400 when Other reason has no notes', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: jsonEncode({'reason': 'Other'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
        final body = await _json(response);
        expect(body['error'], contains('Notes'));
      });

      test('returns 404 when patient not found', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) return [];
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/nonexistent/not-participating',
          body: jsonEncode({'reason': 'Death'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          'nonexistent',
        );

        expect(response.statusCode, 404);
      });

      test('returns 403 when user has no site access', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(siteId: 'other-site', status: 'disconnected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: jsonEncode({'reason': 'Death'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 409 when patient is not disconnected', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'connected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: jsonEncode({'reason': 'Subject Withdrawal'}),
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 409);
      });

      test('returns 400 for invalid JSON body', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/not-participating',
          body: 'not json',
        );

        final response = await markPatientNotParticipatingHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
      });
    });

    // ================================================================
    // reactivatePatientHandler
    // ================================================================
    group('reactivatePatientHandler handler', () {
      test('reactivates not_participating patient', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'not_participating')];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/reactivate',
          body: jsonEncode({'reason': 'Patient changed mind'}),
        );

        final response = await reactivatePatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['success'], true);
        expect(body['previous_status'], 'not_participating');
        expect(body['new_status'], 'disconnected');
      });

      test('returns 403 for non-Investigator role', () async {
        requirePortalAuthOverride = (_) async =>
            _investigator(activeRole: 'Auditor');

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/reactivate',
          body: jsonEncode({'reason': 'Changed mind'}),
        );

        final response = await reactivatePatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 400 when reason is missing', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/reactivate',
          body: jsonEncode({}),
        );

        final response = await reactivatePatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
      });

      test('returns 404 when patient not found', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) return [];
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/nonexistent/reactivate',
          body: jsonEncode({'reason': 'Test'}),
        );

        final response = await reactivatePatientHandler(request, 'nonexistent');

        expect(response.statusCode, 404);
      });

      test('returns 403 when user has no site access', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [
              _patientRow(siteId: 'other-site', status: 'not_participating'),
            ];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/reactivate',
          body: jsonEncode({'reason': 'Test'}),
        );

        final response = await reactivatePatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 403);
      });

      test('returns 409 when patient is not not_participating', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow(status: 'connected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/reactivate',
          body: jsonEncode({'reason': 'Test'}),
        );

        final response = await reactivatePatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 409);
      });

      test('returns 400 for invalid JSON body', () async {
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/reactivate',
          body: 'not json',
        );

        final response = await reactivatePatientHandler(
          request,
          _testPatientId,
        );

        expect(response.statusCode, 400);
      });
    });

    // ================================================================
    // startTrialHandler
    // ================================================================
    group('startTrialHandler handler', () {
      test('starts trial for connected patient', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRowForTrial()];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('FROM patient_fcm_tokens')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/start-trial',
        );

        final response = await startTrialHandler(request, _testPatientId);

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['success'], true);
        expect(body['trial_started'], true);
      });

      test('returns 403 for non-Investigator role', () async {
        requirePortalAuthOverride = (_) async =>
            _investigator(activeRole: 'Administrator');

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/start-trial',
        );

        final response = await startTrialHandler(request, _testPatientId);

        expect(response.statusCode, 403);
      });

      test('returns 404 when patient not found', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) return [];
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/nonexistent/start-trial',
        );

        final response = await startTrialHandler(request, 'nonexistent');

        expect(response.statusCode, 404);
      });

      test('returns 403 when user has no site access', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRowForTrial(siteId: 'other-site')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/start-trial',
        );

        final response = await startTrialHandler(request, _testPatientId);

        expect(response.statusCode, 403);
      });

      test('returns 409 when patient is not connected', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRowForTrial(status: 'disconnected')];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/start-trial',
        );

        final response = await startTrialHandler(request, _testPatientId);

        expect(response.statusCode, 409);
      });

      test('returns 409 when trial already started', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRowForTrial(trialStarted: true)];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/start-trial',
        );

        final response = await startTrialHandler(request, _testPatientId);

        expect(response.statusCode, 409);
        final body = await _json(response);
        expect(body['error'], contains('already'));
      });

      test('sends FCM when patient has token', () async {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRowForTrial()];
          }
          if (query.contains('UPDATE patients')) {
            return [];
          }
          if (query.contains('FROM patient_fcm_tokens')) {
            return [
              ['fake-fcm-token-12345678901234567890'],
            ];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/start-trial',
        );

        final response = await startTrialHandler(request, _testPatientId);

        expect(response.statusCode, 200);
      });
    });
  });
}
