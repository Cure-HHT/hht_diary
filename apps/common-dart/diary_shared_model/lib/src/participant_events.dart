// Implements: DIARY-DEV-shared-events-catalog/A+B+C
//   Refines: DIARY-PRD-participant (lifecycle), DIARY-PRD-status-registry (states)
import 'package:event_sourcing/event_sourcing.dart';

import 'event_origin.dart';

/// Participant lifecycle (`[home: shared]`). Portal-originated except
/// EDC-sync facts (edge). The mobile-authored `participant_linked` ack is held for
/// the cross-post.
const List<SharedEventType> participantEventTypes = <SharedEventType>[
  SharedEventType(
    origin: EventOrigin.edge,
    definition: EntryTypeDefinition(
      id: 'participant_synced_from_edc',
      registeredVersion: 1,
      name: 'Participant Synced From EDC',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_linking_code_issued',
      registeredVersion: 1,
      name: 'Participant Linking Code Issued',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_linking_code_revoked',
      registeredVersion: 1,
      name: 'Participant Linking Code Revoked',
    ),
  ),
  // Implements: DIARY-DEV-linking-code-lifecycle/C — the lifecycle event type the
  //   per-code linking_codes projection folds into a single status.
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_linking_code_used',
      registeredVersion: 1,
      name: 'Participant Linking Code Used',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_trial_started',
      registeredVersion: 1,
      name: 'Participant Trial Started',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_disconnected',
      registeredVersion: 1,
      name: 'Participant Disconnected',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_reconnected',
      registeredVersion: 1,
      name: 'Participant Reconnected',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_marked_not_participating',
      registeredVersion: 1,
      name: 'Participant Marked Not Participating',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'participant_reactivated',
      registeredVersion: 1,
      name: 'Participant Reactivated',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.edge,
    definition: EntryTypeDefinition(
      id: 'participant_enrollment_status_changed',
      registeredVersion: 1,
      name: 'Participant Enrollment Status Changed',
    ),
  ),
];
