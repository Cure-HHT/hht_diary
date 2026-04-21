import 'package:provenance/provenance.dart';
import 'package:test/test.dart';

/// Verifies REQ-d00115-C, REQ-d00115-D, REQ-d00115-E, REQ-d00115-F.
void main() {
  group('ProvenanceEntry', () {
    // Verifies: REQ-d00115-C — carries all five fields with correct types.
    test(
      'REQ-d00115-C: construct with all required fields; getters round-trip',
      () {
        final receivedAt = DateTime.utc(2026, 4, 21, 10, 30, 0);
        final entry = ProvenanceEntry(
          hop: 'mobile-device',
          receivedAt: receivedAt,
          identifier: 'device-uuid-abc123',
          softwareVersion: 'clinical_diary@1.2.3+45',
        );

        expect(entry.hop, 'mobile-device');
        expect(entry.receivedAt, receivedAt);
        expect(entry.identifier, 'device-uuid-abc123');
        expect(entry.softwareVersion, 'clinical_diary@1.2.3+45');
        expect(entry.transformVersion, isNull);
      },
    );

    // Verifies: REQ-d00115-F — transform_version non-null when supplied.
    test(
      'REQ-d00115-F: construct with transformVersion; getter returns value',
      () {
        final entry = ProvenanceEntry(
          hop: 'portal-server',
          receivedAt: DateTime.utc(2026, 4, 21, 11, 0, 0),
          identifier: 'portal-instance-7',
          softwareVersion: 'portal-functions@0.5.0',
          transformVersion: 'fhir-r4-v1',
        );

        expect(entry.transformVersion, 'fhir-r4-v1');
      },
    );

    // Verifies: REQ-d00115-C — toJson serializes all fields in snake_case.
    test(
      'REQ-d00115-C: toJson emits snake_case keys including null transform_version',
      () {
        final entry = ProvenanceEntry(
          hop: 'mobile-device',
          receivedAt: DateTime.utc(2026, 4, 21, 10, 30, 0),
          identifier: 'device-uuid-abc123',
          softwareVersion: 'clinical_diary@1.2.3+45',
        );

        expect(entry.toJson(), {
          'hop': 'mobile-device',
          'received_at': '2026-04-21T10:30:00.000Z',
          'identifier': 'device-uuid-abc123',
          'software_version': 'clinical_diary@1.2.3+45',
          'transform_version': null,
        });
      },
    );

    // Verifies: REQ-d00115-F — toJson emits non-null transform_version.
    test('REQ-d00115-F: toJson emits non-null transform_version when set', () {
      final entry = ProvenanceEntry(
        hop: 'portal-server',
        receivedAt: DateTime.utc(2026, 4, 21, 11, 0, 0),
        identifier: 'portal-instance-7',
        softwareVersion: 'portal-functions@0.5.0',
        transformVersion: 'fhir-r4-v1',
      );

      expect(entry.toJson()['transform_version'], 'fhir-r4-v1');
    });

    // Verifies: REQ-d00115-C — round-trip preserves every field.
    test('REQ-d00115-C: toJson/fromJson round-trip preserves all fields', () {
      final original = ProvenanceEntry(
        hop: 'diary-server',
        receivedAt: DateTime.utc(2026, 4, 21, 12, 15, 30, 500),
        identifier: 'diary-instance-42',
        softwareVersion: 'diary_functions@0.8.2+101',
        transformVersion: 'v2',
      );

      final roundTripped = ProvenanceEntry.fromJson(original.toJson());

      expect(roundTripped, equals(original));
    });

    // Verifies: REQ-d00115-F — round-trip preserves null transform_version.
    test('REQ-d00115-F: round-trip preserves null transform_version', () {
      final original = ProvenanceEntry(
        hop: 'mobile-device',
        receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
        identifier: 'device-xyz',
        softwareVersion: 'clinical_diary@1.0.0',
      );

      final roundTripped = ProvenanceEntry.fromJson(original.toJson());

      expect(roundTripped.transformVersion, isNull);
      expect(roundTripped, equals(original));
    });

    // Verifies: REQ-d00115-C — received_at is ISO 8601 with offset preserved.
    test(
      'REQ-d00115-C: received_at serializes with timezone offset (Z for UTC)',
      () {
        final entry = ProvenanceEntry(
          hop: 'mobile-device',
          receivedAt: DateTime.utc(2026, 4, 21, 10, 30, 0),
          identifier: 'd',
          softwareVersion: 'clinical_diary@1.0.0',
        );

        final json = entry.toJson();
        expect(json['received_at'], endsWith('Z'));
        expect(json['received_at'], '2026-04-21T10:30:00.000Z');
      },
    );

    group('fromJson validation (REQ-d00115-C)', () {
      final validJson = {
        'hop': 'mobile-device',
        'received_at': '2026-04-21T10:30:00.000Z',
        'identifier': 'device-uuid',
        'software_version': 'clinical_diary@1.0.0',
        'transform_version': null,
      };

      // Verifies: REQ-d00115-C — missing hop is rejected.
      test('REQ-d00115-C: missing hop throws FormatException', () {
        final bad = Map<String, Object?>.of(validJson)..remove('hop');
        expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00115-C — missing received_at is rejected.
      test('REQ-d00115-C: missing received_at throws FormatException', () {
        final bad = Map<String, Object?>.of(validJson)..remove('received_at');
        expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00115-C — missing identifier is rejected.
      test('REQ-d00115-C: missing identifier throws FormatException', () {
        final bad = Map<String, Object?>.of(validJson)..remove('identifier');
        expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00115-C — missing software_version is rejected.
      test('REQ-d00115-C: missing software_version throws FormatException', () {
        final bad = Map<String, Object?>.of(validJson)
          ..remove('software_version');
        expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00115-C — wrong-type field is rejected.
      test('REQ-d00115-C: non-string hop throws FormatException', () {
        final bad = Map<String, Object?>.of(validJson)..['hop'] = 42;
        expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00115-F — wrong-type transform_version is rejected.
      test(
        'REQ-d00115-F: non-string transform_version throws FormatException',
        () {
          final bad = Map<String, Object?>.of(validJson)
            ..['transform_version'] = 12;
          expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
        },
      );

      // Verifies: REQ-d00115-C — missing transform_version defaults to null.
      test('REQ-d00115-C: absent transform_version key is treated as null', () {
        final bad = Map<String, Object?>.of(validJson)
          ..remove('transform_version');
        final entry = ProvenanceEntry.fromJson(bad);
        expect(entry.transformVersion, isNull);
      });

      // Verifies: REQ-d00115-C — malformed received_at rejected.
      test('REQ-d00115-C: malformed received_at throws FormatException', () {
        final bad = Map<String, Object?>.of(validJson)
          ..['received_at'] = 'not-a-date';
        expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00115-C — offsetless ISO 8601 rejected. Dart's
      // DateTime.parse would silently accept this as local time, silently
      // breaking the ALCOA+ Contemporaneous guarantee in an audit chain.
      test(
        'REQ-d00115-C: offsetless received_at (no Z, no +/-HH:MM) throws FormatException',
        () {
          final bad = Map<String, Object?>.of(validJson)
            ..['received_at'] = '2026-04-21T10:30:00';
          expect(() => ProvenanceEntry.fromJson(bad), throwsFormatException);
        },
      );

      // Verifies: REQ-d00115-C — explicit colon-separated positive offset.
      test('REQ-d00115-C: received_at with +HH:MM offset is accepted', () {
        final input = Map<String, Object?>.of(validJson)
          ..['received_at'] = '2026-04-21T10:30:00+05:30';
        final entry = ProvenanceEntry.fromJson(input);
        expect(entry.receivedAt.isUtc, isTrue);
      });

      // Verifies: REQ-d00115-C — colonless compact negative offset.
      test(
        'REQ-d00115-C: received_at with -HHMM (no colon) offset is accepted',
        () {
          final input = Map<String, Object?>.of(validJson)
            ..['received_at'] = '2026-04-21T10:30:00-0430';
          final entry = ProvenanceEntry.fromJson(input);
          expect(entry.receivedAt.isUtc, isTrue);
        },
      );
    });

    group('identity shapes (REQ-d00115-D, REQ-d00115-E)', () {
      // Verifies: REQ-d00115-D — mobile device uses a device UUID identifier.
      test(
        'REQ-d00115-D: accepts a mobile-device hop with a device UUID identifier',
        () {
          final entry = ProvenanceEntry(
            hop: 'mobile-device',
            receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
            identifier: '550e8400-e29b-41d4-a716-446655440000',
            softwareVersion: 'clinical_diary@1.2.3+45',
          );
          expect(
            entry.identifier,
            matches(RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false)),
          );
        },
      );

      // Verifies: REQ-d00115-D — server hop uses a server instance identifier.
      test(
        'REQ-d00115-D: accepts a server hop with a server instance identifier',
        () {
          final entry = ProvenanceEntry(
            hop: 'diary-server',
            receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
            identifier: 'diary-instance-42',
            softwareVersion: 'diary_functions@0.8.2',
          );
          expect(entry.identifier, startsWith('diary-instance-'));
        },
      );

      // Verifies: REQ-d00115-E — software_version format is preserved verbatim.
      test(
        'REQ-d00115-E: software_version round-trips package@semver+build verbatim',
        () {
          const target = 'clinical_diary@1.2.3+45';
          final entry = ProvenanceEntry(
            hop: 'mobile-device',
            receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
            identifier: 'd',
            softwareVersion: target,
          );
          expect(entry.softwareVersion, target);
          expect(entry.toJson()['software_version'], target);
        },
      );
    });

    group('value equality', () {
      // Verifies: REQ-d00115-C — two entries with identical fields are equal.
      test(
        'REQ-d00115-C: equal fields produce equal entries and equal hashCodes',
        () {
          final a = ProvenanceEntry(
            hop: 'mobile-device',
            receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
            identifier: 'd',
            softwareVersion: 'clinical_diary@1.0.0',
          );
          final b = ProvenanceEntry(
            hop: 'mobile-device',
            receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
            identifier: 'd',
            softwareVersion: 'clinical_diary@1.0.0',
          );

          expect(a, equals(b));
          expect(a.hashCode, b.hashCode);
        },
      );

      // Verifies: REQ-d00115-C — any field difference breaks equality.
      test('REQ-d00115-C: any field differing breaks equality', () {
        final base = ProvenanceEntry(
          hop: 'mobile-device',
          receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
          identifier: 'd',
          softwareVersion: 'clinical_diary@1.0.0',
        );

        expect(
          base,
          isNot(
            equals(
              ProvenanceEntry(
                hop: 'diary-server',
                receivedAt: base.receivedAt,
                identifier: base.identifier,
                softwareVersion: base.softwareVersion,
              ),
            ),
          ),
        );
        expect(
          base,
          isNot(
            equals(
              ProvenanceEntry(
                hop: base.hop,
                receivedAt: DateTime.utc(2026, 4, 22, 10, 0, 0),
                identifier: base.identifier,
                softwareVersion: base.softwareVersion,
              ),
            ),
          ),
        );
      });
    });
  });
}
