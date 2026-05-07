// test/wire_types_test.dart
// Verifies: REQ-d00168 (dispatcher pipeline wire-shape stability),
//           REQ-d00170 (idempotency hit on the wire),
//           REQ-d00171 (denial variants expose sanitized fields only).
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DispatchRequest', () {
    test('REQ-d00168: round-trips through JSON', () {
      const req = DispatchRequest(
        actionName: 'EditGreenNoteAction',
        rawInput: <String, Object?>{'title': 'hi', 'body': 'there'},
        idempotencyKey: 'abc-123',
        userId: 'green-user-1',
      );
      final json = req.toJson();
      final parsed = DispatchRequest.fromJson(json);
      expect(parsed, equals(req));
    });

    test('REQ-d00168: omits null idempotencyKey and userId', () {
      const req = DispatchRequest(
        actionName: 'RequestHelpAction',
        rawInput: <String, Object?>{},
      );
      final json = req.toJson();
      expect(json.containsKey('idempotencyKey'), isFalse);
      expect(json.containsKey('userId'), isFalse);
    });
  });

  group('DispatchResponse', () {
    test('REQ-d00168: success variant round-trips', () {
      const resp = DispatchResponseSuccess(
        actionInvocationId: 'inv-1',
        emittedEventIds: <String>['evt-1', 'evt-2'],
        result: <String, Object?>{'ok': true},
      );
      final json = resp.toJson();
      final parsed = DispatchResponse.fromJson(json);
      expect(parsed, isA<DispatchResponseSuccess>());
      expect((parsed as DispatchResponseSuccess).actionInvocationId, 'inv-1');
    });

    test(
      'REQ-d00171: denied variant carries denialKind and sanitized error',
      () {
        const resp = DispatchResponseDenied(
          denialKind: 'authorization_denied',
          actionInvocationId: 'inv-2',
          errorClass: 'AuthorizationError',
          errorMessageSanitized: 'permission notes.write.blue not granted',
          permissionDenied: 'notes.write.blue',
        );
        final json = resp.toJson();
        final parsed = DispatchResponse.fromJson(json);
        expect(parsed, isA<DispatchResponseDenied>());
        expect(
          (parsed as DispatchResponseDenied).denialKind,
          'authorization_denied',
        );
      },
    );

    test('REQ-d00170: idempotencyHit variant carries prior result', () {
      const resp = DispatchResponseIdempotencyHit(
        actionInvocationId: 'inv-3',
        priorEventIds: <String>['evt-prev'],
        priorResult: <String, Object?>{'ok': true},
      );
      final json = resp.toJson();
      final parsed = DispatchResponse.fromJson(json);
      expect(parsed, isA<DispatchResponseIdempotencyHit>());
    });
  });
}
