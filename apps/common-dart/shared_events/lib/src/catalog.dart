// Implements: DIARY-DEV-shared-events-catalog/A+B+E — the single registry of
//   cross-wire entry types; each id appears exactly once.
import 'event_origin.dart';
import 'notification_events.dart';
import 'patient_events.dart';
import 'questionnaire_events.dart';

/// The exhaustive `[P]`/edge cross-wire catalog (Plan 1). Mobile-authored
/// `[M]` ids are held in [heldMobileAuthoredIds] until the CUR-1371 cross-post.
const List<SharedEventType> sharedEventCatalog = <SharedEventType>[
  ...patientEventTypes,
  ...questionnaireEventTypes,
  ...notificationEventTypes,
];

/// Mobile-authored cross-wire ids deliberately NOT yet registered. Listed so
/// the catalog records the full intended surface (spec §4) and tests can assert
/// they stay out until mobile confirms their schema.
const List<String> heldMobileAuthoredIds = <String>[
  'patient_linked',
  'questionnaire_submitted',
  'fcm_message_received',
  'fcm_token_registered',
  // clinical ePRO entries (spec §4.5), mobile-authored:
  'epistaxis_event',
  'no_epistaxis_event',
  'unknown_day_event',
  'inbound_tombstone_record_failed',
  // dynamic per-instrument: '{eq|nose_hht|hht_qol}_survey'
];
