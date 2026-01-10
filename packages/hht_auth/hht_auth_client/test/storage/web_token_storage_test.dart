/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation

import 'package:test/test.dart';
import 'package:hht_auth_client/src/storage/web_token_storage.dart';

void main() {
  group('WebTokenStorage', () {
    late WebTokenStorage storage;

    setUp(() {
      storage = WebTokenStorage();
    });

    test('should return null when no token is stored', () async {
      final token = await storage.getToken();
      expect(token, isNull);
    });

    test('should return false when no token is stored', () async {
      final hasToken = await storage.hasToken();
      expect(hasToken, isFalse);
    });

    test('should save and retrieve a token', () async {
      const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
      
      await storage.saveToken(testToken);
      
      final retrievedToken = await storage.getToken();
      expect(retrievedToken, equals(testToken));
    });

    test('should return true after token is saved', () async {
      const testToken = 'test-token';
      
      await storage.saveToken(testToken);
      
      final hasToken = await storage.hasToken();
      expect(hasToken, isTrue);
    });

    test('should replace existing token when saving new token', () async {
      const firstToken = 'first-token';
      const secondToken = 'second-token';
      
      await storage.saveToken(firstToken);
      await storage.saveToken(secondToken);
      
      final retrievedToken = await storage.getToken();
      expect(retrievedToken, equals(secondToken));
    });

    test('should delete token successfully', () async {
      const testToken = 'test-token';
      
      await storage.saveToken(testToken);
      await storage.deleteToken();
      
      final retrievedToken = await storage.getToken();
      expect(retrievedToken, isNull);
    });

    test('should return false after token is deleted', () async {
      const testToken = 'test-token';
      
      await storage.saveToken(testToken);
      await storage.deleteToken();
      
      final hasToken = await storage.hasToken();
      expect(hasToken, isFalse);
    });

    test('should handle multiple delete calls gracefully', () async {
      await storage.deleteToken();
      await storage.deleteToken();
      
      final hasToken = await storage.hasToken();
      expect(hasToken, isFalse);
    });

    test('should store token in memory only (not persistent)', () async {
      const testToken = 'memory-only-token';
      
      await storage.saveToken(testToken);
      
      // Create new instance to verify no persistence
      final newStorage = WebTokenStorage();
      final retrievedToken = await newStorage.getToken();
      
      expect(retrievedToken, isNull);
    });
  });
}
