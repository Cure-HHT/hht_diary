/// diary_shared_model: the cross-wire event entry-type catalog.
library;

export 'src/event_origin.dart';
export 'src/participant_events.dart';
export 'src/questionnaire_events.dart';
export 'src/notification_events.dart';
export 'src/catalog.dart';
export 'src/diary_originated_events.dart';
export 'src/diary_payloads.dart';
export 'src/questionnaire_submission.dart';
export 'src/inbound_payloads.dart';
export 'src/settings.dart';
export 'src/participant_payloads.dart';
export 'src/diary_projection.dart';
export 'src/change_reasons.dart';
export 'src/entry_restrictions.dart';
export 'src/sponsor_ui_config.dart';

// CUR-1557 test (c): shared-lib code change; expect selective run of diary_shared_model + dependents.
