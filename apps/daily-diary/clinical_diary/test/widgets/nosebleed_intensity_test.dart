// Tests for nosebleed_intensity.dart
// Covers: Intensity enum parsing, display names

import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NosebleedIntensity', () {
    group('displayName', () {
      test('spotting returns correct display name', () {
        expect(NosebleedIntensity.spotting.displayName, 'Spotting');
      });

      test('dripping returns correct display name', () {
        expect(NosebleedIntensity.dripping.displayName, 'Dripping');
      });

      test('drippingQuickly returns correct display name', () {
        expect(
          NosebleedIntensity.drippingQuickly.displayName,
          'Dripping quickly',
        );
      });

      test('steadyStream returns correct display name', () {
        expect(NosebleedIntensity.steadyStream.displayName, 'Steady stream');
      });

      test('pouring returns correct display name', () {
        expect(NosebleedIntensity.pouring.displayName, 'Pouring');
      });

      test('gushing returns correct display name', () {
        expect(NosebleedIntensity.gushing.displayName, 'Gushing');
      });

      test('all intensities have unique display names', () {
        final displayNames = NosebleedIntensity.values
            .map((e) => e.displayName)
            .toSet();
        expect(displayNames.length, NosebleedIntensity.values.length);
      });
    });

    group('fromString', () {
      test('parses null as null', () {
        expect(NosebleedIntensity.fromString(null), isNull);
      });

      test('parses empty string as null', () {
        expect(NosebleedIntensity.fromString(''), isNull);
      });

      test('parses enum name form (spotting)', () {
        expect(
          NosebleedIntensity.fromString('spotting'),
          NosebleedIntensity.spotting,
        );
      });

      test('parses enum name form (drippingQuickly)', () {
        expect(
          NosebleedIntensity.fromString('drippingQuickly'),
          NosebleedIntensity.drippingQuickly,
        );
      });

      test('parses enum name form (steadyStream)', () {
        expect(
          NosebleedIntensity.fromString('steadyStream'),
          NosebleedIntensity.steadyStream,
        );
      });

      test('parses display name form (Spotting)', () {
        expect(
          NosebleedIntensity.fromString('Spotting'),
          NosebleedIntensity.spotting,
        );
      });

      test('parses display name form (Dripping quickly)', () {
        expect(
          NosebleedIntensity.fromString('Dripping quickly'),
          NosebleedIntensity.drippingQuickly,
        );
      });

      test('parses display name form (Steady stream)', () {
        expect(
          NosebleedIntensity.fromString('Steady stream'),
          NosebleedIntensity.steadyStream,
        );
      });

      test('returns null for unknown string', () {
        expect(NosebleedIntensity.fromString('unknown'), isNull);
      });

      test('returns null for partial match', () {
        expect(NosebleedIntensity.fromString('Spot'), isNull);
      });

      test('returns null for case mismatch on enum name', () {
        // 'SPOTTING' does not match 'spotting' or 'Spotting'
        expect(NosebleedIntensity.fromString('SPOTTING'), isNull);
      });

      test('all enum values can be round-tripped via name', () {
        for (final intensity in NosebleedIntensity.values) {
          final parsed = NosebleedIntensity.fromString(intensity.name);
          expect(parsed, intensity);
        }
      });

      test('all enum values can be round-tripped via displayName', () {
        for (final intensity in NosebleedIntensity.values) {
          final parsed = NosebleedIntensity.fromString(intensity.displayName);
          expect(parsed, intensity);
        }
      });
    });

    group('values', () {
      test('has exactly 6 intensity levels', () {
        expect(NosebleedIntensity.values.length, 6);
      });

      test('values are in severity order', () {
        expect(NosebleedIntensity.values[0], NosebleedIntensity.spotting);
        expect(NosebleedIntensity.values[1], NosebleedIntensity.dripping);
        expect(
          NosebleedIntensity.values[2],
          NosebleedIntensity.drippingQuickly,
        );
        expect(NosebleedIntensity.values[3], NosebleedIntensity.steadyStream);
        expect(NosebleedIntensity.values[4], NosebleedIntensity.pouring);
        expect(NosebleedIntensity.values[5], NosebleedIntensity.gushing);
      });
    });
  });
}
