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

  group('entryRestrictionConfigFromSettings', () {
    SettingPayload sponsor(String key, Object? value) => SettingPayload(
      key: key,
      value: value,
      source: SettingSource.sponsor,
      locked: true,
    );

    test('maps clinical threshold hours into Durations', () {
      final cfg = entryRestrictionConfigFromSettings(<String, SettingPayload>{
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
      final cfg = entryRestrictionConfigFromSettings(
        const <String, SettingPayload>{},
        trialStart: null,
      );
      expect(cfg.justificationThreshold, isNull);
      expect(cfg.lockThreshold, isNull);
      expect(cfg.trialStart, isNull);
    });
  });
}
