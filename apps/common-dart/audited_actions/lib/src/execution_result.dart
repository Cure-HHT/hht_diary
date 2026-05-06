// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-D: ExecutionResult shape returned by Action.execute.

/// What an `Action.execute` returns to the dispatcher.
///
/// `events` is the (possibly empty) list of event drafts to persist
/// atomically. `securityDetailsOverride`, when non-null, replaces
/// `ActionContext.security` for all events written by this dispatch
/// (rare; default behavior is to use ctx.security).
///
/// EventDraft and SecurityDetails are imported from event_sourcing_datastore
/// at the caller site (typically in action_dispatcher.dart); this class
/// remains agnostic to their concrete types to allow independent unit testing
/// of action implementations without pulling in Flutter dependencies.
//
// Implements: REQ-d00166-D — execute returns this value type; dispatcher
// persists `events` in one transaction (REQ-d00168-I).
class ExecutionResult<TResult> {
  const ExecutionResult({
    required this.result,
    required this.events,
    this.securityDetailsOverride,
  });

  final TResult result;
  final List<dynamic> events;
  final dynamic securityDetailsOverride;
}
