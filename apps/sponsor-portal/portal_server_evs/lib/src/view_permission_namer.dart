// Implements: DIARY-DEV-view-action-permissions/A+B — read-model subscriptions
//   gate on the Action permission that governs the underlying data, instead of
//   the framework default `view:<projection>`. Projections backing an inventory
//   entity-read Action reuse that Action's permission (A); internal feeds gate
//   on their ACT-SEE-* View Action permission (B).
import 'package:reaction/reaction.dart' show ViewPermissionNamer;

/// Projection view-name -> the Action permission name required to subscribe.
///
/// One Action may gate two projections (users_index + user_role_scopes both
/// gate on ACT-SEE-003 portal.user.view_accounts).
const Map<String, String> _viewPermissionByProjection = <String, String>{
  // Entity reads — existing inventory Actions (stable IDs).
  'participant_record': 'portal.participant.view', // ACT-PAT-007
  'sites_index': 'portal.site.view', // ACT-SIT-001
  // Internal feeds — new ACT-SEE-* View Actions.
  'questionnaire_instance': 'portal.questionnaire.view_status', // ACT-SEE-001
  'rave_sync_status': 'portal.rave.view_sync', // ACT-SEE-002
  'users_index': 'portal.user.view_accounts', // ACT-SEE-003
  'user_role_scopes': 'portal.user.view_accounts', // ACT-SEE-003
  'diary_entries': 'portal.diary.view_entries', // ACT-SEE-004
};

/// The portal's [ViewPermissionNamer]. A registered projection gates on its
/// Action permission. An UNREGISTERED projection fails closed: it returns the
/// framework-style `view:<name>` sentinel, which no role holds (all role grants
/// are Action permissions now), so the subscription is denied rather than
/// silently allowed.
// ignore: prefer_function_declarations_over_variables
final ViewPermissionNamer portalViewPermissionNamer = (String viewName) =>
    _viewPermissionByProjection[viewName] ?? 'view:$viewName';
