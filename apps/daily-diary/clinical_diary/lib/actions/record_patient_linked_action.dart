// Implements: DIARY-DEV-action-write-path/A — the write flows through the core
//   ActionDispatcher rather than a direct append.
// Implements: DIARY-DEV-shared-events-catalog/A — emits the diary-originated
//   `patient_linked` event (surface P4) recording participant identity.
//   Refines: DIARY-PRD-linking-code-lifecycle
//
// Diary per-app Action (diary_actions): record that the device has linked to a
// study. Emits one finalized `patient_linked` on the `Patient` aggregate (keyed
// on the stable user id). The cross-wire identity payload lives in the shared
// model (PatientLinkedPayload) and carries NO session token / linking code (those
// stay in secure storage). Like the other system-event actions this does not
// require a UserPrincipal — linking is the moment identity is established.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Records a successful study link as a finalized `patient_linked` event.
/// Returns the user id (the Patient aggregate id).
class RecordPatientLinkedAction extends Action<PatientLinkedPayload, String> {
  const RecordPatientLinkedAction();

  @override
  String get name => 'record_patient_linked';

  @override
  String get description =>
      'App records that the device has linked to a study (participant identity).';

  @override
  Set<Permission> get permissions => const <Permission>{};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  PatientLinkedPayload parseInput(Map<String, Object?> raw) {
    try {
      return PatientLinkedPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid patient_linked payload: $e');
    }
  }

  @override
  void validate(PatientLinkedPayload input) {
    if (input.userId.isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be set');
    }
    if (DateTime.tryParse(input.linkedAt) == null) {
      throw ArgumentError.value(
        input.linkedAt,
        'linkedAt',
        'must be an ISO 8601 timestamp',
      );
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    PatientLinkedPayload input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<String>(
      result: input.userId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'Patient',
          aggregateId: input.userId,
          entryType: 'patient_linked',
          eventType: 'finalized',
          data: input.toJson(),
        ),
      ],
    );
  }
}
