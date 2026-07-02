// Implements: DIARY-DEV-action-write-path/A — the single registration site for
//   every diary write-intent dispatched through the core ActionDispatcher.
import 'package:clinical_diary/actions/acknowledge_recall_action.dart';
import 'package:clinical_diary/actions/checkpoint_epistaxis_event_action.dart';
import 'package:clinical_diary/actions/checkpoint_questionnaire_action.dart';
import 'package:clinical_diary/actions/clear_questionnaire_recall_action.dart';
import 'package:clinical_diary/actions/delete_entry_action.dart';
import 'package:clinical_diary/actions/discard_questionnaire_draft_action.dart';
import 'package:clinical_diary/actions/edit_epistaxis_event_action.dart';
import 'package:clinical_diary/actions/inbound_system_actions.dart';
import 'package:clinical_diary/actions/record_day_marker_action.dart';
import 'package:clinical_diary/actions/record_epistaxis_event_action.dart';
import 'package:clinical_diary/actions/record_participant_linked_action.dart';
import 'package:clinical_diary/actions/record_questionnaire_finalized_action.dart';
import 'package:clinical_diary/actions/record_questionnaire_recalled_action.dart';
import 'package:clinical_diary/actions/settings_actions.dart';
import 'package:clinical_diary/actions/submit_questionnaire_action.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Builds the [ActionRegistry] with every diary Action registered.
ActionRegistry buildDiaryActionRegistry() {
  return ActionRegistry()
    ..register(RecordEpistaxisEventAction())
    ..register(const RecordNoEpistaxisDayAction())
    ..register(const RecordUnknownDayAction())
    ..register(const EditEpistaxisEventAction())
    ..register(const CheckpointEpistaxisEventAction())
    ..register(const DeleteEntryAction())
    ..register(const SubmitQuestionnaireAction())
    ..register(const CheckpointQuestionnaireAction())
    ..register(const DiscardQuestionnaireDraftAction())
    ..register(const RecordFcmMessageReceivedAction())
    ..register(const RegisterFcmTokenAction())
    ..register(const SetUserSettingAction())
    ..register(const ApplySponsorSettingsAction())
    ..register(const UnlockSponsorSettingsAction())
    ..register(const RecordParticipantLinkedAction())
    ..register(const RecordQuestionnaireFinalizedAction())
    ..register(const RecordQuestionnaireUnlockedAction())
    ..register(const RecordQuestionnaireRecalledAction())
    ..register(const AcknowledgeRecallAction())
    ..register(const ClearQuestionnaireRecallAction());
}
