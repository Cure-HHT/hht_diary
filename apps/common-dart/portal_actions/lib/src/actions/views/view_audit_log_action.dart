// Implements: DIARY-PRD-action-inventory/A  (ACT-AUD-001 View Audit Log; unscoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewAuditLogInput {
  const ViewAuditLogInput({this.filter});
  final String? filter;
}

class ViewAuditLogResult {
  const ViewAuditLogResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-AUD-001: gate check — verify the caller has permission to view the
/// audit log. Emits no events (read-only gate). UNSCOPED — no scopeFor override.
///
/// Phase 2: export variant emits auditor_export_recorded
class ViewAuditLogAction extends Action<ViewAuditLogInput, ViewAuditLogResult> {
  ViewAuditLogAction();

  @override
  String get name => 'ACT-AUD-001';

  @override
  String get description =>
      'Gate: verify the caller has permission to view the audit log. '
      'Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-AUD-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewAuditLogInput parseInput(Map<String, Object?> raw) {
    final filter = raw['filter'];
    return ViewAuditLogInput(filter: filter is String ? filter : null);
  }

  @override
  void validate(ViewAuditLogInput input) {
    // No required fields — nothing to validate.
  }

  @override
  Future<ExecutionResult<ViewAuditLogResult>> execute(
    ViewAuditLogInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewAuditLogResult>(
      result: const ViewAuditLogResult(),
      events: const <EventDraft>[],
    );
  }
}
