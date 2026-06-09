// Implements: DIARY-PRD-action-inventory/A  (ACT-SEE-003 View User Accounts; unscoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewUserAccountsInput {
  const ViewUserAccountsInput();
}

class ViewUserAccountsResult {
  const ViewUserAccountsResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-SEE-003: gate check — verify the caller may view user accounts.
/// Emits no events (read-only gate). UNSCOPED. Gates both the users_index and
/// user_role_scopes projections.
class ViewUserAccountsAction
    extends Action<ViewUserAccountsInput, ViewUserAccountsResult> {
  ViewUserAccountsAction();

  @override
  String get name => 'ACT-SEE-003';

  @override
  String get description =>
      'Gate: verify the caller may view user accounts. Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-SEE-003']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewUserAccountsInput parseInput(Map<String, Object?> raw) =>
      const ViewUserAccountsInput();

  @override
  void validate(ViewUserAccountsInput input) {
    // No required fields — nothing to validate.
  }

  @override
  Future<ExecutionResult<ViewUserAccountsResult>> execute(
    ViewUserAccountsInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewUserAccountsResult>(
      result: const ViewUserAccountsResult(),
      events: const <EventDraft>[],
    );
  }
}
