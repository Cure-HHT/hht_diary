// Implements: DIARY-DEV-shared-events-catalog/A+B+C
//   Refines: DIARY-PRD-participant (lifecycle), DIARY-PRD-status-registry (states)
import 'package:event_sourcing/event_sourcing.dart';

import 'event_origin.dart';

/// Patient / participant lifecycle (`[home: shared]`). Portal-originated except
/// EDC-sync facts (edge). The mobile-authored `patient_linked` ack is held for
/// the cross-post.
const List<SharedEventType> patientEventTypes = <SharedEventType>[
  SharedEventType(
    origin: EventOrigin.edge,
    definition: EntryTypeDefinition(
      id: 'patient_synced_from_edc',
      registeredVersion: 1,
      name: 'Patient Synced From EDC',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_linking_code_issued',
      registeredVersion: 1,
      name: 'Patient Linking Code Issued',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_linking_code_revoked',
      registeredVersion: 1,
      name: 'Patient Linking Code Revoked',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_trial_started',
      registeredVersion: 1,
      name: 'Patient Trial Started',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_disconnected',
      registeredVersion: 1,
      name: 'Patient Disconnected',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_reconnected',
      registeredVersion: 1,
      name: 'Patient Reconnected',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_marked_not_participating',
      registeredVersion: 1,
      name: 'Patient Marked Not Participating',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'patient_reactivated',
      registeredVersion: 1,
      name: 'Patient Reactivated',
    ),
  ),
  SharedEventType(
    origin: EventOrigin.edge,
    definition: EntryTypeDefinition(
      id: 'patient_enrollment_status_changed',
      registeredVersion: 1,
      name: 'Patient Enrollment Status Changed',
    ),
  ),
];
