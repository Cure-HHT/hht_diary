// Verifies: DIARY-BASE-sponsor-requested-settings/A
// Verifies: DIARY-DEV-action-write-path/A
import 'package:clinical_diary/actions/settings_actions.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _ctx() => ActionContext(
  principal: UserPrincipal(
    userId: 'P-42',
    roles: const {'participant'},
    activeRole: 'participant',
  ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2025, 10, 16, 12),
);

void main() {
  group('SetUserSettingAction', () {
    const action = SetUserSettingAction();

    test(
      'emits a finalized setting_applied (source: user, locked: false)',
      () async {
        final input = action.parseInput(const {
          'key': 'pref.darkMode',
          'value': true,
        });
        action.validate(input);
        final draft = (await action.execute(input, _ctx())).events.single;
        expect(draft.aggregateType, settingAggregateType);
        expect(draft.aggregateId, 'pref.darkMode'); // per-key aggregate
        expect(draft.entryType, 'setting_applied');
        expect(draft.eventType, 'finalized');
        expect(draft.data['source'], 'user');
        expect(draft.data['locked'], false);
        expect(draft.data['value'], true);
      },
    );

    test('parseInput rejects a missing/empty key', () {
      expect(
        () => action.parseInput(const {'value': true}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => action.parseInput(const {'key': '', 'value': true}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
