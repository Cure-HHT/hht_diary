// Implements: DIARY-PRD-action-inventory/A+C  (ACT-QST-004 Unlock Questionnaire; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class UnlockQuestionnaireInput {
  const UnlockQuestionnaireInput({
    required this.siteId,
    required this.instanceId,
  });
  final String siteId;
  final String instanceId;
}

class UnlockQuestionnaireResult {
  const UnlockQuestionnaireResult({required this.instanceId});
  final String instanceId;
  Map<String, Object?> toJson() => <String, Object?>{'instanceId': instanceId};
}

/// ACT-QST-004: unlock a finalized questionnaire instance for correction.
/// Emits `questionnaire_unlocked`; the flowToken correlates with the Phase-2
/// notification subscriber.
class UnlockQuestionnaireAction
    extends Action<UnlockQuestionnaireInput, UnlockQuestionnaireResult> {
  UnlockQuestionnaireAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-QST-004';

  @override
  String get description =>
      'Unlock a finalized questionnaire instance for correction. Emits '
      'questionnaire_unlocked; the notification is driven by a Phase-2 subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-QST-004']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  UnlockQuestionnaireInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final instanceId = raw['instanceId'];
    if (siteId is! String || instanceId is! String) {
      throw const FormatException(
        'UnlockQuestionnaireAction expects {siteId, instanceId}: String',
      );
    }
    return UnlockQuestionnaireInput(
      siteId: siteId.trim(),
      instanceId: instanceId.trim(),
    );
  }

  @override
  void validate(UnlockQuestionnaireInput input) {
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
  ScopeValue? scopeFor(Permission perm, UnlockQuestionnaireInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<UnlockQuestionnaireResult>> execute(
    UnlockQuestionnaireInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'QST');
    return ExecutionResult<UnlockQuestionnaireResult>(
      result: UnlockQuestionnaireResult(instanceId: input.instanceId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'questionnaire_instance',
          aggregateId: input.instanceId,
          entryType: 'questionnaire_unlocked',
          eventType: 'questionnaire_unlocked',
          flowToken: flowToken,
          data: <String, Object?>{'unlocked_by': ctx.principal.id},
        ),
      ],
    );
  }
}
