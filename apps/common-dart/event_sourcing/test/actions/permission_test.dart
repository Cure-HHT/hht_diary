import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

void main() {
  group('Permission', () {
    test('equality based on name', () {
      const p1 = Permission('user.invite', scope: ScopeClass.global);
      const p2 = Permission('user.invite', scope: ScopeClass.global);
      const p3 = Permission('user.delete', scope: ScopeClass.global);
      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('toString includes the permission name', () {
      const p = Permission('patient.enroll', scope: ScopeClass.global);
      expect(p.toString(), contains('patient.enroll'));
    });

    test('toString includes the scope', () {
      const p = Permission('patient.enroll', scope: ScopeClass.site);
      expect(p.toString(), contains('site'));
    });

    test('rejects empty name', () {
      expect(
        () => Permission.checked('', scope: ScopeClass.global),
        throwsArgumentError,
      );
    });

    test('rejects whitespace-only name', () {
      expect(
        () => Permission.checked('   ', scope: ScopeClass.global),
        throwsArgumentError,
      );
    });

    test('can be used in a Set', () {
      final set = <Permission>{}
        ..add(const Permission('a.b', scope: ScopeClass.global))
        ..add(const Permission('c.d', scope: ScopeClass.global))
        ..add(const Permission('a.b', scope: ScopeClass.global));
      expect(set.length, 2);
    });

    test(
      'REQ-d00172-A: scope field is accessible and matches construction',
      () {
        const p = Permission('foo', scope: ScopeClass.site);
        expect(p.scope, ScopeClass.site);
      },
    );

    test(
      'same name with different scope is still equal (name-only equality)',
      () {
        const p1 = Permission('foo', scope: ScopeClass.global);
        const p2 = Permission('foo', scope: ScopeClass.site);
        // Equality is name-only; scope is code-defined and validated by
        // ActionRegistry — two Permission('foo') with different scopes indicate
        // a programming error, not a legitimate distinct permission.
        expect(p1, equals(p2));
      },
    );
  });
}
