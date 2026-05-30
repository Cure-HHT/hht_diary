// Implements: DIARY-DEV-shared-events-catalog/A+B+C
//   Refines: DIARY-PRD-mobile-notifications
import 'package:event_sourcing/event_sourcing.dart';

import 'event_origin.dart';

/// Notification intent + FCM-token facts (`[home: shared]`). The mobile-authored
/// `fcm_message_received` ack and `fcm_token_registered` are held for the cross-post.
const List<SharedEventType> notificationEventTypes = <SharedEventType>[
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'notification_sent',
      registeredVersion: 1,
      name: 'Notification Sent',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'notification_dispatch_failed',
      registeredVersion: 1,
      name: 'Notification Dispatch Failed',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.edge,
    definition: EntryTypeDefinition(
      id: 'fcm_token_deactivated',
      registeredVersion: 1,
      name: 'FCM Token Deactivated',
    ),
  ),
];
