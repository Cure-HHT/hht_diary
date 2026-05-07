import 'package:event_sourcing/src/actions/authorization_decision.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

void main() {
  group('AuthorizationDecision', () {
    // Verifies: REQ-d00173-B
    test('REQ-d00173-B: Allow is a const singleton-style variant', () {
      const a1 = Allow();
      const a2 = Allow();
      expect(a1, isA<Allow>());
      expect(
        identical(a1, a2),
        isTrue,
        reason: 'const Allow should canonicalize',
      );
    });

    // Verifies: REQ-d00173-C
    test('REQ-d00173-C: Deny carries permission + reason', () {
      const d = Deny(
        permission: Permission('user.invite', scope: ScopeClass.global),
        reason: DenyReason.notGranted,
      );
      expect(d.permission.name, 'user.invite');
      expect(d.reason, DenyReason.notGranted);
    });

    // Verifies: REQ-d00173-B
    test('REQ-d00173-B: sealed switch is exhaustive across both variants', () {
      const AuthorizationDecision d = Allow();
      final desc = switch (d) {
        Allow() => 'allow',
        Deny() => 'deny',
      };
      expect(desc, 'allow');
    });

    // Verifies: REQ-d00173-D
    test('REQ-d00173-D: DenyReason has three values', () {
      expect(DenyReason.values, hasLength(3));
      expect(DenyReason.values.toSet(), {
        DenyReason.notGranted,
        DenyReason.sessionPreconditionMissing,
        DenyReason.bootstrapFailure,
      });
    });
  });
}
