// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00073: Patient Status Definitions
//
// Widget tests for MarkNotParticipatingDialog confirm/success/error/retry states.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/mark_not_participating_dialog.dart';

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

    // POST /not-participating
    if (path.contains('/not-participating') && request.method == 'POST') {
      if (shouldFail) {
        return http.Response(
          jsonEncode({'error': 'Patient not in valid state'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'success': true, 'status': 'not_participating'}),
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
                builder: (_) => MarkNotParticipatingDialog(
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
  group('NotParticipatingReason enum', () {
    test('has exactly 4 values', () {
      expect(NotParticipatingReason.values.length, 4);
    });

    test('has correct labels', () {
      expect(
        NotParticipatingReason.subjectWithdrawal.label,
        'Subject Withdrawal',
      );
      expect(NotParticipatingReason.death.label, 'Death');
      expect(
        NotParticipatingReason.protocolComplete.label,
        'Protocol treatment/study complete',
      );
      expect(NotParticipatingReason.other.label, 'Other');
    });

    test('has correct descriptions', () {
      expect(
        NotParticipatingReason.subjectWithdrawal.description,
        'Patient chose to leave the study',
      );
      expect(NotParticipatingReason.death.description, 'Patient is deceased');
      expect(
        NotParticipatingReason.protocolComplete.description,
        'Patient completed all trial requirements',
      );
      expect(
        NotParticipatingReason.other.description,
        'Specify reason in notes',
      );
    });
  });

  group('MarkNotParticipatingDialog widget', () {
    testWidgets('confirm state shows patient ID and action button', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Mark Patient as Not Participating'), findsOneWidget);
      expect(find.textContaining('999-002-320'), findsOneWidget);
      expect(find.text('Mark as Not Participating'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.person_off), findsWidgets);
    });

    testWidgets('confirm state shows warning and reason dropdown', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Warning:'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.text('Reason *'), findsOneWidget);
      expect(find.text('Select a reason'), findsOneWidget);
      expect(find.textContaining('Completed the trial'), findsOneWidget);
      expect(find.textContaining('Withdrawn consent'), findsOneWidget);
    });

    testWidgets('action button has no effect without reason selected', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Tap button without selecting reason — should remain in confirm
      await tester.tap(find.text('Mark as Not Participating'));
      await tester.pumpAndSettle();

      // Still in confirm state
      expect(find.text('Mark Patient as Not Participating'), findsOneWidget);
      expect(find.text('Select a reason'), findsOneWidget);
    });

    testWidgets('selecting reason enables button and tapping shows success', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Open dropdown and select 'Subject Withdrawal'
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subject Withdrawal').last);
      await tester.pumpAndSettle();

      // Tap action button
      await tester.tap(find.text('Mark as Not Participating'));
      await tester.pumpAndSettle();

      // Success state
      expect(find.text('Status Updated'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(
        find.textContaining('marked as not participating'),
        findsOneWidget,
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('Sponsor-specific rules'), findsOneWidget);
    });

    testWidgets('error state shows error message and Try Again', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      // Select reason and submit
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subject Withdrawal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Not Participating'));
      await tester.pumpAndSettle();

      // Error state
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Patient not in valid state'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Try Again returns to confirm state', (tester) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      // Select reason, submit, get error
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subject Withdrawal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Not Participating'));
      await tester.pumpAndSettle();

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Mark Patient as Not Participating'), findsOneWidget);
      expect(find.text('Mark as Not Participating'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Mark Patient as Not Participating'), findsNothing);
    });

    testWidgets('success state shows reason details', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      // Select 'Subject Withdrawal' reason and submit
      await tester.tap(find.text('Select a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subject Withdrawal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Not Participating'));
      await tester.pumpAndSettle();

      // Success state should show reason info
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Subject Withdrawal'), findsOneWidget);
      expect(find.textContaining('reactivate'), findsOneWidget);
    });
  });
}
