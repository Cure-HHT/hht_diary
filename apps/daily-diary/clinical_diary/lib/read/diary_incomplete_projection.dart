// Implements: DIARY-DEV-reactive-read-path/B — device-local projection of
//   in-progress (checkpoint) entries. A `checkpoint` adds the aggregate; a later
//   `finalized` (entry completed) OR `tombstone` (entry deleted) removes it, so
//   this view holds only entries that are still open drafts and is disjoint from
//   the canonical finalized `diary_entries` view. Not shared, not synced
//   (frozen P6).
// Implements: DIARY-PRD-questionnaire-session-timeout/C — the diary-local
//   `draft_discarded` event (minted by discard_questionnaire_draft when a
//   questionnaire Session expires, CUR-1543) also removes the draft row, so an
//   expired draft can never be resumed. Unlike `tombstone` it is NOT shipped by
//   DiaryServerDestination (which selects finalized/tombstone only), keeping
//   the discard as diary-local as the checkpoint it deletes.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// View name of the diary-local incomplete-entries projection.
const String diaryIncompleteViewName = 'diary_incomplete';

/// One row per aggregate with an open `checkpoint` that has been neither
/// finalized, deleted, nor discarded. A `finalized` completes it, a `tombstone`
/// deletes it, and a `draft_discarded` (expired questionnaire session) discards
/// it — all three remove the row (a dead draft must not linger as
/// "incomplete").
const AggregateProjectionSpec diaryIncompleteProjection =
    AggregateProjectionSpec(
      viewName: diaryIncompleteViewName,
      interest: SubscriptionFilter(
        aggregateTypes: {diaryEntryAggregateType},
        eventTypes: {'checkpoint', 'finalized', 'tombstone', 'draft_discarded'},
      ),
      tombstoneEventTypes: {'finalized', 'tombstone', 'draft_discarded'},
    );
