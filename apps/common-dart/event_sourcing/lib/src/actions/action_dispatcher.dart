// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline): owner of the 10-stage pipeline.
//   This file currently implements stages 1 (lookup), 2 (invocation_id),
//   3 (parse), and 4 (idempotency check).
//   Stages 5-10 land in subsequent commits per plan-1 Tasks 17-22.

import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/action_registry.dart';
import 'package:event_sourcing/src/actions/authorization_policy.dart';
import 'package:event_sourcing/src/actions/denial_events.dart';
import 'package:event_sourcing/src/actions/dispatch_result.dart';
import 'package:event_sourcing/src/actions/idempotency.dart';
import 'package:event_sourcing/src/actions/idempotency_errors.dart';
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
  ///   (Pre-Stage 3) — idempotency-required precondition check
  ///             (REQ-d00170-B): if action requires a key and none was
  ///             supplied, emit `parse_denied` and return before
  ///             parseInput runs.
  ///   Stage 3 — call `action.parseInput(rawInput)`; on throw, emit
  ///             `parse_denied` and return [DispatchParseDenied].
  ///   Stage 4 — idempotency cache lookup for non-none policies with a
  ///             key; on hit, return [DispatchIdempotencyHit] with no
  ///             new event emitted.
  ///   Stages 5-10 — TODO in plan-1 Tasks 17-22.
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

    // Idempotency-required precondition check (REQ-d00170-B).
    // Must run BEFORE parseInput per spec: missing-required-key is a
    // parse-stage denial that fires before the action gets to see the raw
    // input.
    if (action.idempotency == Idempotency.required && idempotencyKey == null) {
      final error = MissingIdempotencyKeyError(actionName);
      final denial = denialParseDenied(
        invocationId: invocationId,
        actionName: actionName,
        error: error,
        actionInvocationMetadata: invocationMetadata,
      );
      await _persistDenial(denial, ctx, flowToken: flowToken);
      return DispatchResult<Object?>.parseDenied(error);
    }

    // Stage 3: parse
    // Implements: REQ-d00168-D
    final Object? parsedInput;
    try {
      parsedInput = action.parseInput(rawInput);
    } catch (error) {
      final denial = denialParseDenied(
        invocationId: invocationId,
        actionName: actionName,
        error: error,
        actionInvocationMetadata: invocationMetadata,
      );
      await _persistDenial(denial, ctx, flowToken: flowToken);
      return DispatchResult<Object?>.parseDenied(error);
    }

    // Stage 4: idempotency cache lookup
    // Implements: REQ-d00168-E, REQ-d00170-A,C
    // Skip entirely for Idempotency.none; also skip if no key was supplied
    // (covers Idempotency.optional with no key).
    if (action.idempotency != Idempotency.none && idempotencyKey != null) {
      final entry = await idempotency.lookup(
        action.name,
        ctx.principal.id,
        idempotencyKey,
      );
      if (entry != null) {
        // Cache hit — short-circuit; no new events emitted.
        return DispatchResult<Object?>.idempotencyHit(
          entry.resultJson,
          entry.emittedEventIds,
        );
      }
      // Cache miss — fall through to Stage 5+.
    }

    // Stages 5-10 land in subsequent tasks.
    // ignore: unused_local_variable
    final _ = parsedInput; // suppress unused warning until Stage 5 lands.
    throw UnimplementedError(
      'Stages 5-10 of the dispatcher pipeline are added in plan-1 Tasks 17-22.',
    );
  }

  /// Persists a denial event through [events]. Single event, atomic by
  /// virtue of EventStore.append's own transaction.
  ///
  /// `entryTypeVersion` is hardcoded to 1 for now; consumers must
  /// register the `action_denial` entry type at version 1. When the
  /// dispatcher's host-bootstrap helper lands (plan-1 Task 22), this
  /// hardcoding gets reviewed.
  Future<void> _persistDenial(
    EventDraft draft,
    ActionContext ctx, {
    String? flowToken,
  }) async {
    await events.append(
      entryType: draft.entryType,
      entryTypeVersion: 1,
      aggregateId: draft.aggregateId,
      aggregateType: draft.aggregateType,
      eventType: draft.eventType,
      data: Map<String, Object?>.from(draft.data),
      initiator: ctx.principal.toInitiator(),
      flowToken: draft.flowToken ?? flowToken,
      metadata: draft.metadata == null
          ? null
          : Map<String, Object?>.from(draft.metadata!),
      security: ctx.security,
    );
  }
}
