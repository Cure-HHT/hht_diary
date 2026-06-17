// Verifies: DIARY-PRD-notification-yesterday-entry/A+B+C+D+E — the service
//   schedules the daily reminder when the previous local day is unrecorded (A),
//   at the local Reminder Time (B/C), suppresses when a Daily Status exists (D),
//   and keeps a single pending notification per day (E).
import 'dart:async';

import 'package:clinical_diary/notifications/local_notification_scheduler.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_schedule.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_service.dart';
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show EntryGateRules, diaryEntriesViewName;
import 'package:event_sourcing/event_sourcing.dart'
    show Update, Snapshot, EndOfReplay, SubscriptionFilter;
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction/reaction.dart' show ViewSource;

class _ScheduledCall {
  _ScheduledCall(this.id, this.whenUtc, this.channel, this.payload);
  final int id;
  final DateTime whenUtc;
  final ReminderChannel channel;
  final String? payload;
}

class _FakeScheduler implements LocalNotificationScheduler {
  final List<_ScheduledCall> scheduled = <_ScheduledCall>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> schedule({
    required int id,
    required DateTime whenUtc,
    required String title,
    required String body,
    ReminderChannel channel = ReminderChannel.ongoingEpistaxis,
    String? payload,
  }) async {
    scheduled.add(_ScheduledCall(id, whenUtc, channel, payload));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async {}
}

class _FakeViewSource implements ViewSource {
  final Map<String, List<Map<String, Object?>>> rows =
      <String, List<Map<String, Object?>>>{};
  int _seq = 0;

  @override
  Stream<Update<T>> watch<T>({
    required String viewName,
    required T Function(Map<String, Object?>) mapper,
    SubscriptionFilter? filter,
    Set<String>? aggregates,
  }) {
    final view = rows[viewName] ?? const <Map<String, Object?>>[];
    final updates = <Update<Map<String, Object?>>>[
      for (final r in view) Snapshot(value: r, sequence: ++_seq),
      EndOfReplay(sequence: ++_seq),
    ];
    return Stream<Update<Map<String, Object?>>>.fromIterable(
      updates,
    ).cast<Update<T>>();
  }
}

void main() {
  late _FakeScheduler scheduler;
  late _FakeViewSource view;

  // 2026-06-16 is "today"; "yesterday" is 2026-06-15.
  final now0700 = DateTime(2026, 6, 16, 7);
  final now1000 = DateTime(2026, 6, 16, 10);

  Map<String, Object?> noEvent(String date) => <String, Object?>{
    'aggregateId': 'day-$date',
    'entryType': 'no_epistaxis_event',
    'date': date,
  };
  Map<String, Object?> incompleteEpistaxis(String date) => <String, Object?>{
    'aggregateId': 'inc-$date',
    'entryType': 'epistaxis_event',
    'startTime': '${date}T10:00',
  };

  YesterdayReminderService build(DateTime Function() now) =>
      YesterdayReminderService(
        viewSource: view,
        scheduler: scheduler,
        now: now,
      );

  setUp(() {
    scheduler = _FakeScheduler();
    view = _FakeViewSource();
  });

  test(
    'schedules at the local Reminder Time when yesterday unrecorded (A/B/C)',
    () async {
      final service = build(() => now0700);
      await service.reevaluate();

      expect(scheduler.scheduled, hasLength(1));
      final call = scheduler.scheduled.single;
      expect(call.id, kYesterdayReminderNotificationId);
      expect(call.channel, ReminderChannel.dailyReminder);
      expect(call.payload, kYesterdayReminderPayload);
      // Default 09:00 today, local → UTC.
      expect(call.whenUtc, DateTime(2026, 6, 16, 9).toUtc());
    },
  );

  test('suppresses when yesterday has a Daily Status (D)', () async {
    view.rows[diaryEntriesViewName] = [noEvent('2026-06-15')];
    final service = build(() => now0700);
    await service.reevaluate();
    expect(scheduler.scheduled, isEmpty);
  });

  test('suppresses when yesterday has an incomplete epistaxis draft', () async {
    view.rows[diaryIncompleteViewName] = [incompleteEpistaxis('2026-06-15')];
    final service = build(() => now0700);
    await service.reevaluate();
    expect(scheduler.scheduled, isEmpty);
  });

  test('does not schedule when disabled', () async {
    final service = build(() => now0700);
    await service.updateConfig(
      config: const YesterdayReminderConfig(enabled: false, timeMinutes: 540),
      gate: const EntryGateRules(),
    );
    expect(scheduler.scheduled, isEmpty);
  });

  test(
    'after the time, schedules tomorrow; recording today then cancels',
    () async {
      final service = build(() => now1000);
      // now 10:00 > 09:00 → next fire is tomorrow 09:00, reviewing today.
      await service.reevaluate();
      expect(scheduler.scheduled, hasLength(1));
      expect(
        scheduler.scheduled.single.whenUtc,
        DateTime(2026, 6, 17, 9).toUtc(),
      );

      // Today (2026-06-16) gets a status → re-eval cancels.
      view.rows[diaryEntriesViewName] = [noEvent('2026-06-16')];
      await service.reevaluate();
      expect(scheduler.cancelled, contains(kYesterdayReminderNotificationId));
    },
  );

  test('idempotent — one notification scheduled per day (E)', () async {
    final service = build(() => now0700);
    await service.reevaluate();
    await service.reevaluate();
    await service.reevaluate();
    expect(scheduler.scheduled, hasLength(1));
  });

  test('does not schedule when the reviewed day is locked', () async {
    final service = build(() => now0700);
    await service.updateConfig(
      config: const YesterdayReminderConfig(enabled: true, timeMinutes: 540),
      // 1h lock → yesterday (2026-06-15 midnight) is long past locked at now.
      gate: const EntryGateRules(lockThreshold: Duration(hours: 1)),
    );
    expect(scheduler.scheduled, isEmpty);
  });
}
