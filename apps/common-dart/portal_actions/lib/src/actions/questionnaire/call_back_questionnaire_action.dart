// Implements: DIARY-PRD-action-inventory/A+C  (ACT-QST-002 Call Back Questionnaire; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class CallBackQuestionnaireInput {
  const CallBackQuestionnaireInput({
    required this.siteId,
    required this.instanceId,
    required this.reason,
  });
  final String siteId;
  final String instanceId;
  final String reason;
}

class CallBackQuestionnaireResult {
  const CallBackQuestionnaireResult({required this.instanceId});
  final String instanceId;
  Map<String, Object?> toJson() => <String, Object?>{'instanceId': instanceId};
}

/// ACT-QST-002: call back (retract) a questionnaire instance. Emits
/// `questionnaire_called_back`; the flowToken correlates with the Phase-2
/// notification subscriber.
class CallBackQuestionnaireAction
    extends Action<CallBackQuestionnaireInput, CallBackQuestionnaireResult> {
  CallBackQuestionnaireAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-QST-002';

  @override
  String get description =>
      'Call back (retract) a questionnaire instance. Emits '
      'questionnaire_called_back; the notification is driven by a Phase-2 subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-QST-002']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  CallBackQuestionnaireInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final instanceId = raw['instanceId'];
    final reason = raw['reason'];
    if (siteId is! String || instanceId is! String || reason is! String) {
      throw const FormatException(
        'CallBackQuestionnaireAction expects {siteId, instanceId, reason}: String',
      );
    }
    return CallBackQuestionnaireInput(
      siteId: siteId.trim(),
      instanceId: instanceId.trim(),
      reason: reason.trim(),
    );
  }

  @override
  void validate(CallBackQuestionnaireInput input) {
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
    if (input.reason.isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, CallBackQuestionnaireInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<CallBackQuestionnaireResult>> execute(
    CallBackQuestionnaireInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'QST');
    return ExecutionResult<CallBackQuestionnaireResult>(
      result: CallBackQuestionnaireResult(instanceId: input.instanceId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'questionnaire_instance',
          aggregateId: input.instanceId,
          entryType: 'questionnaire_called_back',
          eventType: 'questionnaire_called_back',
          flowToken: flowToken,
          data: <String, Object?>{
            'by': ctx.principal.id,
            'reason': input.reason,
          },
        ),
      ],
    );
  }
}
