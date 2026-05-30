// Implements: DIARY-PRD-action-inventory/A+C  (ACT-QST-003 Finalize Questionnaire; scoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class FinalizeQuestionnaireInput {
  const FinalizeQuestionnaireInput({
    required this.siteId,
    required this.instanceId,
    this.edcExportRef,
  });
  final String siteId;
  final String instanceId;
  final String? edcExportRef;
}

class FinalizeQuestionnaireResult {
  const FinalizeQuestionnaireResult({required this.instanceId});
  final String instanceId;
  Map<String, Object?> toJson() => <String, Object?>{'instanceId': instanceId};
}

/// ACT-QST-003: finalize a questionnaire instance, marking it complete.
/// Emits `questionnaire_finalized`. No flowToken (no outgoing notification).
class FinalizeQuestionnaireAction
    extends Action<FinalizeQuestionnaireInput, FinalizeQuestionnaireResult> {
  FinalizeQuestionnaireAction();

  @override
  String get name => 'ACT-QST-003';

  @override
  String get description =>
      'Finalize a questionnaire instance, marking it complete. '
      'Emits questionnaire_finalized.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-QST-003']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  FinalizeQuestionnaireInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final instanceId = raw['instanceId'];
    if (siteId is! String || instanceId is! String) {
      throw const FormatException(
        'FinalizeQuestionnaireAction expects {siteId, instanceId}: String',
      );
    }
    // Optional String field
    final edcExportRef = raw['edcExportRef'];
    return FinalizeQuestionnaireInput(
      siteId: siteId.trim(),
      instanceId: instanceId.trim(),
      edcExportRef: edcExportRef is String ? edcExportRef : null,
    );
  }

  @override
  void validate(FinalizeQuestionnaireInput input) {
    if (input.siteId.isEmpty) {
      throw ArgumentError.value(input.siteId, 'siteId', 'must be non-empty');
    }
    if (input.instanceId.isEmpty) {
      throw ArgumentError.value(
        input.instanceId,
        'instanceId',
        'must be non-empty',
      );
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, FinalizeQuestionnaireInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<FinalizeQuestionnaireResult>> execute(
    FinalizeQuestionnaireInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<FinalizeQuestionnaireResult>(
      result: FinalizeQuestionnaireResult(instanceId: input.instanceId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'questionnaire_instance',
          aggregateId: input.instanceId,
          entryType: 'questionnaire_finalized',
          eventType: 'questionnaire_finalized',
          data: <String, Object?>{
            'finalized_by': ctx.principal.id,
            'edc_export_ref': input.edcExportRef,
          },
        ),
      ],
    );
  }
}
