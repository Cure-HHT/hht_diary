// Verifies: DIARY-DEV-local-participant-authorization/D
import 'package:clinical_diary/scope/local_participant_authorization_policy.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const perm = Permission('diary.record_entry');
  final participant = UserPrincipal(
    userId: 'P-1',
    roles: const {'participant'},
    activeRole: 'participant',
  );

  test('permits any permission for an authenticated participant', () async {
    final policy = LocalParticipantAuthorizationPolicy(
      grantedPermissions: {perm},
    );
    expect(await policy.isPermitted(participant, perm, null), isA<Allow>());
  });

  test('denies an anonymous principal', () async {
    final policy = LocalParticipantAuthorizationPolicy(
      grantedPermissions: {perm},
    );
    final d = await policy.isPermitted(const AnonymousPrincipal(), perm, null);
    expect(d, isA<Deny>());
  });

  test(
    'effectivePermissionsFor returns the granted set for a participant',
    () async {
      final policy = LocalParticipantAuthorizationPolicy(
        grantedPermissions: {perm},
      );
      final eff = await policy.effectivePermissionsFor(participant);
      expect(eff.rolePermissions, {perm});
      expect(eff.activeRole, 'participant');
    },
  );

  test('effectivePermissionsFor is empty for anonymous', () async {
    final policy = LocalParticipantAuthorizationPolicy(
      grantedPermissions: {perm},
    );
    final eff = await policy.effectivePermissionsFor(
      const AnonymousPrincipal(),
    );
    expect(eff, EffectiveAuthorization.empty);
  });
}
