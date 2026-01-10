// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Unit tests for sponsor configuration

import 'dart:convert';

import 'package:diary_functions/diary_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('sponsorConfigHandler', () {
    Future<Map<String, dynamic>> getResponseJson(Response response) async {
      final chunks = await response.read().toList();
      final body = utf8.decode(chunks.expand((c) => c).toList());
      return jsonDecode(body) as Map<String, dynamic>;
    }

    test('returns 405 for POST requests', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 405 for PUT requests', () {
      final request = Request(
        'PUT',
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
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('sponsorId'));
    });

    test('returns 400 when sponsorId is empty', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId='),
      );

      final response = sponsorConfigHandler(request);
      expect(response.statusCode, equals(400));
    });

    test('returns config for curehht sponsor', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('curehht'));
      expect(json['isDefault'], isFalse);
      expect(json['flags'], isNotNull);
    });

    test('returns config for callisto sponsor', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=callisto'),
      );

      final response = sponsorConfigHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('callisto'));
      expect(json['isDefault'], isFalse);

      // Callisto has specific settings
      final flags = json['flags'] as Map<String, dynamic>;
      expect(flags['requireOldEntryJustification'], isTrue);
      expect(flags['enableShortDurationConfirmation'], isTrue);
      expect(flags['enableLongDurationConfirmation'], isTrue);
    });

    test('normalizes sponsorId to lowercase', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=CUREHHT'),
      );

      final response = sponsorConfigHandler(request);
      final json = await getResponseJson(response);

      expect(json['sponsorId'], equals('curehht'));
      expect(json['isDefault'], isFalse);
    });

    test('trims whitespace from sponsorId', () async {
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/sponsor/config?sponsorId=%20curehht%20',
        ),
      );

      final response = sponsorConfigHandler(request);
      final json = await getResponseJson(response);

      expect(json['sponsorId'], equals('curehht'));
    });

    test('returns default config for unknown sponsor', () async {
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/sponsor/config?sponsorId=unknown_sponsor',
        ),
      );

      final response = sponsorConfigHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('unknown_sponsor'));
      expect(json['isDefault'], isTrue);
      expect(json['flags'], isNotNull);
    });

    test('flags include all required fields', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      final json = await getResponseJson(response);
      final flags = json['flags'] as Map<String, dynamic>;

      expect(flags.containsKey('useReviewScreen'), isTrue);
      expect(flags.containsKey('useAnimations'), isTrue);
      expect(flags.containsKey('requireOldEntryJustification'), isTrue);
      expect(flags.containsKey('enableShortDurationConfirmation'), isTrue);
      expect(flags.containsKey('enableLongDurationConfirmation'), isTrue);
      expect(flags.containsKey('longDurationThresholdMinutes'), isTrue);
      expect(flags.containsKey('availableFonts'), isTrue);
    });

    test('availableFonts is a list of strings', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      final json = await getResponseJson(response);
      final fonts = json['flags']['availableFonts'] as List;

      expect(fonts, isA<List>());
      expect(fonts.length, greaterThan(0));
      expect(fonts.every((f) => f is String), isTrue);
    });

    test('longDurationThresholdMinutes is a positive integer', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      final json = await getResponseJson(response);
      final threshold = json['flags']['longDurationThresholdMinutes'];

      expect(threshold, isA<int>());
      expect(threshold, greaterThan(0));
    });

    test('response has correct content-type header', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/config?sponsorId=curehht'),
      );

      final response = sponsorConfigHandler(request);
      expect(response.headers['content-type'], equals('application/json'));
    });
  });

  group('SponsorFeatureFlags', () {
    test('toJson produces valid JSON map', () {
      const flags = SponsorFeatureFlags(
        useReviewScreen: true,
        useAnimations: false,
        requireOldEntryJustification: true,
        enableShortDurationConfirmation: false,
        enableLongDurationConfirmation: true,
        longDurationThresholdMinutes: 30,
        availableFonts: ['Roboto', 'OpenDyslexic'],
      );

      final json = flags.toJson();

      expect(json['useReviewScreen'], isTrue);
      expect(json['useAnimations'], isFalse);
      expect(json['requireOldEntryJustification'], isTrue);
      expect(json['enableShortDurationConfirmation'], isFalse);
      expect(json['enableLongDurationConfirmation'], isTrue);
      expect(json['longDurationThresholdMinutes'], equals(30));
      expect(json['availableFonts'], equals(['Roboto', 'OpenDyslexic']));
    });
  });
}
