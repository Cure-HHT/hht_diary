import 'package:event_sourcing/src/actions/denial_events.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

void main() {
  group('denial event factories', () {
    test('REQ-d00171-A: unknownAction draft has correct shape', () {
      final draft = denialUnknownAction(
        invocationId: 'inv-1',
        requestedName: 'foo',
        actionInvocationMetadata: <String, dynamic>{'request_id': 'r-1'},
      );
      expect(draft.aggregateType, 'action_attempt');
      expect(draft.aggregateId, 'inv-1');
      expect(draft.entryType, 'action_denial');
      expect(draft.eventType, 'unknown_action');
      expect(draft.data['requested_name'], 'foo');
      expect(draft.metadata?['request_id'], 'r-1');
    });

    test('REQ-d00171-A+B: parseDenied includes sanitized error message', () {
      final draft = denialParseDenied(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: ArgumentError(
          'email required at /home/user/secret/file.dart:42',
        ),
      );
      expect(draft.eventType, 'parse_denied');
      expect(draft.data['error_class'], 'ArgumentError');
      // REQ-d00171-C: file paths sanitized out.
      expect(
        draft.data['error_message_sanitized'],
        isNot(contains('/home/user/secret')),
      );
    });

    test('REQ-d00171-A+B: validationDenied carries error class', () {
      final draft = denialValidationDenied(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: StateError('email malformed'),
      );
      expect(draft.eventType, 'validation_denied');
      expect(draft.data['error_class'], 'StateError');
      expect(draft.data['action_name'], 'invite_user');
    });

    test('REQ-d00171-A+B: validationDenied carries optional fieldPath', () {
      final draft = denialValidationDenied(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: StateError('bad'),
        fieldPath: 'email',
      );
      expect(draft.data['field_path'], 'email');
    });

    test(
      'REQ-d00171-A+B: authorizationDenied includes permission and active role',
      () {
        final draft = denialAuthorizationDenied(
          invocationId: 'inv-1',
          actionName: 'user.delete',
          permission: const Permission('user.delete', scope: ScopeClass.global),
          principalActiveRole: 'Investigator',
        );
        expect(draft.eventType, 'authorization_denied');
        expect(draft.data['permission_denied'], 'user.delete');
        expect(draft.data['principal_active_role'], 'Investigator');
      },
    );

    test(
      'REQ-d00171-A+B: authorizationDenied without active role omits the field',
      () {
        final draft = denialAuthorizationDenied(
          invocationId: 'inv-1',
          actionName: 'user.delete',
          permission: const Permission('user.delete', scope: ScopeClass.global),
        );
        expect(draft.data.containsKey('principal_active_role'), isFalse);
      },
    );

    test('REQ-d00171-A+B: executionFailed carries sanitized error', () {
      final draft = denialExecutionFailed(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: StateError('boom'),
      );
      expect(draft.eventType, 'execution_failed');
      expect(draft.data['error_class'], 'StateError');
    });

    test('REQ-d00171-C: sanitization strips stack-trace markers', () {
      final draft = denialExecutionFailed(
        invocationId: 'inv-1',
        actionName: 'a',
        error: StateError(
          'boom\n#0 main (file:///home/me/foo.dart:10:5)\n#1 ...',
        ),
      );
      final msg = draft.data['error_message_sanitized'] as String;
      expect(msg, isNot(contains('#0 main')));
      expect(msg, isNot(contains('file:///')));
    });

    test('REQ-d00171-C: sanitization strips Windows paths', () {
      final draft = denialExecutionFailed(
        invocationId: 'inv-1',
        actionName: 'a',
        error: StateError(r'failed at C:\Users\me\code\foo.dart:99'),
      );
      final msg = draft.data['error_message_sanitized'] as String;
      expect(msg, isNot(contains(r'C:\Users')));
    });

    test('REQ-d00171: every denial type uses aggregateType=action_attempt', () {
      final all = <String>{
        denialUnknownAction(
          invocationId: 'i',
          requestedName: 'x',
        ).aggregateType,
        denialParseDenied(
          invocationId: 'i',
          actionName: 'a',
          error: 'e',
        ).aggregateType,
        denialValidationDenied(
          invocationId: 'i',
          actionName: 'a',
          error: 'e',
        ).aggregateType,
        denialAuthorizationDenied(
          invocationId: 'i',
          actionName: 'a',
          permission: const Permission('p', scope: ScopeClass.global),
        ).aggregateType,
        denialExecutionFailed(
          invocationId: 'i',
          actionName: 'a',
          error: 'e',
        ).aggregateType,
      };
      expect(all, {'action_attempt'});
    });
  });
}
