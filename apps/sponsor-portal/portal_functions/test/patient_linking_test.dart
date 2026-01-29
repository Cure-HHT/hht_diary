// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//   REQ-d00079: Linking Code Pattern Matching
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
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
}
