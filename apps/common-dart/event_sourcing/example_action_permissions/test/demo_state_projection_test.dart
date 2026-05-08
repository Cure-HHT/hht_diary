// test/demo_state_projection_test.dart
// Verifies: REQ-d00168 (inspector projection), REQ-d00175 (matrix populated by seed)
import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/demo_state_projection.dart';
import 'package:flutter_test/flutter_test.dart';

const String _validPermissionsYaml = '''
roles:
  - Admin
  - GreenTeam
  - BlueTeam
grants:
  Admin:
    - users.provision
  GreenTeam:
    - help.ask
    - notes.write.green
    - buttons.press.green
    - buttons.press.red
  BlueTeam:
    - help.ask
    - notes.write.blue
    - buttons.press.blue
    - buttons.press.red
''';

const String _validUsersYaml = '''
users:
  - userId: admin-user
    role: Admin
    activeSite: null
  - userId: green-user-1
    role: GreenTeam
    activeSite: green-workspace
  - userId: blue-user
    role: BlueTeam
    activeSite: blue-workspace
''';

void main() {
  group('PollingDemoStateProjection', () {
    test(
      'REQ-d00168: snapshot includes seeded matrix, directory, no idempotency yet',
      () async {
        final components = await bootstrapDemoServer(
          dbPath: 'unused',
          ephemeral: true,
          permissionsYaml: _validPermissionsYaml,
          usersYaml: _validUsersYaml,
          installIdentifier: '00000000-0000-4000-8000-000000000010',
        );
        final projection = PollingDemoStateProjection(components: components);
        final snap = await projection.snapshot();

        // Matrix has 9 grants (1 Admin + 4 Green + 4 Blue).
        expect(snap.matrixGrants, hasLength(9));
        expect(
          snap.matrixGrants.map((g) => '${g.role}:${g.permission}').toSet(),
          contains('GreenTeam:help.ask'),
        );

        // Directory has the 3 seeded users.
        expect(snap.directory.map((d) => d.userId).toSet(), <String>{
          'admin-user',
          'green-user-1',
          'blue-user',
        });

        // Idempotency cache empty until a dispatch hits it.
        expect(snap.idempotency, isEmpty);

        // No dispatch trace yet.
        expect(snap.lastDispatchTrace, isNull);

        // Seed events recorded: 9 permission_granted + 3 user_provisioned +
        // 1 entry_type_registry_initialized (system) = 13. Allow a small
        // range to absorb future system events.
        expect(snap.events.length, greaterThanOrEqualTo(13));
      },
    );
  });
}
