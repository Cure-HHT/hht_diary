// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p01044-C: sponsor-configurable inactivity timeout
//
// Unit tests for sponsor configuration handler

import 'dart:convert';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('Sponsor Config Handler Tests', () {
    test('returns config for known sponsor (curehht)', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(200));

      // Parse response body
      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['sponsorId'], equals('curehht'));
        expect(json['isDefault'], isFalse);
        expect(json['flags'], isNotNull);
        expect(json['flags']['useAnimations'], isTrue);
      });
    });

    test('returns config for known sponsor (callisto)', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=callisto'),
      );

      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(200));

      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['sponsorId'], equals('callisto'));
        expect(json['isDefault'], isFalse);
        expect(json['flags']['requireOldEntryJustification'], isTrue);
      });
    });

    test('returns default config for unknown sponsor', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=unknown'),
      );

      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(200));

      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['sponsorId'], equals('unknown'));
        expect(json['isDefault'], isTrue);
      });
    });

    test('normalizes sponsor ID to lowercase', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=CUREHHT'),
      );

      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(200));

      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['sponsorId'], equals('curehht'));
        expect(json['isDefault'], isFalse);
      });
    });

    test('returns 400 for missing sponsorId', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config'),
      );

      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(400));

      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['error'], contains('sponsorId'));
      });
    });

    test('returns 405 for non-GET methods', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(405));
    });

    test('config includes all required feature flags', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);

      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;
        final flags = json['flags'] as Map<String, dynamic>;

        // Check all expected flags are present
        expect(flags.containsKey('useReviewScreen'), isTrue);
        expect(flags.containsKey('useAnimations'), isTrue);
        expect(flags.containsKey('requireOldEntryJustification'), isTrue);
        expect(flags.containsKey('enableShortDurationConfirmation'), isTrue);
        expect(flags.containsKey('enableLongDurationConfirmation'), isTrue);
        expect(flags.containsKey('longDurationThresholdMinutes'), isTrue);
        expect(flags.containsKey('availableFonts'), isTrue);
        // REQ-p01044-C: inactivity timeout must be present
        expect(flags.containsKey('inactivityTimeoutMinutes'), isTrue);
        // REQ-p70010-C: disconnect reason format flag must be present
        expect(flags.containsKey('disconnectReasonDropdown'), isTrue);
      });
    });

    // REQ-p70010-C: default is predefined dropdown
    test('default disconnectReasonDropdown is true', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      final body = await response.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['flags']['disconnectReasonDropdown'], isTrue);
    });

    test('unknown sponsor disconnectReasonDropdown defaults to true', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=unknown'),
      );

      final response = sponsorConfigHandler(request);
      final body = await response.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['flags']['disconnectReasonDropdown'], isTrue);
    });

    // REQ-p01044-B: default timeout is 2 minutes
    test('default inactivityTimeoutMinutes is 2 for curehht', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      final body = await response.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['flags']['inactivityTimeoutMinutes'], equals(2));
    });

    // REQ-p01044-C: sponsor can override the inactivity timeout
    test(
      'callisto inactivityTimeoutMinutes is sponsor-configured value',
      () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/v1/sponsor/config?sponsorId=callisto',
          ),
        );

        final response = sponsorConfigHandler(request);
        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final timeout = json['flags']['inactivityTimeoutMinutes'] as int;

        // Must be within the valid range (1–30) and sponsor-specific
        expect(timeout, greaterThanOrEqualTo(1));
        expect(timeout, lessThanOrEqualTo(30));
        expect(timeout, isNot(equals(2))); // callisto overrides the default
      },
    );

    // REQ-p01044-C: unknown sponsor falls back to default timeout
    test('unknown sponsor inactivityTimeoutMinutes defaults to 2', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=unknown'),
      );

      final response = sponsorConfigHandler(request);
      final body = await response.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['flags']['inactivityTimeoutMinutes'], equals(2));
    });

    // REQ-p01044-C: assert prevents out-of-range values at construction time
    test('SponsorFeatureFlags rejects timeout below 1', () {
      expect(
        () => SponsorFeatureFlags(
          useReviewScreen: false,
          useAnimations: true,
          requireOldEntryJustification: false,
          enableShortDurationConfirmation: false,
          enableLongDurationConfirmation: false,
          longDurationThresholdMinutes: 60,
          availableFonts: ['Roboto'],
          inactivityTimeoutMinutes: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('SponsorFeatureFlags rejects timeout above 30', () {
      expect(
        () => SponsorFeatureFlags(
          useReviewScreen: false,
          useAnimations: true,
          requireOldEntryJustification: false,
          enableShortDurationConfirmation: false,
          enableLongDurationConfirmation: false,
          longDurationThresholdMinutes: 60,
          availableFonts: ['Roboto'],
          inactivityTimeoutMinutes: 31,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('availableFonts contains expected fonts', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);

      response.read().toList().then((chunks) {
        final body = utf8.decode(chunks.expand((c) => c).toList());
        final json = jsonDecode(body) as Map<String, dynamic>;
        final fonts = json['flags']['availableFonts'] as List;

        expect(fonts, contains('Roboto'));
        expect(fonts, contains('OpenDyslexic'));
        expect(fonts, contains('AtkinsonHyperlegible'));
      });
    });
  });
}
