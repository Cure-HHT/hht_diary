// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170-B (Idempotency Contract) — Idempotency.required.
//   REQ-d00172 — global-scoped permission (system-admin).
//
// Admin-only. Validates uniqueness against the current in-memory directory
// view. The emitted user_provisioned event is projected back into the
// UserDirectory by the UserDirectoryMaterializer (run inside the
// EventStore transaction).

import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

@immutable
class ProvisionUserInput {
  const ProvisionUserInput({
    required this.userId,
    required this.role,
    required this.activeSite,
  });

  final String userId;
  final String role;
  final String? activeSite;
}

@immutable
class ProvisionUserResult {
  const ProvisionUserResult({required this.userId});

  final String userId;

  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

class ProvisionUserAction
    extends Action<ProvisionUserInput, ProvisionUserResult> {
  ProvisionUserAction({required this.directory});

  final UserDirectory directory;

  @override
  String get name => 'ProvisionUserAction';

  @override
  String get description =>
      'Admin provisions a new user; emits one user_provisioned event '
      'that the directory materializer projects into the in-memory map.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('users.provision', scope: ScopeClass.global),
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ProvisionUserInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    final role = raw['role'];
    final activeSite = raw['activeSite'];
    if (userId is! String || role is! String) {
      throw const FormatException(
        'ProvisionUserAction expects {userId, role}: String, '
        'optional {activeSite}: String?',
      );
    }
    if (activeSite != null && activeSite is! String) {
      throw const FormatException(
        'ProvisionUserAction "activeSite" must be String or null',
      );
    }
    return ProvisionUserInput(
      userId: userId,
      role: role,
      activeSite: activeSite as String?,
    );
  }

  @override
  void validate(ProvisionUserInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    if (input.role.trim().isEmpty) {
      throw ArgumentError.value(input.role, 'role', 'must be non-empty');
    }
    if (directory.contains(input.userId)) {
      throw ArgumentError.value(input.userId, 'userId', 'already provisioned');
    }
  }

  @override
  Future<ExecutionResult<ProvisionUserResult>> execute(
    ProvisionUserInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ProvisionUserResult>(
      result: ProvisionUserResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'user_directory',
          aggregateId: input.userId,
          entryType: 'user_provisioned',
          eventType: 'user_provisioned',
          data: <String, dynamic>{
            'userId': input.userId,
            'role': input.role,
            'activeSite': input.activeSite,
          },
        ),
      ],
    );
  }
}
