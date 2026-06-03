// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-007 View Participant; scoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class ViewParticipantInput {
  const ViewParticipantInput({
    required this.siteId,
    required this.participantId,
  });
  final String siteId;
  final String participantId;
}

class ViewParticipantResult {
  const ViewParticipantResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-007: gate check — verify the caller has permission to view a
/// participant record. Emits no events (read-only gate).
class ViewParticipantAction
    extends Action<ViewParticipantInput, ViewParticipantResult> {
  ViewParticipantAction();

  @override
  String get name => 'ACT-PAT-007';

  @override
  String get description =>
      'Gate: verify the caller has permission to view a participant record. '
      'Emits no events.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-007']!,
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  ViewParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    if (siteId is! String || participantId is! String) {
      throw const FormatException(
        'ViewParticipantAction expects {siteId, participantId}: String',
      );
    }
    return ViewParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
    );
  }

  @override
  void validate(ViewParticipantInput input) {
    if (input.siteId.isEmpty) {
      throw ArgumentError.value(input.siteId, 'siteId', 'must be non-empty');
    }
    if (input.participantId.isEmpty) {
      throw ArgumentError.value(
        input.participantId,
        'participantId',
        'must be non-empty',
      );
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, ViewParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<ViewParticipantResult>> execute(
    ViewParticipantInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ViewParticipantResult>(
      result: ViewParticipantResult(participantId: input.participantId),
      events: const <EventDraft>[],
    );
  }
}
