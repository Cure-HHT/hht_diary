// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00077: Disconnection Notification
//
// Widget tests for DisconnectPatientDialog confirm/success/error/retry states.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/disconnect_patient_dialog.dart';

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

    // POST /disconnect
    if (path.contains('/disconnect') && request.method == 'POST') {
      if (shouldFail) {
        return http.Response(
          jsonEncode({'error': 'Patient not in connected state'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'status': 'disconnected',
          'codes_revoked': 2,
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
  // Use a large surface to avoid dialog overflow in tests
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
                builder: (_) => DisconnectPatientDialog(
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
  group('DisconnectReason enum', () {
    test('has correct labels', () {
      expect(DisconnectReason.deviceIssues.label, 'Device Issues');
      expect(DisconnectReason.technicalIssues.label, 'Technical Issues');
      expect(DisconnectReason.other.label, 'Other');
    });

    test('has correct descriptions', () {
      expect(
        DisconnectReason.deviceIssues.description,
        'Lost, stolen, or damaged device',
      );
      expect(
        DisconnectReason.technicalIssues.description,
        'App not working, sync problems',
      );
      expect(
        DisconnectReason.other.description,
        'No additional details required',
      );
    });

    test('has exactly 3 values matching spec', () {
      expect(DisconnectReason.values.length, 3);
      expect(
        DisconnectReason.values.map((r) => r.label).toList(),
        containsAll(['Device Issues', 'Technical Issues', 'Other']),
      );
    });

    test('reason labels match backend validDisconnectReasons', () {
      expect(DisconnectReason.deviceIssues.label, 'Device Issues');
      expect(DisconnectReason.technicalIssues.label, 'Technical Issues');
      expect(DisconnectReason.other.label, 'Other');
    });
  });

  group('DisconnectPatientDialog widget', () {
    testWidgets('confirm state shows patient ID and Disconnect button', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Disconnect Participant'), findsOneWidget);
      expect(find.textContaining('999-002-320'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsWidgets);
    });

    testWidgets(
      'confirm state shows reason dropdown only (no free text field)',
      (tester) async {
        final apiClient = await _createMockApiClient();

        await _pumpDialog(tester, apiClient);

        expect(find.text('Reason for disconnection *'), findsOneWidget);
        expect(find.text('Select a reason'), findsOneWidget);
        expect(find.textContaining('Additional notes'), findsNothing);
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets('confirm state shows warning message', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(
        find.textContaining('revoke all active linking codes'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('Disconnect button has no effect without reason selected', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Tap Disconnect without selecting a reason — should remain in confirm
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      // Still in confirm state
      expect(find.text('Disconnect Participant'), findsOneWidget);
      expect(find.text('Select a reason'), findsOneWidget);
    });

    testWidgets('selecting reason and tapping Disconnect shows success', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Open dropdown and select 'Device Issues'
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device Issues').last);
      await tester.pumpAndSettle();

      // Tap Disconnect
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      // Success state
      expect(find.text('Participant Disconnected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('has been disconnected'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('Linking codes revoked'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Device Issues'), findsOneWidget);
      expect(
        find.textContaining('generate a new linking code'),
        findsOneWidget,
      );
    });

    testWidgets('error state shows error message and Try Again', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      // Select reason
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device Issues').last);
      await tester.pumpAndSettle();

      // Tap Disconnect
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      // Error state
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Patient not in connected state'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Try Again returns to confirm state', (tester) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      // Select reason and submit
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device Issues').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Participant'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Participant'), findsNothing);
    });
  });
}
