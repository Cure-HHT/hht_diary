import 'package:event_sourcing/src/actions/permission.dart';
import 'package:test/test.dart';

void main() {
  group('Permission', () {
    test('equality based on name', () {
      const p1 = Permission('user.invite');
      const p2 = Permission('user.invite');
      const p3 = Permission('user.delete');
      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('toString includes the permission name', () {
      const p = Permission('patient.enroll');
      expect(p.toString(), contains('patient.enroll'));
    });

    test('rejects empty name', () {
      expect(() => Permission.checked(''), throwsArgumentError);
    });

    test('rejects whitespace-only name', () {
      expect(() => Permission.checked('   '), throwsArgumentError);
    });

    test('can be used in a Set', () {
      final set = <Permission>{}
        ..add(const Permission('a.b'))
        ..add(const Permission('c.d'))
        ..add(const Permission('a.b'));
      expect(set.length, 2);
    });
  });
}
