import 'package:event_sourcing_datastore/src/storage/stored_event.dart';

/// Predicate function signature consulted by [SubscriptionFilter] after
/// the allow-lists have passed.
typedef SubscriptionPredicate = bool Function(StoredEvent event);

/// Predicate that selects which events are enqueued to a Destination.
///
/// Composes three optional constraints, combined with logical AND:
///
/// 1. [entryTypes] — allow-list over `event.entry_type`. `null` means "any
///    entry type"; an **empty list** means "nothing matches" (the
///    distinction is deliberate; see REQ-d00122-F).
/// 2. [eventTypes] — allow-list over `event.event_type` with the same
///    null-vs-empty semantics as [entryTypes].
/// 3. [predicate] — optional escape-hatch function consulted only after
///    the allow-lists pass. Returns `true` for the event to match.
///
/// A filter with no constraints matches every event, which is the default
/// for destinations that want unconditional fan-out.
// Implements: REQ-d00122-B+F — deterministic event selection, allow-lists
// by entry_type / event_type with null-vs-empty distinction, optional
// predicate escape-hatch.
class SubscriptionFilter {
  const SubscriptionFilter({this.entryTypes, this.eventTypes, this.predicate});

  /// Allow-list over `event.entry_type`. `null` = match all entry types;
  /// `[]` = match no entry types.
  final List<String>? entryTypes;

  /// Allow-list over `event.event_type`. `null` = match all event types;
  /// `[]` = match no event types.
  final List<String>? eventTypes;

  /// Escape-hatch consulted after the allow-lists pass. `null` means
  /// "no additional filtering"; a non-null predicate must return `true`
  /// for the event to match.
  final SubscriptionPredicate? predicate;

  /// Returns `true` iff [event] should be enqueued to the destination
  /// that owns this filter. Deterministic: identical inputs produce
  /// identical outputs, so filter evaluations are reproducible from the
  /// event alone.
  // Implements: REQ-d00122-F — null-vs-empty list distinction; predicate
  // short-circuits when allow-lists fail.
  bool matches(StoredEvent event) {
    final entryTypes = this.entryTypes;
    if (entryTypes != null && !entryTypes.contains(event.entryType)) {
      return false;
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
