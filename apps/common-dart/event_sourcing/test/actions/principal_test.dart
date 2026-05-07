import 'package:event_sourcing/event_sourcing.dart'
    show UserInitiator, AnonymousInitiator;
import 'package:event_sourcing/src/actions/principal.dart';
import 'package:test/test.dart';

void main() {
  group('Principal', () {
    group('UserPrincipal', () {
      test('REQ-d00168: id returns userId', () {
        const p = Principal.user(
          userId: 'u-1',
          roles: {'Investigator'},
          activeRole: 'Investigator',
        );
        expect(p, isA<UserPrincipal>());
        expect(p.id, 'u-1');
      });

      test('REQ-d00168: toInitiator returns UserInitiator carrying userId', () {
        const p = Principal.user(userId: 'u-7', roles: {'X'}, activeRole: 'X');
        final init = p.toInitiator();
        expect(init, isA<UserInitiator>());
        expect((init as UserInitiator).userId, 'u-7');
      });

      test('activeSite is optional and defaults to null', () {
        const p = Principal.user(userId: 'u-1', roles: {'X'}, activeRole: 'X');
        expect((p as UserPrincipal).activeSite, isNull);
      });

      test('activeSite carries through when provided', () {
        const p = Principal.user(
          userId: 'u-1',
          roles: {'X'},
          activeRole: 'X',
          activeSite: 'site-A',
        );
        expect((p as UserPrincipal).activeSite, 'site-A');
      });

      test('multi-role users pick their activeRole', () {
        const p = Principal.user(
          userId: 'u-1',
          roles: {'Investigator', 'Analyst'},
          activeRole: 'Analyst',
        );
        expect((p as UserPrincipal).roles, hasLength(2));
        expect(p.activeRole, 'Analyst');
      });

      test('asserts non-empty userId', () {
        // Cannot use const here: Dart evaluates const asserts at compile time
        // and throws a compile-time error rather than a runtime AssertionError.
        // We use a non-const local variable to defer evaluation to runtime.
        final emptyId = ''; // ignore: prefer_const_declarations
        expect(
          () => Principal.user(
            userId: emptyId,
            roles: const {'X'},
            activeRole: 'X',
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('AnonymousPrincipal', () {
      test('REQ-d00168: id returns "anon:<ip>" when ip provided', () {
        const p = Principal.anonymous(ipAddress: '1.2.3.4');
        expect(p.id, 'anon:1.2.3.4');
      });

      test('REQ-d00168: id returns "anon:unknown" when ip absent', () {
        const p = Principal.anonymous();
        expect(p.id, 'anon:unknown');
      });

      test('REQ-d00168: toInitiator returns AnonymousInitiator', () {
        const p = Principal.anonymous(ipAddress: '5.6.7.8');
        final init = p.toInitiator();
        expect(init, isA<AnonymousInitiator>());
      });
    });
  });
}
