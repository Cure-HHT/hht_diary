// Implements: DIARY-PRD-action-inventory/A  (ACT-SEE-001 View Questionnaire Status; scoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewQuestionnaireStatusInput {
  const ViewQuestionnaireStatusInput({required this.siteId});
  final String siteId;
}

class ViewQuestionnaireStatusResult {
  const ViewQuestionnaireStatusResult();
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// ACT-SEE-001: gate check — verify the caller may view questionnaire status.
/// Emits no events (read-only gate). Site-scoped.
class ViewQuestionnaireStatusAction
    extends
        Action<ViewQuestionnaireStatusInput, ViewQuestionnaireStatusResult> {
  ViewQuestionnaireStatusAction();

  @override
  String get name => 'ACT-SEE-001';

  @override
  String get description =>
      'Gate: verify the caller may view questionnaire status. Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-SEE-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewQuestionnaireStatusInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    if (siteId is! String) {
      throw const FormatException(
        'ViewQuestionnaireStatusAction expects {siteId}: String',
      );
    }
    return ViewQuestionnaireStatusInput(siteId: siteId.trim());
  }

  @override
  void validate(ViewQuestionnaireStatusInput input) {
    if (input.siteId.trim().isEmpty) {
      throw ArgumentError.value(input.siteId, 'siteId', 'must be non-empty');
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, ViewQuestionnaireStatusInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<ViewQuestionnaireStatusResult>> execute(
    ViewQuestionnaireStatusInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewQuestionnaireStatusResult>(
      result: const ViewQuestionnaireStatusResult(),
      events: const <EventDraft>[],
    );
  }
}
