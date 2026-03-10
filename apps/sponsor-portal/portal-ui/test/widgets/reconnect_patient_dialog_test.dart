// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00021: Patient Reconnection Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00073: Patient Status Definitions
//
// Widget tests for ReconnectPatientDialog confirm/success/error/retry states.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/reconnect_patient_dialog.dart';

MockClient _createMockHttpClient({bool shouldFail = false}) {
  return MockClient((request) async {
    final path = request.url.path;

    // GET /api/v1/portal/me
    if (path == '/api/v1/portal/me' && request.method == 'GET') {
      return http.Response(
        jsonEncode({
          'id': 'user-001',
          'email': 'test@example.com',
          'name': 'Test User',
          'status': 'active',
          'roles': ['Investigator'],
          'active_role': 'Investigator',
          'mfa_type': 'email_otp',
          'email_otp_required': true,
          'sites': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /link-code (reconnect endpoint)
    if (path.contains('/link-code') && request.method == 'POST') {
      if (shouldFail) {
        return http.Response(
          jsonEncode({'error': 'Patient not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'patient_id': 'PAT-TEST-001',
          'site_name': 'Site Alpha',
          'code': 'CAXXX-XXXXX',
          'code_raw': 'CAXXXXXXXX',
          'expires_at': DateTime.now()
              .add(const Duration(hours: 72))
              .toIso8601String(),
          'expires_in_hours': 72,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response('Not found', 404);
  });
}

Future<ApiClient> _createMockApiClient({bool shouldFail = false}) async {
  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient(shouldFail: shouldFail);
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('test@example.com', 'password');
  return ApiClient(authService, httpClient: mockHttpClient);
}

Future<void> _pumpDialog(WidgetTester tester, ApiClient apiClient) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ReconnectPatientDialog(
                  patientId: 'PAT-TEST-001',
                  patientDisplayId: '999-002-320',
                  apiClient: apiClient,
                ),
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  group('ReconnectPatientDialog widget', () {
    testWidgets('confirm state shows patient ID and Reconnect button', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Reconnect Patient'), findsOneWidget);
      expect(find.textContaining('999-002-320'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsWidgets);
    });

    testWidgets('confirm state shows mandatory reason field', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Reason for reconnection *'), findsOneWidget);
      expect(find.text('Enter reason for reconnection...'), findsOneWidget);
      expect(
        find.textContaining('new linking code will be generated'),
        findsOneWidget,
      );
    });

    testWidgets('Reconnect button has no effect when reason empty', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Tap Reconnect without entering a reason — should remain in confirm
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();

      // Still in confirm state
      expect(find.text('Reconnect Patient'), findsOneWidget);
      expect(find.text('Reason for reconnection *'), findsOneWidget);
    });

    testWidgets(
      'entering reason enables Reconnect and tapping shows success with code',
      (tester) async {
        final apiClient = await _createMockApiClient();

        await _pumpDialog(tester, apiClient);

        // Enter reason
        await tester.enterText(
          find.byType(TextField),
          'Patient got new device',
        );
        await tester.pump();

        // Tap Reconnect
        await tester.tap(find.text('Reconnect'));
        await tester.pumpAndSettle();

        // Success state
        expect(find.text('Linking Code Generated'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.textContaining('Site Alpha'), findsOneWidget);
        expect(find.textContaining('999-002-320'), findsOneWidget);
        expect(find.textContaining('Patient got new device'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.textContaining('Expires in'), findsOneWidget);
      },
    );

    testWidgets('error state shows error message and Try Again', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      // Enter reason and submit
      await tester.enterText(find.byType(TextField), 'Test reason');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();

      // Error state
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Patient not found'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Try Again returns to confirm state', (tester) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      // Enter reason, submit, get error
      await tester.enterText(find.byType(TextField), 'Test reason');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Reconnect Patient'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Reconnect Patient'), findsNothing);
    });
  });
}
