/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///   REQ-d00080: Web Session Management Implementation

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:hht_auth_client/src/http/auth_http_client.dart';
import 'package:hht_auth_core/hht_auth_core.dart';

// Mock token storage for testing
class MockTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async {
    return _token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<bool> hasToken() async {
    return _token != null;
  }
}

void main() {
  group('AuthHttpClient', () {
    late MockTokenStorage tokenStorage;
    late AuthHttpClient client;
    const baseUrl = 'https://auth.example.com';

    setUp(() {
      tokenStorage = MockTokenStorage();
      client = AuthHttpClient(
        baseUrl: baseUrl,
        tokenStorage: tokenStorage,
      );
    });

    group('constructor', () {
      test('should create client with base URL', () {
        expect(client.baseUrl, equals(baseUrl));
      });

      test('should create client with custom http client', () {
        final customClient = http.Client();
        final authClient = AuthHttpClient(
          baseUrl: baseUrl,
          tokenStorage: tokenStorage,
          httpClient: customClient,
        );
        expect(authClient, isNotNull);
      });
    });

    group('buildUri', () {
      test('should build URI from path', () {
        final uri = client.buildUri('/auth/login');
        expect(uri.toString(), equals('$baseUrl/auth/login'));
      });

      test('should build URI with query parameters', () {
        final uri = client.buildUri('/auth/validate', queryParams: {
          'code': 'ABC123',
          'sponsor': 'test',
        });
        expect(uri.toString(), contains('code=ABC123'));
        expect(uri.toString(), contains('sponsor=test'));
      });

      test('should handle path without leading slash', () {
        final uri = client.buildUri('auth/login');
        expect(uri.toString(), equals('$baseUrl/auth/login'));
      });
    });

    group('buildHeaders', () {
      test('should return default headers when no token', () async {
        final headers = await client.buildHeaders();
        
        expect(headers['Content-Type'], equals('application/json'));
        expect(headers.containsKey('Authorization'), isFalse);
      });

      test('should include Authorization header when token exists', () async {
        const testToken = 'test-jwt-token';
        await tokenStorage.saveToken(testToken);

        final headers = await client.buildHeaders();
        
        expect(headers['Authorization'], equals('Bearer $testToken'));
        expect(headers['Content-Type'], equals('application/json'));
      });

      test('should merge custom headers', () async {
        final headers = await client.buildHeaders(
          additionalHeaders: {
            'X-Custom-Header': 'custom-value',
            'X-Request-ID': '12345',
          },
        );
        
        expect(headers['X-Custom-Header'], equals('custom-value'));
        expect(headers['X-Request-ID'], equals('12345'));
        expect(headers['Content-Type'], equals('application/json'));
      });

      test('should allow overriding Content-Type', () async {
        final headers = await client.buildHeaders(
          additionalHeaders: {
            'Content-Type': 'text/plain',
          },
        );
        
        expect(headers['Content-Type'], equals('text/plain'));
      });
    });

    group('request lifecycle', () {
      test('should inject token into requests automatically', () async {
        const testToken = 'auto-injected-token';
        await tokenStorage.saveToken(testToken);

        final headers = await client.buildHeaders();
        
        expect(headers['Authorization'], equals('Bearer $testToken'));
      });

      test('should handle token refresh scenario', () async {
        // Initial token
        const initialToken = 'initial-token';
        await tokenStorage.saveToken(initialToken);

        var headers = await client.buildHeaders();
        expect(headers['Authorization'], equals('Bearer $initialToken'));

        // Simulate token refresh
        const refreshedToken = 'refreshed-token';
        await tokenStorage.saveToken(refreshedToken);

        headers = await client.buildHeaders();
        expect(headers['Authorization'], equals('Bearer $refreshedToken'));
      });

      test('should handle token deletion', () async {
        const testToken = 'will-be-deleted';
        await tokenStorage.saveToken(testToken);

        var headers = await client.buildHeaders();
        expect(headers.containsKey('Authorization'), isTrue);

        await tokenStorage.deleteToken();

        headers = await client.buildHeaders();
        expect(headers.containsKey('Authorization'), isFalse);
      });
    });

    group('close', () {
      test('should close underlying http client', () {
        expect(() => client.close(), returnsNormally);
      });
    });
  });
}
