import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/src/self_management_guard_policy.dart';
import 'package:test/test.dart';

/// Inner policy that allows everything, so the wrapper's self-deny is the only
/// thing that can produce a Deny.
class _AllowAllPolicy extends AuthorizationPolicy {
  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission permission,
    ScopeValue? scopeValue, {
    Transaction? txn,
  }) async => const Allow();

  @override
  Future<EffectiveAuthorization> effectivePermissionsFor(
    Principal principal, {
    Transaction? txn,
  }) async => EffectiveAuthorization.empty;
}

Principal _alice() => Principal.user(
  userId: 'alice',
  roles: const {'Administrator'},
  activeRole: 'Administrator',
);

void main() {
  final guard = SelfManagementGuardPolicy(_AllowAllPolicy());
  const userPerm = Permission('portal.user.deactivate', scopeClass: 'user');

  test('denies a user-scoped action targeting the actor itself', () async {
    final d = await guard.isPermitted(
      _alice(),
      userPerm,
      const BoundScope(class_: 'user', value: 'alice'),
    );
    expect(d, isA<Deny>());
  });

  test('allows the same action targeting a DIFFERENT user', () async {
    final d = await guard.isPermitted(
      _alice(),
      userPerm,
      const BoundScope(class_: 'user', value: 'bob'),
    );
    expect(d, isA<Allow>());
  });

  test(
    'does not touch non-user-scoped permissions (e.g. site, tier)',
    () async {
      // A site-scoped permission whose value happens to equal the actor id must
      // still delegate — the guard only governs the `user` scope class.
      final site = await guard.isPermitted(
        _alice(),
        const Permission('portal.participant.link', scopeClass: 'site'),
        const BoundScope(class_: 'site', value: 'alice'),
      );
      expect(site, isA<Allow>());
      final tier = await guard.isPermitted(
        _alice(),
        const Permission('portal.user.grant_role', scopeClass: 'tier'),
        const BoundScope(class_: 'tier', value: 'staff'),
      );
      expect(tier, isA<Allow>());
    },
  );

  test('delegates unscoped permissions unchanged', () async {
    final d = await guard.isPermitted(
      _alice(),
      const Permission('portal.user.create'),
      null,
    );
    expect(d, isA<Allow>());
  });
}
