// Tests for sponsor configuration handler
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/sponsor.dart';

void main() {
  group('FontOption', () {
    test('roboto has correct name', () {
      expect(FontOption.roboto.name, equals('Roboto'));
    });

    test('openDyslexic has correct name', () {
      expect(FontOption.openDyslexic.name, equals('OpenDyslexic'));
    });

    test('atkinsonHyperlegible has correct name', () {
      expect(
        FontOption.atkinsonHyperlegible.name,
        equals('AtkinsonHyperlegible'),
      );
    });
  });

  group('SponsorFeatureFlags', () {
    test('toJson includes all fields', () {
      const flags = SponsorFeatureFlags(
        useReviewScreen: true,
        useAnimations: false,
        requireOldEntryJustification: true,
        enableShortDurationConfirmation: true,
        enableLongDurationConfirmation: false,
        longDurationThresholdMinutes: 45,
        availableFonts: ['Roboto'],
      );

      final json = flags.toJson();

      expect(json['useReviewScreen'], isTrue);
      expect(json['useAnimations'], isFalse);
      expect(json['requireOldEntryJustification'], isTrue);
      expect(json['enableShortDurationConfirmation'], isTrue);
      expect(json['enableLongDurationConfirmation'], isFalse);
      expect(json['longDurationThresholdMinutes'], equals(45));
      expect(json['availableFonts'], equals(['Roboto']));
    });
  });

  group('sponsorConfigHandler', () {
    test('returns 405 for non-GET requests', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );
      final response = sponsorConfigHandler(request);

      expect(response.statusCode, equals(405));
    });

    test('returns 400 when sponsorId is missing', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config'),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(400));
      expect(body['error'], contains('sponsorId'));
    });

    test('returns 400 for empty sponsorId', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId='),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(400));
      expect(body['error'], contains('sponsorId'));
    });

    test('returns config for known sponsor (curehht)', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(200));
      expect(body['sponsorId'], equals('curehht'));
      expect(body['isDefault'], isFalse);
      expect(body['flags'], isA<Map>());
      expect(body['flags']['availableFonts'], isA<List>());
    });

    test('returns config for known sponsor (callisto)', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=callisto'),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(200));
      expect(body['sponsorId'], equals('callisto'));
      expect(body['isDefault'], isFalse);
      expect(body['flags']['requireOldEntryJustification'], isTrue);
      expect(body['flags']['enableShortDurationConfirmation'], isTrue);
    });

    test('returns default config for unknown sponsor', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=unknown'),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(200));
      expect(body['sponsorId'], equals('unknown'));
      expect(body['isDefault'], isTrue);
      expect(body['flags'], isA<Map>());
    });

    test('normalizes sponsorId to lowercase', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=CUREHHT'),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(200));
      expect(body['sponsorId'], equals('curehht'));
      expect(body['isDefault'], isFalse);
    });

    test('trims whitespace from sponsorId', () async {
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/sponsor/config?sponsorId=%20curehht%20',
        ),
      );
      final response = sponsorConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, equals(200));
      expect(body['sponsorId'], equals('curehht'));
    });

    test('returns JSON content type', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );
      final response = sponsorConfigHandler(request);

      expect(response.headers['Content-Type'], equals('application/json'));
    });
  });
}
