// test/permissions/table_backed_authorization_policy_test.dart
// Verifies: REQ-d00176-A (isPermitted with scope-precondition first),
//           REQ-d00176-B (permissionsFor filters by precondition).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TableBackedAuthorizationPolicy', () {
    const reader = InMemoryRoleMatrixReader(<String, Map<String, Permission>>{
      'admin': <String, Permission>{
        'user.invite': Permission('user.invite', scope: ScopeClass.global),
        'site.manage': Permission('site.manage', scope: ScopeClass.site),
        'profile.read': Permission('profile.read', scope: ScopeClass.self),
      },
    });
    const policy = TableBackedAuthorizationPolicy(reader);

    test('REQ-d00176-A: Allow when role holds global permission', () async {
      const p = Principal.user(
        userId: 'u1',
        roles: {'admin'},
        activeRole: 'admin',
      );
      final d = await policy.isPermitted(
        p,
        const Permission('user.invite', scope: ScopeClass.global),
      );
      expect(d, isA<Allow>());
    });

    test(
      'REQ-d00176-A: Deny notGranted when role does not hold permission',
      () async {
        const p = Principal.user(
          userId: 'u1',
          roles: {'patient'},
          activeRole: 'patient',
        );
        final d = await policy.isPermitted(
          p,
          const Permission('user.invite', scope: ScopeClass.global),
        );
        expect(d, isA<Deny>());
        expect((d as Deny).reason, DenyReason.notGranted);
      },
    );

    test(
      'REQ-d00176-A: Deny sessionPreconditionMissing for site-scoped without activeSite',
      () async {
        const p = Principal.user(
          userId: 'u1',
          roles: {'admin'},
          activeRole: 'admin',
          // activeSite: null (default)
        );
        final d = await policy.isPermitted(
          p,
          const Permission('site.manage', scope: ScopeClass.site),
        );
        expect(d, isA<Deny>());
        expect((d as Deny).reason, DenyReason.sessionPreconditionMissing);
      },
    );

    test(
      'REQ-d00176-A: Deny sessionPreconditionMissing for self-scoped when anonymous',
      () async {
        const p = Principal.anonymous();
        final d = await policy.isPermitted(
          p,
          const Permission('profile.read', scope: ScopeClass.self),
        );
        expect(d, isA<Deny>());
        expect((d as Deny).reason, DenyReason.sessionPreconditionMissing);
      },
    );

    test(
      'REQ-d00176-A: Deny sessionPreconditionMissing for site-scoped when anonymous (precondition before matrix lookup)',
      () async {
        const p = Principal.anonymous();
        final d = await policy.isPermitted(
          p,
          const Permission('site.manage', scope: ScopeClass.site),
        );
        expect(d, isA<Deny>());
        expect((d as Deny).reason, DenyReason.sessionPreconditionMissing);
      },
    );

    test(
      'REQ-d00176-A: Deny notGranted when anonymous attempts global-scoped permission (no role)',
      () async {
        const p = Principal.anonymous();
        final d = await policy.isPermitted(
          p,
          const Permission('user.invite', scope: ScopeClass.global),
        );
        expect(d, isA<Deny>());
        expect((d as Deny).reason, DenyReason.notGranted);
      },
    );

    test(
      'REQ-d00176-A: Allow self-scoped permission for any user (userId always present)',
      () async {
        const p = Principal.user(
          userId: 'u1',
          roles: {'admin'},
          activeRole: 'admin',
        );
        final d = await policy.isPermitted(
          p,
          const Permission('profile.read', scope: ScopeClass.self),
        );
        expect(d, isA<Allow>());
      },
    );

    test(
      'REQ-d00176-B: permissionsFor filters out site-scoped perms when no activeSite',
      () async {
        const p = Principal.user(
          userId: 'u1',
          roles: {'admin'},
          activeRole: 'admin',
          // activeSite: null
        );
        final perms = await policy.permissionsFor(p);
        // Self-scope passes (userId present), site-scope fails (no activeSite),
        // global always passes.
        expect(perms.map((x) => x.name).toSet(), <String>{
          'user.invite',
          'profile.read',
        });
      },
    );

    test(
      'REQ-d00176-B: permissionsFor returns all when preconditions met',
      () async {
        const p = Principal.user(
          userId: 'u1',
          roles: {'admin'},
          activeRole: 'admin',
          activeSite: 's1',
        );
        final perms = await policy.permissionsFor(p);
        expect(perms.map((x) => x.name).toSet(), <String>{
          'user.invite',
          'site.manage',
          'profile.read',
        });
      },
    );

    test(
      'REQ-d00176-B: permissionsFor returns empty for anonymous principal',
      () async {
        const p = Principal.anonymous();
        expect(await policy.permissionsFor(p), isEmpty);
      },
    );
  });
}
