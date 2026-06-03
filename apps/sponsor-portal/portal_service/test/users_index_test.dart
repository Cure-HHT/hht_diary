// Verifies: DIARY-DEV-user-account-projection/A+B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('users_index folds identity + explicit status; preserved across edits; '
      'tombstoned on delete', () async {
    final store = await _open('users-index-1');
    Future<void> ev(String type, Map<String, Object?> data) => store.append(
      entryType: type,
      aggregateType: 'portal_user',
      aggregateId: 'u@x.com',
      eventType: type,
      data: data,
      initiator: const AutomationInitiator(service: 't'),
    );

    await ev('user_created', {
      'email': 'u@x.com',
      'name': 'U',
      'status': 'pending',
    });
    var rows = await store.backend.findViewRows('users_index');
    expect(rows.single['status'], 'pending');
    expect(rows.single['name'], 'U');

    // non-status event: status preserved, new-name field merged (action uses key 'after')
    await ev('user_profile_changed', {'after': 'U2', 'changed_by': 'admin-1'});
    rows = await store.backend.findViewRows('users_index');
    expect(rows.single['status'], 'pending');
    expect(rows.single['after'], 'U2');

    // status transition
    await ev('user_deactivated', {'reason': 'x', 'status': 'revoked'});
    rows = await store.backend.findViewRows('users_index');
    expect(rows.single['status'], 'revoked');

    // delete tombstones the row
    await ev('user_deleted', {'deleted_by': 'admin-1'});
    rows = await store.backend.findViewRows('users_index');
    expect(rows, isEmpty);
  });
}
