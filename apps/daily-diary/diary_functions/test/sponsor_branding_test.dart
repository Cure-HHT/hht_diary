// Tests for sponsor branding handler and configuration
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d000012: Sponsor Configuration Detection Implementation

import 'dart:convert';

import 'package:diary_functions/diary_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('SponsorBranding', () {
    test('loadConfig returns null when config file does not exist', () {
      // Without a valid sponsor-content directory on disk, loadConfig
      // cannot find sponsor-config.json
      final config = SponsorBranding.loadConfig('dummy-sponsor');
      expect(config, isNull);
    });
  });

  group('sponsorBrandingHandler', () {
    test('returns 503 when sponsor is not configured', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/branding/dummy-sponsor'),
      );

      final response = sponsorBrandingHandler(request, 'dummy-sponsor');

      expect(response.statusCode, 503);
    });

    test('returns JSON content type on 503', () {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/branding/dummy-sponsor'),
      );

      final response = sponsorBrandingHandler(request, 'dummy-sponsor');

      expect(response.headers['content-type'], 'application/json');
    });

    test('returns descriptive error message on 503', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/sponsor/branding/dummy-sponsor'),
      );

      final response = sponsorBrandingHandler(request, 'dummy-sponsor');
      final body = jsonDecode(await response.readAsString());

      expect(body['error'], 'Sponsor branding not configured');
      expect(body['message'], contains('SPONSOR_ID'));
    });
  });
}
