// Verifies: bootstrap admin seed — PORTAL_BOOTSTRAP_ADMIN_EMAIL / bootstrapAdminEmail
//   seeds an Administrator role assignment for that user on a fresh store.
//   bootstrapRoleAssignments appends entryType 'user_role_scope' (eventType
//   'role_assigned') with the user id under data['user_id'].
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('seeds an Administrator assignment for the configured bootstrap admin',
      () async {
    final db = await newDatabaseFactoryMemory().openDatabase('a.db');
    final backend = SembastBackend(database: db);
    final boot = await bootstrapPortalServer(
      backend: backend,
      raveClient: DevSeedRaveClient(),
      bootstrapAdminEmail: 'admin@example.org',
    );
    addTearDown(boot.dispose);

    var found = false;
    await for (final e in backend.readEventsReverse()) {
      if (e.entryType == 'user_role_scope' &&
          e.data['user_id'] == 'admin@example.org') {
        found = true;
        break;
      }
    }
    expect(found, isTrue);
  });
}
