// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00031: Deactivate User Account
//   REQ-CAL-p00032: Reactivate User Account
//   REQ-CAL-p00062: Activation code generation on reactivation
//   REQ-CAL-p00066: Capture deactivation/reactivation reason
//   REQ-CAL-p00067: Active/Inactive user tabs
//
// Widget tests for UserManagementTab
// Tests search/filter, edit button visibility, tabs, deactivation, and reactivation dialogs

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
    'status_change_reason': 'Employee left the organization',
    'status_changed_at': '2024-06-15T10:30:00Z',
    'status_changed_by': 'user-001',
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

    testWidgets('displays active user names in Active tab', (tester) async {
      await _pumpUserManagementTab(tester);
      // Active Users tab is default — shows Alice and Bob
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsOneWidget);
      // Carol is revoked — not visible on Active tab
      expect(find.text('Carol Auditor'), findsNothing);
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

      // Active tab: Alice and Bob visible initially
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsOneWidget);

      // Type "Alice" in the search field
      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'Alice',
      );
      await tester.pumpAndSettle();

      // Only Alice should remain
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsNothing);
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
        'ALICE',
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsNothing);
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

      // Active tab users visible again
      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Bob Investigator'), findsOneWidget);
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

    testWidgets('Active tab shows edit buttons for active users only', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Active tab: Alice + Bob each get edit icons
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
    });

    testWidgets('shows create user and refresh buttons', (tester) async {
      await _pumpUserManagementTab(tester);
      expect(find.text('Create User'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('active non-pending users show deactivate button', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Active tab: Alice and Bob are both active (non-pending) → both show block icon
      expect(find.byIcon(Icons.block), findsNWidgets(2));
    });

    testWidgets('Inactive tab shows reactivate button for revoked users', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Switch to Inactive Users tab
      await tester.tap(find.text('Inactive Users'));
      await tester.pumpAndSettle();

      // Carol is revoked → shows check_circle_outline for reactivate
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Carol Auditor'), findsOneWidget);
    });

    testWidgets('shows role badges with sponsor display names on Active tab', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Active tab: Admin→Administrator (Alice), Study Coordinator→Investigator (Bob)
      expect(find.text('Admin'), findsOneWidget); // Alice
      expect(find.text('Study Coordinator'), findsOneWidget); // Bob
      // Carol (CRA) is on Inactive tab, not visible
      expect(find.text('CRA'), findsNothing);
    });

    testWidgets('investigator shows site name, admin shows All sites', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Active tab only: Bob is Investigator with 1 site → shows site name
      expect(find.text('Site One'), findsOneWidget);
      // Alice is Administrator → shows "All sites"
      expect(find.text('All sites'), findsOneWidget);
    });

    testWidgets('Active tab shows Active status badges', (tester) async {
      await _pumpUserManagementTab(tester);

      // Active tab: Alice and Bob are active
      expect(find.text('Active'), findsNWidgets(2));
      // Carol is on Inactive tab
      expect(find.text('Inactive'), findsNothing);
    });
  });

  group('CreateUserDialog', () {
    final roleMappings = [
      const SponsorRoleMapping(
        sponsorName: 'Admin',
        systemRole: 'Administrator',
      ),
      const SponsorRoleMapping(
        sponsorName: 'Study Coordinator',
        systemRole: 'Investigator',
      ),
      const SponsorRoleMapping(sponsorName: 'CRA', systemRole: 'Auditor'),
    ];

    final sites = [
      {'site_id': 's1', 'site_name': 'Site One', 'site_number': 'S001'},
    ];

    Future<void> pumpCreateDialog(WidgetTester tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final client = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => CreateUserDialog(
                      sites: sites,
                      apiClient: client,
                      roleMappings: roleMappings,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Create New User title', (tester) async {
      await pumpCreateDialog(tester);
      expect(find.text('Create New User'), findsOneWidget);
    });

    testWidgets('shows name and email fields', (tester) async {
      await pumpCreateDialog(tester);

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('shows role checkboxes from mappings', (tester) async {
      await pumpCreateDialog(tester);

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Study Coordinator'), findsOneWidget);
      expect(find.text('CRA'), findsOneWidget);
    });

    testWidgets('shows Roles heading and validation hint', (tester) async {
      await pumpCreateDialog(tester);

      expect(find.text('Roles *'), findsOneWidget);
      expect(find.text('Select at least one role'), findsOneWidget);
    });

    testWidgets('shows Cancel and Create buttons', (tester) async {
      await pumpCreateDialog(tester);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('validates empty name field', (tester) async {
      await pumpCreateDialog(tester);

      // Select a role first so we get past role validation
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      // Enter email but leave name empty
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );

      // Tap Create
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('validates empty email field', (tester) async {
      await pumpCreateDialog(tester);

      // Select a role
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      // Enter name but leave email empty
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Test User',
      );

      // Tap Create
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('validates invalid email format', (tester) async {
      await pumpCreateDialog(tester);

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'not-an-email',
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows site selection when Study Coordinator role selected', (
      tester,
    ) async {
      await pumpCreateDialog(tester);

      // Initially no sites section
      expect(find.text('Assigned Sites *'), findsNothing);

      // Select Study Coordinator (maps to Investigator system role)
      await tester.tap(find.text('Study Coordinator'));
      await tester.pumpAndSettle();

      // Sites section should appear
      expect(find.text('Assigned Sites *'), findsOneWidget);
      expect(find.text('S001 - Site One'), findsOneWidget);
    });

    testWidgets('hides site selection when non-investigator role selected', (
      tester,
    ) async {
      await pumpCreateDialog(tester);

      // Select Admin (maps to Administrator — no sites needed)
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Assigned Sites *'), findsNothing);
    });
  });

  group('UserInfoDialog', () {
    testWidgets('shows user name and email', (tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      final roleMappings = [
        const SponsorRoleMapping(
          sponsorName: 'Admin',
          systemRole: 'Administrator',
        ),
        const SponsorRoleMapping(
          sponsorName: 'Study Coordinator',
          systemRole: 'Investigator',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u1',
                'name': 'Jane Doe',
                'email': 'jane@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: const [],
              roleMappings: roleMappings,
              toSponsorName: (systemRole) {
                final m = roleMappings.firstWhere(
                  (r) => r.systemRole == systemRole,
                  orElse: () => SponsorRoleMapping(
                    sponsorName: systemRole,
                    systemRole: systemRole,
                  ),
                );
                return m.sponsorName;
              },
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      expect(find.text('User Information'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('shows roles section with badge', (tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      final roleMappings = [
        const SponsorRoleMapping(
          sponsorName: 'Study Coordinator',
          systemRole: 'Investigator',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u2',
                'name': 'Bob',
                'email': 'bob@example.com',
                'status': 'active',
                'roles': ['Investigator'],
                'sites': [
                  {
                    'site_id': 's1',
                    'site_name': 'Site One',
                    'site_number': 'S001',
                  },
                ],
              },
              sites: const [],
              roleMappings: roleMappings,
              toSponsorName: (systemRole) {
                final m = roleMappings.firstWhere(
                  (r) => r.systemRole == systemRole,
                  orElse: () => SponsorRoleMapping(
                    sponsorName: systemRole,
                    systemRole: systemRole,
                  ),
                );
                return m.sponsorName;
              },
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      expect(find.text('Roles'), findsOneWidget);
      // Badge shows sponsor name
      expect(find.text('Study Coordinator'), findsOneWidget);
    });

    testWidgets('shows assigned sites section', (tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u2',
                'name': 'Bob',
                'email': 'bob@example.com',
                'status': 'active',
                'roles': ['Investigator'],
                'sites': [
                  {
                    'site_id': 's1',
                    'site_name': 'Site One',
                    'site_number': 'S001',
                  },
                ],
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      expect(find.text('Assigned Sites (1)'), findsOneWidget);
      expect(find.text('S001 - Site One'), findsOneWidget);
    });

    testWidgets('shows Edit User and Deactivate buttons for active user', (
      tester,
    ) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u1',
                'name': 'Active User',
                'email': 'active@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      expect(find.text('Edit User'), findsOneWidget);
      expect(find.text('Deactivate User'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('hides Edit/Deactivate buttons for revoked user', (
      tester,
    ) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u3',
                'name': 'Revoked User',
                'email': 'revoked@example.com',
                'status': 'revoked',
                'roles': ['Auditor'],
                'sites': <dynamic>[],
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      expect(find.text('Edit User'), findsNothing);
      expect(find.text('Deactivate User'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows "All sites" for non-investigator with no sites', (
      tester,
    ) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u1',
                'name': 'Admin User',
                'email': 'admin@test.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      expect(
        find.text('All sites (role does not require site assignment)'),
        findsOneWidget,
      );
    });
  });

  group('EditUserDialog', () {
    final roleMappings = [
      const SponsorRoleMapping(
        sponsorName: 'Admin',
        systemRole: 'Administrator',
      ),
      const SponsorRoleMapping(
        sponsorName: 'Study Coordinator',
        systemRole: 'Investigator',
      ),
      const SponsorRoleMapping(sponsorName: 'CRA', systemRole: 'Auditor'),
    ];

    final sites = [
      {'site_id': 's1', 'site_name': 'Site One', 'site_number': 'S001'},
    ];

    String toSponsorName(String systemRole) {
      final m = roleMappings.firstWhere(
        (r) => r.systemRole == systemRole,
        orElse: () =>
            SponsorRoleMapping(sponsorName: systemRole, systemRole: systemRole),
      );
      return m.sponsorName;
    }

    Future<ApiClient> createApiClient() async {
      final mockUser = MockUser(
        uid: 'test-uid',
        email: 'admin@example.com',
        displayName: 'Test Admin',
      );
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      return ApiClient(authService, httpClient: mockHttpClient);
    }

    testWidgets('shows Edit User title and session warning', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = await createApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: const {
                'id': 'u1',
                'name': 'Alice Admin',
                'email': 'alice@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: sites,
              apiClient: apiClient,
              roleMappings: roleMappings,
              toSponsorName: toSponsorName,
            ),
          ),
        ),
      );

      expect(find.text('Edit User'), findsOneWidget);
      expect(
        find.textContaining('Active sessions will be terminated'),
        findsOneWidget,
      );
    });

    testWidgets('shows pre-filled name and read-only email', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = await createApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: const {
                'id': 'u1',
                'name': 'Alice Admin',
                'email': 'alice@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: sites,
              apiClient: apiClient,
              roleMappings: roleMappings,
              toSponsorName: toSponsorName,
            ),
          ),
        ),
      );

      // Name field pre-filled
      expect(find.text('Alice Admin'), findsOneWidget);
      // Email shown as read-only text
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    testWidgets('shows role checkboxes with current role pre-selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = await createApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: const {
                'id': 'u1',
                'name': 'Alice Admin',
                'email': 'alice@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: sites,
              apiClient: apiClient,
              roleMappings: roleMappings,
              toSponsorName: toSponsorName,
            ),
          ),
        ),
      );

      // All role checkboxes shown
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Study Coordinator'), findsOneWidget);
      expect(find.text('CRA'), findsOneWidget);

      // Admin checkbox should be checked (Alice has Administrator role)
      final adminCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Admin'),
      );
      expect(adminCheckbox.value, isTrue);
    });

    testWidgets('Save Changes button disabled when no changes', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = await createApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: const {
                'id': 'u1',
                'name': 'Alice Admin',
                'email': 'alice@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: sites,
              apiClient: apiClient,
              roleMappings: roleMappings,
              toSponsorName: toSponsorName,
            ),
          ),
        ),
      );

      // Save button should be disabled (no changes made)
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Changes'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('shows site checkboxes for investigator user', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = await createApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: const {
                'id': 'u2',
                'name': 'Bob Investigator',
                'email': 'bob@example.com',
                'status': 'active',
                'roles': ['Investigator'],
                'sites': [
                  {
                    'site_id': 's1',
                    'site_name': 'Site One',
                    'site_number': 'S001',
                  },
                ],
              },
              sites: sites,
              apiClient: apiClient,
              roleMappings: roleMappings,
              toSponsorName: toSponsorName,
            ),
          ),
        ),
      );

      // Sites section visible for Investigator
      expect(find.text('Assigned Sites *'), findsOneWidget);
      expect(find.text('S001 - Site One'), findsOneWidget);
    });

    testWidgets('Cancel button present', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiClient = await createApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: const {
                'id': 'u1',
                'name': 'Alice',
                'email': 'alice@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: sites,
              apiClient: apiClient,
              roleMappings: roleMappings,
              toSponsorName: toSponsorName,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
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

  // REQ-CAL-p00067: Active/Inactive tabs
  group('Active/Inactive Tabs', () {
    testWidgets('shows Active Users and Inactive Users tabs', (tester) async {
      await _pumpUserManagementTab(tester);
      expect(find.text('Active Users'), findsOneWidget);
      expect(find.text('Inactive Users'), findsOneWidget);
    });

    testWidgets('Active Users tab shows correct count badge', (tester) async {
      await _pumpUserManagementTab(tester);
      // 2 active users (Alice + Bob)
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Inactive Users tab shows correct count badge', (tester) async {
      await _pumpUserManagementTab(tester);
      // 1 inactive user (Carol)
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('switching to Inactive tab shows revoked users', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Initially on Active tab — Carol not visible
      expect(find.text('Carol Auditor'), findsNothing);

      // Switch to Inactive tab
      await tester.tap(find.text('Inactive Users'));
      await tester.pumpAndSettle();

      // Carol visible, Alice and Bob not visible
      expect(find.text('Carol Auditor'), findsOneWidget);
      expect(find.text('Alice Admin'), findsNothing);
      expect(find.text('Bob Investigator'), findsNothing);
    });

    testWidgets('search works across Inactive tab', (tester) async {
      await _pumpUserManagementTab(tester);

      // Switch to Inactive tab
      await tester.tap(find.text('Inactive Users'));
      await tester.pumpAndSettle();

      expect(find.text('Carol Auditor'), findsOneWidget);

      // Search for "nonexistent"
      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or email'),
        'nonexistent',
      );
      await tester.pumpAndSettle();

      expect(find.text('Carol Auditor'), findsNothing);
    });
  });

  // REQ-CAL-p00031: DeactivateUserDialog
  group('DeactivateUserDialog', () {
    Future<void> pumpDeactivateDialog(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        const DeactivateUserDialog(userName: 'Lisa Test'),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows dialog title and user name', (tester) async {
      await pumpDeactivateDialog(tester);
      expect(find.text('Deactivate User Account'), findsOneWidget);
      expect(find.textContaining('Lisa Test'), findsOneWidget);
    });

    testWidgets('shows consequences list', (tester) async {
      await pumpDeactivateDialog(tester);
      expect(
        find.textContaining('Terminate all active sessions'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Prevent the user from logging in'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Move the user to the Inactive Users tab'),
        findsOneWidget,
      );
      expect(find.textContaining('can be reversed'), findsOneWidget);
    });

    testWidgets('shows reason text field', (tester) async {
      await pumpDeactivateDialog(tester);
      expect(
        find.widgetWithText(TextField, 'Reason for deactivation *'),
        findsOneWidget,
      );
    });

    testWidgets('Deactivate button disabled when reason is empty', (
      tester,
    ) async {
      await pumpDeactivateDialog(tester);

      // Find the Deactivate button
      final deactivateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Deactivate'),
      );
      expect(deactivateButton.onPressed, isNull);
    });

    testWidgets('Deactivate button enabled when reason is entered', (
      tester,
    ) async {
      await pumpDeactivateDialog(tester);

      // Enter a reason
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for deactivation *'),
        'Employee left the company',
      );
      await tester.pumpAndSettle();

      // Deactivate button should now be enabled
      final deactivateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Deactivate'),
      );
      expect(deactivateButton.onPressed, isNotNull);
    });

    testWidgets('Cancel button closes dialog without result', (tester) async {
      await pumpDeactivateDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Deactivate User Account'), findsNothing);
    });
  });

  // REQ-CAL-p00031: UserInfoDialog shows deactivation details
  group('UserInfoDialog - deactivation info', () {
    testWidgets('shows deactivation details for revoked user', (tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u3',
                'name': 'Deactivated User',
                'email': 'deactivated@example.com',
                'status': 'revoked',
                'roles': ['Auditor'],
                'sites': <dynamic>[],
                'status_change_reason': 'Employee left the organization',
                'status_changed_at': '2024-06-15T10:30:00Z',
                'status_changed_by': 'admin-user-id',
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              onReactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      // Shows deactivation details section
      expect(find.text('Deactivation Details'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Employee left the organization'), findsOneWidget);
      expect(find.text('Deactivated on'), findsOneWidget);
      expect(find.text('2024-06-15T10:30:00Z'), findsOneWidget);
    });

    testWidgets('shows Reactivate button for revoked user', (tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u3',
                'name': 'Revoked User',
                'email': 'revoked@example.com',
                'status': 'revoked',
                'roles': ['Auditor'],
                'sites': <dynamic>[],
                'status_change_reason': 'Left company',
                'status_changed_at': '2024-06-15T10:30:00Z',
                'status_changed_by': null,
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              onReactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      // Should show Reactivate button, not Edit/Deactivate
      expect(find.text('Reactivate User'), findsOneWidget);
      expect(find.text('Edit User'), findsNothing);
      expect(find.text('Deactivate User'), findsNothing);
    });

    testWidgets('hides deactivation details for active user', (tester) async {
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
      final mockFirebaseAuth = MockFirebaseAuth(
        mockUser: mockUser,
        signedIn: true,
      );
      final mockHttpClient = _createMockHttpClient();
      final authService = AuthService(
        firebaseAuth: mockFirebaseAuth,
        httpClient: mockHttpClient,
      );
      await authService.signIn('admin@example.com', 'password');
      final apiClient = ApiClient(authService, httpClient: mockHttpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDialog(
              user: const {
                'id': 'u1',
                'name': 'Active User',
                'email': 'active@example.com',
                'status': 'active',
                'roles': ['Administrator'],
                'sites': <dynamic>[],
              },
              sites: const [],
              roleMappings: const [],
              toSponsorName: (role) => role,
              onEdit: () {},
              onDeactivate: () {},
              apiClient: apiClient,
            ),
          ),
        ),
      );

      // No deactivation section for active user
      expect(find.text('Deactivation Details'), findsNothing);
      expect(find.text('Reactivate User'), findsNothing);
    });
  });

  // REQ-CAL-p00032: ReactivateUserDialog
  group('ReactivateUserDialog', () {
    final roleMappings = [
      const SponsorRoleMapping(
        sponsorName: 'Admin',
        systemRole: 'Administrator',
      ),
      const SponsorRoleMapping(
        sponsorName: 'Study Coordinator',
        systemRole: 'Investigator',
      ),
      const SponsorRoleMapping(sponsorName: 'CRA', systemRole: 'Auditor'),
    ];

    String toSponsorName(String systemRole) {
      final m = roleMappings.firstWhere(
        (r) => r.systemRole == systemRole,
        orElse: () =>
            SponsorRoleMapping(sponsorName: systemRole, systemRole: systemRole),
      );
      return m.sponsorName;
    }

    Future<void> pumpReactivateDialog(
      WidgetTester tester, {
      Map<String, dynamic>? userOverride,
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final user =
          userOverride ??
          const {
            'id': 'u3',
            'name': 'Maria Garcia',
            'email': 'maria@example.com',
            'status': 'revoked',
            'roles': ['Investigator'],
            'sites': [
              {'site_id': 's1', 'site_name': 'Site One', 'site_number': 'S001'},
            ],
            'status_change_reason': 'Employee left the organization',
            'status_changed_at': '2024-06-15T10:30:00Z',
            'status_changed_by': 'user-001',
          };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ReactivateUserDialog(
                      user: user,
                      roleMappings: roleMappings,
                      toSponsorName: toSponsorName,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows dialog title with icon', (tester) async {
      await pumpReactivateDialog(tester);
      expect(find.text('Reactivate User Account'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets('shows user name and email', (tester) async {
      await pumpReactivateDialog(tester);
      expect(find.text('Maria Garcia'), findsOneWidget);
      expect(find.text('maria@example.com'), findsOneWidget);
    });

    testWidgets('shows previous deactivation reason', (tester) async {
      await pumpReactivateDialog(tester);
      expect(find.text('Previous deactivation reason'), findsOneWidget);
      expect(find.text('Employee left the organization'), findsOneWidget);
    });

    testWidgets('shows previous access section with role badges', (
      tester,
    ) async {
      await pumpReactivateDialog(tester);
      expect(find.text('Previous Access'), findsOneWidget);
      // Investigator maps to Study Coordinator
      expect(find.text('Study Coordinator'), findsOneWidget);
    });

    testWidgets('shows previous access section with sites', (tester) async {
      await pumpReactivateDialog(tester);
      expect(find.text('S001 - Site One'), findsOneWidget);
    });

    testWidgets('shows what-happens info section', (tester) async {
      await pumpReactivateDialog(tester);
      expect(find.text('What happens next'), findsOneWidget);
      expect(
        find.text('A new activation email will be sent to the user'),
        findsOneWidget,
      );
      expect(
        find.text('User must create a new password for security'),
        findsOneWidget,
      );
      expect(
        find.text('Previous roles and site assignments will be preserved'),
        findsOneWidget,
      );
      expect(
        find.text('Account will move to Active Users once activated'),
        findsOneWidget,
      );
    });

    testWidgets('shows required reason field', (tester) async {
      await pumpReactivateDialog(tester);
      expect(
        find.widgetWithText(TextField, 'Reason for reactivation *'),
        findsOneWidget,
      );
    });

    testWidgets('Reactivate button disabled without reason', (tester) async {
      await pumpReactivateDialog(tester);

      final reactivateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reactivate'),
      );
      expect(reactivateButton.onPressed, isNull);
    });

    testWidgets('Reactivate button enabled when reason is entered', (
      tester,
    ) async {
      await pumpReactivateDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for reactivation *'),
        'Employee returning to project',
      );
      await tester.pumpAndSettle();

      final reactivateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reactivate'),
      );
      expect(reactivateButton.onPressed, isNotNull);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      await pumpReactivateDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Reactivate User Account'), findsNothing);
    });

    testWidgets('hides deactivation reason when not available', (tester) async {
      await pumpReactivateDialog(
        tester,
        userOverride: const {
          'id': 'u4',
          'name': 'No Reason User',
          'email': 'noreason@example.com',
          'status': 'revoked',
          'roles': ['Auditor'],
          'sites': <dynamic>[],
        },
      );

      expect(find.text('Previous deactivation reason'), findsNothing);
    });
  });
}
