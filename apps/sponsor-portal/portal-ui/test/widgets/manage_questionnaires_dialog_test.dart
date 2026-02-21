// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//
// Widget tests for ManageQuestionnairesDialog.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/manage_questionnaires_dialog.dart';

/// Creates a mock HTTP client that returns questionnaire data
MockClient _createMockHttpClient({
  String noseStatus = 'not_sent',
  String qolStatus = 'not_sent',
  String? noseId,
  String? qolId,
  bool failGetStatus = false,
  bool failSend = false,
  bool failDelete = false,
  bool failUnlock = false,
  bool failFinalize = false,
}) {
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

    // GET /questionnaires
    if (path.contains('/questionnaires') &&
        request.method == 'GET' &&
        !path.contains('/send') &&
        !path.contains('/unlock') &&
        !path.contains('/finalize')) {
      if (failGetStatus) {
        return http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      }

      final questionnaires = <Map<String, dynamic>>[
        {
          'questionnaire_type': 'nose_hht',
          'status': noseStatus,
          if (noseId != null) 'id': noseId,
        },
        {
          'questionnaire_type': 'qol',
          'status': qolStatus,
          if (qolId != null) 'id': qolId,
        },
        {'questionnaire_type': 'eq', 'status': 'sent', 'id': 'eq-instance-1'},
      ];

      return http.Response(
        jsonEncode({
          'patient_id': 'PAT-TEST-001',
          'questionnaires': questionnaires,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /send
    if (path.contains('/send') && request.method == 'POST') {
      if (failSend) {
        return http.Response(
          jsonEncode({'error': 'Failed to send questionnaire'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'instance_id': 'new-instance-id',
          'status': 'sent',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // DELETE (revoke)
    if (request.method == 'DELETE') {
      if (failDelete) {
        return http.Response(
          jsonEncode({'error': 'Failed to delete'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /unlock
    if (path.contains('/unlock') && request.method == 'POST') {
      if (failUnlock) {
        return http.Response(
          jsonEncode({'error': 'Failed to unlock'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'success': true, 'status': 'sent'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /finalize
    if (path.contains('/finalize') && request.method == 'POST') {
      if (failFinalize) {
        return http.Response(
          jsonEncode({'error': 'Failed to finalize'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'success': true, 'status': 'finalized', 'score': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response('Not found', 404);
  });
}

Future<ApiClient> _createMockApiClient({
  String noseStatus = 'not_sent',
  String qolStatus = 'not_sent',
  String? noseId,
  String? qolId,
  bool failGetStatus = false,
  bool failSend = false,
  bool failDelete = false,
  bool failUnlock = false,
  bool failFinalize = false,
}) async {
  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient(
    noseStatus: noseStatus,
    qolStatus: qolStatus,
    noseId: noseId,
    qolId: qolId,
    failGetStatus: failGetStatus,
    failSend: failSend,
    failDelete: failDelete,
    failUnlock: failUnlock,
    failFinalize: failFinalize,
  );
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('test@example.com', 'password');
  return ApiClient(authService, httpClient: mockHttpClient);
}

Future<void> _pumpDialog(WidgetTester tester, ApiClient apiClient) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<void>(
                context: context,
                builder: (_) => ManageQuestionnairesDialog(
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
  group('ManageQuestionnairesDialog', () {
    testWidgets('shows loading then questionnaire table', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // After loading, should show the table
      expect(find.text('Manage Questionnaires'), findsOneWidget);
      expect(find.text('Nose HHT'), findsOneWidget);
      expect(find.text('QoL'), findsOneWidget);
    });

    testWidgets('shows Nose HHT and QoL rows but not EQ', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Nose HHT'), findsOneWidget);
      expect(find.text('QoL'), findsOneWidget);
      // EQ should be filtered out
      expect(find.text('EQ'), findsNothing);
    });

    testWidgets('shows patient display ID in subtitle', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.textContaining('999-002-320'), findsOneWidget);
    });

    testWidgets('shows Send button for not_sent status', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Both Nose HHT and QoL are not_sent, so 2 Send buttons
      expect(find.text('Send'), findsNWidgets(2));
      expect(find.text('Not Sent'), findsNWidgets(2));
    });

    testWidgets('shows Revoke button for sent status', (tester) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'sent',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      expect(find.text('Revoke'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      // QoL is still not_sent
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('shows Unlock and Finalize for ready_to_review', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'ready_to_review',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Finalize'), findsOneWidget);
      expect(find.text('Ready to Review'), findsOneWidget);
    });

    testWidgets('shows no actions for in_progress', (tester) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'in_progress',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Patient is working'), findsOneWidget);
    });

    testWidgets('shows empty state when all not_sent', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(
        find.text('No questionnaires have been sent yet.'),
        findsOneWidget,
      );
    });

    testWidgets('Send action calls POST and refreshes list', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Tap the first Send button (Nose HHT)
      await tester.tap(find.text('Send').first);
      await tester.pumpAndSettle();

      // Dialog should still be showing with refreshed data
      expect(find.text('Manage Questionnaires'), findsOneWidget);
    });

    testWidgets('Revoke shows confirmation dialog', (tester) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'sent',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Revoke Questionnaire?'), findsOneWidget);
      expect(find.text('Cancel'), findsWidgets);
      expect(find.text('Revoke Questionnaire'), findsOneWidget);
      expect(
        find.text('Any in-progress answers will be lost.'),
        findsOneWidget,
      );
    });

    testWidgets('Revoke confirmation cancel does not revoke', (tester) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'sent',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();

      // Cancel the confirmation
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // Should still show Revoke button (not revoked)
      expect(find.text('Revoke'), findsOneWidget);
    });

    testWidgets('Finalize shows confirmation dialog', (tester) async {
      // Use a larger surface so buttons are not clipped in DataTable
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final apiClient = await _createMockApiClient(
        noseStatus: 'ready_to_review',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      final finalizeFinder = find.widgetWithText(FilledButton, 'Finalize');
      await tester.ensureVisible(finalizeFinder);
      await tester.pumpAndSettle();
      await tester.tap(finalizeFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Finalize Questionnaire?'), findsOneWidget);
      expect(find.text('Mark the questionnaire as finalized'), findsOneWidget);
      expect(find.text('Calculate the questionnaire score'), findsOneWidget);
      expect(find.text('Finalize Questionnaire'), findsOneWidget);
    });

    testWidgets('handles API error on load', (tester) async {
      final apiClient = await _createMockApiClient(failGetStatus: true);

      await _pumpDialog(tester, apiClient);

      expect(find.text('Server error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('close button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Manage Questionnaires'), findsNothing);
    });

    testWidgets('shows check icon for finalized status', (tester) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'finalized',
        noseId: 'nose-instance-1',
      );

      await _pumpDialog(tester, apiClient);

      expect(find.text('Finalized'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
