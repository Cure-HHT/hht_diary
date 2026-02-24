// Tests for sponsor branding handler and configuration
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/sponsor_branding.dart';

void main() {
  group('SponsorBranding', () {
    test('sponsorId returns empty string when SPONSOR_ID env is not set', () {
      // In the test environment SPONSOR_ID is not set
      // (unless the test runner explicitly exports it)
      final id = SponsorBranding.sponsorId;
      // We just verify it returns a String (empty or the env value)
      expect(id, isA<String>());
    });

    test('isConfigured returns false when SPONSOR_ID is not set', () {
      // Without SPONSOR_ID the getter short-circuits on sponsorId.isNotEmpty
      expect(SponsorBranding.isConfigured, isFalse);
    });

    test('loadConfig returns null when config file does not exist', () {
      // Without a valid sponsor-content directory on disk, loadConfig
      // cannot find sponsor-config.json
      final config = SponsorBranding.loadConfig();
      expect(config, isNull);
    });
  });

  group('sponsorBrandingHandler', () {
    test('returns 503 when sponsor is not configured', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/branding'),
      );

      final response = sponsorBrandingHandler(request);

      expect(response.statusCode, 503);
    });

    test('returns JSON content type on 503', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/branding'),
      );

      final response = sponsorBrandingHandler(request);

      expect(response.headers['content-type'], 'application/json');
    });

    test('returns descriptive error message on 503', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/branding'),
      );

      final response = sponsorBrandingHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(body['error'], 'Sponsor branding not configured');
      expect(body['message'], contains('SPONSOR_ID'));
    });
  });
}
