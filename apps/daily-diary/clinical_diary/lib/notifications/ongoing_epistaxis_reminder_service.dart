// Implements: DIARY-PRD-notification-ongoing-epistaxis/A+B+C+D+E+F — observes the
//   device-local `diary_incomplete` projection and drives the OS local-
//   notification scheduler so each open epistaxis (nosebleed) draft gets the
//   resolved Reminder Schedule of reminders:
//     A — the row's stamped `updatedAt` IS the most-recent-interaction time.
//     B — one notification scheduled per interval (via [fireTimesFor]).
//     C — no notification beyond the final interval (the schedule is finite).
//     D — a new `checkpoint`/`edit` re-stamps `updatedAt`, arriving as a Delta;
//         the service cancels the record's pending reminders and reschedules
//         from the new anchor — restarting the schedule from the first interval.
//     E — `finalized` (completion) removes the row (Tombstone) → reminders are
//         cancelled.
//     F — `tombstone` (deletion) removes the row (Tombstone) → reminders are
//         cancelled.
//
// The empty default schedule (G) yields no fire times, so the service simply
// never schedules anything. Schedule resolution (G/H/I/J) is supplied by the
// caller via [updateSchedule] from `resolveEpistaxisReminderSchedule`.
import 'dart:async';

import 'package:clinical_diary/notifications/epistaxis_reminder_schedule.dart';
import 'package:clinical_diary/notifications/local_notification_scheduler.dart';
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:event_sourcing/event_sourcing.dart'
    show Update, Snapshot, Delta, Tombstone, EndOfReplay;
import 'package:flutter/foundation.dart';
import 'package:reaction/reaction.dart';

/// Default notification copy. The Callisto overlay configures only the schedule
/// timing, not the text, so a clear platform default is used.
const String _kReminderTitle = 'Ongoing nosebleed';
const String _kReminderBody =
    'Your nosebleed record is still open. Tap to confirm it is ongoing or add '
    'the end time.';

/// Max reminders scheduled per record. Bounds the per-record notification-id
/// range so removed records can be cancelled by id without tracking each id, and
/// guards against an absurd schedule length. Real schedules are a handful.
const int _kMaxIntervalsPerRecord = 16;

/// Soft ceiling on simultaneously-scheduled OS notifications, kept under the
/// iOS 64-pending-notification limit with headroom. With a 4-interval schedule
/// this allows ~15 concurrent open records; excess (oldest-interaction) records
/// are not scheduled and the drop is logged — never silently truncated.
const int _kMaxPendingNotifications = 60;

/// Watches the `diary_incomplete` view and schedules/cancels the Ongoing
/// Epistaxis Reminder notifications. Construct, set the resolved schedule via
/// [updateSchedule], then call [start]; [dispose] cancels the view subscription
/// (pending OS notifications persist by design).
class OngoingEpistaxisReminderService {
  OngoingEpistaxisReminderService({
    required ViewSource viewSource,
    required LocalNotificationScheduler scheduler,
    DateTime Function() now = DateTime.now,
  }) : _viewSource = viewSource,
       _scheduler = scheduler,
       _now = now;

  final ViewSource _viewSource;
  final LocalNotificationScheduler _scheduler;
  final DateTime Function() _now;

  /// aggregateId → most-recent-interaction instant (UTC), for every currently
  /// open epistaxis draft.
  final Map<String, DateTime> _anchors = <String, DateTime>{};

  /// aggregateIds whose reminders are currently scheduled with the OS, so a
  /// record that drops out (removed or capped) can be cancelled by id range.
  final Set<String> _scheduled = <String>{};

  List<Duration> _schedule = const <Duration>[];

  StreamSubscription<Update<Map<String, Object?>>>? _sub;
  bool _disposed = false;

  // Serial reschedule guard: view updates mutate [_anchors] synchronously and
  // request a reschedule; the async reschedule runs one-at-a-time and coalesces
  // (a request while one is running marks it dirty rather than queueing many).
  Future<void> _chain = Future<void>.value();
  bool _rescheduleQueued = false;

  /// Replace the effective Reminder Schedule (resolved sponsor-over-personal-
  /// over-empty) and reschedule all tracked records.
  void updateSchedule(List<Duration> schedule) {
    if (_listEquals(_schedule, schedule)) return;
    _schedule = List<Duration>.unmodifiable(schedule);
    _requestReschedule();
  }

  /// Begin observing the `diary_incomplete` projection. Safe to call once.
  Future<void> start() async {
    if (_disposed || _sub != null) return;
    _sub = _viewSource
        .watch<Map<String, Object?>>(
          viewName: diaryIncompleteViewName,
          mapper: (r) => r,
        )
        .listen(
          _onUpdate,
          onError: (Object e, StackTrace st) {
            debugPrint('[EpistaxisReminder] view error: $e\n$st');
          },
        );
  }

  void _onUpdate(Update<Map<String, Object?>> update) {
    switch (update) {
      case Snapshot<Map<String, Object?>>(:final value):
        if (value != null) _trackRow(value);
      case Delta<Map<String, Object?>>(:final value):
        _trackRow(value);
        _requestReschedule();
      case Tombstone<Map<String, Object?>>(:final aggregateId):
        _anchors.remove(aggregateId);
        _requestReschedule();
      case EndOfReplay<Map<String, Object?>>():
        // Initial replay complete — schedule everything observed so far.
        _requestReschedule();
    }
  }

  /// Records (or refreshes) the interaction anchor for an open epistaxis draft.
  /// Non-epistaxis rows and rows without a parseable `updatedAt` are ignored.
  void _trackRow(Map<String, Object?> row) {
    if (row['entryType'] != 'epistaxis_event') return;
    final id = row['aggregateId'];
    final updatedAt = row['updatedAt'];
    if (id is! String || updatedAt is! String) return;
    final anchor = DateTime.tryParse(updatedAt)?.toUtc();
    if (anchor == null) return;
    _anchors[id] = anchor;
  }

  void _requestReschedule() {
    if (_disposed) return;
    if (_rescheduleQueued) return;
    _rescheduleQueued = true;
    _chain = _chain
        .then((_) async {
          _rescheduleQueued = false;
          if (_disposed) return;
          await _reschedule();
        })
        .catchError((Object e, StackTrace st) {
          _rescheduleQueued = false;
          debugPrint('[EpistaxisReminder] reschedule failed: $e\n$st');
        });
  }

  /// Cancels and re-creates OS notifications to match the current [_anchors] and
  /// [_schedule]. Idempotent: deterministic per-(record,index) ids mean a record
  /// whose anchor is unchanged resolves to the same fire times.
  Future<void> _reschedule() async {
    final intervals = _schedule.length > _kMaxIntervalsPerRecord
        ? _schedule.sublist(0, _kMaxIntervalsPerRecord)
        : _schedule;
    if (_schedule.length > _kMaxIntervalsPerRecord) {
      debugPrint(
        '[EpistaxisReminder] schedule has ${_schedule.length} intervals; '
        'scheduling only the first $_kMaxIntervalsPerRecord.',
      );
    }

    // Target records: when there is no schedule, none. Otherwise the most-
    // recently-interacted records up to the pending-notification budget.
    var target = <String>[];
    if (intervals.isNotEmpty) {
      final maxRecords = (_kMaxPendingNotifications ~/ intervals.length).clamp(
        0,
        _anchors.length,
      );
      final byRecency = _anchors.keys.toList()
        ..sort((a, b) => _anchors[b]!.compareTo(_anchors[a]!));
      if (byRecency.length > maxRecords) {
        debugPrint(
          '[EpistaxisReminder] ${byRecency.length} open records exceed the '
          'pending-notification budget; scheduling the $maxRecords most recent.',
        );
      }
      target = byRecency.take(maxRecords).toList();
    }
    final targetSet = target.toSet();

    // Cancel records that should no longer be scheduled (removed/completed/
    // deleted, capped out, or the schedule went empty).
    for (final id in _scheduled.toList()) {
      if (!targetSet.contains(id)) {
        await _clearRecord(id);
        _scheduled.remove(id);
      }
    }

    // (Re)schedule each target record from its anchor, skipping past-due times.
    final nowUtc = _now().toUtc();
    for (final id in target) {
      await _clearRecord(id);
      final fireTimes = fireTimesFor(_anchors[id]!, intervals);
      for (var i = 0; i < fireTimes.length; i++) {
        final when = fireTimes[i];
        if (!when.isAfter(nowUtc)) continue;
        await _scheduler.schedule(
          id: _notificationId(id, i),
          whenUtc: when,
          title: _kReminderTitle,
          body: _kReminderBody,
          payload: id,
        );
      }
      _scheduled.add(id);
    }
  }

  Future<void> _clearRecord(String aggregateId) async {
    for (var i = 0; i < _kMaxIntervalsPerRecord; i++) {
      await _scheduler.cancel(_notificationId(aggregateId, i));
    }
  }

  /// Stable, collision-resistant notification id for a (record, interval index).
  /// The base is a 26-bit FNV-1a hash of the aggregateId so
  /// `base * _kMaxIntervalsPerRecord + index` stays a positive 32-bit int
  /// (Android notification ids are 32-bit).
  int _notificationId(String aggregateId, int index) {
    var hash = 0x811c9dc5;
    for (final unit in aggregateId.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
    }
    final base = hash & 0x3FFFFFF; // 26 bits
    return base * _kMaxIntervalsPerRecord + index;
  }

  /// Cancel the view subscription. Pending OS notifications are intentionally
  /// left in place (they must survive app teardown to fire while closed).
  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
  }

  static bool _listEquals(List<Duration> a, List<Duration> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
