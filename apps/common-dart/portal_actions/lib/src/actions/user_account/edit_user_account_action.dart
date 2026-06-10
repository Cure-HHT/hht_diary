// Implements: DIARY-PRD-user-account-edit/A — edits a staff user account's profile
//   name and/or requests an email-address change (emits user_profile_changed
//   and/or user_email_change_requested).
// Implements: DIARY-PRD-action-inventory/A — declares the portal.user.edit
//   permission the dispatcher enforces RBAC against.
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';
import '../../user_email_format.dart';

class EditUserAccountInput {
  EditUserAccountInput({
    required this.userId,
    required this.name,
    required this.newEmail,
  });
  final String userId;
  final String? name;
  final String? newEmail;
}

class EditUserAccountResult {
  const EditUserAccountResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-002: edit a staff user account profile or email address.
/// Emits user_profile_changed when name changes, user_email_change_requested
/// when a new email is provided. At least one change must be present.
class EditUserAccountAction
    extends Action<EditUserAccountInput, EditUserAccountResult> {
  EditUserAccountAction();

  @override
  String get name => 'ACT-USR-002';

  @override
  String get description =>
      'Edit a staff user account (profile name and/or email change request). '
      'Emits user_profile_changed and/or user_email_change_requested.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-002']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  EditUserAccountInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    if (userId is! String) {
      throw const FormatException(
        'EditUserAccountAction expects {userId}: String',
      );
    }
    String? optString(String key) {
      final v = raw[key];
      return v is String ? v : null;
    }

    return EditUserAccountInput(
      userId: userId.trim(),
      name: optString('name'),
      newEmail: optString('newEmail')?.trim(),
    );
  }

  @override
  void validate(EditUserAccountInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
    final nameChanged = input.name != null && input.name!.trim().isNotEmpty;
    final emailChanged =
        input.newEmail != null && input.newEmail!.trim().isNotEmpty;
    if (!(nameChanged || emailChanged)) {
      throw ArgumentError('no change requested');
    }
    if (emailChanged && !isValidAccountEmail(input.newEmail!)) {
      throw ArgumentError.value(
        input.newEmail,
        'newEmail',
        'must be a valid email address',
      );
    }
  }

  // Implements: DIARY-DEV-operator-tier-authz/C
  // Implements: DIARY-PRD-user-account-edit/H — the edit is gated on the target
  //   account's tier (user-contained-in-tier), so a non-operator cannot edit a
  //   System Operator account.
  @override
  ScopeValue? scopeFor(Permission perm, EditUserAccountInput input) =>
      perm.scopeClass == 'user'
      ? BoundScope(class_: 'user', value: input.userId)
      : null;

  @override
  Future<ExecutionResult<EditUserAccountResult>> execute(
    EditUserAccountInput input,
    ActionContext ctx,
  ) async {
    final nameChanged = input.name != null && input.name!.trim().isNotEmpty;
    final emailChanged =
        input.newEmail != null && input.newEmail!.trim().isNotEmpty;
    final events = <EventDraft>[];
    if (nameChanged) {
      events.add(
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_profile_changed',
          eventType: 'user_profile_changed',
          // Canonical key 'name' (matches user_created) so the
          // users_index key-wise merge updates the row's display name.
          data: <String, Object?>{
            'name': input.name,
            'changed_by': ctx.principal.id,
          },
        ),
      );
    }
    if (emailChanged) {
      events.add(
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_email_change_requested',
          eventType: 'user_email_change_requested',
          data: <String, Object?>{
            'new_email': input.newEmail,
            'requested_by': ctx.principal.id,
          },
        ),
      );
    }
    return ExecutionResult<EditUserAccountResult>(
      result: EditUserAccountResult(userId: input.userId),
      events: events,
    );
  }
}
