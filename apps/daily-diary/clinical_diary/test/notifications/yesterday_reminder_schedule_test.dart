// Verifies: DIARY-PRD-notification-yesterday-entry/F — Reminder Time / enable
//   resolution: sponsor overrides personal, sponsor force-enable, defaults, and
//   off-grid/out-of-range clamping.
import 'package:clinical_diary/notifications/yesterday_reminder_schedule.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

SettingPayload _user(String key, Object? value) => SettingPayload(
  key: key,
  value: value,
  source: SettingSource.user,
  locked: false,
);

SettingPayload _sponsor(String key, Object? value) => SettingPayload(
  key: key,
  value: value,
  source: SettingSource.sponsor,
  locked: true,
);

void main() {
  group('resolveYesterdayReminderConfig', () {
    test('defaults: enabled, 09:00', () {
      final c = resolveYesterdayReminderConfig(const {});
      expect(c.enabled, isTrue);
      expect(c.timeMinutes, kDefaultYesterdayReminderMinutes); // 540
    });

    test('personal time + enabled applied', () {
      final c = resolveYesterdayReminderConfig({
        reminderYesterdayTimeMinutesKey: _user(
          reminderYesterdayTimeMinutesKey,
          7 * 60,
        ),
        reminderYesterdayEnabledKey: _user(reminderYesterdayEnabledKey, false),
      });
      expect(c.timeMinutes, 7 * 60);
      expect(c.enabled, isFalse);
    });

    test('sponsor time overrides personal (F)', () {
      final c = resolveYesterdayReminderConfig({
        reminderYesterdayTimeMinutesKey: _user(
          reminderYesterdayTimeMinutesKey,
          7 * 60,
        ),
        reminderYesterdayTimeMinutesSponsorKey: _sponsor(
          reminderYesterdayTimeMinutesSponsorKey,
          9 * 60,
        ),
      });
      expect(c.timeMinutes, 9 * 60);
    });

    test('sponsor force-enable overrides a personal disable', () {
      final c = resolveYesterdayReminderConfig({
        reminderYesterdayEnabledKey: _user(reminderYesterdayEnabledKey, false),
        reminderYesterdayEnabledSponsorKey: _sponsor(
          reminderYesterdayEnabledSponsorKey,
          true,
        ),
      });
      expect(c.enabled, isTrue);
    });

    test('off-grid and out-of-range times are snapped/clamped', () {
      expect(
        resolveYesterdayReminderConfig({
          reminderYesterdayTimeMinutesKey: _user(
            reminderYesterdayTimeMinutesKey,
            7 * 60 + 10, // 07:10 → 07:00
          ),
        }).timeMinutes,
        7 * 60,
      );
      expect(
        resolveYesterdayReminderConfig({
          reminderYesterdayTimeMinutesKey: _user(
            reminderYesterdayTimeMinutesKey,
            7 * 60 + 20, // 07:20 → 07:30
          ),
        }).timeMinutes,
        7 * 60 + 30,
      );
      expect(
        resolveYesterdayReminderConfig({
          reminderYesterdayTimeMinutesKey: _user(
            reminderYesterdayTimeMinutesKey,
            99 * 60, // clamps to 23:30
          ),
        }).timeMinutes,
        23 * 60 + 30,
      );
    });
  });
}
