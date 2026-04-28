// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00072: View Linking Code Button
//   REQ-CAL-p00073: Patient Status Definitions
//
// Widget tests for PatientActionsDialog rendering based on patient status.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/patient_actions_dialog.dart';

MockClient _createMockHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;

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

    return http.Response('Not found', 404);
  });
}

Future<ApiClient> _createMockApiClient() async {
  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient();
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('test@example.com', 'password');
  return ApiClient(authService, httpClient: mockHttpClient);
}

Future<void> _pumpDialog(
  WidgetTester tester,
  ApiClient apiClient,
  String mobileLinkingStatus,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<PatientActionResult>(
                context: context,
                builder: (_) => PatientActionsDialog(
                  patientId: 'PAT-TEST-001',
                  patientDisplayId: '999-002-320',
                  mobileLinkingStatus: mobileLinkingStatus,
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
  group('PatientActionsDialog', () {
    testWidgets('shows title and patient ID', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'disconnected');

      expect(find.text('Participant Actions'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsWidgets);
      expect(find.text('999-002-320'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    // CUR-1069: disconnected now shows "Show Participant Linking Code" (reference)
    testWidgets('disconnected status shows 3 action tiles', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'disconnected');

      expect(find.text('Show Participant Linking Code'), findsOneWidget);
      expect(find.text('Reconnect Participant'), findsOneWidget);
      expect(find.text('Mark as Not Participating'), findsOneWidget);

      expect(
        find.text('View the code used to link this device (reference only)'),
        findsOneWidget,
      );
      expect(
        find.text('Generate new linking code to reconnect'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.person_off), findsOneWidget);
    });

    testWidgets('linking_in_progress shows Show Linking Code only', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'linking_in_progress');

      expect(find.text('Show Linking Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code), findsOneWidget);
      expect(find.text('Reconnect Participant'), findsNothing);
      expect(find.text('Mark as Not Participating'), findsNothing);
    });

    // CUR-1069: not_participating now includes "Show Participant Linking Code"
    testWidgets(
      'not_participating shows info message and Show Participant Linking Code',
      (tester) async {
        final apiClient = await _createMockApiClient();

        await _pumpDialog(tester, apiClient, 'not_participating');

        expect(
          find.textContaining('marked as not participating'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.textContaining('Reactivate'), findsOneWidget);
        expect(find.text('Show Linking Code'), findsNothing);
        expect(find.text('Reconnect Participant'), findsNothing);
      },
    );

    // REQ-CAL-p00072: View Linking Code for any patient with a valid code
    // REQ-CAL-p00073 Assertion C: Show Linking Code for connected patients
    // CUR-1069: connected now shows "Show Participant Linking Code" (reference)
    testWidgets('connected status shows Show Participant Linking Code action', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'connected');

      expect(find.text('Show Participant Linking Code'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('Show Linking Code'), findsNothing);
    });

    testWidgets('connected status shows Disconnect Participant action', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'connected');

      expect(find.text('Disconnect Participant'), findsOneWidget);
    });

    testWidgets(
      'linking_in_progress shows "Show Linking Code" (not Participant)',
      (tester) async {
        final apiClient = await _createMockApiClient();

        await _pumpDialog(tester, apiClient, 'linking_in_progress');

        expect(find.text('Show Linking Code'), findsOneWidget);
        expect(find.text('Show Participant Linking Code'), findsNothing);
        expect(find.byIcon(Icons.qr_code), findsOneWidget);
      },
    );

    testWidgets('unknown status shows no actions message', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'some_unknown_status');

      expect(
        find.text('No actions available for this participant status.'),
        findsOneWidget,
      );
    });

    testWidgets('Close button dismisses dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient, 'disconnected');

      expect(find.text('Participant Actions'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Participant Actions'), findsNothing);
    });
  });
}
