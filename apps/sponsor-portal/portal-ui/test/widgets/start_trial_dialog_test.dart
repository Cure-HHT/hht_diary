// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00079: Start Trial Workflow
//   REQ-CAL-p00073: Patient Status Definitions
//
// Widget tests for StartTrialDialog confirm/success/error/retry states.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/start_trial_dialog.dart';

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

    // POST /start-trial
    if (path.contains('/start-trial') && request.method == 'POST') {
      if (shouldFail) {
        return http.Response(
          jsonEncode({'error': 'Patient not linked'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'trial_started_at': '2026-01-15T10:30:00Z',
          'status': 'active',
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
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => StartTrialDialog(
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
  group('StartTrialDialog', () {
    testWidgets('confirm state shows patient ID and Send EQ button', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.textContaining('999-002-320'), findsWidgets);
      expect(find.text('Send EQ'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.textContaining('EQ questionnaire'), findsWidgets);
    });

    testWidgets('confirm state shows Sync Enabled notice', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      expect(find.text('Sync Enabled'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.textContaining('Epistaxis questionnaire'), findsOneWidget);
    });

    testWidgets('tapping Send EQ shows success state', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Send EQ'));
      await tester.pumpAndSettle();

      expect(find.text('Trial Started'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Trial Active'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('success state shows started-at info', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Send EQ'));
      await tester.pumpAndSettle();

      expect(find.text('Started at'), findsOneWidget);
      expect(find.textContaining('Data sync is now enabled'), findsOneWidget);
    });

    testWidgets('error state shows error message and Try Again', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Send EQ'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Patient not linked'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Try Again returns to confirm state', (tester) async {
      final apiClient = await _createMockApiClient(shouldFail: true);

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Send EQ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Start Trial'), findsOneWidget);
      expect(find.text('Send EQ'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpDialog(tester, apiClient);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Start Trial'), findsNothing);
    });
  });
}
