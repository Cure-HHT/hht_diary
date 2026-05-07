// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 (Action Interface Contract): unit-of-work interface that
//   every audited command implements. Pure parseInput/validate; effectful
//   execute returns events for atomic persistence.
//   REQ-d00170-F (Idempotency Contract): per-action idempotencyTtl with
//   24-hour default.

import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/execution_result.dart';
import 'package:event_sourcing/src/actions/idempotency.dart';
import 'package:event_sourcing/src/actions/permission.dart';

/// A portal command. Concrete subclasses define one action and one
/// command shape (`TInput`) and one result shape (`TResult`).
///
/// Lifecycle inside `ActionDispatcher`:
///   parseInput(raw)        -> TInput            (pure)
///   validate(input)        throws on invalid    (pure)
///   authorize via policy                        (uses [permissions])
///   execute(input, ctx)    -> ExecutionResult   (effectful; returns
///                                                events for atomic
///                                                persistence)
//
// Implements: REQ-d00166-A — interface shape with name/description/
//             permissions/idempotency + parseInput/validate/execute methods.
//             REQ-d00166-B,C — purity contracts on parseInput and validate
//             (no I/O; enforced by review, not the type system).
//             REQ-d00166-D — execute returns ExecutionResult.
//             REQ-d00166-E — idempotency declared per action.
//             REQ-d00170-F — per-action idempotencyTtl with 24-hour default.
abstract class Action<TInput, TResult> {
  const Action();

  /// Stable identifier; appears in event metadata as `action_name` and
  /// is the lookup key in `ActionRegistry`.
  String get name;

  /// Human-readable description for admin UIs and discovery output.
  String get description;

  /// Permissions required by this action. The dispatcher's authorize
  /// stage checks every permission in this set against the
  /// `AuthorizationPolicy`; the first denial short-circuits.
  Set<Permission> get permissions;

  /// How the dispatcher treats `idempotencyKey` for calls to this
  /// action: ignore (`none`), use if supplied (`optional`), or demand
  /// (`required`).
  Idempotency get idempotency;

  /// Per-action TTL override for idempotency cache entries.
  /// Default: 24 hours.
  Duration get idempotencyTtl => defaultIdempotencyTtl;

  /// Parse raw input into the typed shape. Pure: no I/O, no global
  /// state. Throws (typically `FormatException` or `ArgumentError`)
  /// on malformed input; the dispatcher converts the throw into a
  /// `parse_denied` denial event.
  TInput parseInput(Map<String, Object?> raw);

  /// Validate the typed input. Pure: no I/O. Throws on invalid input
  /// (typically `ValidationError`); the dispatcher converts the throw
  /// into a `validation_denied` denial event.
  void validate(TInput input);

  /// Run the action. Returns `ExecutionResult` carrying the typed
  /// result and the events to persist atomically (one transaction in
  /// the events lib).
  Future<ExecutionResult<TResult>> execute(TInput input, ActionContext ctx);
}
