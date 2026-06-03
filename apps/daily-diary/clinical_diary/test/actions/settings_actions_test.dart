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

  group('ApplySponsorSettingsAction', () {
    const apply = ApplySponsorSettingsAction();

    test('emits one locked sponsor setting_applied per key', () async {
      final input = apply.parseInput(const {
        'settings': {
          'clinical.lockThresholdHours': 48,
          'useReviewScreen': true,
        },
      });
      apply.validate(input);
      final events = (await apply.execute(input, _ctx())).events;
      expect(events.length, 2);
      for (final e in events) {
        expect(e.aggregateType, settingAggregateType);
        expect(e.entryType, 'setting_applied');
        expect(e.data['source'], 'sponsor');
        expect(e.data['locked'], true);
      }
      final byKey = {for (final e in events) e.aggregateId: e.data['value']};
      expect(byKey['clinical.lockThresholdHours'], 48);
      expect(byKey['useReviewScreen'], true);
    });

    test('parseInput rejects a missing settings map', () {
      expect(() => apply.parseInput(const {}), throwsA(isA<FormatException>()));
    });

    test('validate rejects an empty settings map', () {
      final input = apply.parseInput(const {'settings': <String, Object?>{}});
      expect(() => apply.validate(input), throwsArgumentError);
    });
  });

  group('UnlockSponsorSettingsAction', () {
    const unlock = UnlockSponsorSettingsAction();

    test(
      'emits keep-as-is unlock (source: sponsor, locked: false) per key',
      () async {
        final input = unlock.parseInput(const {
          'lockedSettings': {'clinical.lockThresholdHours': 48},
        });
        unlock.validate(input);
        final draft = (await unlock.execute(input, _ctx())).events.single;
        expect(draft.entryType, 'setting_applied');
        expect(draft.aggregateId, 'clinical.lockThresholdHours');
        expect(draft.data['source'], 'sponsor');
        expect(draft.data['locked'], false);
        expect(draft.data['value'], 48); // keep-as-is
      },
    );

    test('parseInput rejects a missing lockedSettings map', () {
      expect(
        () => unlock.parseInput(const {}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
