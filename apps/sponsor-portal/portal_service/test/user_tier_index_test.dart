// Verifies: DIARY-DEV-operator-tier-authz/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('folds user_tier_changed into user_tier_index; '
      're-issue overwrites the tier', () async {
    final store = await _open('uti-1');
    await store.append(
      entryType: 'user_tier_changed',
      aggregateType: 'portal_user',
      aggregateId: 'u1',
      eventType: 'user_tier_changed',
      data: <String, Object?>{'user_id': 'u1', 'tier': 'operator'},
      initiator: const AutomationInitiator(service: 'user_tier_reactor'),
    );

    var rows = await store.backend.findViewRows('user_tier_index');
    expect(rows, hasLength(1));
    expect(rows.single['user_id'], 'u1');
    expect(rows.single['tier'], 'operator');

    // A second event upserts the row (tier downgrade: operator -> staff).
    await store.append(
      entryType: 'user_tier_changed',
      aggregateType: 'portal_user',
      aggregateId: 'u1',
      eventType: 'user_tier_changed',
      data: <String, Object?>{'user_id': 'u1', 'tier': 'staff'},
      initiator: const AutomationInitiator(service: 'user_tier_reactor'),
    );
    rows = await store.backend.findViewRows('user_tier_index');
    expect(rows, hasLength(1));
    expect(rows.single['tier'], 'staff');
  });
}
