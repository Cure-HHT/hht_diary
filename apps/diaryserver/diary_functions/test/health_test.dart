// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Unit tests for health check handler

import 'dart:convert';

import 'package:diary_functions/diary_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('healthHandler', () {
    Future<Map<String, dynamic>> getResponseJson(Response response) async {
      final chunks = await response.read().toList();
      final body = utf8.decode(chunks.expand((c) => c).toList());
      return jsonDecode(body) as Map<String, dynamic>;
    }

    test('returns 200 OK status', () {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = healthHandler(request);

      expect(response.statusCode, equals(200));
    });

    test('returns status ok in body', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = healthHandler(request);
      final json = await getResponseJson(response);

      expect(json['status'], equals('ok'));
    });

    test('returns service name', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = healthHandler(request);
      final json = await getResponseJson(response);

      expect(json['service'], equals('diary-server'));
    });

    test('returns region', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = healthHandler(request);
      final json = await getResponseJson(response);

      expect(json['region'], equals('europe-west1'));
    });

    test('returns valid timestamp', () async {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = healthHandler(request);
      final json = await getResponseJson(response);

      expect(json['timestamp'], isNotNull);

      // Should be a valid ISO 8601 timestamp
      final timestamp = DateTime.parse(json['timestamp'] as String);
      expect(timestamp.isUtc, isTrue);

      // Should be recent (within last minute)
      final now = DateTime.now().toUtc();
      final diff = now.difference(timestamp);
      expect(diff.inSeconds.abs(), lessThan(60));
    });

    test('response has correct content-type', () {
      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = healthHandler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });

    test('works with any HTTP method', () {
      // Health endpoints typically accept any method
      for (final method in ['GET', 'POST', 'HEAD']) {
        final request = Request(method, Uri.parse('http://localhost/health'));
        final response = healthHandler(request);
        expect(response.statusCode, equals(200));
      }
    });
  });
}
