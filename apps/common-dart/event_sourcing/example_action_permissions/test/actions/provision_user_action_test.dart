// Verifies: REQ-d00166 (Action interface), REQ-d00170-B (idempotency required),
//           REQ-d00172 (global-scoped permission for system admin)
import 'package:action_permissions_demo/server/actions/provision_user_action.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _adminCtx() => ActionContext(
  principal: const Principal.user(
    userId: 'admin-user',
    roles: <String>{'Admin'},
    activeRole: 'Admin',
  ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2026, 5, 8, 12),
);

void main() {
  group('ProvisionUserAction', () {
    late UserDirectory directory;
    late ProvisionUserAction action;

    setUp(() {
      directory = UserDirectory();
      action = ProvisionUserAction(directory: directory);
    });

    test(
      'REQ-d00166-A: declares global users.provision, idempotency required',
      () {
        expect(action.name, 'ProvisionUserAction');
        expect(
          action.permissions,
          contains(
            const Permission('users.provision', scope: ScopeClass.global),
          ),
        );
        expect(action.idempotency, Idempotency.required);
      },
    );

    test('REQ-d00166-C: parseInput accepts {userId, role, activeSite?}', () {
      final input = action.parseInput(<String, Object?>{
        'userId': 'new-user',
        'role': 'GreenTeam',
        'activeSite': 'green-workspace',
      });
      expect(input.userId, 'new-user');
      expect(input.role, 'GreenTeam');
      expect(input.activeSite, 'green-workspace');
    });

    test('REQ-d00166-C: parseInput accepts null/missing activeSite', () {
      final fromNull = action.parseInput(<String, Object?>{
        'userId': 'admin-2',
        'role': 'Admin',
        'activeSite': null,
      });
      expect(fromNull.activeSite, isNull);
      final fromMissing = action.parseInput(<String, Object?>{
        'userId': 'admin-3',
        'role': 'Admin',
      });
      expect(fromMissing.activeSite, isNull);
    });

    test(
      'REQ-d00166-C: parseInput throws FormatException on missing/wrong fields',
      () {
        expect(
          () => action.parseInput(<String, Object?>{'userId': 'x'}),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => action.parseInput(<String, Object?>{
            'userId': 42,
            'role': 'Admin',
          }),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'REQ-d00166-D: validate rejects empty userId or role with ArgumentError',
      () {
        expect(
          () => action.validate(
            const ProvisionUserInput(
              userId: '',
              role: 'Admin',
              activeSite: null,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => action.validate(
            const ProvisionUserInput(userId: 'x', role: '', activeSite: null),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('REQ-d00166-D: validate rejects userId already in directory', () {
      directory.upsert(userId: 'taken', role: 'GreenTeam', activeSite: null);
      expect(
        () => action.validate(
          const ProvisionUserInput(
            userId: 'taken',
            role: 'BlueTeam',
            activeSite: null,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('REQ-d00166-D: validate accepts a fresh userId', () {
      action.validate(
        const ProvisionUserInput(
          userId: 'fresh',
          role: 'GreenTeam',
          activeSite: 'green-workspace',
        ),
      );
    });

    test(
      'REQ-d00166-E: execute emits one user_provisioned event with the payload',
      () async {
        final result = await action.execute(
          const ProvisionUserInput(
            userId: 'fresh',
            role: 'GreenTeam',
            activeSite: 'green-workspace',
          ),
          _adminCtx(),
        );
        expect(result.events, hasLength(1));
        final draft = result.events.single;
        expect(draft.eventType, 'user_provisioned');
        expect(draft.aggregateType, 'user_directory');
        expect(draft.entryType, 'user_provisioned');
        expect(draft.aggregateId, 'fresh');
        expect(draft.data['userId'], 'fresh');
        expect(draft.data['role'], 'GreenTeam');
        expect(draft.data['activeSite'], 'green-workspace');
        expect(result.result.userId, 'fresh');
      },
    );
  });
}
