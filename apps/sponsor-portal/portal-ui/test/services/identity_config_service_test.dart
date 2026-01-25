// Tests for IdentityConfigService and IdentityPlatformConfig
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-o00056: Container infrastructure for Cloud Run

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/identity_config_service.dart';

void main() {
  group('IdentityPlatformConfig', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'apiKey': 'test-api-key',
        'appId': '1:123456789:web:abcdef',
        'projectId': 'test-project',
        'authDomain': 'test-project.firebaseapp.com',
        'messagingSenderId': '123456789',
      };

      final config = IdentityPlatformConfig.fromJson(json);

      expect(config.apiKey, 'test-api-key');
      expect(config.appId, '1:123456789:web:abcdef');
      expect(config.projectId, 'test-project');
      expect(config.authDomain, 'test-project.firebaseapp.com');
      expect(config.messagingSenderId, '123456789');
    });

    test('fromJson handles missing fields with empty strings', () {
      final json = <String, dynamic>{};

      final config = IdentityPlatformConfig.fromJson(json);

      expect(config.apiKey, isEmpty);
      expect(config.appId, isEmpty);
      expect(config.projectId, isEmpty);
      expect(config.authDomain, isEmpty);
      expect(config.messagingSenderId, isEmpty);
    });

    test('fromJson handles null values with empty strings', () {
      final json = {
        'apiKey': null,
        'appId': null,
        'projectId': null,
        'authDomain': null,
        'messagingSenderId': null,
      };

      final config = IdentityPlatformConfig.fromJson(json);

      expect(config.apiKey, isEmpty);
      expect(config.appId, isEmpty);
      expect(config.projectId, isEmpty);
      expect(config.authDomain, isEmpty);
      expect(config.messagingSenderId, isEmpty);
    });

    test('isValid returns true when all required fields are present', () {
      const config = IdentityPlatformConfig(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:abcdef',
        projectId: 'test-project',
        authDomain: 'test-project.firebaseapp.com',
      );

      expect(config.isValid, isTrue);
    });

    test('isValid returns true even without messagingSenderId', () {
      const config = IdentityPlatformConfig(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:abcdef',
        projectId: 'test-project',
        authDomain: 'test-project.firebaseapp.com',
        messagingSenderId: '',
      );

      expect(config.isValid, isTrue);
    });

    test('isValid returns false when apiKey is empty', () {
      const config = IdentityPlatformConfig(
        apiKey: '',
        appId: '1:123456789:web:abcdef',
        projectId: 'test-project',
        authDomain: 'test-project.firebaseapp.com',
      );

      expect(config.isValid, isFalse);
    });

    test('isValid returns false when appId is empty', () {
      const config = IdentityPlatformConfig(
        apiKey: 'test-api-key',
        appId: '',
        projectId: 'test-project',
        authDomain: 'test-project.firebaseapp.com',
      );

      expect(config.isValid, isFalse);
    });

    test('isValid returns false when projectId is empty', () {
      const config = IdentityPlatformConfig(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:abcdef',
        projectId: '',
        authDomain: 'test-project.firebaseapp.com',
      );

      expect(config.isValid, isFalse);
    });

    test('isValid returns false when authDomain is empty', () {
      const config = IdentityPlatformConfig(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:abcdef',
        projectId: 'test-project',
        authDomain: '',
      );

      expect(config.isValid, isFalse);
    });

    test('emulator config is valid', () {
      expect(IdentityPlatformConfig.emulator.isValid, isTrue);
    });

    test('emulator config has expected placeholder values', () {
      expect(IdentityPlatformConfig.emulator.apiKey, 'demo-api-key');
      expect(IdentityPlatformConfig.emulator.projectId, 'demo-sponsor-portal');
    });

    test('toString includes projectId and authDomain', () {
      const config = IdentityPlatformConfig(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:abcdef',
        projectId: 'test-project',
        authDomain: 'test-project.firebaseapp.com',
      );

      final str = config.toString();

      expect(str, contains('test-project'));
      expect(str, contains('test-project.firebaseapp.com'));
    });
  });

  group('IdentityConfigException', () {
    test('toString includes message', () {
      final exception = IdentityConfigException('Test error');
      expect(exception.toString(), contains('Test error'));
    });

    test('toString includes status code when provided', () {
      final exception = IdentityConfigException('Test error', statusCode: 503);
      expect(exception.toString(), contains('503'));
    });

    test('stores cause when provided', () {
      final cause = Exception('Original error');
      final exception = IdentityConfigException('Wrapped error', cause: cause);
      expect(exception.cause, cause);
    });
  });

  group('IdentityConfigService', () {
    test('fetchConfig returns config on successful response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'apiKey': 'test-api-key',
            'appId': '1:123456789:web:abcdef',
            'projectId': 'test-project',
            'authDomain': 'test-project.firebaseapp.com',
            'messagingSenderId': '123456789',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = IdentityConfigService(httpClient: mockClient);
      final config = await service.fetchConfig();

      expect(config.apiKey, 'test-api-key');
      expect(config.projectId, 'test-project');
      expect(config.isValid, isTrue);
    });

    test('fetchConfig throws IdentityConfigException on 503', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'Identity Platform not configured',
            'message': 'Server is missing required configuration.',
          }),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = IdentityConfigService(httpClient: mockClient);

      expect(
        () => service.fetchConfig(),
        throwsA(
          isA<IdentityConfigException>().having(
            (e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('fetchConfig throws IdentityConfigException on 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = IdentityConfigService(httpClient: mockClient);

      expect(
        () => service.fetchConfig(),
        throwsA(
          isA<IdentityConfigException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('fetchConfig throws IdentityConfigException on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = IdentityConfigService(httpClient: mockClient);

      expect(
        () => service.fetchConfig(),
        throwsA(
          isA<IdentityConfigException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('fetchConfig throws on invalid JSON response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final service = IdentityConfigService(httpClient: mockClient);

      expect(
        () => service.fetchConfig(),
        throwsA(isA<IdentityConfigException>()),
      );
    });

    test('fetchConfig throws on invalid config in response', () async {
      final mockClient = MockClient((request) async {
        // Return empty/invalid config
        return http.Response(
          jsonEncode({
            'apiKey': '',
            'appId': '',
            'projectId': '',
            'authDomain': '',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = IdentityConfigService(httpClient: mockClient);

      expect(
        () => service.fetchConfig(),
        throwsA(isA<IdentityConfigException>()),
      );
    });

    test('fetchConfig calls correct endpoint', () async {
      String? capturedPath;

      final mockClient = MockClient((request) async {
        capturedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'apiKey': 'test-api-key',
            'appId': '1:123456789:web:abcdef',
            'projectId': 'test-project',
            'authDomain': 'test-project.firebaseapp.com',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = IdentityConfigService(httpClient: mockClient);
      await service.fetchConfig();

      expect(capturedPath, '/api/v1/portal/config/identity');
    });
  });
}
