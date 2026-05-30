// Implements: DIARY-DEV-reactive-read-path/B — diary-LOCAL projection of
//   in-progress (checkpoint) entries. A `checkpoint` adds the aggregate; a later
//   `finalized` tombstones it, so this view is disjoint from the canonical
//   finalized `diary_entries` view. Not shared, not synced (frozen P6).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// View name of the diary-local incomplete-entries projection.
const String diaryIncompleteViewName = 'diary_incomplete';

/// One row per aggregate that has an open `checkpoint` and no `finalized` event.
const AggregateProjectionSpec diaryIncompleteProjection =
    AggregateProjectionSpec(
      viewName: diaryIncompleteViewName,
      interest: SubscriptionFilter(
        aggregateTypes: {diaryEntryAggregateType},
        eventTypes: {'checkpoint', 'finalized'},
      ),
      tombstoneEventTypes: {'finalized'},
    );
