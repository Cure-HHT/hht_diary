// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00032: Role-Based Access Control Implementation
//
// Widget tests for RolePickerPage
// Tests role display names and descriptions from AuthService with fallback

import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/role_picker_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

/// Role mappings with descriptions from backend
final _roleMappingsWithDescriptions = {
  'sponsorId': 'callisto',
  'mappings': [
    {
      'sponsorName': 'Study Coordinator / PI',
      'systemRole': 'Investigator',
      'description': 'Manage patients and questionnaires',
    },
    {
      'sponsorName': 'CRA',
      'systemRole': 'Auditor',
      'description': 'Review audit trails and compliance',
    },
  ],
};

/// Role mappings without descriptions (tests fallback)
final _roleMappingsNoDescriptions = {
  'sponsorId': 'callisto',
  'mappings': [
    {'sponsorName': 'Study Coordinator / PI', 'systemRole': 'Investigator'},
    {'sponsorName': 'CRA', 'systemRole': 'Auditor'},
  ],
};

/// Multi-role user response
final _multiRoleUser = {
  'id': 'user-multi',
  'email': 'multi@example.com',
  'name': 'Multi Role User',
  'roles': ['Investigator', 'Auditor'],
  'active_role': 'Investigator',
  'status': 'active',
  'sites': <dynamic>[],
};

/// Creates a mock client where AuthService.signIn fetches /me and /roles
MockClient _createMockClient({Map<String, dynamic>? roleMappings}) {
  final mappings = roleMappings ?? _roleMappingsWithDescriptions;
  return MockClient((request) async {
    final path = request.url.path;

    if (path == '/api/v1/portal/me') {
      return http.Response(
        jsonEncode(_multiRoleUser),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.startsWith('/api/v1/sponsor/roles')) {
      return http.Response(
        jsonEncode(mappings),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('Not found', 404);
  });
}

MockClient _createFailingRolesClient() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path == '/api/v1/portal/me') {
      return http.Response(
        jsonEncode(_multiRoleUser),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (path.startsWith('/api/v1/sponsor/roles')) {
      return http.Response('Internal Server Error', 500);
    }
    return http.Response('Not found', 404);
  });
}

Future<void> _pumpRolePickerPage(
  WidgetTester tester, {
  MockClient? mockClient,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final client = mockClient ?? _createMockClient();

  final mockUser = MockUser(
    uid: 'test-uid',
    email: 'multi@example.com',
    displayName: 'Multi Role User',
  );
  final mockFirebaseAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

  // AuthService now fetches role mappings during signIn → _fetchPortalUser
  final authService = AuthService(
    firebaseAuth: mockFirebaseAuth,
    httpClient: client,
  );
  await authService.signIn('multi@example.com', 'password');

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const RolePickerPage(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('RolePickerPage', () {
    testWidgets('shows welcome message with user name', (tester) async {
      await _pumpRolePickerPage(tester);
      expect(find.text('Welcome, Multi Role User'), findsOneWidget);
      expect(find.text('Select a role to continue'), findsOneWidget);
    });

    testWidgets('displays sponsor role names from API', (tester) async {
      await _pumpRolePickerPage(tester);
      // Should show sponsor names, not system names
      expect(find.text('Study Coordinator / PI'), findsOneWidget);
      expect(find.text('CRA'), findsOneWidget);
    });

    testWidgets('displays descriptions from API when present', (tester) async {
      await _pumpRolePickerPage(tester);
      expect(find.text('Manage patients and questionnaires'), findsOneWidget);
      expect(find.text('Review audit trails and compliance'), findsOneWidget);
    });

    testWidgets('falls back to default descriptions when API has none', (
      tester,
    ) async {
      final client = _createMockClient(
        roleMappings: _roleMappingsNoDescriptions,
      );
      await _pumpRolePickerPage(tester, mockClient: client);

      // Should fall back to _fallbackDescriptions constant
      expect(
        find.text('Patient management and questionnaire workflows'),
        findsOneWidget,
      );
      expect(find.text('Audit trails and compliance review'), findsOneWidget);
    });

    testWidgets('falls back to default descriptions when API fails', (
      tester,
    ) async {
      final client = _createFailingRolesClient();
      await _pumpRolePickerPage(tester, mockClient: client);

      // Should fall back to _fallbackDescriptions constant
      expect(
        find.text('Patient management and questionnaire workflows'),
        findsOneWidget,
      );
      expect(find.text('Audit trails and compliance review'), findsOneWidget);
    });

    testWidgets('shows role switch info text', (tester) async {
      await _pumpRolePickerPage(tester);
      expect(
        find.text(
          'You can switch roles at any time using the role dropdown in the top bar.',
        ),
        findsOneWidget,
      );
    });
  });
}
