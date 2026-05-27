// IMPLEMENTS REQUIREMENTS:
//   REQ-p00004: Immutable Audit Trail via Event Sourcing (canonicalisation)
//   REQ-p00011: ALCOA+ Data Integrity Principles (deterministic hashing)
//
// Verifies: RFC 8785 conformance vectors beyond the default test set.
//
// These vectors target edge cases that are most likely to drift in a
// re-implementation: surrogate pairs in keys, very small/large numbers,
// nested object key ordering, and array-of-object stability.

import 'dart:convert';

import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:test/test.dart';

void main() {
  group('RFC 8785 — Appendix A object vectors', () {
    test('object with mixed value types — keys sorted by code unit', () {
      final input = <String, Object?>{
        'numbers': [
          333333333.33333329,
          1e30,
          4.50,
          2e-3,
          0.000000000000000000000000001,
        ],
        'string': '€\$\nA\'B"\\\\"/',
        'literals': [null, true, false],
      };
      // JCS sorts keys by UTF-16 codepoint:
      //   l(0x6c) < n(0x6e) < s(0x73) -> literals, numbers, string.
      final out = canonicalize(input);
      final keysInOrder = RegExp(
        r'"([a-z]+)":',
      ).allMatches(out).map((m) => m.group(1)).toList();
      expect(keysInOrder, ['literals', 'numbers', 'string']);
    });

    test('nested objects sort independently at each depth', () {
      final input = {
        'outer': {
          'z': 1,
          'a': {'y': 2, 'b': 3},
        },
        'a': 4,
      };
      expect(canonicalize(input), '{"a":4,"outer":{"a":{"b":3,"y":2},"z":1}}');
    });

    test('array element order is preserved (not sorted)', () {
      expect(
        canonicalize([
          {'b': 2, 'a': 1},
          {'b': 4, 'a': 3},
        ]),
        '[{"a":1,"b":2},{"a":3,"b":4}]',
      );
    });
  });

  group('RFC 8785 — string edge cases', () {
    test('surrogate pair key sorts by UTF-16 code unit order', () {
      // U+1D11E (MUSICAL SYMBOL G CLEF) starts with high surrogate D834.
      // U+10000 (LINEAR B SYLLABLE B008 A) starts with high surrogate D800.
      // In UTF-16 code-unit order, U+10000 sorts before U+1D11E.
      final input = <String, Object?>{'\u{1D11E}': 1, '\u{10000}': 2, 'a': 3};
      final out = canonicalize(input);
      // 'a' (U+0061) comes first, then U+10000 (D800...), then U+1D11E (D834...)
      expect(out.indexOf('"a"'), lessThan(out.indexOf('"\u{10000}"')));
      expect(out.indexOf('"\u{10000}"'), lessThan(out.indexOf('"\u{1D11E}"')));
    });

    test('forward slash is NOT escaped (per RFC 8785 §3.2.2.2)', () {
      expect(canonicalize('a/b/c'), '"a/b/c"');
    });

    test('DEL (U+007F) is passed through, not escaped', () {
      // U+007F is above the C0 control range; RFC 8785 only escapes U+0000–U+001F
      // and " and \. DEL stays as a literal byte in the UTF-8 output.
      expect(canonicalize(''), '""');
    });
  });

  group('RFC 8785 — number edge cases', () {
    test('very small subnormal positive value', () {
      // 5e-324 is the smallest positive double
      expect(canonicalize(5e-324), '5e-324');
    });

    test('integer boundary values', () {
      expect(canonicalize(9007199254740992), '9007199254740992'); // 2^53
      expect(canonicalize(-9007199254740992), '-9007199254740992');
    });

    test('integers exceeding 2^53 emit literal int (Dart VM)', () {
      // Dart on VM has arbitrary-precision int; the encoder must emit the
      // integer literal as-is.
      expect(canonicalize(2305843009213693952), '2305843009213693952'); // 2^61
    });
  });

  group('Canonicalization invariance — adversarial inputs', () {
    test('re-encoded JSON round-trips identically', () {
      final original = <String, Object?>{
        'b': [3, 1, 2],
        'a': {'z': null, 'y': true},
      };
      final encoded = canonicalize(original);
      final decoded = jsonDecode(encoded);
      final reEncoded = canonicalize(decoded);
      expect(reEncoded, equals(encoded));
    });

    test('insertion order does not affect bytes (200-key stress)', () {
      final keys = List.generate(
        200,
        (i) => 'key_${i.toString().padLeft(3, "0")}',
      );
      final forward = <String, Object?>{for (final k in keys) k: k.hashCode};
      final reverse = <String, Object?>{
        for (final k in keys.reversed) k: k.hashCode,
      };
      expect(canonicalizeBytes(forward), canonicalizeBytes(reverse));
    });
  });
}
