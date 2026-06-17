// Verifies: DIARY-PRD-notification-ongoing-epistaxis/A+B+C+D+E+F+G — the
//   reminder service tracks interaction anchors from the `diary_incomplete`
//   view, schedules one notification per interval (A/B), none past the final
//   interval (C), restarts on a later interaction (D), cancels on completion
//   (E) and deletion (F), and never schedules under the empty default (G).
import 'dart:async';

import 'package:clinical_diary/notifications/local_notification_scheduler.dart';
import 'package:clinical_diary/notifications/ongoing_epistaxis_reminder_service.dart';
import 'package:event_sourcing/event_sourcing.dart'
    show Update, Snapshot, Delta, Tombstone, EndOfReplay, SubscriptionFilter;
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction/reaction.dart' show ViewSource;

class _ScheduledCall {
  _ScheduledCall(this.id, this.whenUtc, this.payload);
  final int id;
  final DateTime whenUtc;
  final String? payload;
}

class _FakeScheduler implements LocalNotificationScheduler {
  final List<_ScheduledCall> scheduled = <_ScheduledCall>[];
  final List<int> cancelled = <int>[];
  bool cancelledAll = false;

  @override
  Future<void> schedule({
    required int id,
    required DateTime whenUtc,
    required String title,
    required String body,
    ReminderChannel channel = ReminderChannel.ongoingEpistaxis,
    String? payload,
  }) async {
    scheduled.add(_ScheduledCall(id, whenUtc, payload));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelledAll = true;
}

class _FakeViewSource implements ViewSource {
  // Closed in tearDown.
  // ignore: close_sinks
  final StreamController<Update<Map<String, Object?>>> controller =
      StreamController<Update<Map<String, Object?>>>.broadcast();

  @override
  Stream<Update<T>> watch<T>({
    required String viewName,
    required T Function(Map<String, Object?>) mapper,
    SubscriptionFilter? filter,
    Set<String>? aggregates,
  }) {
    return controller.stream.cast<Update<T>>();
  }
}

void main() {
  late _FakeScheduler scheduler;
  late _FakeViewSource view;
  late OngoingEpistaxisReminderService service;
  var seq = 0;

  final t0 = DateTime.utc(2026, 6, 16, 12);
  // Callisto schedule: 5/10/15/30 → cumulative fire offsets +5/+15/+30/+60.
  const schedule = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];
  const expectedOffsets = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  Map<String, Object?> row(String id, DateTime updatedAt) => {
    'aggregateId': id,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'entryType': 'epistaxis_event',
  };

  void emitDelta(String id, DateTime updatedAt) => view.controller.add(
    Delta(value: row(id, updatedAt), sequence: ++seq, cause: 'checkpoint'),
  );

  void emitSnapshot(String id, DateTime updatedAt) =>
      view.controller.add(Snapshot(value: row(id, updatedAt), sequence: ++seq));

  void emitEndOfReplay() => view.controller.add(EndOfReplay(sequence: ++seq));

  void emitTombstone(String id) =>
      view.controller.add(Tombstone(aggregateId: id, sequence: ++seq));

  setUp(() {
    seq = 0;
    scheduler = _FakeScheduler();
    view = _FakeViewSource();
    service = OngoingEpistaxisReminderService(
      viewSource: view,
      scheduler: scheduler,
      now: () => t0,
    );
  });

  tearDown(() async {
    await service.dispose();
    await view.controller.close();
  });

  test(
    'schedules one notification per interval from the anchor (A/B/C)',
    () async {
      service.updateSchedule(schedule);
      await service.start();
      emitDelta('agg-1', t0);
      await pumpEventQueue();

      expect(scheduler.scheduled, hasLength(4)); // C: exactly the 4 intervals
      expect(scheduler.scheduled.map((c) => c.whenUtc), [
        for (final o in expectedOffsets) t0.add(o),
      ]);
      expect(scheduler.scheduled.every((c) => c.payload == 'agg-1'), isTrue);
    },
  );

  test('snapshot rows are scheduled after end-of-replay', () async {
    service.updateSchedule(schedule);
    await service.start();
    emitSnapshot('agg-1', t0);
    emitEndOfReplay();
    await pumpEventQueue();

    expect(scheduler.scheduled, hasLength(4));
    expect(
      scheduler.scheduled.first.whenUtc,
      t0.add(const Duration(minutes: 5)),
    );
  });

  test('a later interaction cancels and restarts the schedule (D)', () async {
    service.updateSchedule(schedule);
    await service.start();
    emitDelta('agg-1', t0);
    await pumpEventQueue();
    final firstRoundIds = scheduler.scheduled.map((c) => c.id).toSet();
    scheduler.scheduled.clear();
    scheduler.cancelled.clear();

    final t1 = t0.add(const Duration(minutes: 3));
    emitDelta('agg-1', t1);
    await pumpEventQueue();

    // The record's prior notification ids were cancelled...
    expect(scheduler.cancelled.toSet().containsAll(firstRoundIds), isTrue);
    // ...and rescheduled from the new anchor.
    expect(scheduler.scheduled.map((c) => c.whenUtc), [
      for (final o in expectedOffsets) t1.add(o),
    ]);
  });

  test('completion (finalize → tombstone) cancels reminders (E)', () async {
    service.updateSchedule(schedule);
    await service.start();
    emitDelta('agg-1', t0);
    await pumpEventQueue();
    final ids = scheduler.scheduled.map((c) => c.id).toSet();
    scheduler.scheduled.clear();
    scheduler.cancelled.clear();

    emitTombstone('agg-1');
    await pumpEventQueue();

    expect(scheduler.cancelled.toSet().containsAll(ids), isTrue);
    expect(scheduler.scheduled, isEmpty);
  });

  test('deletion (tombstone) cancels reminders (F)', () async {
    // Same removal path as completion; asserted separately for traceability.
    service.updateSchedule(schedule);
    await service.start();
    emitDelta('agg-2', t0);
    await pumpEventQueue();
    expect(scheduler.scheduled, isNotEmpty);
    scheduler.scheduled.clear();
    scheduler.cancelled.clear();

    emitTombstone('agg-2');
    await pumpEventQueue();

    expect(scheduler.cancelled, isNotEmpty);
    expect(scheduler.scheduled, isEmpty);
  });

  test('empty schedule never schedules (G)', () async {
    // No updateSchedule call — default is empty.
    await service.start();
    emitDelta('agg-1', t0);
    await pumpEventQueue();
    expect(scheduler.scheduled, isEmpty);
  });

  test('past-due fire times are skipped', () async {
    // now is 20 minutes after the anchor: +5 and +15 are past; +30 and +60 future.
    service = OngoingEpistaxisReminderService(
      viewSource: view,
      scheduler: scheduler,
      now: () => t0.add(const Duration(minutes: 20)),
    )..updateSchedule(schedule);
    await service.start();
    emitDelta('agg-1', t0);
    await pumpEventQueue();

    expect(scheduler.scheduled.map((c) => c.whenUtc), [
      t0.add(const Duration(minutes: 30)),
      t0.add(const Duration(minutes: 60)),
    ]);
  });

  test('non-epistaxis rows are ignored', () async {
    service.updateSchedule(schedule);
    await service.start();
    view.controller.add(
      Delta(
        value: {
          'aggregateId': 'day-1',
          'updatedAt': t0.toIso8601String(),
          'entryType': 'no_epistaxis_event',
        },
        sequence: ++seq,
        cause: 'finalized',
      ),
    );
    await pumpEventQueue();
    expect(scheduler.scheduled, isEmpty);
  });
}
