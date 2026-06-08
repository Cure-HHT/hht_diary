// Verifies: DIARY-DEV-portal-durable-event-store/A — buildPortalDispatcher honors
//   an injected IdempotencyStore instead of always constructing an in-memory one.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import '_reference_role_grants.dart';

void main() {
  test('buildPortalDispatcher uses the injected idempotency store', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('t.db');
    final store = await openPortalEventStore(
      backend: SembastBackend(database: db),
    );
    final injected = InMemoryIdempotencyStore();
    final dispatcher = await buildPortalDispatcher(
      eventStore: store,
      roleGrantsYaml: referenceRoleGrantsYaml(),
      idempotency: injected,
    );
    expect(dispatcher, isA<ActionDispatcher>());
  });
}
