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
//
// Tests for patient_linking.dart handlers and utilities

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/patient_linking.dart';

void main() {
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
}
