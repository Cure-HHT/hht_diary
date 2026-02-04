// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00074: Dashboard columns
//   REQ-CAL-p00063: EDC Patient Ingestion
//
// Widget tests for StudyCoordinatorPatientsTab (Study Coordinator Dashboard)
// Tests column structure, search/filter, and patient display

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/investigator/patients_tab.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

/// Test data: patients with various statuses
final _testPatients = [
  {
    'patient_id': 'PAT-001',
    'site_id': 'site-1',
    'edc_subject_key': 'SUBJ-001',
    'mobile_linking_status': 'not_connected',
    'edc_synced_at': '2024-01-01T00:00:00Z',
    'site_name': 'Test Site One',
    'site_number': '001',
  },
  {
    'patient_id': 'PAT-002',
    'site_id': 'site-1',
    'edc_subject_key': 'SUBJ-002',
    'mobile_linking_status': 'connected',
    'edc_synced_at': '2024-01-02T00:00:00Z',
    'site_name': 'Test Site One',
    'site_number': '001',
  },
  {
    'patient_id': 'PAT-003',
    'site_id': 'site-1',
    'edc_subject_key': 'SUBJ-003',
    'mobile_linking_status': 'linking_in_progress',
    'edc_synced_at': '2024-01-03T00:00:00Z',
    'site_name': 'Test Site One',
    'site_number': '001',
  },
];

final _testSites = [
  {'site_id': 'site-1', 'site_name': 'Test Site One', 'site_number': '001'},
];

final _currentUser = {
  'id': 'user-001',
  'email': 'investigator@example.com',
  'name': 'Test Investigator',
  'status': 'active',
  'roles': ['Investigator'],
  'active_role': 'Investigator',
  'mfa_type': 'email_otp',
  'email_otp_required': true,
  'sites': _testSites,
};

/// Creates a mock HTTP client for test API calls
MockClient _createMockHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;

    // GET /api/v1/portal/me - required by AuthService
    if (path == '/api/v1/portal/me' && request.method == 'GET') {
      return http.Response(
        jsonEncode(_currentUser),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /api/v1/portal/patients
    if (path == '/api/v1/portal/patients' && request.method == 'GET') {
      return http.Response(
        jsonEncode({'patients': _testPatients, 'assigned_sites': _testSites}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response('Not found', 404);
  });
}

/// Builds the test widget with properly injected mock dependencies
Future<void> _pumpPatientsTab(WidgetTester tester) async {
  // Portal is a desktop/tablet layout — use a very wide viewport to avoid overflow
  // The extra EQ, NOSE HHT, QoL columns cause overflow at smaller sizes
  tester.view.physicalSize = const Size(2400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'investigator@example.com',
    displayName: 'Test Investigator',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  final mockHttpClient = _createMockHttpClient();

  // AuthService needed by ChangeNotifierProvider (widget tree may read it)
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('investigator@example.com', 'password');

  // Inject ApiClient directly — avoids the default http.Client()
  final apiClient = ApiClient(authService, httpClient: mockHttpClient);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: Scaffold(
          body: StudyCoordinatorPatientsTab(apiClient: apiClient),
        ),
      ),
    ),
  );

  // Wait for async _loadPatients to complete
  await tester.pumpAndSettle();
}

void main() {
  group('StudyCoordinatorPatientsTab', () {
    group('Dashboard Columns (REQ-CAL-p00074)', () {
      testWidgets('should NOT display EQ, NOSE HHT, or QoL columns', (
        WidgetTester tester,
      ) async {
        await _pumpPatientsTab(tester);

        // These columns should NOT be present (per REQ-CAL-p00074)
        expect(find.text('EQ'), findsNothing);
        expect(find.text('NOSE HHT'), findsNothing);
        expect(find.text('QoL'), findsNothing);
      });

      testWidgets(
        'should display only Patient ID, Site, Mobile Linking, Actions columns',
        (WidgetTester tester) async {
          await _pumpPatientsTab(tester);

          // These columns SHOULD be present
          expect(find.text('Patient ID'), findsOneWidget);
          expect(find.text('Site'), findsOneWidget);
          expect(find.text('Mobile Linking'), findsOneWidget);
          expect(find.text('Actions'), findsOneWidget);
        },
      );
    });

    group('Patient Display', () {
      testWidgets('should display patient data in table', (
        WidgetTester tester,
      ) async {
        await _pumpPatientsTab(tester);

        // Should show patient IDs
        expect(find.text('PAT-001'), findsOneWidget);
        expect(find.text('PAT-002'), findsOneWidget);
        expect(find.text('PAT-003'), findsOneWidget);
      });

      testWidgets('should display site information', (
        WidgetTester tester,
      ) async {
        await _pumpPatientsTab(tester);

        // Should show site info (format: "number - name")
        expect(find.textContaining('001'), findsWidgets);
        expect(find.textContaining('Test Site One'), findsWidgets);
      });

      testWidgets('should display Patient Summary header', (
        WidgetTester tester,
      ) async {
        await _pumpPatientsTab(tester);

        expect(find.text('Patient Summary'), findsOneWidget);
      });
    });

    group('Patient Status (REQ-CAL-p00073)', () {
      testWidgets('should display linking status chips for patients', (
        WidgetTester tester,
      ) async {
        await _pumpPatientsTab(tester);

        // Check status chips are displayed
        expect(find.text('Not Connected'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
      });
    });

    group('Search and Filter', () {
      testWidgets('should display search field', (WidgetTester tester) async {
        await _pumpPatientsTab(tester);

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('Search patients...'), findsOneWidget);
      });

      testWidgets('should display status filter tabs', (
        WidgetTester tester,
      ) async {
        await _pumpPatientsTab(tester);

        // Filter tabs should be present
        expect(find.textContaining('All'), findsOneWidget);
        expect(find.textContaining('Not Connected'), findsWidgets);
        expect(find.textContaining('Active'), findsWidgets);
        expect(find.textContaining('Inactive'), findsOneWidget);
      });
    });
  });
}
