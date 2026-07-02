// Implements: DIARY-PRD-action-inventory/A
// Implements: DIARY-DEV-shared-events-catalog/D
// Implements: DIARY-DEV-user-account-projection/B
// Implements: DIARY-PRD-user-account-create/A — server-authoritative check that a
//   non-Administrator (site-scoped) role carries at least one Site.
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';
import '../../site_scoped_roles.dart';
import '../../user_email_format.dart';

class CreateUserAccountInput {
  CreateUserAccountInput({
    required this.email,
    required this.name,
    required this.activationExpiresAt,
    required this.roles,
    required this.sites,
  });
  final String email;
  final String name;
  final String activationExpiresAt;
  final List<String> roles;
  final List<String> sites;
}

class CreateUserAccountResult {
  const CreateUserAccountResult({required this.email});
  final String email;
  Map<String, Object?> toJson() => <String, Object?>{'email': email};
}

/// ACT-USR-001: create a new staff user account. Emits user_created +
/// user_activation_code_issued (same flowToken). The flowToken correlates
/// with the Phase-2 email/notification subscriber.
class CreateUserAccountAction
    extends Action<CreateUserAccountInput, CreateUserAccountResult> {
  CreateUserAccountAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-USR-001';

  @override
  String get description =>
      'Create a new staff user account. Emits user_created + '
      'user_activation_code_issued; the activation email is driven by a '
      'Phase-2 notification subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  CreateUserAccountInput parseInput(Map<String, Object?> raw) {
    final email = raw['email'];
    final name = raw['name'];
    final activationExpiresAt = raw['activationExpiresAt'];
    if (email is! String || name is! String || activationExpiresAt is! String) {
      throw const FormatException(
        'CreateUserAccountAction expects '
        '{email, name, activationExpiresAt}: String',
      );
    }
    final rawRoles = raw['roles'];
    if (rawRoles is! List || !rawRoles.every((dynamic e) => e is String)) {
      throw const FormatException(
        'CreateUserAccountAction: roles must be a List<String>',
      );
    }
    final rawSites = raw['sites'];
    if (rawSites is! List || !rawSites.every((dynamic e) => e is String)) {
      throw const FormatException(
        'CreateUserAccountAction: sites must be a List<String>',
      );
    }
    return CreateUserAccountInput(
      email: email.trim(),
      name: name.trim(),
      activationExpiresAt: activationExpiresAt.trim(),
      roles: List<String>.from(rawRoles),
      sites: List<String>.from(rawSites),
    );
  }

  @override
  void validate(CreateUserAccountInput input) {
    if (input.email.trim().isEmpty) {
      throw ArgumentError.value(input.email, 'email', 'must be non-empty');
    }
    if (!isValidAccountEmail(input.email)) {
      throw ArgumentError.value(
        input.email,
        'email',
        'must be a valid email address',
      );
    }
    if (input.name.trim().isEmpty) {
      throw ArgumentError.value(input.name, 'name', 'must be non-empty');
    }
    if (input.activationExpiresAt.trim().isEmpty) {
      throw ArgumentError.value(
        input.activationExpiresAt,
        'activationExpiresAt',
        'must be non-empty',
      );
    }
    // Implements: DIARY-PRD-user-account-create/A — a site-scoped role (Study
    //   Coordinator / CRA) must be created with at least one Site. Rejected at
    //   the action boundary so the invariant holds even if the client form's
    //   Save guard is bypassed. Administrator / SystemOperator are wildcard-
    //   scoped and may legitimately have zero Sites.
    final siteScopedRoles = input.roles
        .where(isSiteScopedRole)
        .toList(growable: false);
    if (siteScopedRoles.isNotEmpty && input.sites.isEmpty) {
      throw ArgumentError.value(
        input.sites,
        'sites',
        'at least one Site is required for ${siteScopedRoles.join(', ')}',
      );
    }
  }

  @override
  Future<ExecutionResult<CreateUserAccountResult>> execute(
    CreateUserAccountInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'USR');
    return ExecutionResult<CreateUserAccountResult>(
      result: CreateUserAccountResult(email: input.email),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.email,
          entryType: 'user_created',
          eventType: 'user_created',
          flowToken: flowToken,
          data: <String, Object?>{
            'email': input.email,
            'name': input.name,
            'roles': input.roles,
            'sites': input.sites,
            'created_by': ctx.principal.id,
            'status': 'pending',
          },
        ),
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.email,
          entryType: 'user_activation_code_issued',
          eventType: 'user_activation_code_issued',
          flowToken: flowToken,
          data: <String, Object?>{
            'expires_at': input.activationExpiresAt,
            'issued_by': ctx.principal.id,
            'reissue': false,
          },
        ),
      ],
    );
  }
}
