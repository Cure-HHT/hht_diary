// Verifies: DIARY-DEV-portal-session-token/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;

  setUp(() async {
    final db = await databaseFactoryMemory.openDatabase('sess.db');
    store = await openPortalEventStore(backend: SembastBackend(database: db));
  });

  Future<void> append(String eventType, Map<String, Object?> data) =>
      store.append(
        entryType: eventType,
        aggregateType: 'session',
        aggregateId: 'sid-1',
        eventType: eventType,
        data: data,
        initiator: const AutomationInitiator(service: 'test'),
      );

  test(
    'session_started -> live row with user_id; session_terminated -> row removed',
    () async {
      await append('session_started', {
        'user_id': 'jane@site.org',
        'started_at': '2026-06-01T12:00:00.000Z',
      });
      var rows = await store.backend.findViewRows('sessions_index');
      expect(rows, hasLength(1));
      expect(rows.single['user_id'], 'jane@site.org');

      await append('session_terminated', {'reason': 'logout'});
      rows = await store.backend.findViewRows('sessions_index');
      expect(
        rows,
        isEmpty,
        reason: 'terminated session is tombstoned -> no live row',
      );
    },
  );
}
