import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:portal_server_evs/src/session_store.dart';
import 'package:portal_server_evs/src/session_token.dart';
import 'package:portal_server_evs/src/session_token_validator.dart';
import 'package:reaction/reaction.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-portal-session-token/B
  // Verifies: DIARY-DEV-portal-session-lifecycle/A+C
  // Verifies: DIARY-DEV-portal-active-role-switch/A+C
  const key = 'k';
  late EventStore store;
  late StorageBackend backend;
  final t0 = DateTime.utc(2026, 6, 1, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('val.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
  });

  Future<void> assignRole(String userId, String role) => store.append(
        entryType: 'user_role_scope',
        aggregateType: 'user_role_scope',
        aggregateId: '$userId:$role',
        eventType: 'role_assigned',
        data: {'user_id': userId, 'role': role, 'scope': 'global'},
        initiator: const AutomationInitiator(service: 'test'),
      );

  Future<void> startSession(String sid, String userId, String role) =>
      store.append(
        entryType: 'session_started',
        aggregateType: 'session',
        aggregateId: sid,
        eventType: 'session_started',
        data: {
          'user_id': userId,
          'active_role': role,
          'started_at': t0.toIso8601String(),
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

  SessionTokenValidator validator(DateTime Function() now) =>
      SessionTokenValidator(
        signingKey: key,
        backend: backend,
        eventStore: store,
        sessionStore: SessionStore(),
        idleTimeout: const Duration(minutes: 10),
        now: now,
      );

  test('live session + held role -> Principal with session active role',
      () async {
    await assignRole('jane@site.org', 'StudyCoordinator');
    await assignRole('jane@site.org', 'Administrator');
    await startSession('sid-1', 'jane@site.org', 'Administrator');
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);

    final p = await validator(() => t0).authenticate(token) as UserPrincipal;
    expect(p.userId, 'jane@site.org');
    expect(p.activeRole, 'Administrator');
    expect(p.roles, containsAll(<String>{'StudyCoordinator', 'Administrator'}));
  });

  test('tampered token -> denied', () async {
    expect(() => validator(() => t0).authenticate('garbage.sig'),
        throwsA(isA<AuthenticationDenied>()));
  });

  test('terminated session -> denied', () async {
    await assignRole('jane@site.org', 'Administrator');
    await startSession('sid-1', 'jane@site.org', 'Administrator');
    await store.append(
      entryType: 'session_terminated',
      aggregateType: 'session',
      aggregateId: 'sid-1',
      eventType: 'session_terminated',
      data: {'reason': 'logout'},
      initiator: const AutomationInitiator(service: 'test'),
    );
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
    expect(() => validator(() => t0).authenticate(token),
        throwsA(isA<AuthenticationDenied>()));
  });

  test('idle-expired session -> denied + session row removed', () async {
    await assignRole('jane@site.org', 'Administrator');
    await startSession('sid-1', 'jane@site.org', 'Administrator');
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);

    var clock = t0;
    final v = validator(() => clock);
    await v.authenticate(token); // first call touches lastSeen at t0
    clock = t0.add(const Duration(minutes: 11)); // advance past idle window
    await expectLater(
        () => v.authenticate(token), throwsA(isA<AuthenticationDenied>()));

    final rows = await backend.findViewRows('sessions_index');
    expect(rows.where((r) => r['aggregateId'] == 'sid-1'), isEmpty,
        reason: 'idle terminate appends session_terminated -> row tombstoned');
  });

  test(
      'active role not in current roles falls back to highest-priority held role',
      () async {
    await assignRole('jane@site.org', 'StudyCoordinator');
    // session stored with Administrator, but the user no longer holds it
    await startSession('sid-1', 'jane@site.org', 'Administrator');
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
    final p = await validator(() => t0).authenticate(token) as UserPrincipal;
    expect(p.activeRole, 'StudyCoordinator'); // only role held
  });
}
