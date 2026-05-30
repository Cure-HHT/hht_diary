// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import 'actions/deactivate_user_account_action.dart';
import 'actions/participant/disconnect_participant_action.dart';
import 'actions/participant/link_participant_action.dart';
import 'actions/participant/mark_not_participating_action.dart';
import 'actions/participant/reactivate_participant_action.dart';
import 'actions/participant/reconnect_participant_action.dart';
import 'actions/participant/start_trial_action.dart';
import 'actions/participant/view_participant_action.dart';
import 'actions/questionnaire/call_back_questionnaire_action.dart';
import 'actions/questionnaire/finalize_questionnaire_action.dart';
import 'actions/questionnaire/send_questionnaire_action.dart';
import 'actions/questionnaire/unlock_questionnaire_action.dart';
import 'actions/user_account/assign_role_action.dart';
import 'actions/user_account/assign_site_action.dart';
import 'actions/user_account/create_user_account_action.dart';
import 'actions/user_account/delete_pending_user_action.dart';
import 'actions/user_account/edit_user_account_action.dart';
import 'actions/user_account/reactivate_user_account_action.dart';
import 'actions/user_account/resend_activation_email_action.dart';
import 'actions/user_account/unlock_user_account_action.dart';
import 'actions/views/view_admin_settings_action.dart';
import 'actions/views/view_audit_log_action.dart';
import 'actions/views/view_sites_action.dart';
import 'flow_token_minter.dart';

/// Build the portal's ActionRegistry. Extend as concrete actions land.
ActionRegistry buildPortalActionRegistry({FlowTokenMinter? flowTokenMinter}) {
  final minter = flowTokenMinter ?? SerialFlowTokenMinter();
  final registry = ActionRegistry()
    ..register(DeactivateUserAccountAction())
    ..register(LinkParticipantAction())
    ..register(StartTrialAction(flowTokenMinter: minter))
    ..register(DisconnectParticipantAction(flowTokenMinter: minter))
    ..register(ReconnectParticipantAction(flowTokenMinter: minter))
    ..register(MarkNotParticipatingAction(flowTokenMinter: minter))
    ..register(ReactivateParticipantAction(flowTokenMinter: minter))
    ..register(ViewParticipantAction())
    ..register(SendQuestionnaireAction(flowTokenMinter: minter))
    ..register(CallBackQuestionnaireAction(flowTokenMinter: minter))
    ..register(FinalizeQuestionnaireAction())
    ..register(UnlockQuestionnaireAction(flowTokenMinter: minter))
    ..register(CreateUserAccountAction(flowTokenMinter: minter))
    ..register(EditUserAccountAction())
    ..register(ReactivateUserAccountAction(flowTokenMinter: minter))
    ..register(UnlockUserAccountAction())
    ..register(ResendActivationEmailAction(flowTokenMinter: minter))
    ..register(AssignRoleAction())
    ..register(AssignSiteAction())
    ..register(DeletePendingUserAction())
    ..register(ViewSitesAction())
    ..register(ViewAuditLogAction())
    ..register(ViewAdminSettingsAction());
  return registry;
}
