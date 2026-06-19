// Implements: DIARY-PRD-notification-yesterday-entry/A+B+C+D+E — schedules the
//   daily Yesterday Entry Reminder:
//     A — when the previous calendar day has no Daily Status, schedule a push at
//         the Reminder Time.
//     B — the Reminder Time is computed in the device-local timezone (local
//         `DateTime`, converted to an absolute UTC instant for the OS).
//     C — "the previous calendar day" is the local calendar day before now.
//     D — when a Daily Status exists for the reviewed day, cancel / never
//         schedule. Re-evaluated on every trigger (app resume / periodic / after
//         a record), so recording yesterday cancels the pending reminder.
//     E — a single stable notification id means at most one reminder is pending
//         (hence delivered) per calendar day.
//
// The reminder is tap-to-open: tapping surfaces the existing on-screen Yesterday
// Reminder Task (the `YesterdayBanner`), which carries the No / Unknown / Add
// actions. This service does not create records itself.
import 'dart:async';

import 'package:clinical_diary/notifications/local_notification_scheduler.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_schedule.dart';
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show EntryGate, EntryGateRules, diaryEntriesViewName, entryGateForDate;
import 'package:event_sourcing/event_sourcing.dart'
    show Update, Snapshot, EndOfReplay;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:reaction/reaction.dart' show ViewSource;

/// Stable notification id for the Yesterday reminder. Chosen above the Ongoing
/// Epistaxis id range (`base<2^26> * 16 + index`, max ≈ 0x3FFFFFFF) so the two
/// features never collide.
const int kYesterdayReminderNotificationId = 2000000001;

/// Payload tag carried on the notification so a tap can be routed to the home
/// screen (where the Yesterday banner surfaces).
const String kYesterdayReminderPayload = 'yesterday_reminder';

const String _kTitle = "Yesterday's diary";
const String _kBody = 'Did you have any nosebleeds yesterday? Tap to record.';

/// Observes the diary read views and schedules / cancels the daily Yesterday
/// Entry Reminder. Drive [reevaluate] from the app's sync triggers; feed the
/// resolved config via [updateConfig]; [dispose] is a no-op beyond marking the
/// service inert (the pending OS notification persists by design).
class YesterdayReminderService {
  YesterdayReminderService({
    required ViewSource viewSource,
    required LocalNotificationScheduler scheduler,
    DateTime Function() now = DateTime.now,
  }) : _viewSource = viewSource,
       _scheduler = scheduler,
       _now = now;

  final ViewSource _viewSource;
  final LocalNotificationScheduler _scheduler;
  final DateTime Function() _now;

  YesterdayReminderConfig _config = const YesterdayReminderConfig(
    enabled: true,
    timeMinutes: kDefaultYesterdayReminderMinutes,
  );
  EntryGateRules _gate = const EntryGateRules();

  bool _disposed = false;
  bool _hasScheduled = false;
  DateTime? _scheduledFireUtc;

  // Serial guard: overlapping triggers queue rather than run concurrent reads.
  Future<void> _chain = Future<void>.value();

  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');

  /// Replace the resolved config + clinical gate (lock thresholds) and
  /// re-evaluate. Called from the settings projection at the app root.
  Future<void> updateConfig({
    required YesterdayReminderConfig config,
    required EntryGateRules gate,
  }) {
    _config = config;
    _gate = gate;
    return reevaluate();
  }

  /// Re-evaluate whether the reminder should be scheduled. Safe to call from any
  /// trigger; calls are serialised.
  Future<void> reevaluate() {
    if (_disposed) return Future<void>.value();
    return _chain = _chain.then((_) => _reevaluate()).catchError((
      Object e,
      StackTrace st,
    ) {
      debugPrint('[YesterdayReminder] reevaluate failed: $e\n$st');
    });
  }

  Future<void> _reevaluate() async {
    if (_disposed) return;
    final local = _now();
    final time = _config.timeMinutes;

    DateTime atTimeOn(DateTime day) =>
        DateTime(day.year, day.month, day.day, time ~/ 60, time % 60);

    // The next occurrence of the Reminder Time, and the calendar day it reviews
    // (the day before that occurrence). Before today's time → today's fire
    // reviews yesterday (complete, decidable now); otherwise tomorrow's fire
    // reviews today (tentative — re-evaluated again before it fires).
    final todayAt = atTimeOn(local);
    final DateTime fire;
    final DateTime reviewDay;
    if (local.isBefore(todayAt)) {
      fire = todayAt;
      reviewDay = _dateOnly(local.subtract(const Duration(days: 1)));
    } else {
      fire = atTimeOn(local.add(const Duration(days: 1)));
      reviewDay = _dateOnly(local);
    }

    final shouldSchedule =
        _config.enabled &&
        !_isLocked(reviewDay, local) &&
        !await _hasDailyStatus(reviewDay);

    if (_disposed) return;

    if (shouldSchedule) {
      final fireUtc = fire.toUtc();
      // Idempotent: an unchanged decision does not re-schedule (E).
      if (_hasScheduled && _scheduledFireUtc == fireUtc) return;
      await _scheduler.schedule(
        id: kYesterdayReminderNotificationId,
        whenUtc: fireUtc,
        title: _kTitle,
        body: _kBody,
        channel: ReminderChannel.dailyReminder,
        payload: kYesterdayReminderPayload,
      );
      _hasScheduled = true;
      _scheduledFireUtc = fireUtc;
    } else if (_hasScheduled) {
      await _scheduler.cancel(kYesterdayReminderNotificationId);
      _hasScheduled = false;
      _scheduledFireUtc = null;
    }
  }

  /// Whether [day] (local) already has a Daily Status: any finalized
  /// nosebleed-related entry, or an open (incomplete) epistaxis draft on that
  /// day — mirrors the home screen's yesterday-banner suppression.
  Future<bool> _hasDailyStatus(DateTime day) async {
    final dayStr = _ymd.format(day);
    final finalized = await _readRows(diaryEntriesViewName);
    if (hasNosebleedRelatedEntryOn(finalized, dayStr)) return true;
    final incomplete = await _readRows(diaryIncompleteViewName);
    return entriesOnLocalDate(
      incomplete,
      dayStr,
      entryType: 'epistaxis_event',
    ).isNotEmpty;
  }

  bool _isLocked(DateTime day, DateTime now) =>
      entryGateForDate(
        eventLocalMidnight: _dateOnly(day),
        now: now,
        config: _gate,
      ) ==
      EntryGate.locked;

  /// One-shot read of [viewName]: drains the snapshot phase into typed rows and
  /// returns once `EndOfReplay` arrives (live deltas are not consulted).
  Future<List<DiaryEntryRow>> _readRows(String viewName) async {
    final out = <DiaryEntryRow>[];
    final done = Completer<void>();
    late final StreamSubscription<Update<Map<String, Object?>>> sub;
    sub = _viewSource
        .watch<Map<String, Object?>>(viewName: viewName, mapper: (r) => r)
        .listen((u) {
          switch (u) {
            case Snapshot<Map<String, Object?>>(:final value):
              if (value != null) out.add(DiaryEntryRow.fromViewRow(value));
            case EndOfReplay<Map<String, Object?>>():
              if (!done.isCompleted) done.complete();
            default:
              break;
          }
        });
    await done.future;
    await sub.cancel();
    return out;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> dispose() async {
    _disposed = true;
  }
}
