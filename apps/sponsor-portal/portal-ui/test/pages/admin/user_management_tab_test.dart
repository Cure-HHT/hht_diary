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

    testWidgets('active non-pending users show revoke button', (tester) async {
      await _pumpUserManagementTab(tester);

      // Alice and Bob are both active (non-pending) → both show block icon
      expect(find.byIcon(Icons.block), findsNWidgets(2));
    });

    testWidgets('revoked users show reactivate button', (tester) async {
      await _pumpUserManagementTab(tester);

      // Carol is revoked → shows check_circle_outline for reactivate
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows role badges with sponsor display names', (tester) async {
      await _pumpUserManagementTab(tester);

      // Role mappings: Admin→Administrator, Study Coordinator→Investigator, CRA→Auditor
      expect(find.text('Admin'), findsOneWidget); // Alice
      expect(find.text('Study Coordinator'), findsOneWidget); // Bob
      expect(find.text('CRA'), findsOneWidget); // Carol
    });

    testWidgets('investigator shows site name, others show All sites', (
      tester,
    ) async {
      await _pumpUserManagementTab(tester);

      // Bob is Investigator with 1 site → shows site name
      expect(find.text('Site One'), findsOneWidget);
      // Alice is Administrator → shows "All sites"
      // Carol is Auditor → shows "All sites"
      expect(find.text('All sites'), findsNWidgets(2));
    });

    testWidgets('shows status badges for all users', (tester) async {
      await _pumpUserManagementTab(tester);

      // Alice and Bob are active, Carol is revoked (shown as "Inactive")
      expect(find.text('Active'), findsNWidgets(2));
      expect(find.text('Inactive'), findsOneWidget);
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
}
