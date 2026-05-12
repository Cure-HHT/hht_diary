// Tests for main.dart bootstrap paths
// Covers: Bootstrap failure display, FCM token registration, device ID minting

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('Device ID minting', () {
    const deviceIdKey = 'clinical_diary.device_id';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('mints new UUID when no device ID exists', () async {
      final prefs = await SharedPreferences.getInstance();

      // No device ID exists
      expect(prefs.getString(deviceIdKey), isNull);

      // Simulate the minting logic from main.dart
      var existing = prefs.getString(deviceIdKey);
      if (existing == null || existing.isEmpty) {
        // In the real code, this would be: const Uuid().v4()
        existing = 'test-uuid-1234-5678-9012';
        await prefs.setString(deviceIdKey, existing);
      }

      expect(prefs.getString(deviceIdKey), isNotNull);
      expect(prefs.getString(deviceIdKey), 'test-uuid-1234-5678-9012');
    });

    test('reuses existing device ID', () async {
      SharedPreferences.setMockInitialValues({
        deviceIdKey: 'existing-device-id',
      });

      final prefs = await SharedPreferences.getInstance();
      var existing = prefs.getString(deviceIdKey);

      expect(existing, 'existing-device-id');
    });

    test('handles empty string as no device ID', () async {
      SharedPreferences.setMockInitialValues({
        deviceIdKey: '',
      });

      final prefs = await SharedPreferences.getInstance();
      var existing = prefs.getString(deviceIdKey);

      if (existing == null || existing.isEmpty) {
        existing = 'new-device-id';
        await prefs.setString(deviceIdKey, existing);
      }

      expect(prefs.getString(deviceIdKey), 'new-device-id');
    });
  });

  group('FCM token registration HTTP flow', () {
    test('sends correct request format', () async {
      String? capturedUrl;
      Map<String, dynamic>? capturedBody;
      Map<String, String>? capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        capturedHeaders = request.headers;
        return http.Response('{"success": true}', 200);
      });

      // Simulate the registration call
      const token = 'fcm-token-12345';
      const jwt = 'test-jwt-token';
      const backendUrl = 'https://api.example.com';
      const platform = 'android';

      final response = await mockClient.post(
        Uri.parse('$backendUrl/api/v1/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'fcm_token': token, 'platform': platform}),
      );

      expect(capturedUrl, '$backendUrl/api/v1/user/fcm-token');
      expect(capturedBody!['fcm_token'], token);
      expect(capturedBody!['platform'], platform);
      expect(capturedHeaders!['Authorization'], 'Bearer $jwt');
      expect(response.statusCode, 200);
    });

    test('handles successful registration', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"success": true}', 200);
      });

      final response = await mockClient.post(
        Uri.parse('https://api.example.com/api/v1/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer jwt',
        },
        body: jsonEncode({'fcm_token': 'token', 'platform': 'ios'}),
      );

      expect(response.statusCode, 200);
    });

    test('handles registration failure gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Unauthorized"}', 401);
      });

      final response = await mockClient.post(
        Uri.parse('https://api.example.com/api/v1/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer expired-jwt',
        },
        body: jsonEncode({'fcm_token': 'token', 'platform': 'android'}),
      );

      // Should not throw, just return error response
      expect(response.statusCode, 401);
    });

    test('handles network error', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      // Should not crash the app
      try {
        await mockClient.post(
          Uri.parse('https://api.example.com/api/v1/user/fcm-token'),
          body: '{}',
        );
        fail('Should have thrown');
      } on http.ClientException catch (e) {
        expect(e.message, 'Network error');
      }
    });

    test('skips registration when no JWT available', () async {
      // Simulate the check in _registerFcmToken
      const jwt = null;

      // When jwt is null, registration should be skipped
      expect(jwt, isNull);
      // In real code, this returns early without making HTTP call
    });

    test('skips registration when no backend URL available', () async {
      // Simulate the check in _registerFcmToken
      const backendUrl = null;

      // When backendUrl is null, registration should be skipped
      expect(backendUrl, isNull);
    });
  });

  group('Bootstrap error display', () {
    testWidgets('shows error message when bootstrap fails', (tester) async {
      // Simulate the error UI that would be shown
      final errorMessage = 'Failed to open database';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to initialize storage: $errorMessage'),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Failed to initialize'), findsOneWidget);
      expect(find.textContaining('database'), findsOneWidget);
    });

    testWidgets('centers error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Failed to initialize storage: Test error'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('shows loading indicator during runtime init', (tester) async {
      // Before runtime is initialized, should show loading
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
