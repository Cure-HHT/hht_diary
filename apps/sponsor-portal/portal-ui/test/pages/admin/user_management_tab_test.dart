// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-CAL-p00030: Edit User Account
//
// Widget tests for UserManagementTab
// Tests search/filter functionality and edit button visibility

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/admin/user_management_tab.dart';
import 'package:sponsor_portal_ui/services/api_client.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

/// Test data: users with various roles and statuses
final _testUsers = [
  {
    'id': 'user-001',
    'email': 'alice@example.com',
    'name': 'Alice Admin',
    'status': 'active',
    'roles': ['Administrator'],
    'sites': <dynamic>[],
    'linking_code': null,
    'activation_code': null,
    'created_at': '2024-01-01T00:00:00Z',
  },
  {
    'id': 'user-002',
    'email': 'bob@example.com',
    'name': 'Bob Investigator',
    'status': 'active',
    'roles': ['Investigator'],
    'sites': [
      {'site_id': 's1', 'site_name': 'Site One', 'site_number': 'S001'},
    ],
    'linking_code': null,
    'activation_code': null,
    'created_at': '2024-01-02T00:00:00Z',
  },
  {
    'id': 'user-003',
    'email': 'carol@example.com',
    'name': 'Carol Auditor',
    'status': 'revoked',
    'roles': ['Auditor'],
    'sites': <dynamic>[],
    'linking_code': null,
    'activation_code': null,
    'created_at': '2024-01-03T00:00:00Z',
  },
];

final _testSites = [
  {'site_id': 's1', 'site_name': 'Site One', 'site_number': 'S001'},
];

final _testRoleMappings = {
  'mappings': [
    {'sponsorName': 'Admin', 'systemRole': 'Administrator'},
    {'sponsorName': 'Study Coordinator', 'systemRole': 'Investigator'},
    {'sponsorName': 'CRA', 'systemRole': 'Auditor'},
  ],
};

/// Creates a mock HTTP client that serves test data for all API endpoints
MockClient _createMockHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path == '/api/v1/portal/users') {
      return http.Response(
        jsonEncode({'users': _testUsers}),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path == '/api/v1/portal/sites') {
      return http.Response(
        jsonEncode({'sites': _testSites}),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.startsWith('/api/v1/sponsor/roles')) {
      return http.Response(
        jsonEncode(_testRoleMappings),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path == '/api/v1/portal/me') {
      return http.Response(
        jsonEncode({
          'id': 'user-001',
          'email': 'admin@example.com',
          'name': 'Test Admin',
          'roles': ['Administrator'],
          'active_role': 'Administrator',
          'status': 'active',
          'sites': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('Not found', 404);
  });
}

/// Builds the widget tree, injecting a mock ApiClient via the
/// @visibleForTesting parameter so no real HTTP calls are made.
Future<void> _pumpUserManagementTab(WidgetTester tester) async {
  // Admin portal is a desktop/tablet layout — use a wide viewport
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'admin@example.com',
    displayName: 'Test Admin',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

  final mockHttpClient = _createMockHttpClient();

  // AuthService needed by ChangeNotifierProvider (widget tree may read it)
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: mockHttpClient,
  );
  await authService.signIn('admin@example.com', 'password');

  // Inject ApiClient directly — avoids the default http.Client()
  final apiClient = ApiClient(authService, httpClient: mockHttpClient);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: Scaffold(body: UserManagementTab(apiClient: apiClient)),
      ),
    ),
  );

  // Wait for async _loadData to complete
  await tester.pumpAndSettle();
}

void main() {
  group('UserManagementTab', () {
    testWidgets('shows Portal Users title', (tester) async {
      await _pumpUserManagementTab(tester);
      expect(find.text('Portal Users'), findsOneWidget);
    });

    testWidgets('displays user names in the table', (tester) async {
      await _pumpUserManagementTab(tester);
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsOneWidget);
      expect(find.text('Carol Auditor'), findsOneWidget);
    });

    testWidgets('shows search field with hint text', (tester) async {
      await _pumpUserManagementTab(tester);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Search by name or email'),
        findsOneWidget,
      );
    });

    testWidgets('search filters users by name', (tester) async {
      await _pumpUserManagementTab(tester);

      // All 3 users visible initially
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsOneWidget);
      expect(find.text('Carol Auditor'), findsOneWidget);

      // Type "Alice" in the search field
      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'Alice',
      );
      await tester.pumpAndSettle();

      // Only Alice should remain
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsNothing);
      expect(find.text('Carol Auditor'), findsNothing);
    });

    testWidgets('search filters users by email', (tester) async {
      await _pumpUserManagementTab(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'bob@',
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Admin'), findsNothing);
      expect(find.text('Bob Investigator'), findsOneWidget);
      expect(find.text('Carol Auditor'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await _pumpUserManagementTab(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'CAROL',
      );
      await tester.pumpAndSettle();

      expect(find.text('Carol Auditor'), findsOneWidget);
      expect(find.text('Alice Admin'), findsNothing);
    });

    testWidgets('shows "no match" message when search has no results', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'nonexistent',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No users match'), findsOneWidget);
    });

    testWidgets('clear button appears and resets search', (tester) async {
      await _pumpUserManagementTab(tester);

      // No clear button initially
      expect(find.byIcon(Icons.clear), findsNothing);

      // Type something
      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'test',
      );
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // All users visible again
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsOneWidget);
      expect(find.text('Carol Auditor'), findsOneWidget);
    });

    testWidgets('edit button uses primary colored filled icon', (tester) async {
      await _pumpUserManagementTab(tester);

      // Find edit buttons (only for non-revoked users: Alice and Bob)
      final editIcons = find.byIcon(Icons.edit);
      expect(editIcons, findsNWidgets(2));

      // Verify icon uses primary color
      final iconWidget = tester.widget<Icon>(editIcons.first);
      final colorScheme = Theme.of(tester.element(editIcons.first)).colorScheme;
      expect(iconWidget.color, equals(colorScheme.primary));
    });

    testWidgets('revoked users do not show edit button', (tester) async {
      await _pumpUserManagementTab(tester);

      // Carol is revoked — only Alice + Bob get edit icons
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
    });

    testWidgets('shows create user and refresh buttons', (tester) async {
      await _pumpUserManagementTab(tester);
      expect(find.text('Create User'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });

  group('SponsorRoleMapping', () {
    test('fromJson creates mapping correctly', () {
      final mapping = SponsorRoleMapping.fromJson({
        'sponsorName': 'Study Coordinator',
        'systemRole': 'Investigator',
      });
      expect(mapping.sponsorName, equals('Study Coordinator'));
      expect(mapping.systemRole, equals('Investigator'));
    });
  });
}
