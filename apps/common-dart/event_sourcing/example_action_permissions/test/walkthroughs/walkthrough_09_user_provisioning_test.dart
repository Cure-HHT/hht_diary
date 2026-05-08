// test/walkthroughs/walkthrough_09_user_provisioning_test.dart
//
// Verifies: REQ-d00174-C — UserDirectoryMaterializer (via the adapter)
//           projects user_provisioned events into the in-memory directory
//           inside the EventStore transaction;
//           REQ-d00177 — the new user's snapshot reflects the seeded role.

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'test_support/demo_server_harness.dart';

void main() {
  late DemoServerHarness harness;

  setUp(() async {
    harness = await DemoServerHarness.start();
  });

  tearDown(() async {
    await harness.stop();
  });

  group('Walkthrough 9: User provisioning end-to-end', () {
    test(
      'admin provisions green-user-3 -> directory updated -> new user can edit green notes',
      () async {
        // 1. green-user-3 is not in the directory yet.
        var snap = await harness.inspect();
        expect(
          snap.directory.where((d) => d.userId == 'green-user-3'),
          isEmpty,
        );

        // 2. Admin provisions green-user-3.
        final provisionResp = await harness.dispatch(
          actionName: 'ProvisionUserAction',
          rawInput: <String, Object?>{
            'userId': 'green-user-3',
            'role': 'GreenTeam',
            'activeSite': 'green-workspace',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'admin-user',
        );
        expect(provisionResp, isA<DispatchResponseSuccess>());

        // 3. Directory now reflects the provisioned user.
        snap = await harness.inspect();
        final newEntry = snap.directory.singleWhere(
          (d) => d.userId == 'green-user-3',
        );
        expect(newEntry.role, 'GreenTeam');
        expect(newEntry.activeSite, 'green-workspace');

        // 4. session/start for green-user-3 returns GreenTeam principal +
        //    snapshot including notes.write.green.
        final session = await harness.sessionStart(userId: 'green-user-3');
        expect(session.principalRole, 'GreenTeam');
        expect(session.principalUserId, 'green-user-3');
        expect(session.principalActiveSite, 'green-workspace');
        expect(session.snapshotPermissions, contains('notes.write.green'));

        // 5. green-user-3 can edit a green note.
        final editResp = await harness.dispatch(
          actionName: 'EditGreenNoteAction',
          rawInput: <String, Object?>{
            'noteId': 'note-from-g3',
            'title': 't',
            'body': 'b',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'green-user-3',
        );
        expect(editResp, isA<DispatchResponseSuccess>());

        // The note event carries g3's userId as initiator.
        snap = await harness.inspect();
        final note = snap.events.singleWhere(
          (e) => e.eventType == 'demo_note' && e.aggregateId == 'note-from-g3',
        );
        expect(note.initiatorUserId, 'green-user-3');
        expect(note.initiatorRole, 'GreenTeam');
      },
    );

    test('non-admin trying ProvisionUser -> authorization_denied', () async {
      final resp = await harness.dispatch(
        actionName: 'ProvisionUserAction',
        rawInput: <String, Object?>{
          'userId': 'newbie',
          'role': 'GreenTeam',
          'activeSite': 'green-workspace',
        },
        idempotencyKey: const Uuid().v4(),
        userId: 'green-user-1', // not Admin
      );
      expect(resp, isA<DispatchResponseDenied>());
      final denied = resp as DispatchResponseDenied;
      expect(denied.denialKind, 'authorization_denied');
      expect(denied.permissionDenied, 'users.provision');
    });

    test(
      'admin provisioning a duplicate userId -> validation_denied',
      () async {
        // green-user-1 is already in the seeded directory. Trying to
        // re-provision should fail validation (duplicate userId).
        final resp = await harness.dispatch(
          actionName: 'ProvisionUserAction',
          rawInput: <String, Object?>{
            'userId': 'green-user-1',
            'role': 'GreenTeam',
            'activeSite': 'green-workspace',
          },
          idempotencyKey: const Uuid().v4(),
          userId: 'admin-user',
        );
        expect(resp, isA<DispatchResponseDenied>());
        final denied = resp as DispatchResponseDenied;
        expect(denied.denialKind, 'validation_denied');
      },
    );
  });
}
