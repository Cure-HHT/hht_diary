import 'package:event_sourcing/src/actions/authorization_decision.dart';
import 'package:event_sourcing/src/actions/deny_all_authorization_policy.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/principal.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

// DenyAllAuthorizationPolicy is convenience scaffolding without a
// canonical REQ — these tests verify its contract as the deny-all
// fallback used by tests and early bootstrap.
void main() {
  group('DenyAllAuthorizationPolicy', () {
    test('returns Deny(notGranted) for an authenticated user', () async {
      const policy = DenyAllAuthorizationPolicy.forTests();
      const p = Principal.user(
        userId: 'u-1',
        roles: {'Admin'},
        activeRole: 'Admin',
      );
      final result = await policy.isPermitted(
        p,
        const Permission('any.thing', scope: ScopeClass.global),
      );
      expect(result, isA<Deny>());
      expect((result as Deny).reason, DenyReason.notGranted);
      expect(result.permission.name, 'any.thing');
    });

    test('returns Deny(notGranted) for anonymous', () async {
      const policy = DenyAllAuthorizationPolicy.forTests();
      const p = Principal.anonymous();
      final result = await policy.isPermitted(
        p,
        const Permission('any.thing', scope: ScopeClass.global),
      );
      expect(result, isA<Deny>());
      expect((result as Deny).reason, DenyReason.notGranted);
    });

    test('permissionsFor returns empty set', () async {
      const policy = DenyAllAuthorizationPolicy.forTests();
      const p = Principal.user(
        userId: 'u-1',
        roles: {'Admin'},
        activeRole: 'Admin',
      );
      expect(await policy.permissionsFor(p), isEmpty);
    });
  });
}
