import 'package:audited_actions/src/dispatch_result.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

void main() {
  group('DispatchResult', () {
    test('REQ-d00168-K: success carries result + emitted ids', () {
      const r = DispatchResult<int>.success(42, ['evt-1', 'evt-2']);
      expect(r, isA<DispatchSuccess<int>>());
      r as DispatchSuccess<int>;
      expect(r.result, 42);
      expect(r.emittedEventIds, hasLength(2));
    });

    test('REQ-d00168-B: unknownAction carries requested name', () {
      const r = DispatchResult<int>.unknownAction('foo');
      expect(r, isA<DispatchUnknownAction<int>>());
      r as DispatchUnknownAction<int>;
      expect(r.requestedName, 'foo');
    });

    test('REQ-d00168-D: parseDenied carries the error', () {
      final err = ArgumentError('bad input');
      final r = DispatchResult<int>.parseDenied(err);
      expect(r, isA<DispatchParseDenied<int>>());
      r as DispatchParseDenied<int>;
      expect(r.error, err);
    });

    test('REQ-d00168-F: validationDenied carries the error', () {
      final err = StateError('invalid');
      final r = DispatchResult<int>.validationDenied(err);
      expect(r, isA<DispatchValidationDenied<int>>());
    });

    test('REQ-d00168-G: authorizationDenied carries the failed permission', () {
      const p = Permission('user.invite');
      const r = DispatchResult<int>.authorizationDenied(p);
      expect(r, isA<DispatchAuthorizationDenied<int>>());
      r as DispatchAuthorizationDenied<int>;
      expect(r.permission, p);
    });

    test('REQ-d00168-H: executionFailed carries the error', () {
      final err = StateError('boom');
      final r = DispatchResult<int>.executionFailed(err);
      expect(r, isA<DispatchExecutionFailed<int>>());
    });

    test('REQ-d00168-E: idempotencyHit carries cached payload', () {
      const r = DispatchResult<Map<String, dynamic>>.idempotencyHit(
        {'ok': true},
        ['evt-prior'],
      );
      expect(r, isA<DispatchIdempotencyHit<Map<String, dynamic>>>());
    });

    test('sealed: switch is exhaustive', () {
      const r = DispatchResult<int>.success(1, []);
      final desc = switch (r) {
        DispatchSuccess<int>() => 'success',
        DispatchUnknownAction<int>() => 'unknown',
        DispatchParseDenied<int>() => 'parse',
        DispatchValidationDenied<int>() => 'validation',
        DispatchAuthorizationDenied<int>() => 'authz',
        DispatchExecutionFailed<int>() => 'execfail',
        DispatchIdempotencyHit<int>() => 'hit',
      };
      expect(desc, 'success');
    });
  });
}
