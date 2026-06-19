// Diary-local mint actions: record the device's OBSERVATION (via /user/tasks)
// that the portal finalized or unlocked a questionnaire instance.
// Device-originated; the portal's own questionnaire_finalized/unlocked remains
// system-of-record. Per-event provenance (origin=mobile-device) is stamped by
// the diary scope — no provenance fields are set here. The diary records ONLY
// the FACT of observation; `data` carries only `{'source':'portal-state-sync'}`.
import 'package:event_sourcing/event_sourcing.dart';

/// Records the device-observed portal finalization of a questionnaire instance.
/// Emits one `questionnaire_finalized` event on the `questionnaire_instance`
/// aggregate. Input: `{instance_id}` only.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
// Refines: DIARY-BASE-questionnaire-lock-after-submission
// Implements: DIARY-DEV-action-write-path/A — the write flows through the core
//   ActionDispatcher rather than a direct append.
class RecordQuestionnaireFinalizedAction
    extends Action<Map<String, Object?>, String> {
  const RecordQuestionnaireFinalizedAction();

  @override
  String get name => 'record_questionnaire_finalized';

  @override
  String get description =>
      'Records the device-observed portal finalization of a questionnaire instance.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_questionnaire_status'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) => raw;

  @override
  void validate(Map<String, Object?> input) {
    final id = input['instance_id'];
    if (id is! String || id.isEmpty) {
      throw ArgumentError.value(id, 'instance_id', 'must be set');
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    final instanceId = input['instance_id'] as String;
    return ExecutionResult<String>(
      result: instanceId,
      events: [
        EventDraft(
          // SHARED aggregate + same event type as the portal. Per-event
          // provenance (origin=mobile-device) marks it as the device's
          // observation; the diary records only the FACT (finalized) and carries
          // no portal-internal payload.
          aggregateType: 'questionnaire_instance',
          aggregateId: instanceId,
          entryType: 'questionnaire_finalized',
          eventType: 'questionnaire_finalized',
          data: const <String, Object?>{'source': 'portal-state-sync'},
        ),
      ],
    );
  }
}

/// Records the device-observed portal unlock of a questionnaire instance.
/// Emits one `questionnaire_unlocked` event on the `questionnaire_instance`
/// aggregate. Input: `{instance_id}` only.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
// Refines: DIARY-BASE-questionnaire-lock-after-submission
// Implements: DIARY-DEV-action-write-path/A — the write flows through the core
//   ActionDispatcher rather than a direct append.
class RecordQuestionnaireUnlockedAction
    extends Action<Map<String, Object?>, String> {
  const RecordQuestionnaireUnlockedAction();

  @override
  String get name => 'record_questionnaire_unlocked';

  @override
  String get description =>
      'Records the device-observed portal unlock of a questionnaire instance.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_questionnaire_status'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) => raw;

  @override
  void validate(Map<String, Object?> input) {
    final id = input['instance_id'];
    if (id is! String || id.isEmpty) {
      throw ArgumentError.value(id, 'instance_id', 'must be set');
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    final instanceId = input['instance_id'] as String;
    return ExecutionResult<String>(
      result: instanceId,
      events: [
        EventDraft(
          aggregateType: 'questionnaire_instance',
          aggregateId: instanceId,
          entryType: 'questionnaire_unlocked',
          eventType: 'questionnaire_unlocked',
          data: const <String, Object?>{'source': 'portal-state-sync'},
        ),
      ],
    );
  }
}
