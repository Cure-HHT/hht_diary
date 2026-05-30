// Implements: DIARY-PRD-action-inventory/A+C  (ACT-QST-001 Send Questionnaire; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../portal_permissions.dart';

class SendQuestionnaireInput {
  SendQuestionnaireInput({
    required this.siteId,
    required this.instanceId,
    required this.participantId,
    required this.questionnaireType,
    this.schemaVersion,
    this.contentVersion,
    this.guiVersion,
    this.translationVersion,
    this.studyEvent,
    this.cycleOrdinal,
  });
  final String siteId;
  final String instanceId;
  final String participantId;
  final String questionnaireType;
  final String? schemaVersion;
  final String? contentVersion;
  final String? guiVersion;
  final String? translationVersion;
  final String? studyEvent;
  final int? cycleOrdinal;
}

class SendQuestionnaireResult {
  const SendQuestionnaireResult({
    required this.instanceId,
    required this.flowToken,
  });
  final String instanceId;
  final String flowToken;
  Map<String, Object?> toJson() => <String, Object?>{
    'instanceId': instanceId,
    'flowToken': flowToken,
  };
}

/// ACT-QST-001: assign/send a questionnaire to a participant. Emits
/// `questionnaire_assigned`; the flowToken correlates with the Phase-2
/// notification subscriber that emits notification_sent.
class SendQuestionnaireAction
    extends Action<SendQuestionnaireInput, SendQuestionnaireResult> {
  SendQuestionnaireAction({required this.flowTokenMinter});
  final FlowTokenMinter flowTokenMinter;

  @override
  String get name => 'ACT-QST-001';

  @override
  String get description =>
      'Send/assign a questionnaire to a participant. Emits '
      'questionnaire_assigned; the notification is driven by a Phase-2 subscriber.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-QST-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  SendQuestionnaireInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final instanceId = raw['instanceId'];
    final participantId = raw['participantId'];
    final questionnaireType = raw['questionnaireType'];
    if (siteId is! String ||
        instanceId is! String ||
        participantId is! String ||
        questionnaireType is! String) {
      throw const FormatException(
        'SendQuestionnaireAction expects '
        '{siteId, instanceId, participantId, questionnaireType}: String',
      );
    }

    // Optional String fields: parse only if present and a String
    String? optString(String key) {
      final v = raw[key];
      return v is String ? v : null;
    }

    // cycleOrdinal: must be int if present
    int? cycleOrdinal;
    if (raw.containsKey('cycleOrdinal')) {
      final v = raw['cycleOrdinal'];
      if (v is! int) {
        throw const FormatException(
          'SendQuestionnaireAction: cycleOrdinal must be an int when present',
        );
      }
      cycleOrdinal = v;
    }

    return SendQuestionnaireInput(
      siteId: siteId.trim(),
      instanceId: instanceId.trim(),
      participantId: participantId.trim(),
      questionnaireType: questionnaireType.trim(),
      schemaVersion: optString('schemaVersion'),
      contentVersion: optString('contentVersion'),
      guiVersion: optString('guiVersion'),
      translationVersion: optString('translationVersion'),
      studyEvent: optString('studyEvent'),
      cycleOrdinal: cycleOrdinal,
    );
  }

  @override
  void validate(SendQuestionnaireInput input) {
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
    if (input.participantId.isEmpty) {
      throw ArgumentError.value(
        input.participantId,
        'participantId',
        'must be non-empty',
      );
    }
    if (input.questionnaireType.isEmpty) {
      throw ArgumentError.value(
        input.questionnaireType,
        'questionnaireType',
        'must be non-empty',
      );
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, SendQuestionnaireInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<SendQuestionnaireResult>> execute(
    SendQuestionnaireInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'QST');
    return ExecutionResult<SendQuestionnaireResult>(
      result: SendQuestionnaireResult(
        instanceId: input.instanceId,
        flowToken: flowToken,
      ),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'questionnaire_instance',
          aggregateId: input.instanceId,
          entryType: 'questionnaire_assigned',
          eventType: 'questionnaire_assigned',
          flowToken: flowToken,
          data: <String, Object?>{
            'participant_id': input.participantId,
            'type': input.questionnaireType,
            'schema_version': input.schemaVersion,
            'content_version': input.contentVersion,
            'gui_version': input.guiVersion,
            'translation_version': input.translationVersion,
            'study_event': input.studyEvent,
            'cycle_ordinal': input.cycleOrdinal,
            'assigned_by': ctx.principal.id,
          },
        ),
      ],
    );
  }
}
