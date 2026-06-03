// Implements: DIARY-DEV-reactive-read-path/B — device-local projection of
//   in-progress (checkpoint) entries. A `checkpoint` adds the aggregate; a later
//   `finalized` (entry completed) OR `tombstone` (entry deleted) removes it, so
//   this view holds only entries that are still open drafts and is disjoint from
//   the canonical finalized `diary_entries` view. Not shared, not synced
//   (frozen P6).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// View name of the diary-local incomplete-entries projection.
const String diaryIncompleteViewName = 'diary_incomplete';

/// One row per aggregate with an open `checkpoint` that has been neither
/// finalized nor deleted. A `finalized` completes it and a `tombstone` deletes
/// it — both remove the row (a deleted draft must not linger as "incomplete").
const AggregateProjectionSpec diaryIncompleteProjection =
    AggregateProjectionSpec(
      viewName: diaryIncompleteViewName,
      interest: SubscriptionFilter(
        aggregateTypes: {diaryEntryAggregateType},
        eventTypes: {'checkpoint', 'finalized', 'tombstone'},
      ),
      tombstoneEventTypes: {'finalized', 'tombstone'},
    );
