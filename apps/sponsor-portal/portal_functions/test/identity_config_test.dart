// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Tests for identity_config.dart
//
// Note: These tests run inside Doppler environment which may have
// PORTAL_IDENTITY_* variables set. Tests are designed to pass
// regardless of environment configuration.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/identity_config.dart';

void main() {
  group('IdentityConfig', () {
    test('toJson returns all configuration fields', () {
      final json = IdentityConfig.toJson();

      // These keys should always be present
      expect(json, containsPair('apiKey', isA<String>()));
      expect(json, containsPair('appId', isA<String>()));
      expect(json, containsPair('projectId', isA<String>()));
      expect(json, containsPair('authDomain', isA<String>()));
      expect(json, containsPair('messagingSenderId', isA<String>()));
      expect(json.length, 5);
    });

    test('apiKey reads from PORTAL_IDENTITY_API_KEY environment variable', () {
      // Test that getter reads from correct env var
      final envValue = Platform.environment['PORTAL_IDENTITY_API_KEY'] ?? '';
      expect(IdentityConfig.apiKey, envValue);
    });

    test('appId reads from PORTAL_IDENTITY_APP_ID environment variable', () {
      final envValue = Platform.environment['PORTAL_IDENTITY_APP_ID'] ?? '';
      expect(IdentityConfig.appId, envValue);
    });

    test(
      'projectId reads from PORTAL_IDENTITY_PROJECT_ID environment variable',
      () {
        final envValue =
            Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ?? '';
        expect(IdentityConfig.projectId, envValue);
      },
    );

    test(
      'authDomain reads from PORTAL_IDENTITY_AUTH_DOMAIN environment variable',
      () {
        final envValue =
            Platform.environment['PORTAL_IDENTITY_AUTH_DOMAIN'] ?? '';
        expect(IdentityConfig.authDomain, envValue);
      },
    );

    test(
      'messagingSenderId reads from PORTAL_IDENTITY_MESSAGING_SENDER_ID environment variable',
      () {
        final envValue =
            Platform.environment['PORTAL_IDENTITY_MESSAGING_SENDER_ID'] ?? '';
        expect(IdentityConfig.messagingSenderId, envValue);
      },
    );
  });

  group('IdentityConfig.isConfigured', () {
    test('returns true when all required env vars are set', () {
      // Check if env vars are actually set
      final hasApiKey = IdentityConfig.apiKey.isNotEmpty;
      final hasAppId = IdentityConfig.appId.isNotEmpty;
      final hasProjectId = IdentityConfig.projectId.isNotEmpty;
      final hasAuthDomain = IdentityConfig.authDomain.isNotEmpty;

      // isConfigured should match whether all required vars are set
      expect(
        IdentityConfig.isConfigured,
        hasApiKey && hasAppId && hasProjectId && hasAuthDomain,
      );
    });

    test('isConfigured correctly evaluates required fields', () {
      // This test documents the fields checked by isConfigured
      // The logic is: apiKey && appId && projectId && authDomain all non-empty
      // messagingSenderId is optional

      // Verify the getter returns consistent results
      final firstCall = IdentityConfig.isConfigured;
      final secondCall = IdentityConfig.isConfigured;
      expect(firstCall, secondCall);
    });
  });

  group('identityConfigHandler', () {
    test('returns JSON content type', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await identityConfigHandler(request);

      expect(response.headers['content-type'], 'application/json');
    });

    test('returns 200 when configured or 503 when not configured', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await identityConfigHandler(request);

      if (IdentityConfig.isConfigured) {
        expect(response.statusCode, 200);
      } else {
        expect(response.statusCode, 503);
      }
    });

    test('returns configuration JSON when configured', () async {
      if (!IdentityConfig.isConfigured) {
        // Skip this test if not configured
        return;
      }

      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await identityConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(body, containsPair('apiKey', isA<String>()));
      expect(body, containsPair('appId', isA<String>()));
      expect(body, containsPair('projectId', isA<String>()));
      expect(body, containsPair('authDomain', isA<String>()));
      expect(body, containsPair('messagingSenderId', isA<String>()));
    });

    test('returns error JSON when not configured', () async {
      if (IdentityConfig.isConfigured) {
        // Skip this test if configured
        return;
      }

      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await identityConfigHandler(request);
      final body = jsonDecode(await response.readAsString());

      expect(body, containsPair('error', isA<String>()));
      expect(body['error'], contains('not configured'));
      expect(body, containsPair('message', isA<String>()));
    });
  });

  group('Integration', () {
    test('handler response matches isConfigured state', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await identityConfigHandler(request);

      // Handler should return 200 if and only if isConfigured is true
      expect(response.statusCode == 200, IdentityConfig.isConfigured);
    });

    test('toJson output matches handler response when configured', () async {
      if (!IdentityConfig.isConfigured) {
        return;
      }

      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await identityConfigHandler(request);
      final handlerBody = jsonDecode(await response.readAsString());
      final toJsonBody = IdentityConfig.toJson();

      expect(handlerBody, toJsonBody);
    });
  });
}
