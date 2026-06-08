import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-view-action-permissions/A+B
  test('each gated projection maps to its Action permission', () {
    expect(portalViewPermissionNamer('participant_record'),
        'portal.participant.view');
    expect(portalViewPermissionNamer('sites_index'), 'portal.site.view');
    expect(portalViewPermissionNamer('questionnaire_instance'),
        'portal.questionnaire.view_status');
    expect(
        portalViewPermissionNamer('rave_sync_status'), 'portal.rave.view_sync');
    expect(
        portalViewPermissionNamer('users_index'), 'portal.user.view_accounts');
    expect(portalViewPermissionNamer('user_role_scopes'),
        'portal.user.view_accounts');
    expect(portalViewPermissionNamer('diary_entries'),
        'portal.diary.view_entries');
  });

  test(
      'an unknown projection is denied by default (no permission can grant it)',
      () {
    expect(
      portalViewPermissionNamer('some_unregistered_view'),
      equals('view:some_unregistered_view'),
    );
  });
}
