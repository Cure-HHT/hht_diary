// Implements: DIARY-PRD-action-inventory/A  (ACT-SEE-002 View RAVE Sync Status; unscoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewRaveSyncStatusInput {
  const ViewRaveSyncStatusInput();
}

class ViewRaveSyncStatusResult {
  const ViewRaveSyncStatusResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-SEE-002: gate check — verify the caller may view RAVE sync status.
/// Emits no events (read-only gate). UNSCOPED.
class ViewRaveSyncStatusAction
    extends Action<ViewRaveSyncStatusInput, ViewRaveSyncStatusResult> {
  ViewRaveSyncStatusAction();

  @override
  String get name => 'ACT-SEE-002';

  @override
  String get description =>
      'Gate: verify the caller may view RAVE sync status. Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-SEE-002']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewRaveSyncStatusInput parseInput(Map<String, Object?> raw) =>
      const ViewRaveSyncStatusInput();

  @override
  void validate(ViewRaveSyncStatusInput input) {
    // No required fields — nothing to validate.
  }

  @override
  Future<ExecutionResult<ViewRaveSyncStatusResult>> execute(
    ViewRaveSyncStatusInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewRaveSyncStatusResult>(
      result: const ViewRaveSyncStatusResult(),
      events: const <EventDraft>[],
    );
  }
}
