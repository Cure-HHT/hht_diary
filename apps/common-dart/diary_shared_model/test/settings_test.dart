// Verifies: DIARY-BASE-sponsor-requested-settings/B+F
// Verifies: DIARY-DEV-shared-events-catalog/A+D
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  group('SettingPayload', () {
    test('round-trips a sponsor-locked setting', () {
      const p = SettingPayload(
        key: 'clinical.lockThresholdHours',
        value: 48,
        source: SettingSource.sponsor,
        locked: true,
      );
      final back = SettingPayload.fromJson(p.toJson());
      expect(back.key, 'clinical.lockThresholdHours');
      expect(back.value, 48);
      expect(back.source, SettingSource.sponsor);
      expect(back.locked, isTrue);
    });

    test('round-trips a user setting (unlocked)', () {
      const p = SettingPayload(
        key: 'pref.darkMode',
        value: true,
        source: SettingSource.user,
        locked: false,
      );
      final back = SettingPayload.fromJson(p.toJson());
      expect(back.source, SettingSource.user);
      expect(back.locked, isFalse);
      expect(back.value, true);
    });

    test('rejects an unknown source', () {
      expect(
        () => SettingPayload.fromJson(const {
          'key': 'x',
          'value': 1,
          'source': 'martian',
          'locked': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('DIARY-DEV-shared-events-catalog/D: no secret fields', () {
      final json = const SettingPayload(
        key: 'pref.darkMode',
        value: true,
        source: SettingSource.user,
        locked: false,
      ).toJson();
      for (final forbidden in const [
        'otp',
        'recovery',
        'session',
        'password',
        'token',
      ]) {
        expect(json.keys.any((k) => k.toLowerCase() == forbidden), isFalse);
      }
    });
  });

  group('EntryGateRules.fromSettings', () {
    SettingPayload sponsor(String key, Object? value) => SettingPayload(
      key: key,
      value: value,
      source: SettingSource.sponsor,
      locked: true,
    );

    test('maps clinical threshold hours into Durations', () {
      final cfg = EntryGateRules.fromSettings(<String, SettingPayload>{
        'clinical.justificationThresholdHours': sponsor(
          'clinical.justificationThresholdHours',
          24,
        ),
        'clinical.lockThresholdHours': sponsor(
          'clinical.lockThresholdHours',
          48,
        ),
      }, trialStart: DateTime.utc(2025, 10, 1));
      expect(cfg.justificationThreshold, const Duration(hours: 24));
      expect(cfg.lockThreshold, const Duration(hours: 48));
      expect(cfg.trialStart, DateTime.utc(2025, 10, 1));
    });

    test('absent threshold keys yield null thresholds (gate = allowed)', () {
      final cfg = EntryGateRules.fromSettings(
        const <String, SettingPayload>{},
        trialStart: null,
      );
      expect(cfg.justificationThreshold, isNull);
      expect(cfg.lockThreshold, isNull);
      expect(cfg.trialStart, isNull);
    });
  });

  group('ClinicalRules.fromSettings', () {
    SettingPayload of(String key, Object? value, SettingSource source) =>
        SettingPayload(
          key: key,
          value: value,
          source: source,
          locked: source == SettingSource.sponsor,
        );

    test('empty settings yield no restrictions (all off, permissive gate)', () {
      final r = ClinicalRules.fromSettings(
        const <String, SettingPayload>{},
        trialStart: null,
      );
      expect(r.shortDurationConfirm, isFalse);
      expect(r.longDurationConfirm, isFalse);
      expect(r.longDurationThresholdMinutes, 240);
      expect(r.useReviewScreen, isFalse);
      expect(r.gate.justificationThreshold, isNull);
      expect(r.gate.lockThreshold, isNull);
    });

    test('maps every clinical key (incl. the gate thresholds)', () {
      final r = ClinicalRules.fromSettings(<String, SettingPayload>{
        justificationThresholdHoursKey: of(
          justificationThresholdHoursKey,
          24,
          SettingSource.sponsor,
        ),
        lockThresholdHoursKey: of(
          lockThresholdHoursKey,
          72,
          SettingSource.sponsor,
        ),
        shortDurationConfirmKey: of(
          shortDurationConfirmKey,
          true,
          SettingSource.sponsor,
        ),
        longDurationConfirmKey: of(
          longDurationConfirmKey,
          true,
          SettingSource.sponsor,
        ),
        longDurationThresholdMinutesKey: of(
          longDurationThresholdMinutesKey,
          240,
          SettingSource.sponsor,
        ),
        useReviewScreenKey: of(useReviewScreenKey, true, SettingSource.sponsor),
      }, trialStart: DateTime.utc(2025, 10, 1));
      expect(r.gate.justificationThreshold, const Duration(hours: 24));
      expect(r.gate.lockThreshold, const Duration(hours: 72));
      expect(r.gate.trialStart, DateTime.utc(2025, 10, 1));
      expect(r.shortDurationConfirm, isTrue);
      expect(r.longDurationConfirm, isTrue);
      expect(r.longDurationThresholdMinutes, 240);
      expect(r.useReviewScreen, isTrue);
    });

    test(
      'derivation is source-agnostic: a user-set rule reads identically',
      () {
        final asUser = ClinicalRules.fromSettings(<String, SettingPayload>{
          lockThresholdHoursKey: of(
            lockThresholdHoursKey,
            48,
            SettingSource.user,
          ),
          shortDurationConfirmKey: of(
            shortDurationConfirmKey,
            true,
            SettingSource.user,
          ),
        }, trialStart: null);
        expect(asUser.gate.lockThreshold, const Duration(hours: 48));
        expect(asUser.shortDurationConfirm, isTrue);
      },
    );

    test('lockedKeys reflects sponsor-locked settings only', () {
      final r = ClinicalRules.fromSettings(<String, SettingPayload>{
        // sponsor-applied => locked
        lockThresholdHoursKey: of(
          lockThresholdHoursKey,
          72,
          SettingSource.sponsor,
        ),
        // user-set => not locked
        shortDurationConfirmKey: of(
          shortDurationConfirmKey,
          true,
          SettingSource.user,
        ),
      }, trialStart: null);
      expect(r.isLocked(lockThresholdHoursKey), isTrue);
      expect(r.isLocked(shortDurationConfirmKey), isFalse);
      expect(r.lockedKeys, {lockThresholdHoursKey});
    });

    test('wrong-typed values fall back to defaults', () {
      final r = ClinicalRules.fromSettings(<String, SettingPayload>{
        shortDurationConfirmKey: of(
          shortDurationConfirmKey,
          'yes',
          SettingSource.user,
        ),
        longDurationThresholdMinutesKey: of(
          longDurationThresholdMinutesKey,
          '240',
          SettingSource.user,
        ),
      }, trialStart: null);
      expect(r.shortDurationConfirm, isFalse);
      expect(r.longDurationThresholdMinutes, 240);
    });
  });
}
