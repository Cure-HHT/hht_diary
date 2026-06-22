// Verifies: DIARY-DEV-linking-code-lifecycle/A+E
import 'dart:convert';
import 'dart:io';

import 'package:portal_actions/src/linking_code_generator.dart';
import 'package:test/test.dart';

void main() {
  test('code is prefix + 8 non-ambiguous chars, random', () {
    const charset = 'ABCDEFGHJKLMNPQRTUVWXY346789';
    final codes = {
      for (var i = 0; i < 100; i++) generateLinkingCode(prefix: 'CA'),
    };
    expect(codes.length, 100);
    for (final c in codes) {
      expect(c.startsWith('CA'), isTrue);
      expect(c.length, 10);
      expect(c.substring(2).split('').every(charset.contains), isTrue);
    }
  });

  const key = 'test-sponsor-key-not-secret';
  const charset = 'ABCDEFGHJKLMNPQRTUVWXY346789';

  group('checkCharsFor', () {
    test('is deterministic and two chars from the charset', () {
      final c = checkCharsFor('CARANDOM', key);
      expect(c.length, 2);
      expect(charset.contains(c[0]), isTrue);
      expect(charset.contains(c[1]), isTrue);
      expect(checkCharsFor('CARANDOM', key), c); // stable
    });

    test('changes with key (HMAC, not a public checksum)', () {
      expect(
        checkCharsFor('CARANDOM', key),
        isNot(checkCharsFor('CARANDOM', 'different-key')),
      );
    });
  });

  group('generateLinkingCode', () {
    test('is 10 chars: prefix + 6 random + 2 valid check', () {
      final code = generateLinkingCode(prefix: 'CA', sponsorKey: key);
      expect(code.length, 10);
      expect(code.startsWith('CA'), isTrue);
      expect(code.substring(2).split('').every(charset.contains), isTrue);
      // last 2 are the MAC over the first 8
      expect(code.substring(8), checkCharsFor(code.substring(0, 8), key));
    });
  });

  group('golden vectors (cross-language contract)', () {
    test('every vector recomputes to its committed check chars', () {
      final file = File(
        '${Directory.current.path}/../../../contract/'
        'linking-code-mac-vectors.json',
      );
      final vectors = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(vectors, isNotEmpty);
      for (final v in vectors) {
        expect(
          checkCharsFor(v['input'] as String, v['keyUtf8'] as String),
          v['check'] as String,
          reason: 'vector ${v['input']} drifted',
        );
      }
    });
  });
}
