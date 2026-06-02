// Verifies: DIARY-BASE-local-data-reset/B+C — reset is forbidden while
//   participating regardless of the setting; the sponsor-controllable
//   allow_local_reset setting gates it otherwise (default enabled).
import 'package:clinical_diary/settings/local_reset_policy.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

SettingPayload _setting(Object? value, {bool locked = false}) => SettingPayload(
  key: kAllowLocalResetKey,
  value: value,
  source: SettingSource.sponsor,
  locked: locked,
);

void main() {
  group('allowLocalResetSetting', () {
    test('defaults to true when absent', () {
      expect(allowLocalResetSetting(const {}), isTrue);
    });

    test('honors an explicit false', () {
      expect(
        allowLocalResetSetting({kAllowLocalResetKey: _setting(false)}),
        isFalse,
      );
    });

    test('honors an explicit true', () {
      expect(
        allowLocalResetSetting({kAllowLocalResetKey: _setting(true)}),
        isTrue,
      );
    });

    test('defaults to true for a non-bool value', () {
      expect(
        allowLocalResetSetting({kAllowLocalResetKey: _setting('nope')}),
        isTrue,
      );
    });
  });

  group('canResetLocalData', () {
    test('blocked while participating, even if the setting allows it', () {
      expect(
        canResetLocalData(participating: true, settingAllowsReset: true),
        isFalse,
      );
    });

    test('allowed when not participating and the setting allows it', () {
      expect(
        canResetLocalData(participating: false, settingAllowsReset: true),
        isTrue,
      );
    });

    test(
      'blocked when the setting disallows it, even if not participating',
      () {
        expect(
          canResetLocalData(participating: false, settingAllowsReset: false),
          isFalse,
        );
      },
    );
  });
}
