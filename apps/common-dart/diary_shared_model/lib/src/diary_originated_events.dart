// Implements: DIARY-DEV-shared-events-catalog/A+B+C
//   Refines: DIARY-PRD-participant, DIARY-PRD-mobile-notifications
//
// Cross-wire entry types AUTHORED BY THE DIARY (origin: mobile), frozen with the
// diary side 2026-05-29 (docs/evs-lib-port/diary-event-surface.md). The event
// "kind" (finalized / tombstone / checkpoint) rides in event metadata, NOT in the
// entry-type id. Survey entry types (`<id>_survey`) are registered dynamically by
// the diary app from its questionnaires.json asset and are NOT hardcoded here.
import 'package:event_sourcing/event_sourcing.dart';

import 'event_origin.dart';

const List<SharedEventType> diaryOriginatedEventTypes = <SharedEventType>[
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'epistaxis_event',
      registeredVersion: 1,
      name: 'Epistaxis Event',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'no_epistaxis_event',
      registeredVersion: 1,
      name: 'No Epistaxis Event',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'unknown_day_event',
      registeredVersion: 1,
      name: 'Unknown Day Event',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'participant_linked',
      registeredVersion: 1,
      name: 'Participant Linked',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'fcm_token_registered',
      registeredVersion: 1,
      name: 'FCM Token Registered',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'fcm_message_received',
      registeredVersion: 1,
      name: 'FCM Message Received',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.mobile,
    definition: EntryTypeDefinition(
      id: 'setting_applied',
      registeredVersion: 1,
      name: 'Setting Applied',
    ),
  ),
];
