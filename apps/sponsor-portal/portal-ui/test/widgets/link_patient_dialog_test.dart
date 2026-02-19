// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00049: Mobile Linking Codes
//
// Tests for ShowLinkingCodeDialog, specifically the "Generate New Code"
// button when no active linking code exists.

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/link_patient_dialog.dart';

/// Creates a mock HTTP client that returns no active code on GET,
/// then returns a new code on POST.
MockClient _createMockHttpClient({
  bool hasActiveCode = false,
  bool generateShouldFail = false,
}) {
  return MockClient((request) async {
    final path = request.url.path;

    // GET /api/v1/portal/me - required by AuthService
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

    // GET /link-code — fetch existing code status
    if (path.contains('/link-code') && request.method == 'GET') {
      if (hasActiveCode) {
        return http.Response(
          jsonEncode({
            'has_active_code': true,
            'code': 'CATEST-12345',
            'expires_at': DateTime.now()
                .add(const Duration(hours: 48))
                .toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'has_active_code': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /link-code — generate new code
    if (path.contains('/link-code') && request.method == 'POST') {
      if (generateShouldFail) {
        return http.Response(
          jsonEncode({'error': 'Patient already connected'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'code': 'CANEW-67890',
          'expires_at': DateTime.now()
              .add(const Duration(hours: 72))
              .toIso8601String(),
          'site_name': 'DEV Test Site',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response('Not found', 404);
  });
}

/// Creates an ApiClient with mocked HTTP and auth.
Future<ApiClient> _createMockApiClient({
  bool hasActiveCode = false,
  bool generateShouldFail = false,
}) async {
  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient(
    hasActiveCode: hasActiveCode,
    generateShouldFail: generateShouldFail,
  );
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('test@example.com', 'password');
  return ApiClient(authService, httpClient: mockHttpClient);
}

/// Pumps the ShowLinkingCodeDialog inside a MaterialApp scaffold.
Future<void> _pumpShowLinkingCodeDialog(
  WidgetTester tester,
  ApiClient apiClient,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // Immediately show the dialog
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<void>(
                context: context,
                builder: (_) => ShowLinkingCodeDialog(
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
  // First pump triggers the post-frame callback (shows dialog)
  await tester.pump();
  // Second pump allows the dialog to build
  await tester.pump();
  // Wait for the async _fetchCode() to complete
  await tester.pumpAndSettle();
}

/// Pumps the LinkPatientDialog (generate code for new patient).
Future<void> _pumpLinkPatientDialog(
  WidgetTester tester,
  ApiClient apiClient,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => LinkPatientDialog(
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
  group('LinkPatientDialog', () {
    testWidgets('confirm state shows patient ID and Generate Code button', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpLinkPatientDialog(tester, apiClient);

      expect(find.text('Link Patient'), findsOneWidget);
      expect(find.text('999-002-320'), findsOneWidget);
      expect(find.text('Generate Code'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.textContaining('expires after 72 hours'), findsOneWidget);
    });

    testWidgets('tapping Generate Code shows new code on success', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient();

      await _pumpLinkPatientDialog(tester, apiClient);

      await tester.tap(find.text('Generate Code'));
      await tester.pumpAndSettle();

      expect(find.text('Linking Code Generated'), findsOneWidget);
      expect(find.text('CANEW-67890'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('error state shows error message and Try Again button', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(generateShouldFail: true);

      await _pumpLinkPatientDialog(tester, apiClient);

      await tester.tap(find.text('Generate Code'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Patient already connected'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Try Again returns to confirm state', (tester) async {
      final apiClient = await _createMockApiClient(generateShouldFail: true);

      await _pumpLinkPatientDialog(tester, apiClient);

      await tester.tap(find.text('Generate Code'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Link Patient'), findsOneWidget);
      expect(find.text('Generate Code'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      final apiClient = await _createMockApiClient();

      await _pumpLinkPatientDialog(tester, apiClient);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Link Patient'), findsNothing);
    });
  });

  group('ShowLinkingCodeDialog', () {
    testWidgets('shows "No Active Linking Code" when code expired', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(hasActiveCode: false);

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      expect(find.text('No Active Linking Code'), findsOneWidget);
      expect(
        find.textContaining('does not have an active linking code'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Generate New Code" button when no active code', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(hasActiveCode: false);

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      expect(find.text('Generate New Code'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('tapping "Generate New Code" calls POST and shows new code', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(hasActiveCode: false);

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      // Verify we're in the "no code" state
      expect(find.text('Generate New Code'), findsOneWidget);

      // Tap the button
      await tester.tap(find.text('Generate New Code'));
      await tester.pumpAndSettle();

      // Should now show the new code
      expect(find.text('CANEW-67890'), findsOneWidget);
      // "No Active Linking Code" message should be gone
      expect(find.text('No Active Linking Code'), findsNothing);
    });

    testWidgets('shows inline error and retry button when generation fails', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(
        hasActiveCode: false,
        generateShouldFail: true,
      );

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      // Tap generate
      await tester.tap(find.text('Generate New Code'));
      await tester.pumpAndSettle();

      // Should show inline error text
      expect(find.text('Patient already connected'), findsOneWidget);
      // Button should still be visible for retry
      expect(find.text('Generate New Code'), findsOneWidget);
      // Should still be in the "no active code" state
      expect(find.text('No Active Linking Code'), findsOneWidget);
    });

    testWidgets('shows existing code when active code exists', (tester) async {
      final apiClient = await _createMockApiClient(hasActiveCode: true);

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      // Should show the code, not the "no active code" message
      expect(find.text('No Active Linking Code'), findsNothing);
      expect(find.text('CATEST-12345'), findsOneWidget);
    });

    testWidgets('dialog title shows "Linking Code" with QR icon', (
      tester,
    ) async {
      final apiClient = await _createMockApiClient(hasActiveCode: false);

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      expect(find.text('Linking Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code), findsOneWidget);
    });

    testWidgets('Close button dismisses dialog', (tester) async {
      final apiClient = await _createMockApiClient(hasActiveCode: false);

      await _pumpShowLinkingCodeDialog(tester, apiClient);

      expect(find.text('Linking Code'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Linking Code'), findsNothing);
    });
  });
}
