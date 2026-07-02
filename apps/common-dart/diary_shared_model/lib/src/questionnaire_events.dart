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
  // The portal mints `questionnaire_submission_received` (via the
  // QuestionnaireSubmissionReactor) when a diary `<id>_survey` finalized event
  // arrives for a live instance, folding the instance to Ready to Review.
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_submission_received',
      registeredVersion: 1,
      name: 'Questionnaire Submission Received',
    ),
  ),
  // CUR-1539: the portal governance lock event, renamed from
  // `questionnaire_finalized`. Pairs with `questionnaire_unlocked`.
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_locked',
      registeredVersion: 1,
      name: 'Questionnaire Locked',
    ),
  ),
  // CUR-1539: frozen legacy alias for `questionnaire_locked`. Kept registered
  // so (a) pre-rename portal event logs still replay/fold, and (b) the diary's
  // device-observed status mint (`record_questionnaire_finalized`, which echoes
  // the portal wire status `finalized` from /user/tasks) keeps its id — older
  // mobile builds in testers' hands still mint this id. Do NOT emit this from
  // portal code; new portal locks emit `questionnaire_locked`.
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
  SharedEventType(
    origin: EventOrigin.portal,
    definition: EntryTypeDefinition(
      id: 'questionnaire_recall_notice',
      registeredVersion: 1,
      name: 'Questionnaire Recall Notice',
    ),
  ),
];
