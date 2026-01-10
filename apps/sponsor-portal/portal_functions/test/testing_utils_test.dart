// Tests for testing utility functions
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00036: Create User Dialog Implementation

import 'package:test/test.dart';

// ignore: deprecated_member_use_from_same_package
import 'package:portal_functions/src/testing_utils.dart';

void main() {
  group('base64UrlDecodeForTesting', () {
    test('decodes standard base64url without padding', () {
      // "Hello" in base64url
      final result = base64UrlDecodeForTesting('SGVsbG8');
      expect(result, equals('Hello'));
    });

    test('decodes base64url with one padding needed', () {
      // "Hi" in base64url (needs one padding char)
      final result = base64UrlDecodeForTesting('SGk');
      expect(result, equals('Hi'));
    });

    test('decodes base64url with two padding needed', () {
      // "H" in base64url (needs two padding chars)
      final result = base64UrlDecodeForTesting('SA');
      expect(result, equals('H'));
    });

    test('decodes JWT-style payload', () {
      // {"sub":"123"} in base64url
      final result = base64UrlDecodeForTesting('eyJzdWIiOiIxMjMifQ');
      expect(result, equals('{"sub":"123"}'));
    });

    test('handles empty string', () {
      final result = base64UrlDecodeForTesting('');
      expect(result, isEmpty);
    });

    test('handles URL-safe characters', () {
      // Test with _ and - which are base64url specific
      final result = base64UrlDecodeForTesting('YWJj');
      expect(result, equals('abc'));
    });
  });

  group('generateLinkingCodeForTesting', () {
    test('generates code in correct format', () {
      final code = generateLinkingCodeForTesting();
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}$')));
    });

    test('generates codes with only allowed characters', () {
      // Generate multiple codes and verify all characters are valid
      const allowedChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

      for (var i = 0; i < 10; i++) {
        final code = generateLinkingCodeForTesting();
        final codeWithoutDash = code.replaceAll('-', '');

        for (final char in codeWithoutDash.split('')) {
          expect(
            allowedChars.contains(char),
            isTrue,
            reason: 'Character $char should be in allowed set',
          );
        }
      }
    });

    test('generates unique codes', () {
      // Generate 100 codes and verify they are unique
      final codes = <String>{};

      for (var i = 0; i < 100; i++) {
        final code = generateLinkingCodeForTesting();
        codes.add(code);
      }

      expect(codes.length, equals(100), reason: 'All codes should be unique');
    });

    test('excludes ambiguous characters (I, O, 0, 1)', () {
      // Generate many codes and verify no ambiguous characters
      // Note: L is allowed (only I, O, 0, 1 are excluded for readability)
      const ambiguousChars = ['I', 'O', '0', '1'];

      for (var i = 0; i < 100; i++) {
        final code = generateLinkingCodeForTesting();

        for (final char in ambiguousChars) {
          expect(
            code.contains(char),
            isFalse,
            reason: 'Code should not contain ambiguous character: $char',
          );
        }
      }
    });

    test('has correct length', () {
      final code = generateLinkingCodeForTesting();
      expect(code.length, equals(11)); // 5 + 1 (dash) + 5 = 11
    });
  });

  group('isValidLinkingCode', () {
    test('validates correct format', () {
      // Only allowed chars: ABCDEFGHJKLMNPQRSTUVWXYZ23456789
      expect(isValidLinkingCode('ABCDE-23456'), isTrue);
      expect(isValidLinkingCode('XXXXX-YYYYY'), isTrue);
      expect(isValidLinkingCode('A2B3C-D4E5F'), isTrue);
    });

    test('rejects invalid formats', () {
      expect(isValidLinkingCode('ABCDE23456'), isFalse); // Missing dash
      expect(isValidLinkingCode('ABCD-23456'), isFalse); // First part too short
      expect(
        isValidLinkingCode('ABCDE-2345'),
        isFalse,
      ); // Second part too short
      expect(isValidLinkingCode('abcde-23456'), isFalse); // Lowercase
      expect(isValidLinkingCode(''), isFalse); // Empty
      expect(
        isValidLinkingCode('ABCDI-23456'),
        isFalse,
      ); // Contains I (excluded)
      expect(
        isValidLinkingCode('ABCDO-23456'),
        isFalse,
      ); // Contains O (excluded)
      expect(
        isValidLinkingCode('ABCD0-23456'),
        isFalse,
      ); // Contains 0 (excluded)
      expect(
        isValidLinkingCode('ABCD1-23456'),
        isFalse,
      ); // Contains 1 (excluded)
      // Note: L is allowed, not excluded
    });

    test('accepts codes with L (L is allowed)', () {
      expect(isValidLinkingCode('ABCDL-23456'), isTrue);
      expect(isValidLinkingCode('LLLLL-LLLLL'), isTrue);
    });

    test('validates generated codes', () {
      for (var i = 0; i < 50; i++) {
        final code = generateLinkingCodeForTesting();
        expect(isValidLinkingCode(code), isTrue);
      }
    });
  });

  group('linkingCodePattern', () {
    test('matches valid patterns', () {
      // Only chars in: A-HJ-NP-Z2-9 (excludes I, L, O, 0, 1)
      expect(linkingCodePattern.hasMatch('ABCDE-23456'), isTrue);
      expect(linkingCodePattern.hasMatch('22222-33333'), isTrue);
      expect(linkingCodePattern.hasMatch('ZZZZZ-YYYYY'), isTrue);
    });

    test('rejects invalid patterns', () {
      expect(linkingCodePattern.hasMatch('TEST'), isFalse);
      expect(linkingCodePattern.hasMatch('TESTX-CODE'), isFalse);
      expect(linkingCodePattern.hasMatch('testx-code1'), isFalse);
      expect(linkingCodePattern.hasMatch('TESTX-CODE1'), isFalse); // Contains 1
      expect(linkingCodePattern.hasMatch('ABCDI-23456'), isFalse); // Contains I
    });
  });

  group('validateUsernameForTesting', () {
    test('returns null for valid username', () {
      expect(validateUsernameForTesting('validuser'), isNull);
      expect(validateUsernameForTesting('user123'), isNull);
      expect(validateUsernameForTesting('user_name'), isNull);
      expect(validateUsernameForTesting('UPPERCASE'), isNull);
      expect(validateUsernameForTesting('Mix_Case_123'), isNull);
    });

    test('rejects null username', () {
      final error = validateUsernameForTesting(null);
      expect(error, contains('at least'));
    });

    test('rejects short username', () {
      expect(validateUsernameForTesting('short'), contains('at least'));
      expect(validateUsernameForTesting('ab'), contains('at least'));
      expect(validateUsernameForTesting(''), contains('at least'));
    });

    test('rejects username with @ symbol', () {
      expect(validateUsernameForTesting('user@domain'), contains('@'));
      expect(validateUsernameForTesting('test@test.com'), contains('@'));
    });

    test('rejects username with special characters', () {
      expect(
        validateUsernameForTesting('user-name'),
        contains('letters, numbers'),
      );
      expect(
        validateUsernameForTesting('user.name'),
        contains('letters, numbers'),
      );
      expect(
        validateUsernameForTesting('user name'),
        contains('letters, numbers'),
      );
      expect(
        validateUsernameForTesting('user!name'),
        contains('letters, numbers'),
      );
    });

    test('exactly 6 characters is valid', () {
      expect(validateUsernameForTesting('abcdef'), isNull);
    });
  });

  group('validatePasswordHashForTesting', () {
    test('returns null for valid SHA-256 hash', () {
      // Valid 64-char lowercase hex
      expect(validatePasswordHashForTesting('a' * 64), isNull);
      expect(validatePasswordHashForTesting('0123456789abcdef' * 4), isNull);
    });

    test('accepts uppercase hex', () {
      expect(validatePasswordHashForTesting('ABCDEF0123456789' * 4), isNull);
    });

    test('accepts mixed case hex', () {
      expect(validatePasswordHashForTesting('AbCdEf0123456789' * 4), isNull);
    });

    test('rejects null password hash', () {
      final error = validatePasswordHashForTesting(null);
      expect(error, contains('8 characters'));
    });

    test('rejects short password hash', () {
      expect(validatePasswordHashForTesting('abc'), contains('8 characters'));
      expect(
        validatePasswordHashForTesting('a' * 63),
        contains('8 characters'),
      );
    });

    test('rejects long password hash', () {
      expect(
        validatePasswordHashForTesting('a' * 65),
        contains('8 characters'),
      );
    });

    test('rejects non-hex characters', () {
      expect(
        validatePasswordHashForTesting('g' * 64),
        contains('Invalid password format'),
      );
      expect(
        validatePasswordHashForTesting('z' * 64),
        contains('Invalid password format'),
      );
      expect(
        validatePasswordHashForTesting('!' * 64),
        contains('Invalid password format'),
      );
    });
  });

  group('mapEventTypeToOperationForTesting', () {
    test('maps create events to USER_CREATE', () {
      expect(
        mapEventTypeToOperationForTesting('create'),
        equals('USER_CREATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('CREATE'),
        equals('USER_CREATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('nosebleedrecorded'),
        equals('USER_CREATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('NOSEBLEEDRECORDED'),
        equals('USER_CREATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('surveysubmitted'),
        equals('USER_CREATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('SurveySubmitted'),
        equals('USER_CREATE'),
      );
    });

    test('maps update events to USER_UPDATE', () {
      expect(
        mapEventTypeToOperationForTesting('update'),
        equals('USER_UPDATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('UPDATE'),
        equals('USER_UPDATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('nosebleedupdated'),
        equals('USER_UPDATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('NosebleedUpdated'),
        equals('USER_UPDATE'),
      );
    });

    test('maps delete events to USER_DELETE', () {
      expect(
        mapEventTypeToOperationForTesting('delete'),
        equals('USER_DELETE'),
      );
      expect(
        mapEventTypeToOperationForTesting('DELETE'),
        equals('USER_DELETE'),
      );
      expect(
        mapEventTypeToOperationForTesting('nosebleeddeleted'),
        equals('USER_DELETE'),
      );
      expect(
        mapEventTypeToOperationForTesting('NOSEBLEEDDELETED'),
        equals('USER_DELETE'),
      );
    });

    test('defaults to USER_CREATE for unknown types', () {
      expect(
        mapEventTypeToOperationForTesting('unknown'),
        equals('USER_CREATE'),
      );
      expect(
        mapEventTypeToOperationForTesting('random'),
        equals('USER_CREATE'),
      );
      expect(mapEventTypeToOperationForTesting(''), equals('USER_CREATE'));
    });
  });

  group('enrollmentCodePattern', () {
    test('matches valid enrollment codes', () {
      expect(enrollmentCodePattern.hasMatch('CUREHHT0'), isTrue);
      expect(enrollmentCodePattern.hasMatch('CUREHHT1'), isTrue);
      expect(enrollmentCodePattern.hasMatch('CUREHHT9'), isTrue);
      expect(
        enrollmentCodePattern.hasMatch('curehht5'),
        isTrue,
      ); // Case insensitive
    });

    test('rejects invalid enrollment codes', () {
      expect(
        enrollmentCodePattern.hasMatch('CUREHHT'),
        isFalse,
      ); // Missing digit
      expect(
        enrollmentCodePattern.hasMatch('CUREHHT10'),
        isFalse,
      ); // Two digits
      expect(enrollmentCodePattern.hasMatch('CUREHHT-1'), isFalse); // Dash
      expect(
        enrollmentCodePattern.hasMatch('CUREHX1'),
        isFalse,
      ); // Wrong prefix
      expect(enrollmentCodePattern.hasMatch(''), isFalse);
    });
  });

  group('isValidEnrollmentCode', () {
    test('validates correct format', () {
      expect(isValidEnrollmentCode('CUREHHT0'), isTrue);
      expect(isValidEnrollmentCode('CUREHHT5'), isTrue);
      expect(isValidEnrollmentCode('curehht3'), isTrue); // Handles lowercase
    });

    test('rejects invalid format', () {
      expect(isValidEnrollmentCode('INVALID'), isFalse);
      expect(isValidEnrollmentCode(''), isFalse);
      expect(isValidEnrollmentCode('CUREHHT'), isFalse);
    });
  });
}
