// Verifies: DIARY-DEV-action-write-path/A
import 'package:clinical_diary/scope/diary_action_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers every diary action by name', () {
    final registry = buildDiaryActionRegistry();
    final names = registry.all.map((a) => a.name).toSet();
    expect(
      names,
      containsAll(<String>[
        'record_epistaxis_event',
        'record_no_epistaxis_day',
        'record_unknown_day',
        'edit_epistaxis_event',
        'delete_entry',
        'submit_questionnaire',
        'record_fcm_message_received',
        'register_fcm_token',
        'set_user_setting',
        'apply_sponsor_settings',
        'unlock_sponsor_settings',
        'record_patient_linked',
      ]),
    );
  });
}
