import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test(
    'buildPortalAuthorizationPolicy returns a ready policy (no seed errors)',
    () async {
      final db = await databaseFactoryMemory.openDatabase('authz-build');
      final eventStore = await openPortalEventStore(
        backend: SembastBackend(database: db),
      );
      final result = await buildPortalAuthorizationPolicy(
        eventStore: eventStore,
      );
      expect(result.isReady, isTrue, reason: 'seed errors: ${result.errors}');
    },
  );

  test('buildPortalDispatcher wires registry + policy + idempotency', () async {
    final db = await databaseFactoryMemory.openDatabase('dispatch-build');
    final eventStore = await openPortalEventStore(
      backend: SembastBackend(database: db),
    );
    final dispatcher = await buildPortalDispatcher(eventStore: eventStore);
    expect(dispatcher, isA<ActionDispatcher>());
  });
}
