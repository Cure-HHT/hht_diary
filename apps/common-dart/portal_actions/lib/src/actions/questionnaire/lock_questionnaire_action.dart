// Implements: DIARY-PRD-action-inventory/A+C  (ACT-QST-003 Finalize Questionnaire; scoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class LockQuestionnaireInput {
  const LockQuestionnaireInput({
    required this.siteId,
    required this.instanceId,
    this.edcExportRef,
    this.cycle,
    this.endEvent,
  });
  final String siteId;
  final String instanceId;
  final String? edcExportRef;

  /// The study_event (Cycle value) being finalized, e.g. `'Cycle 2 Day 1'`.
  /// Null when cycle tracking is disabled / no cycle is recorded.
  final String? cycle;

  /// A terminal close marker: one of `'end_of_treatment'` / `'end_of_study'`,
  /// or null for a normal (non-terminal) cycle finalize.
  final String? endEvent;
}

class LockQuestionnaireResult {
  const LockQuestionnaireResult({required this.instanceId});
  final String instanceId;
  Map<String, Object?> toJson() => <String, Object?>{'instanceId': instanceId};
}

/// ACT-QST-003: lock (GUI: "Finalize") a questionnaire instance, marking it
/// complete. Emits `questionnaire_locked`. No flowToken (no outgoing
/// notification).
///
/// CUR-1539: renamed from `FinalizeQuestionnaireAction`; the emitted event was
/// `questionnaire_finalized` (now a frozen legacy alias in the shared catalog).
/// The dispatch wire name stays `ACT-QST-003` and the event-payload key
/// `finalized_by` is unchanged for pre-rename log continuity.
class LockQuestionnaireAction
    extends Action<LockQuestionnaireInput, LockQuestionnaireResult> {
  LockQuestionnaireAction();

  @override
  String get name => 'ACT-QST-003';

  @override
  String get description =>
      'Lock (finalize) a questionnaire instance, marking it complete. '
      'Emits questionnaire_locked.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-QST-003']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  LockQuestionnaireInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final instanceId = raw['instanceId'];
    if (siteId is! String || instanceId is! String) {
      throw const FormatException(
        'LockQuestionnaireAction expects {siteId, instanceId}: String',
      );
    }
    // Optional String fields (trimmed; null when absent / non-String).
    final edcExportRef = raw['edcExportRef'];
    final cycle = raw['cycle'];
    final endEvent = raw['endEvent'];
    return LockQuestionnaireInput(
      siteId: siteId.trim(),
      instanceId: instanceId.trim(),
      edcExportRef: edcExportRef is String ? edcExportRef : null,
      cycle: cycle is String ? cycle.trim() : null,
      endEvent: endEvent is String ? endEvent.trim() : null,
    );
  }

  @override
  void validate(LockQuestionnaireInput input) {
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
    // A terminal close marker, when present, must be one of the two terminal
    // cycle values. The server / UI controls the exact Cycle label, so cycle
    // validation stays light here — only reject an obviously empty string.
    if (input.cycle != null && input.cycle!.isEmpty) {
      throw ArgumentError.value(
        input.cycle,
        'cycle',
        'must be non-empty when present',
      );
    }
    if (input.endEvent != null &&
        input.endEvent != 'end_of_treatment' &&
        input.endEvent != 'end_of_study') {
      throw ArgumentError.value(
        input.endEvent,
        'endEvent',
        "must be 'end_of_treatment' or 'end_of_study' when present",
      );
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, LockQuestionnaireInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  // Implements: DIARY-BASE-questionnaire-finalization/D+E — the finalized event
  //   records WHICH cycle was finalized (`cycle`) and whether the close is
  //   terminal (`end_event`: End of Treatment / End of Study). D = a normal
  //   cycle finalize (null end_event); E = a terminal close that permanently
  //   blocks further sends (the next-cycle computation reads `end_event`).
  @override
  Future<ExecutionResult<LockQuestionnaireResult>> execute(
    LockQuestionnaireInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<LockQuestionnaireResult>(
      result: LockQuestionnaireResult(instanceId: input.instanceId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'questionnaire_instance',
          aggregateId: input.instanceId,
          entryType: 'questionnaire_locked',
          eventType: 'questionnaire_locked',
          data: <String, Object?>{
            'finalized_by': ctx.principal.id,
            'edc_export_ref': input.edcExportRef,
            'cycle': input.cycle,
            'end_event': input.endEvent,
          },
        ),
      ],
    );
  }
}
