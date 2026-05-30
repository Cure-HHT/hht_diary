// Implements: DIARY-DEV-shared-events-catalog/A+B+C
//   Refines: DIARY-PRD-questionnaire-versioning, DIARY-PRD-status-registry
import 'package:event_sourcing/event_sourcing.dart';

import 'event_origin.dart';

/// Questionnaire instance lifecycle (`[home: shared]`), portal-originated.
/// The mobile-authored `questionnaire_submitted` is held for the cross-post.
const List<SharedEventType> questionnaireEventTypes = <SharedEventType>[
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_assigned',
      registeredVersion: 1,
      name: 'Questionnaire Assigned',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_delivery_failed',
      registeredVersion: 1,
      name: 'Questionnaire Delivery Failed',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_finalized',
      registeredVersion: 1,
      name: 'Questionnaire Finalized',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_scored',
      registeredVersion: 1,
      name: 'Questionnaire Scored',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_unlocked',
      registeredVersion: 1,
      name: 'Questionnaire Unlocked',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_called_back',
      registeredVersion: 1,
      name: 'Questionnaire Called Back',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_end_event_set',
      registeredVersion: 1,
      name: 'Questionnaire End Event Set',
    ),
  ),
];
