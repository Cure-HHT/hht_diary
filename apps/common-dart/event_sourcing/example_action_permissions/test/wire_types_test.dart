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

  group('SessionStartRequest/Response', () {
    test('REQ-d00177: SessionStartRequest round-trip with userId', () {
      const req = SessionStartRequest(userId: 'green-user-1');
      final parsed = SessionStartRequest.fromJson(req.toJson());
      expect(parsed.userId, 'green-user-1');
    });

    test(
      'REQ-d00177: SessionStartRequest round-trip without userId (Anon)',
      () {
        const req = SessionStartRequest();
        final parsed = SessionStartRequest.fromJson(req.toJson());
        expect(parsed.userId, isNull);
      },
    );

    test(
      'REQ-d00177: SessionStartResponse round-trip with snapshot fields',
      () {
        const resp = SessionStartResponse(
          principalRole: 'GreenTeam',
          principalUserId: 'green-user-1',
          principalActiveSite: 'site-A',
          snapshotPermissions: <String>['notes.write.green', 'help.request'],
        );
        final parsed = SessionStartResponse.fromJson(resp.toJson());
        expect(parsed.principalRole, 'GreenTeam');
        expect(parsed.principalUserId, 'green-user-1');
        expect(parsed.principalActiveSite, 'site-A');
        expect(parsed.snapshotPermissions, hasLength(2));
      },
    );
  });

  group('InspectSnapshot', () {
    test('round-trips through JSON', () {
      final snap = InspectSnapshot(
        events: const <StoredEventSummary>[
          StoredEventSummary(
            eventId: 'evt-1',
            eventType: 'help_request',
            aggregateType: 'help_ticket',
            aggregateId: 'agg-1',
            actionInvocationId: 'inv-1',
            initiatorUserId: null,
            initiatorRole: 'Anon',
          ),
        ],
        matrixGrants: const <MatrixGrant>[
          MatrixGrant(role: 'Admin', permission: 'audit.read.all'),
        ],
        directory: const <UserDirectoryEntry>[
          UserDirectoryEntry(
            userId: 'admin-user',
            role: 'Admin',
            activeSite: null,
          ),
        ],
        idempotency: <IdempotencyEntrySummary>[
          IdempotencyEntrySummary(
            actionName: 'PressRedAlarmAction',
            principalUserId: 'admin-user',
            idempotencyKey: 'k-1',
            expiresAt: DateTime.utc(2026, 5, 8),
          ),
        ],
        lastDispatchTrace: const DispatchTrace(
          actionInvocationId: 'inv-1',
          actionName: 'RequestHelpAction',
          stages: <String>['lookup OK', 'parse OK', 'authorize OK'],
        ),
      );
      final parsed = InspectSnapshot.fromJson(snap.toJson());
      expect(parsed.events, hasLength(1));
      expect(parsed.matrixGrants, hasLength(1));
      expect(parsed.directory, hasLength(1));
      expect(parsed.idempotency, hasLength(1));
      expect(parsed.lastDispatchTrace?.actionName, 'RequestHelpAction');
    });

    test('handles null lastDispatchTrace', () {
      const snap = InspectSnapshot(
        events: <StoredEventSummary>[],
        matrixGrants: <MatrixGrant>[],
        directory: <UserDirectoryEntry>[],
        idempotency: <IdempotencyEntrySummary>[],
        lastDispatchTrace: null,
      );
      final parsed = InspectSnapshot.fromJson(snap.toJson());
      expect(parsed.lastDispatchTrace, isNull);
    });
  });
}
