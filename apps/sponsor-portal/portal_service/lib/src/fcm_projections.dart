// participant_fcm_tokens materializes
//   the current active FCM token per (participant, platform) by folding the
//   device-authored fcm_token_registered events that cross-post via /ingest.
//   The aggregate id is "{participantId}:fcm:{platform}", so AggregateIdKey
//   yields one stable row per participant+platform; a refresh overwrites it.
//   fcm_token_deactivated removes the row (dead-token cleanup).
import 'package:event_sourcing/event_sourcing.dart';

/// `participant_fcm_tokens`: one row per (participant, platform) carrying the
/// device's current active FCM routing token. The NotificationDispatchReactor
/// reads this to address a push. The row's `aggregateId`
/// (`"{participantId}:fcm:{platform}"`) carries the participant + platform; the
/// row data carries the token itself.
final TableProjectionSpec fcmActiveTokensSpec = TableProjectionSpec(
  viewName: 'participant_fcm_tokens',
  interest: const SubscriptionFilter(
    eventTypes: {'fcm_token_registered', 'fcm_token_deactivated'},
    aggregateTypes: {'FcmToken'},
  ),
  insertEventTypes: const {'fcm_token_registered'},
  removeEventTypes: const {'fcm_token_deactivated'},
  rowKey: const AggregateIdKey(),
  rowData: const SelectedFields(['token', 'platform']),
);
