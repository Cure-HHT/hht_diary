// Implements: DIARY-PRD-action-inventory/A  (ACT-SEE-004 View Diary Entries; unscoped, debug)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewDiaryEntriesInput {
  const ViewDiaryEntriesInput();
}

class ViewDiaryEntriesResult {
  const ViewDiaryEntriesResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-SEE-004: gate check — verify the caller may view raw diary entries.
/// Emits no events (read-only gate). UNSCOPED. Debug-only: granted to no
/// production role; the reference sponsor grants it for test coverage.
class ViewDiaryEntriesAction
    extends Action<ViewDiaryEntriesInput, ViewDiaryEntriesResult> {
  ViewDiaryEntriesAction();

  @override
  String get name => 'ACT-SEE-004';

  @override
  String get description =>
      'Gate: verify the caller may view raw diary entries (debug). '
      'Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-SEE-004']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewDiaryEntriesInput parseInput(Map<String, Object?> raw) =>
      const ViewDiaryEntriesInput();

  @override
  void validate(ViewDiaryEntriesInput input) {
    // No required fields — nothing to validate.
  }

  @override
  Future<ExecutionResult<ViewDiaryEntriesResult>> execute(
    ViewDiaryEntriesInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewDiaryEntriesResult>(
      result: const ViewDiaryEntriesResult(),
      events: const <EventDraft>[],
    );
  }
}
