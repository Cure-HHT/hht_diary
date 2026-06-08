// participant_fcm_tokens materializes
//   the current active FCM token per (participant, platform) by folding the
//   device-authored FcmToken events that cross-post via /ingest. The aggregate
//   id is "{participantId}:fcm:{platform}", so AggregateIdKey yields one stable
//   row per participant+platform; a refresh overwrites it. A deactivation
//   tombstone removes the row (dead-token cleanup).
//
//   IMPORTANT: the fold gates on event.eventType, NOT entryType. Device actions
//   emit eventType='finalized' with the semantic name in entryType (e.g.
//   entryType='fcm_token_registered'); deactivation is emitted as a tombstone
//   (eventType='tombstone', entryType='fcm_token_deactivated'). So the filter
//   selects {'finalized','tombstone'} on the FcmToken aggregate, inserts on
//   'finalized' and removes on 'tombstone' — mirroring diaryEntriesProjection.
import 'package:event_sourcing/event_sourcing.dart';

/// `participant_fcm_tokens`: one row per (participant, platform) carrying the
/// device's current active FCM routing token. The NotificationDispatchReactor
/// reads this to address a push. The row's `aggregateId`
/// (`"{participantId}:fcm:{platform}"`) carries the participant + platform; the
/// row data carries the token itself.
final TableProjectionSpec fcmActiveTokensSpec = TableProjectionSpec(
  viewName: 'participant_fcm_tokens',
  interest: const SubscriptionFilter(
    aggregateTypes: {'FcmToken'},
    eventTypes: {'finalized', 'tombstone'},
  ),
  insertEventTypes: const {'finalized'},
  removeEventTypes: const {'tombstone'},
  rowKey: const AggregateIdKey(),
  rowData: const SelectedFields(['token', 'platform']),
);
