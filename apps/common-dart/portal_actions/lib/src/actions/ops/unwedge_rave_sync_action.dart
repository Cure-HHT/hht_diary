// Implements: DIARY-BASE-ops-action-inventory/B
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class UnwedgeRaveSyncInput {
  UnwedgeRaveSyncInput({required this.reason});
  final String reason;
}

class UnwedgeRaveSyncResult {
  const UnwedgeRaveSyncResult();
}

/// ACT-OPS-001: restore outbound RAVE/EDC sync after a wedge. Emits
/// rave_unwedged on the rave_sync aggregate; the endpoint probe is driven by a
/// subscriber on rave_unwedged, not here.
class UnwedgeRaveSyncAction
    extends Action<UnwedgeRaveSyncInput, UnwedgeRaveSyncResult> {
  UnwedgeRaveSyncAction();

  @override
  String get name => 'ACT-OPS-001';

  @override
  String get description =>
      'Restore outbound RAVE/EDC sync after a wedge and probe the endpoint.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-OPS-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  UnwedgeRaveSyncInput parseInput(Map<String, Object?> raw) {
    final reason = raw['reason'];
    if (reason is! String) {
      throw const FormatException(
        'UnwedgeRaveSyncAction expects {reason}: String',
      );
    }
    return UnwedgeRaveSyncInput(reason: reason.trim());
  }

  @override
  void validate(UnwedgeRaveSyncInput input) {
    if (input.reason.trim().isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<UnwedgeRaveSyncResult>> execute(
    UnwedgeRaveSyncInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<UnwedgeRaveSyncResult>(
      result: const UnwedgeRaveSyncResult(),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'rave_sync',
          aggregateId: 'rave_sync',
          entryType: 'rave_unwedged',
          eventType: 'rave_unwedged',
          data: <String, Object?>{
            'reason': input.reason,
            'by': ctx.principal.id,
          },
        ),
      ],
    );
  }
}
