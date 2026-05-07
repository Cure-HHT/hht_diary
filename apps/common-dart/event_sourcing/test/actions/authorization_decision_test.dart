import 'package:event_sourcing/src/actions/authorization_decision.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

void main() {
  group('AuthorizationDecision', () {
    test('REQ-d00169-A: Allow is a const singleton-style variant', () {
      const a1 = Allow();
      const a2 = Allow();
      expect(a1, isA<Allow>());
      expect(
        identical(a1, a2),
        isTrue,
        reason: 'const Allow should canonicalize',
      );
    });

    test('REQ-d00169-A: Deny carries permission + reason', () {
      const d = Deny(
        permission: Permission('user.invite', scope: ScopeClass.global),
        reason: DenyReason.notGranted,
      );
      expect(d.permission.name, 'user.invite');
      expect(d.reason, DenyReason.notGranted);
    });

    test('REQ-d00169-A: sealed switch is exhaustive across both variants', () {
      const AuthorizationDecision d = Allow();
      final desc = switch (d) {
        Allow() => 'allow',
        Deny() => 'deny',
      };
      expect(desc, 'allow');
    });

    test('REQ-d00169-A: DenyReason has three values', () {
      expect(DenyReason.values, hasLength(3));
      expect(DenyReason.values.toSet(), {
        DenyReason.notGranted,
        DenyReason.sessionPreconditionMissing,
        DenyReason.bootstrapFailure,
      });
    });
  });
}
