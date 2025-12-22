/// Tests for SponsorConfigLoader
///
/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00084: Sponsor Configuration Loading

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:hht_auth_client/src/services/sponsor_config_loader.dart';
import 'package:hht_auth_core/hht_auth_core.dart';

void main() {
  group('SponsorConfigLoader', () {
    late MockClient mockClient;
    late SponsorConfigLoader loader;
    late AuthToken testToken;

    setUp(() {
      testToken = AuthToken(
        sub: 'user-123',
        username: 'testuser',
        sponsorId: 'sponsor-abc',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: 'app-uuid-123',
        iat: DateTime.now(),
        exp: DateTime.now().add(const Duration(minutes: 15)),
      );
    });

    group('loadConfig', () {
      test('fetches config from sponsor portal', () async {
        final configJson = {
          'sponsorId': 'sponsor-abc',
          'sponsorName': 'Test Sponsor',
          'sessionTimeoutMinutes': 5,
          'branding': {
            'logoUrl': 'https://sponsor.example.com/logo.png',
            'primaryColor': '#FF0000',
            'secondaryColor': '#00FF00',
            'welcomeMessage': 'Welcome!',
          },
        };

        mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://sponsor.example.com/api/diary/config',
          );
          return http.Response(jsonEncode(configJson), 200);
        });

        loader = SponsorConfigLoader(mockClient);

        final config = await loader.loadConfig(testToken);

        expect(config.sponsorId, 'sponsor-abc');
        expect(config.sponsorName, 'Test Sponsor');
        expect(config.sessionTimeoutMinutes, 5);
        expect(config.branding.logoUrl, 'https://sponsor.example.com/logo.png');
        expect(config.branding.primaryColor, '#FF0000');
        expect(config.branding.welcomeMessage, 'Welcome!');
      });

      test('caches config for subsequent calls', () async {
        var requestCount = 0;
        final configJson = {
          'sponsorId': 'sponsor-abc',
          'sponsorName': 'Test Sponsor',
          'sessionTimeoutMinutes': 5,
          'branding': {
            'logoUrl': 'https://sponsor.example.com/logo.png',
            'primaryColor': '#FF0000',
            'secondaryColor': '#00FF00',
          },
        };

        mockClient = MockClient((request) async {
          requestCount++;
          return http.Response(jsonEncode(configJson), 200);
        });

        loader = SponsorConfigLoader(mockClient);

        // First call - should make request
        await loader.loadConfig(testToken);
        expect(requestCount, 1);

        // Second call - should use cache
        await loader.loadConfig(testToken);
        expect(requestCount, 1);
      });

      test('returns defaults on HTTP error', () async {
        mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        loader = SponsorConfigLoader(mockClient);

        final config = await loader.loadConfig(testToken);

        expect(config.sponsorId, 'sponsor-abc');
        expect(config.sponsorName, 'Clinical Diary'); // default name
        expect(config.sessionTimeoutMinutes, 2); // default timeout
        expect(config.branding.primaryColor, '#1976D2'); // default color
      });

      test('returns defaults on network error', () async {
        mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        loader = SponsorConfigLoader(mockClient);

        final config = await loader.loadConfig(testToken);

        expect(config.sponsorId, 'sponsor-abc');
        expect(config.sponsorName, 'Clinical Diary');
      });

      test('returns defaults on parse error', () async {
        mockClient = MockClient((request) async {
          return http.Response('invalid json', 200);
        });

        loader = SponsorConfigLoader(mockClient);

        final config = await loader.loadConfig(testToken);

        expect(config.sponsorId, 'sponsor-abc');
        expect(config.sponsorName, 'Clinical Diary');
      });
    });

    group('loadConfigFromUrl', () {
      test('fetches config from provided URL', () async {
        final configJson = {
          'sponsorId': 'sponsor-xyz',
          'sponsorName': 'URL Sponsor',
          'sessionTimeoutMinutes': 10,
          'branding': {
            'logoUrl': 'https://other.example.com/logo.png',
            'primaryColor': '#0000FF',
            'secondaryColor': '#FF00FF',
          },
        };

        mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://other.example.com/api/diary/config',
          );
          return http.Response(jsonEncode(configJson), 200);
        });

        loader = SponsorConfigLoader(mockClient);

        final config = await loader.loadConfigFromUrl(
          sponsorId: 'sponsor-xyz',
          sponsorUrl: 'https://other.example.com',
        );

        expect(config.sponsorId, 'sponsor-xyz');
        expect(config.sponsorName, 'URL Sponsor');
        expect(config.sessionTimeoutMinutes, 10);
      });

      test('returns defaults on error', () async {
        mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        loader = SponsorConfigLoader(mockClient);

        final config = await loader.loadConfigFromUrl(
          sponsorId: 'sponsor-xyz',
          sponsorUrl: 'https://other.example.com',
        );

        expect(config.sponsorId, 'sponsor-xyz');
        expect(config.sponsorName, 'Clinical Diary');
      });
    });

    group('clearCache', () {
      test('clears cached config', () async {
        var requestCount = 0;
        final configJson = {
          'sponsorId': 'sponsor-abc',
          'sponsorName': 'Test Sponsor',
          'sessionTimeoutMinutes': 5,
          'branding': {
            'logoUrl': '',
            'primaryColor': '#FF0000',
            'secondaryColor': '#00FF00',
          },
        };

        mockClient = MockClient((request) async {
          requestCount++;
          return http.Response(jsonEncode(configJson), 200);
        });

        loader = SponsorConfigLoader(mockClient);

        await loader.loadConfig(testToken);
        expect(requestCount, 1);

        loader.clearCache();

        await loader.loadConfig(testToken);
        expect(requestCount, 2); // New request after cache clear
      });
    });

    group('isCached', () {
      test('returns false when not cached', () {
        mockClient = MockClient((request) async {
          return http.Response('', 200);
        });
        loader = SponsorConfigLoader(mockClient);

        expect(loader.isCached('sponsor-abc'), false);
      });

      test('returns true when cached', () async {
        final configJson = {
          'sponsorId': 'sponsor-abc',
          'sponsorName': 'Test',
          'sessionTimeoutMinutes': 2,
          'branding': {
            'logoUrl': '',
            'primaryColor': '#000000',
            'secondaryColor': '#FFFFFF',
          },
        };

        mockClient = MockClient((request) async {
          return http.Response(jsonEncode(configJson), 200);
        });

        loader = SponsorConfigLoader(mockClient);
        await loader.loadConfig(testToken);

        expect(loader.isCached('sponsor-abc'), true);
      });
    });
  });
}
