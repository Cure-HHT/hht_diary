// test/walkthroughs/walkthrough_01_onboarding_test.dart
//
// Verifies: REQ-d00177 (PermissionSnapshot delivery), REQ-d00176 (AuthorizationPolicy
// permissionsFor) — session-start endpoint shape.

import 'package:flutter_test/flutter_test.dart';

import 'test_support/demo_server_harness.dart';

void main() {
  late DemoServerHarness harness;

  setUpAll(() async {
    harness = await DemoServerHarness.start();
  });

  tearDownAll(() async {
    await harness.stop();
  });

  group('Walkthrough 1: Onboarding', () {
    test(
      'REQ-d00177: admin-user resolves to Admin with users.provision only',
      () async {
        final resp = await harness.sessionStart(userId: 'admin-user');
        expect(resp.principalRole, 'Admin');
        expect(resp.principalUserId, 'admin-user');
        expect(resp.principalActiveSite, isNull);
        expect(resp.snapshotPermissions, <String>['users.provision']);
      },
    );

    test(
      'REQ-d00177: green-user-1 resolves to GreenTeam in green-workspace with 4 grants',
      () async {
        final resp = await harness.sessionStart(userId: 'green-user-1');
        expect(resp.principalRole, 'GreenTeam');
        expect(resp.principalUserId, 'green-user-1');
        expect(resp.principalActiveSite, 'green-workspace');
        expect(resp.snapshotPermissions.toSet(), <String>{
          'help.ask',
          'notes.write.green',
          'buttons.press.green',
          'buttons.press.red',
        });
      },
    );

    test(
      'REQ-d00177: blue-user resolves to BlueTeam in blue-workspace with 4 grants',
      () async {
        final resp = await harness.sessionStart(userId: 'blue-user');
        expect(resp.principalRole, 'BlueTeam');
        expect(resp.principalUserId, 'blue-user');
        expect(resp.principalActiveSite, 'blue-workspace');
        expect(resp.snapshotPermissions.toSet(), <String>{
          'help.ask',
          'notes.write.blue',
          'buttons.press.blue',
          'buttons.press.red',
        });
      },
    );

    test(
      'REQ-d00177: unknown userId resolves to Anon with empty permissions',
      () async {
        final resp = await harness.sessionStart(userId: 'fake-user-12345');
        expect(resp.principalRole, 'Anon');
        expect(resp.principalUserId, isNull);
        expect(resp.snapshotPermissions, isEmpty);
      },
    );

    test(
      'REQ-d00177: no userId also resolves to Anon with empty permissions',
      () async {
        final resp = await harness.sessionStart();
        expect(resp.principalRole, 'Anon');
        expect(resp.principalUserId, isNull);
        expect(resp.snapshotPermissions, isEmpty);
      },
    );
  });
}
