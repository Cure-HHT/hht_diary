import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:portal_server_evs/src/session_cascade_reactor.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-portal-session-lifecycle/B
  late EventStore store;
  late StorageBackend backend;
  final t0 = DateTime.utc(2026, 6, 1, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('casc.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
  });

  Future<void> startSession(String sid, String userId) => store.append(
        entryType: 'session_started',
        aggregateType: 'session',
        aggregateId: sid,
        eventType: 'session_started',
        data: {
          'user_id': userId,
          'started_at': t0.toIso8601String(),
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

  test('user_deactivated terminates that user\'s live sessions only', () async {
    await startSession('sid-a', 'jane@site.org');
    await startSession('sid-b', 'jane@site.org');
    await startSession('sid-c', 'bob@site.org');

    final reactor = SessionCascadeReactor(eventStore: store, backend: backend);
    await reactor.handleSecurityEvent(StoredEvent.synthetic(
      eventId: 'e1',
      aggregateId: 'jane@site.org',
      aggregateType: 'portal_user',
      entryType: 'user_deactivated',
      eventType: 'user_deactivated',
      data: const <String, Object?>{},
      initiator: const AutomationInitiator(service: 'test'),
      clientTimestamp: t0,
      eventHash: 'fakehash',
    ));

    final sessions = await backend.findViewRows('sessions_index');
    final sids = sessions.map((r) => r['aggregateId']).toSet();
    expect(sids, contains('sid-c')); // bob untouched
    expect(sids, isNot(contains('sid-a'))); // jane terminated
    expect(sids, isNot(contains('sid-b')));
  });

  test('role_unassigned resolves the affected user from event data', () async {
    await startSession('sid-a', 'jane@site.org');
    final reactor = SessionCascadeReactor(eventStore: store, backend: backend);
    await reactor.handleSecurityEvent(StoredEvent.synthetic(
      eventId: 'e2',
      aggregateId: 'jane@site.org:Administrator',
      aggregateType: 'user_role_scope',
      entryType: 'user_role_scope',
      eventType: 'role_unassigned',
      data: const <String, Object?>{
        'user_id': 'jane@site.org',
        'role': 'Administrator'
      },
      initiator: const AutomationInitiator(service: 'test'),
      clientTimestamp: t0,
      eventHash: 'fakehash',
    ));
    final sessions = await backend.findViewRows('sessions_index');
    expect(sessions.map((r) => r['aggregateId']), isNot(contains('sid-a')));
  });
}
