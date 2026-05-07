// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-D: ExecutionResult shape returned by Action.execute.

import 'package:event_sourcing/src/event_draft.dart';
import 'package:event_sourcing/src/security/security_details.dart';

/// What an `Action.execute` returns to the dispatcher.
///
/// `events` is the (possibly empty) list of [EventDraft]s to persist
/// atomically. `securityDetailsOverride`, when non-null, replaces
/// `ActionContext.security` for all events written by this dispatch
/// (rare; default behavior is to use ctx.security).
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
  final List<EventDraft> events;
  final SecurityDetails? securityDetailsOverride;
}
