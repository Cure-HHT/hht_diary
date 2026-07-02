// Implements: DIARY-DEV-shared-events-catalog/A+B+E — the single registry of
//   cross-wire entry types; each id appears exactly once. Surface frozen with the
//   diary side 2026-05-29.
import 'diary_originated_events.dart';
import 'event_origin.dart';
import 'notification_events.dart';
import 'participant_events.dart';
import 'questionnaire_events.dart';

/// The exhaustive cross-wire entry-type catalog (frozen 2026-05-29):
/// portal-originated + edge + diary-originated static types. Survey types
/// (`<id>_survey`) are diary-app-registered dynamically and are not listed here.
///
/// CUR-1539 (pre-approved rename on the frozen surface): the portal governance
/// lock event is `questionnaire_locked`; `questionnaire_finalized` remains
/// registered as its frozen legacy alias (pre-rename portal logs + the diary's
/// device-observed status mint).
const List<SharedEventType> sharedEventCatalog = <SharedEventType>[
  ...participantEventTypes,
  ...questionnaireEventTypes,
  ...notificationEventTypes,
  ...diaryOriginatedEventTypes,
];

/// Ids intentionally NOT distinct entry types in the frozen surface:
/// - `questionnaire_submitted`: realized as a `finalized`-kind event on a
///   `<id>_survey` entry type, not its own id.
/// - `inbound_tombstone_record_failed`: dropped both sides (idempotent retry).
const List<String> intentionallyAbsentIds = <String>[
  'questionnaire_submitted',
  'inbound_tombstone_record_failed',
];
