// Implements: DIARY-PRD-action-inventory/A  (ACT-SIT-001 View Sites)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewSitesInput {
  const ViewSitesInput({required this.siteId, this.filter});
  final String siteId;
  final String? filter;
}

class ViewSitesResult {
  const ViewSitesResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-SIT-001: gate check — verify the caller has permission to view sites.
/// Emits no events (read-only gate). Site-scoped — scopeFor binds the site
/// scope so site visibility is gated by the caller's site assignments.
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
    final siteId = raw['siteId'];
    if (siteId is! String) {
      throw const FormatException('ViewSitesAction expects {siteId}: String');
    }
    final filter = raw['filter'];
    return ViewSitesInput(
      siteId: siteId.trim(),
      filter: filter is String ? filter : null,
    );
  }

  @override
  void validate(ViewSitesInput input) {
    if (input.siteId.trim().isEmpty) {
      throw ArgumentError.value(input.siteId, 'siteId', 'must be non-empty');
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, ViewSitesInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

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
