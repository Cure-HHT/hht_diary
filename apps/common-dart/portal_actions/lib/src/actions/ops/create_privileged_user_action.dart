// Implements: DIARY-BASE-ops-action-inventory/B
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class CreatePrivilegedUserInput {
  CreatePrivilegedUserInput({required this.email, required this.name});
  final String email;
  final String name;
}

class CreatePrivilegedUserResult {
  const CreatePrivilegedUserResult({required this.email});
  final String email;
  Map<String, Object?> toJson() => <String, Object?>{'email': email};
}

/// Shared base for the ops-only privileged-user creators (ACT-OPS-002 /
/// ACT-OPS-003). Emits a single user_created event on the portal_user
/// aggregate, stamping the role declared by the concrete subclass.
abstract class CreatePrivilegedUserAction
    extends Action<CreatePrivilegedUserInput, CreatePrivilegedUserResult> {
  CreatePrivilegedUserAction();

  String get _actId;
  String get _role;

  @override
  String get name => _actId;

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId[_actId]!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  CreatePrivilegedUserInput parseInput(Map<String, Object?> raw) {
    final email = raw['email'];
    final name = raw['name'];
    if (email is! String || name is! String) {
      throw const FormatException(
        'CreatePrivilegedUserAction expects {email, name}: String',
      );
    }
    return CreatePrivilegedUserInput(email: email.trim(), name: name.trim());
  }

  @override
  void validate(CreatePrivilegedUserInput input) {
    if (!input.email.contains('@')) {
      throw ArgumentError.value(input.email, 'email', 'must contain "@"');
    }
    if (input.name.trim().isEmpty) {
      throw ArgumentError.value(input.name, 'name', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<CreatePrivilegedUserResult>> execute(
    CreatePrivilegedUserInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<CreatePrivilegedUserResult>(
      result: CreatePrivilegedUserResult(email: input.email),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.email,
          entryType: 'user_created',
          eventType: 'user_created',
          data: <String, Object?>{
            'email': input.email,
            'name': input.name,
            'roles': <String>[_role],
            'created_by': ctx.principal.id,
          },
        ),
      ],
    );
  }
}

/// ACT-OPS-003: create a portal Administrator account (ops-only).
class CreateAdministratorAction extends CreatePrivilegedUserAction {
  CreateAdministratorAction();

  @override
  String get _actId => 'ACT-OPS-003';

  @override
  String get _role => 'Administrator';

  @override
  String get description =>
      'Create a portal Administrator account (operations-only).';
}

/// ACT-OPS-002: create a portal SystemOperator account (ops-only).
class CreateSystemOperatorAction extends CreatePrivilegedUserAction {
  CreateSystemOperatorAction();

  @override
  String get _actId => 'ACT-OPS-002';

  @override
  String get _role => 'SystemOperator';

  @override
  String get description =>
      'Create a portal SystemOperator account (operations-only).';
}
