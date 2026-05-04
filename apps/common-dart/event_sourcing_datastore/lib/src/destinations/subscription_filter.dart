import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';

/// Predicate function signature consulted by [SubscriptionFilter] after
/// the allow-lists have passed.
typedef SubscriptionPredicate = bool Function(StoredEvent event);

/// Predicate that selects which events are enqueued to a Destination.
///
/// Composes the system-event opt-in plus three optional user-event
/// constraints, combined with logical AND:
///
/// 1. [includeSystemEvents] — opt-in for events whose `entryType` is in
///    [kReservedSystemEntryTypeIds]. When `true`, system events bypass
///    [entryTypes] entirely and pass [matches]. When `false` (the
///    default), system events are rejected by [matches] regardless of
///    [entryTypes] content. See REQ-d00128-J / REQ-d00154-F.
/// 2. [entryTypes] — allow-list over `event.entry_type` for user events.
///    `null` means "any user entry type"; an **empty list** means
///    "nothing matches" (the distinction is deliberate; see REQ-d00122-F).
///    Reserved system entry types route through [includeSystemEvents]
///    and never consult this list.
/// 3. [eventTypes] — allow-list over `event.event_type` with the same
///    null-vs-empty semantics as [entryTypes].
/// 4. [predicate] — optional escape-hatch function consulted only after
///    the allow-lists pass. Returns `true` for the event to match.
///
/// A filter with no constraints matches every user event and (since
/// [includeSystemEvents] defaults to `false`) admits no system events,
/// which is the default for destinations that want unconditional fan-out
/// of user events without forensic visibility into config-change audits.
// Implements: REQ-d00122-B+F — deterministic event selection, allow-lists
// by entry_type / event_type with null-vs-empty distinction, optional
// predicate escape-hatch.
// Implements: REQ-d00128-J, REQ-d00154-F — system entry types dispatch
// through includeSystemEvents (opt-in) rather than entryTypes; matches
// is the single authority on per-destination admission for both user
// and system events.
class SubscriptionFilter {
  const SubscriptionFilter({
    this.entryTypes,
    this.eventTypes,
    this.predicate,
    this.includeSystemEvents = false,
  });

  /// Allow-list over `event.entry_type` for user events. `null` = match
  /// all user entry types; `[]` = match no user entry types. Reserved
  /// system entry types ignore this list and route through
  /// [includeSystemEvents].
  final List<String>? entryTypes;

  /// Allow-list over `event.event_type`. `null` = match all event types;
  /// `[]` = match no event types.
  final List<String>? eventTypes;

  /// Escape-hatch consulted after the allow-lists pass. `null` means
  /// "no additional filtering"; a non-null predicate must return `true`
  /// for the event to match.
  final SubscriptionPredicate? predicate;

  /// Opt-in for events whose `entryType` is in
  /// [kReservedSystemEntryTypeIds]. When `true`, [matches] admits every
  /// reserved system entry type regardless of [entryTypes] content (the
  /// list is bypassed for system events). When `false`, [matches]
  /// rejects every reserved system entry type regardless of [entryTypes]
  /// content. Defaults to `false` so destinations carrying user
  /// payloads do not accidentally admit forensic audit events.
  ///
  /// A destination subscribing to forensic / audit visibility on an
  /// upstream node's local-state mutations sets this to `true` (paired
  /// with a possibly-empty [entryTypes] when the destination wants only
  /// system events).
  // Implements: REQ-d00128-J, REQ-d00154-F — system-event opt-in.
  final bool includeSystemEvents;

  /// Returns `true` iff [event] should be enqueued to the destination
  /// that owns this filter. Deterministic: identical inputs produce
  /// identical outputs, so filter evaluations are reproducible from the
  /// event alone.
  ///
  /// Reserved system entry types (those in [kReservedSystemEntryTypeIds])
  /// are admitted iff [includeSystemEvents] is `true`. The
  /// [entryTypes] allow-list is consulted only for user entry types.
  /// [eventTypes] and [predicate] are consulted for both system and
  /// user events that cleared the entry-type gate.
  // Implements: REQ-d00122-F — null-vs-empty list distinction; predicate
  // short-circuits when allow-lists fail.
  // Implements: REQ-d00128-J, REQ-d00154-F — system entry types dispatch
  // through includeSystemEvents, bypassing entryTypes; user entry types
  // use the entryTypes list.
  bool matches(StoredEvent event) {
    if (kReservedSystemEntryTypeIds.contains(event.entryType)) {
      if (!includeSystemEvents) return false;
      // System event admitted past the entry-type gate; eventTypes /
      // predicate constraints still apply (they refine within the
      // admitted set).
    } else {
      final entryTypes = this.entryTypes;
      if (entryTypes != null && !entryTypes.contains(event.entryType)) {
        return false;
      }
    }
    final eventTypes = this.eventTypes;
    if (eventTypes != null && !eventTypes.contains(event.eventType)) {
      return false;
    }
    final predicate = this.predicate;
    if (predicate != null && !predicate(event)) {
      return false;
    }
    return true;
  }
}
