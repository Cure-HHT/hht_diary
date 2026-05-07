// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline): owner of the 10-stage pipeline.
//   This file currently implements stages 1 (lookup) and 2 (invocation_id).
//   Stages 3-10 land in subsequent commits per plan-1 Tasks 16-22.

import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/action_registry.dart';
import 'package:event_sourcing/src/actions/authorization_policy.dart';
import 'package:event_sourcing/src/actions/denial_events.dart';
import 'package:event_sourcing/src/actions/dispatch_result.dart';
import 'package:event_sourcing/src/actions/idempotency_store.dart';
import 'package:event_sourcing/src/event_draft.dart';
import 'package:event_sourcing/src/event_store.dart';
import 'package:uuid/uuid.dart';

/// Runs every untrusted-ingress action through the standard 10-stage
/// pipeline. See REQ-d00168 in `spec/dev-event-sourcing.md` for the
/// stage list and contract.
class ActionDispatcher {
  ActionDispatcher({
    required this.registry,
    required this.authorization,
    required this.events,
    required this.idempotency,
  });

  final ActionRegistry registry;
  final AuthorizationPolicy authorization;
  final EventStore events;
  final IdempotencyStore idempotency;

  static const _uuid = Uuid();

  /// Dispatch one action call.
  ///
  /// Pipeline (per REQ-d00168):
  ///   Stage 1 — lookup `actionName` in [registry]. If unknown, emit
  ///             `unknown_action` denial event and return
  ///             [DispatchUnknownAction].
  ///   Stage 2 — generate v4 UUID `action_invocation_id`; stamp it into
  ///             every emitted event's metadata.
  ///   Stages 3-10 — TODO in plan-1 Tasks 16-22.
  Future<DispatchResult<Object?>> dispatch(
    String actionName,
    Map<String, Object?> rawInput,
    ActionContext ctx, {
    String? idempotencyKey,
    String? flowToken,
  }) async {
    // Stage 2: invocation_id (generated up front so denials can carry it).
    final invocationId = _uuid.v4();
    final invocationMetadata = <String, dynamic>{
      'action_invocation_id': invocationId,
      'action_name': actionName,
    };

    // Stage 1: lookup
    // Implements: REQ-d00168-B
    final action = registry.lookup(actionName);
    if (action == null) {
      final denial = denialUnknownAction(
        invocationId: invocationId,
        requestedName: actionName,
        actionInvocationMetadata: invocationMetadata,
      );
      await _persistDenial(denial, ctx, flowToken: flowToken);
      return DispatchResult<Object?>.unknownAction(actionName);
    }

    // Stages 3-10 land in subsequent tasks.
    throw UnimplementedError(
      'Stages 3-10 of the dispatcher pipeline are added in plan-1 Tasks 16-22.',
    );
  }

  /// Persists a denial event through [events]. Single event, atomic by
  /// virtue of EventStore.append's own transaction.
  ///
  /// `entryTypeVersion` is hardcoded to 1 for now; consumers must
  /// register the `action_denial` entry type at version 1. When the
  /// dispatcher's host-bootstrap helper lands (plan-1 Task 22), this
  /// hardcoding gets reviewed.
  ///
  /// **EventStore.eventType vs EventDraft.eventType**: EventStore.append
  /// requires `eventType` to be one of `finalized | checkpoint | tombstone`
  /// (the diary-entry lifecycle state). `EventDraft.eventType` carries the
  /// business-level denial discriminator (e.g. `unknown_action`). The
  /// dispatcher maps the business type into `data['denial_event_type']` and
  /// uses `eventType: 'finalized'` so the event is stored atomically through
  /// the normal append path.
  Future<void> _persistDenial(
    EventDraft draft,
    ActionContext ctx, {
    String? flowToken,
  }) async {
    // Merge the business denial type into data so it survives in the log
    // alongside the structured denial payload.
    final data = <String, Object?>{
      'denial_event_type': draft.eventType,
      ...draft.data,
    };

    await events.append(
      entryType: draft.entryType,
      entryTypeVersion: 1,
      aggregateId: draft.aggregateId,
      aggregateType: draft.aggregateType,
      // EventStore.append validates eventType ∈ {finalized,checkpoint,
      // tombstone}. All system audit events use 'finalized' (consistent
      // with clearSecurityContext, applyRetentionPolicy, destination audits).
      eventType: 'finalized',
      data: data,
      initiator: ctx.principal.toInitiator(),
      flowToken: draft.flowToken ?? flowToken,
      metadata: draft.metadata == null
          ? null
          : Map<String, Object?>.from(draft.metadata!),
      security: ctx.security,
    );
  }
}
