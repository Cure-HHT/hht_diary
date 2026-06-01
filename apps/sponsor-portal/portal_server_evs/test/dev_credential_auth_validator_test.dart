// Verifies: DIARY-DEV-portal-reaction-server/B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:reaction/reaction.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<StorageBackend> _backendWithRoles(
    String userId, List<String> roles) async {
  final db = await newDatabaseFactoryMemory().openDatabase('dev-val.db');
  final backend = SembastBackend(database: db);
  // openPortalEventStore registers the user_role_scopes view so findViewRows
  // reflects appended role_assigned events.
  final store = await openPortalEventStore(backend: backend);
  for (final role in roles) {
    await store.append(
      entryType: 'user_role_scope',
      aggregateType: 'user_role_scope',
      aggregateId: '$userId:$role',
      eventType: 'role_assigned',
      data: <String, Object?>{
        'user_id': userId,
        'role': role,
        'scope': 'global',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );
  }
  return backend;
}

void main() {
  const userId = 'u@x.org';

  test('bare userId resolves full role set; activeRole = highest priority',
      () async {
    final backend =
        await _backendWithRoles(userId, ['Administrator', 'StudyCoordinator']);
    final v = DevCredentialAuthValidator(backend: backend);
    final p = await v.authenticate(userId);
    expect(p, isA<UserPrincipal>());
    final up = p as UserPrincipal;
    expect(up.userId, userId);
    expect(up.roles, containsAll(['Administrator', 'StudyCoordinator']));
    // Administrator is highest-priority per kPortalRolePriority.
    expect(up.activeRole, 'Administrator');
  });

  test('userId|role honors the claim when held', () async {
    final backend =
        await _backendWithRoles(userId, ['Administrator', 'StudyCoordinator']);
    final v = DevCredentialAuthValidator(backend: backend);
    final p = await v.authenticate('$userId|StudyCoordinator');
    final up = p as UserPrincipal;
    expect(up.activeRole, 'StudyCoordinator');
    expect(up.roles, containsAll(['Administrator', 'StudyCoordinator']));
  });

  test('userId|unheldrole falls back to highest-priority', () async {
    final backend =
        await _backendWithRoles(userId, ['Administrator', 'StudyCoordinator']);
    final v = DevCredentialAuthValidator(backend: backend);
    final p = await v.authenticate('$userId|CRA'); // CRA not held
    final up = p as UserPrincipal;
    expect(up.activeRole, 'Administrator');
  });

  test('unknown userId throws AuthenticationDenied', () async {
    final backend = await _backendWithRoles(userId, ['Administrator']);
    final v = DevCredentialAuthValidator(backend: backend);
    expect(
      () => v.authenticate('nobody@x.org'),
      throwsA(isA<AuthenticationDenied>()),
    );
  });

  test('empty credential throws AuthenticationDenied', () async {
    final backend = await _backendWithRoles(userId, ['Administrator']);
    final v = DevCredentialAuthValidator(backend: backend);
    expect(
      () => v.authenticate(''),
      throwsA(isA<AuthenticationDenied>()),
    );
  });
}
