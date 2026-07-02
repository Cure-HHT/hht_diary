// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import 'actions/deactivate_user_account_action.dart';
import 'actions/ops/create_privileged_user_action.dart';
import 'actions/ops/unwedge_rave_sync_action.dart';
import 'actions/participant/disconnect_participant_action.dart';
import 'actions/participant/link_participant_action.dart';
import 'actions/participant/mark_not_participating_action.dart';
import 'actions/participant/reactivate_participant_action.dart';
import 'actions/participant/reconnect_participant_action.dart';
import 'actions/participant/start_trial_action.dart';
import 'actions/participant/view_participant_action.dart';
import 'actions/questionnaire/call_back_questionnaire_action.dart';
import 'actions/questionnaire/lock_questionnaire_action.dart';
import 'actions/questionnaire/send_questionnaire_action.dart';
import 'actions/questionnaire/unlock_questionnaire_action.dart';
import 'actions/user_account/assign_role_action.dart';
import 'actions/user_account/assign_site_action.dart';
import 'actions/user_account/create_user_account_action.dart';
import 'actions/user_account/delete_pending_user_action.dart';
import 'actions/user_account/edit_user_account_action.dart';
import 'actions/user_account/reactivate_user_account_action.dart';
import 'actions/user_account/resend_activation_email_action.dart';
import 'actions/user_account/revoke_role_action.dart';
import 'actions/user_account/revoke_site_action.dart';
import 'actions/user_account/unlock_user_account_action.dart';
import 'actions/views/view_admin_settings_action.dart';
import 'actions/views/view_audit_log_action.dart';
import 'actions/views/view_diary_entries_action.dart';
import 'actions/views/view_questionnaire_status_action.dart';
import 'actions/views/view_rave_sync_status_action.dart';
import 'actions/views/view_sites_action.dart';
import 'actions/views/view_user_accounts_action.dart';
import 'flow_token_minter.dart';

/// Build the portal's ActionRegistry. Extend as concrete actions land.
ActionRegistry buildPortalActionRegistry({
  FlowTokenMinter? flowTokenMinter,
  String linkingPrefix = 'XX',
  String sponsorResolverKey = '',
}) {
  final minter = flowTokenMinter ?? SerialFlowTokenMinter();
  final registry = ActionRegistry()
    ..register(DeactivateUserAccountAction())
    ..register(
      LinkParticipantAction(
        linkingPrefix: linkingPrefix,
        sponsorResolverKey: sponsorResolverKey,
      ),
    )
    ..register(StartTrialAction(flowTokenMinter: minter))
    ..register(DisconnectParticipantAction(flowTokenMinter: minter))
    ..register(
      ReconnectParticipantAction(
        flowTokenMinter: minter,
        linkingPrefix: linkingPrefix,
        sponsorResolverKey: sponsorResolverKey,
      ),
    )
    ..register(MarkNotParticipatingAction(flowTokenMinter: minter))
    ..register(
      ReactivateParticipantAction(
        flowTokenMinter: minter,
        linkingPrefix: linkingPrefix,
        sponsorResolverKey: sponsorResolverKey,
      ),
    )
    ..register(ViewParticipantAction())
    ..register(SendQuestionnaireAction(flowTokenMinter: minter))
    ..register(CallBackQuestionnaireAction(flowTokenMinter: minter))
    ..register(LockQuestionnaireAction())
    ..register(UnlockQuestionnaireAction(flowTokenMinter: minter))
    ..register(CreateUserAccountAction(flowTokenMinter: minter))
    ..register(EditUserAccountAction())
    ..register(ReactivateUserAccountAction(flowTokenMinter: minter))
    ..register(UnlockUserAccountAction())
    ..register(ResendActivationEmailAction(flowTokenMinter: minter))
    ..register(AssignRoleAction())
    ..register(AssignSiteAction())
    ..register(RevokeRoleAction())
    ..register(RevokeSiteAction())
    ..register(DeletePendingUserAction())
    ..register(ViewSitesAction())
    ..register(ViewAuditLogAction())
    ..register(ViewAdminSettingsAction())
    ..register(ViewQuestionnaireStatusAction())
    ..register(ViewRaveSyncStatusAction())
    ..register(ViewUserAccountsAction())
    ..register(ViewDiaryEntriesAction())
    ..register(UnwedgeRaveSyncAction())
    ..register(CreateAdministratorAction())
    ..register(CreateSystemOperatorAction());
  return registry;
}
