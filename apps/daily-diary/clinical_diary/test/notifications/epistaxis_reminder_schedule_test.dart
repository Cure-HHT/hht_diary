// Verifies: DIARY-PRD-notification-ongoing-epistaxis/G+H+I+J — schedule
//   resolution precedence (sponsor-over-personal-over-empty) and A+B+C —
//   cumulative fire times measured from the interaction anchor.
import 'package:clinical_diary/notifications/epistaxis_reminder_schedule.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

SettingPayload _user(Object? value) => SettingPayload(
  key: reminderEpistaxisScheduleKey,
  value: value,
  source: SettingSource.user,
  locked: false,
);

SettingPayload _sponsor(Object? value) => SettingPayload(
  key: reminderEpistaxisScheduleSponsorKey,
  value: value,
  source: SettingSource.sponsor,
  locked: true,
);

void main() {
  group('resolveEpistaxisReminderSchedule', () {
    test('never configured → personal-use default (CUR-863)', () {
      // Deviation from spec assertion G: the default is non-empty so reminders
      // work when not connected to a Sponsor.
      expect(resolveEpistaxisReminderSchedule(const {}), const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 15),
        Duration(minutes: 30),
      ]);
    });

    test('explicit empty personal schedule → off, overrides default', () {
      final schedule = resolveEpistaxisReminderSchedule({
        reminderEpistaxisScheduleKey: _user(<int>[]),
      });
      expect(schedule, isEmpty);
    });

    test('personal schedule only → personal applied (H)', () {
      final schedule = resolveEpistaxisReminderSchedule({
        reminderEpistaxisScheduleKey: _user(<int>[5, 10, 15, 30]),
      });
      expect(schedule, const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 15),
        Duration(minutes: 30),
      ]);
    });

    test('sponsor schedule present → overrides personal (J)', () {
      final schedule = resolveEpistaxisReminderSchedule({
        reminderEpistaxisScheduleKey: _user(<int>[1, 2]),
        reminderEpistaxisScheduleSponsorKey: _sponsor(<int>[5, 10, 15, 30]),
      });
      expect(schedule, const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 15),
        Duration(minutes: 30),
      ]);
    });

    test('sponsor absent + personal present → personal (I/J boundary)', () {
      final schedule = resolveEpistaxisReminderSchedule({
        reminderEpistaxisScheduleKey: _user(<int>[7]),
        // sponsor key present but non-list (null value) → not "in effect"
        reminderEpistaxisScheduleSponsorKey: _sponsor(null),
      });
      expect(schedule, const [Duration(minutes: 7)]);
    });

    test('empty sponsor list is in effect and suppresses personal (J)', () {
      final schedule = resolveEpistaxisReminderSchedule({
        reminderEpistaxisScheduleKey: _user(<int>[5, 10]),
        reminderEpistaxisScheduleSponsorKey: _sponsor(<int>[]),
      });
      expect(schedule, isEmpty);
    });

    test('drops non-positive, non-integer, and over-range entries', () {
      final schedule = resolveEpistaxisReminderSchedule({
        reminderEpistaxisScheduleKey: _user(<Object?>[
          5,
          0,
          -3,
          'x',
          10.0,
          100000,
        ]),
      });
      expect(schedule, const [Duration(minutes: 5), Duration(minutes: 10)]);
    });
  });

  group('fireTimesFor', () {
    final anchor = DateTime.utc(2026, 6, 16, 12);

    test(
      'cumulative offsets, one per interval, none past the last (A/B/C)',
      () {
        final times = fireTimesFor(anchor, const [
          Duration(minutes: 5),
          Duration(minutes: 10),
          Duration(minutes: 15),
          Duration(minutes: 30),
        ]);
        expect(times, [
          anchor.add(const Duration(minutes: 5)),
          anchor.add(const Duration(minutes: 15)),
          anchor.add(const Duration(minutes: 30)),
          anchor.add(const Duration(minutes: 60)),
        ]);
      },
    );

    test('empty schedule → no fire times (G)', () {
      expect(fireTimesFor(anchor, const []), isEmpty);
    });

    test('normalizes the anchor to UTC', () {
      final localAnchor = DateTime(2026, 6, 16, 12);
      final times = fireTimesFor(localAnchor, const [Duration(minutes: 5)]);
      expect(times.single.isUtc, isTrue);
      expect(times.single, localAnchor.toUtc().add(const Duration(minutes: 5)));
    });
  });
}
