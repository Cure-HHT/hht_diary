import 'package:portal_server_evs/src/activation_code_store.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 6, 1, 12);
  ActivationCodeStore newStore() {
    var n = 0;
    return ActivationCodeStore(codeGen: () => 'CODE-${n++}');
  }

  test('issued code validates to its email, then consume makes it single-use',
      () {
    final s = newStore();
    final code =
        s.issue(email: 'a@x.org', expiresAt: t0.add(const Duration(days: 14)));
    expect(s.validate(code, now: t0)?.email, 'a@x.org');
    s.consume(code);
    expect(s.validate(code, now: t0), isNull);
  });

  test('expired code is rejected', () {
    final s = newStore();
    final code =
        s.issue(email: 'a@x.org', expiresAt: t0.add(const Duration(days: 14)));
    expect(s.validate(code, now: t0.add(const Duration(days: 15))), isNull);
  });

  test('issuing a new code invalidates the prior unused code for that email',
      () {
    final s = newStore();
    final first =
        s.issue(email: 'a@x.org', expiresAt: t0.add(const Duration(days: 14)));
    final second =
        s.issue(email: 'a@x.org', expiresAt: t0.add(const Duration(days: 14)));
    expect(s.validate(first, now: t0), isNull);
    expect(s.validate(second, now: t0)?.email, 'a@x.org');
  });

  test('unknown code is rejected', () {
    expect(newStore().validate('nope', now: t0), isNull);
  });
}
