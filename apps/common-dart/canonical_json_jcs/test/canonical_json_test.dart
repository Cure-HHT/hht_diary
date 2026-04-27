// Test vectors adapted from affinidi-ssi-dart's JCS test suite
// (Apache License 2.0). See the package NOTICE.md for full attribution.

import 'dart:convert';
import 'dart:typed_data';

import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:test/test.dart';

// Convert a 64-bit hex string to a Dart double for Appendix B tests.
double _hex2double(String hexValue) {
  final h = hexValue.startsWith('0x') ? hexValue.substring(2) : hexValue;
  if (h.length != 16) {
    throw ArgumentError('Expecting 64-bit hex string, got "$hexValue"');
  }
  final bdata = ByteData(8);
  for (var i = 0; i < h.length / 2; i += 1) {
    bdata.setInt8(i, int.parse(h.substring(2 * i, 2 * i + 2), radix: 16));
  }
  return bdata.getFloat64(0);
}

void _testNumber(String hex, String expected) {
  final d = _hex2double(hex);
  expect(canonicalize(d), equals(expected));
}

void main() {
  group('CanonicalJson (RFC 8785)', () {
    group('primitives', () {
      test('null', () => expect(canonicalize(null), 'null'));
      test('true', () => expect(canonicalize(true), 'true'));
      test('false', () => expect(canonicalize(false), 'false'));
    });

    group('integers', () {
      test('zero', () => expect(canonicalize(0), '0'));
      test('positive', () => expect(canonicalize(42), '42'));
      test('negative', () => expect(canonicalize(-17), '-17'));
      test('large', () => expect(canonicalize(1000000), '1000000'));
    });

    group('doubles', () {
      test('whole-valued double strips .0', () {
        expect(canonicalize(1.0), '1');
        expect(canonicalize(0.0), '0');
        expect(canonicalize(-5.0), '-5');
      });

      test('fractional', () {
        expect(canonicalize(3.14), '3.14');
        expect(canonicalize(-2.5), '-2.5');
        expect(canonicalize(0.123), '0.123');
      });

      test('negative zero renders as 0', () {
        expect(canonicalize(-0.0), '0');
      });

      test('NaN rejected', () {
        expect(() => canonicalize(double.nan), throwsFormatException);
      });

      test('Infinity rejected', () {
        expect(() => canonicalize(double.infinity), throwsFormatException);
        expect(
          () => canonicalize(double.negativeInfinity),
          throwsFormatException,
        );
      });

      // RFC 8785 Appendix B number test vectors.
      test('RFC 8785 Appendix B vectors', () {
        _testNumber('0x0000000000000000', '0');
        _testNumber('0x8000000000000000', '0');
        _testNumber('0x0000000000000001', '5e-324');
        _testNumber('0x8000000000000001', '-5e-324');
        _testNumber('0x7fefffffffffffff', '1.7976931348623157e+308');
        _testNumber('0xffefffffffffffff', '-1.7976931348623157e+308');
        _testNumber('0x4340000000000000', '9007199254740992');
        _testNumber('0xc340000000000000', '-9007199254740992');
        _testNumber('0x44b52d02c7e14af6', '1e+23');
        _testNumber('0x444b1ae4d6e2ef50', '1e+21');
        _testNumber('0x3eb0c6f7a0b5ed8d', '0.000001');
        _testNumber('0x41b3de4355555555', '333333333.3333333');
      });
    });

    group('strings', () {
      test('plain', () {
        expect(canonicalize('hello'), '"hello"');
        expect(canonicalize(''), '""');
        expect(canonicalize('hello world'), '"hello world"');
      });

      test('JSON special escapes', () {
        expect(canonicalize('"'), r'"\""');
        expect(canonicalize(r'\'), r'"\\"');
        expect(canonicalize('\b'), r'"\b"');
        expect(canonicalize('\f'), r'"\f"');
        expect(canonicalize('\n'), r'"\n"');
        expect(canonicalize('\r'), r'"\r"');
        expect(canonicalize('\t'), r'"\t"');
      });

      test(r'control characters escape as \u00XX', () {
        expect(canonicalize('\u0000'), r'"\u0000"');
        expect(canonicalize('\u0001'), r'"\u0001"');
        expect(canonicalize('\u001F'), r'"\u001f"');
      });

      test('non-ASCII passes through as UTF-8', () {
        expect(canonicalize('café'), '"café"');
        expect(canonicalize('🚀'), '"🚀"');
      });
    });

    group('arrays', () {
      test('empty', () => expect(canonicalize(<Object?>[]), '[]'));
      test('single int', () => expect(canonicalize([1]), '[1]'));
      test('multiple', () => expect(canonicalize([1, 2, 3]), '[1,2,3]'));
      test('mixed types', () {
        expect(canonicalize([1, 'hello', true, null]), '[1,"hello",true,null]');
      });
      test('nested', () {
        expect(
          canonicalize([
            [1, 2],
            [3, 4],
          ]),
          '[[1,2],[3,4]]',
        );
      });
      test('order preserved (not sorted)', () {
        expect(canonicalize([3, 1, 2]), '[3,1,2]');
      });
    });

    group('objects', () {
      test('empty', () {
        expect(canonicalize(<String, Object?>{}), '{}');
      });

      test('keys sorted lexicographically', () {
        expect(
          canonicalize(<String, Object?>{'b': 1, 'a': 2, 'c': 3}),
          '{"a":2,"b":1,"c":3}',
        );
      });

      test('nested keys sorted recursively', () {
        expect(
          canonicalize(<String, Object?>{
            'z': <String, Object?>{'b': 1, 'a': 2},
            'a': 3,
          }),
          '{"a":3,"z":{"a":2,"b":1}}',
        );
      });

      test('insertion order does not affect output', () {
        final forward = <String, Object?>{'a': 1, 'b': 2, 'c': 3};
        final reverse = <String, Object?>{'c': 3, 'b': 2, 'a': 1};
        expect(canonicalize(forward), equals(canonicalize(reverse)));
      });

      test('identical input produces identical UTF-8 bytes', () {
        final input = <String, Object?>{
          'event_id': 'abc',
          'aggregate_id': 'xyz',
          'sequence_number': 42,
          'data': <String, Object?>{'intensity': 'mild', 'notes': 'ok'},
        };
        final bytesA = canonicalizeBytes(input);
        final bytesB = canonicalizeBytes(input);
        expect(bytesA, equals(bytesB));
        // Content is UTF-8 of the canonicalize() string.
        expect(utf8.decode(bytesA), canonicalize(input));
      });
    });

    group('unsupported types', () {
      test('DateTime throws FormatException', () {
        expect(
          () => canonicalize(DateTime.utc(2026, 4, 22)),
          throwsFormatException,
        );
      });

      test('custom object throws FormatException', () {
        expect(() => canonicalize(Object()), throwsFormatException);
      });
    });

    group('cross-platform invariance property', () {
      // These are the shape tests that most closely mirror the production
      // use case: a Dart client canonicalizes an event record; a server
      // in a different language re-canonicalizes the same record and
      // should get the same bytes. We can't run the server here, but we
      // can pin the exact canonical form so any receiver targeting our
      // format has a concrete baseline to match.
      test('example event record matches known canonical form', () {
        final event = <String, Object?>{
          'event_id': 'abc123',
          'aggregate_id': 'agg-1',
          'entry_type': 'epistaxis_event',
          'event_type': 'finalized',
          'sequence_number': 1,
          'data': <String, Object?>{'intensity': 'mild', 'notes': null},
          'user_id': 'u-1',
          'device_id': 'd-1',
          'client_timestamp': '2026-04-22T15:30:00Z',
          'previous_event_hash': null,
        };

        // Expected form: keys sorted lexicographically at both depths,
        // no whitespace, explicit null for missing optional fields.
        const expected =
            '{"aggregate_id":"agg-1","client_timestamp":"2026-04-22T15:30:00Z",'
            '"data":{"intensity":"mild","notes":null},"device_id":"d-1",'
            '"entry_type":"epistaxis_event","event_id":"abc123",'
            '"event_type":"finalized","previous_event_hash":null,'
            '"sequence_number":1,"user_id":"u-1"}';
        expect(canonicalize(event), equals(expected));
      });
    });
  });
}
