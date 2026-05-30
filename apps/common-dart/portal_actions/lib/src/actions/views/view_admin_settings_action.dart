// Implements: DIARY-PRD-action-inventory/A  (ACT-ADM-001 View Administrator Settings; unscoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewAdminSettingsInput {
  const ViewAdminSettingsInput();
}

class ViewAdminSettingsResult {
  const ViewAdminSettingsResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-ADM-001: gate check — verify the caller has permission to view
/// administrator settings. Emits no events (read-only gate).
/// UNSCOPED — no scopeFor override.
class ViewAdminSettingsAction
    extends Action<ViewAdminSettingsInput, ViewAdminSettingsResult> {
  ViewAdminSettingsAction();

  @override
  String get name => 'ACT-ADM-001';

  @override
  String get description =>
      'Gate: verify the caller has permission to view administrator settings. '
      'Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-ADM-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewAdminSettingsInput parseInput(Map<String, Object?> raw) {
    return const ViewAdminSettingsInput();
  }

  @override
  void validate(ViewAdminSettingsInput input) {
    // No required fields — nothing to validate.
  }

  @override
  Future<ExecutionResult<ViewAdminSettingsResult>> execute(
    ViewAdminSettingsInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewAdminSettingsResult>(
      result: const ViewAdminSettingsResult(),
      events: const <EventDraft>[],
    );
  }
}
