import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WirePayload', () {
    // Verifies: REQ-d00122-D — value carries bytes + contentType +
    // transformVersion; getters return the stored values.
    test('REQ-d00122-D: constructor stores and exposes all three fields', () {
      final bytes = Uint8List.fromList([0x7b, 0x7d]); // '{}'
      final payload = WirePayload(
        bytes: bytes,
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      expect(payload.bytes, bytes);
      expect(payload.contentType, 'application/json');
      expect(payload.transformVersion, 'json-v1');
    });

    test('REQ-d00122-D: equal fields produce equal values', () {
      final a = WirePayload(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      final b = WirePayload(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('bytes are compared element-wise, not by identity', () {
      final a = WirePayload(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      final b = WirePayload(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      expect(identical(a.bytes, b.bytes), isFalse);
      expect(a == b, isTrue);
    });

    test('different bytes break equality', () {
      final a = WirePayload(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      final b = WirePayload(
        bytes: Uint8List.fromList([1, 2, 4]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      expect(a == b, isFalse);
    });

    test('different contentType breaks equality', () {
      final a = WirePayload(
        bytes: Uint8List.fromList([1]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      final b = WirePayload(
        bytes: Uint8List.fromList([1]),
        contentType: 'application/fhir+json',
        transformVersion: 'json-v1',
      );
      expect(a == b, isFalse);
    });

    test('different transformVersion breaks equality', () {
      final a = WirePayload(
        bytes: Uint8List.fromList([1]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      final b = WirePayload(
        bytes: Uint8List.fromList([1]),
        contentType: 'application/json',
        transformVersion: 'json-v2',
      );
      expect(a == b, isFalse);
    });

    test('constructor defensively copies bytes; caller mutation does not '
        'leak into the payload', () {
      final mutable = Uint8List.fromList([1, 2, 3]);
      final payload = WirePayload(
        bytes: mutable,
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      mutable[0] = 99;
      expect(payload.bytes, Uint8List.fromList([1, 2, 3]));
    });

    test('toString summarizes byte length and stamps', () {
      final payload = WirePayload(
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      final str = payload.toString();
      expect(str, contains('5 bytes'));
      expect(str, contains('application/json'));
      expect(str, contains('json-v1'));
    });

    test('empty payload is allowed', () {
      final empty = WirePayload(
        bytes: Uint8List(0),
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      expect(empty.bytes, isEmpty);
      expect(empty.contentType, 'application/json');
    });
  });
}
