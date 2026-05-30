// Implements: DIARY-PRD-action-inventory/A  (ACT-SIT-001 View Sites; unscoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewSitesInput {
  const ViewSitesInput({this.filter});
  final String? filter;
}

class ViewSitesResult {
  const ViewSitesResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-SIT-001: gate check — verify the caller has permission to view sites.
/// Emits no events (read-only gate). UNSCOPED — no scopeFor override.
class ViewSitesAction extends Action<ViewSitesInput, ViewSitesResult> {
  ViewSitesAction();

  @override
  String get name => 'ACT-SIT-001';

  @override
  String get description =>
      'Gate: verify the caller has permission to view the site list. '
      'Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-SIT-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewSitesInput parseInput(Map<String, Object?> raw) {
    final filter = raw['filter'];
    return ViewSitesInput(filter: filter is String ? filter : null);
  }

  @override
  void validate(ViewSitesInput input) {
    // No required fields — nothing to validate.
  }

  @override
  Future<ExecutionResult<ViewSitesResult>> execute(
    ViewSitesInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewSitesResult>(
      result: const ViewSitesResult(),
      events: const <EventDraft>[],
    );
  }
}
