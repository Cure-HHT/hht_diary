// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00080: Questionnaire Study Event Association
//
// Widget tests for ManageQuestionnairesDialog (card-based layout).

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
  String? noseStudyEvent,
  bool failGetStatus = false,
  bool failSend = false,
  bool failDelete = false,
}) {
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
      return http.Response(
        jsonEncode({
          'patient_id': 'PAT-TEST-001',
          'questionnaires': [
            {
              'questionnaire_type': 'nose_hht',
              'status': noseStatus,
              if (noseId != null) 'id': noseId,
              if (noseStudyEvent != null) 'study_event': noseStudyEvent,
              if (noseStatus == 'not_sent')
                'next_cycle_info': {'needs_initial_selection': true},
            },
            {
              'questionnaire_type': 'qol',
              'status': qolStatus,
              if (qolId != null) 'id': qolId,
              if (qolStatus == 'not_sent')
                'next_cycle_info': {'needs_initial_selection': true},
            },
            {
              'questionnaire_type': 'eq',
              'status': 'sent',
              'id': 'eq-instance-1',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/send') && request.method == 'POST') {
      if (failSend) {
        return http.Response(
          jsonEncode({'error': 'Failed'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'instance_id': 'new-id',
          'status': 'sent',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.method == 'DELETE') {
      if (failDelete) {
        return http.Response(
          jsonEncode({'error': 'Failed'}),
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

    if (path.contains('/unlock') && request.method == 'POST') {
      return http.Response(
        jsonEncode({'success': true, 'status': 'sent'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/finalize') && request.method == 'POST') {
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
  String? noseStudyEvent,
  bool failGetStatus = false,
  bool failSend = false,
  bool failDelete = false,
}) async {
  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient(
    noseStatus: noseStatus,
    qolStatus: qolStatus,
    noseId: noseId,
    qolId: qolId,
    noseStudyEvent: noseStudyEvent,
    failGetStatus: failGetStatus,
    failSend: failSend,
    failDelete: failDelete,
  );
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('test@example.com', 'password');
  return ApiClient(authService, httpClient: mockHttpClient);
}

Future<void> _pumpDialog(WidgetTester tester, ApiClient apiClient) async {
  tester.view.physicalSize = const Size(1200, 900);
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
    testWidgets('shows title and patient ID', (tester) async {
      final apiClient = await _createMockApiClient();
      await _pumpDialog(tester, apiClient);

      expect(find.text('Manage Questionnaires'), findsOneWidget);
      expect(find.textContaining('999-002-320'), findsOneWidget);
    });

    testWidgets('shows NOSE HHT and HHT-QoL cards but not EQ', (tester) async {
      final apiClient = await _createMockApiClient();
      await _pumpDialog(tester, apiClient);

      expect(find.text('NOSE HHT'), findsOneWidget);
      expect(find.text('HHT-QoL'), findsOneWidget);
      expect(find.text('EQ'), findsNothing);
    });

    testWidgets('shows Send Now buttons for not_sent status', (tester) async {
      final apiClient = await _createMockApiClient();
      await _pumpDialog(tester, apiClient);

      expect(find.text('Send Now'), findsNWidgets(2));
      expect(find.text('Not Sent'), findsNWidgets(2));
    });

    testWidgets('shows delete icon for sent status', (tester) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'sent',
        noseId: 'nose-1',
      );
      await _pumpDialog(tester, apiClient);

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows Finalize and delete for ready_to_review', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'ready_to_review',
        noseId: 'nose-1',
      );
      await _pumpDialog(tester, apiClient);

      expect(find.text('Finalize'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows "Participant is working" for in_progress', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'in_progress',
        noseId: 'nose-1',
      );
      await _pumpDialog(tester, apiClient);

      expect(find.text('Participant is working'), findsOneWidget);
    });

    testWidgets('Send Now shows cycle selection then sends (CUR-856)', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();
      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Send Now').first);
      await tester.pumpAndSettle();

      expect(find.text('Start Questionnaire?'), findsOneWidget);

      await tester.tap(find.text('Confirm and Send'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Questionnaires'), findsOneWidget);
    });

    // REQ-CAL-p00080 Assertion C: cancelling the Starting Cycle dialog must
    // abort the send — the questionnaire SHALL NOT be sent.
    Future<ApiClient> createTrackingApiClient({
      required bool Function() getSendCalled,
      required void Function() setSendCalled,
    }) async {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = MockClient((request) async {
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

        if (path.contains('/questionnaires') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'patient_id': 'PAT-TEST-001',
              'questionnaires': [
                {
                  'questionnaire_type': 'nose_hht',
                  'status': 'not_sent',
                  'next_cycle_info': {'needs_initial_selection': true},
                },
                {
                  'questionnaire_type': 'qol',
                  'status': 'not_sent',
                  'next_cycle_info': {'needs_initial_selection': true},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/send') && request.method == 'POST') {
          setSendCalled();
          return http.Response(
            jsonEncode({
              'success': true,
              'instance_id': 'new-id',
              'status': 'sent',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not found', 404);
      });
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('test@example.com', 'password');
      return ApiClient(authService, httpClient: mockHttpClient);
    }

    testWidgets(
      'Cancelling cycle selection dialog does not send questionnaire (REQ-CAL-p00080-C)',
      (tester) async {
        var sendCalled = false;
        final apiClient = await createTrackingApiClient(
          getSendCalled: () => sendCalled,
          setSendCalled: () => sendCalled = true,
        );

        await _pumpDialog(tester, apiClient);

        await tester.tap(find.text('Send Now').first);
        await tester.pumpAndSettle();

        expect(find.text('Start Questionnaire?'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(sendCalled, isFalse);
        expect(find.text('Manage Questionnaires'), findsOneWidget);
      },
    );

    testWidgets(
      'Closing cycle selection via X does not send questionnaire (REQ-CAL-p00080-C)',
      (tester) async {
        var sendCalled = false;
        final apiClient = await createTrackingApiClient(
          getSendCalled: () => sendCalled,
          setSendCalled: () => sendCalled = true,
        );

        await _pumpDialog(tester, apiClient);

        await tester.tap(find.text('Send Now').first);
        await tester.pumpAndSettle();

        expect(find.text('Start Questionnaire?'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        expect(sendCalled, isFalse);
        expect(find.text('Manage Questionnaires'), findsOneWidget);
      },
    );

    testWidgets('Delete shows confirmation dialog with reason input', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'sent',
        noseId: 'nose-1',
      );
      await _pumpDialog(tester, apiClient);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Call Back Questionnaire?'), findsOneWidget);
      expect(find.text('Enter reason...'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('close button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();
      await _pumpDialog(tester, apiClient);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Manage Questionnaires'), findsNothing);
    });

    testWidgets('handles API error on load', (tester) async {
      final apiClient = await _createMockApiClient(failGetStatus: true);
      await _pumpDialog(tester, apiClient);

      expect(find.text('Server error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Finalize dialog shows cycle dropdown (CUR-856)', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(
        noseStatus: 'ready_to_review',
        noseId: 'nose-1',
        noseStudyEvent: 'Cycle 3 Day 1',
      );
      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Finalize'));
      await tester.pumpAndSettle();

      expect(find.text('Finalize Questionnaire?'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('shows disabled Start Next Cycle when blocked (CUR-856)', (
      tester,
    ) async {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/portal/me' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 'user-001',
              'email': 'test@example.com',
              'name': 'Test',
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
        if (path.contains('/questionnaires') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'patient_id': 'PAT-TEST-001',
              'questionnaires': [
                {
                  'questionnaire_type': 'nose_hht',
                  'status': 'not_sent',
                  'last_finalized_at': '2026-04-02T10:00:00Z',
                  'last_finalized_study_event': 'Cycle 5 Day 1',
                  'next_cycle_info': {
                    'blocked': true,
                    'blocked_reason': 'End of Treatment was finalized',
                  },
                },
                {
                  'questionnaire_type': 'qol',
                  'status': 'not_sent',
                  'next_cycle_info': {'needs_initial_selection': true},
                },
                {'questionnaire_type': 'eq', 'status': 'sent', 'id': 'eq-1'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('test@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await _pumpDialog(tester, apiClient);

      // NOSE HHT: status chip shows "Closed" (no end_event); blocked cards
      // show no action button.
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Start Next Cycle'), findsNothing);
      // QoL: still has Send Now
      expect(find.text('Send Now'), findsOneWidget);
    });
  });
}
