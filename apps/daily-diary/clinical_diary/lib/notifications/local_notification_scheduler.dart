// Implements: DIARY-PRD-notification-ongoing-epistaxis/B — delivery seam for the
//   timed reminder Push Notifications. The OS holds the timers (so a reminder
//   fires while the app is backgrounded or closed); this file is the only place
//   that touches `flutter_local_notifications`.
// Implements: DIARY-PRD-notification-yesterday-entry/A — the same seam delivers
//   the daily Yesterday Entry Reminder on a separate, Medium-importance channel,
//   and routes a tapped reminder back to the app.
// Implements: DIARY-BASE-mobile-notifications/A — local (OS-held) delivery of the
//   scheduled reminder notifications.
//
// The abstract [LocalNotificationScheduler] lets the orchestrators and their
// tests stay free of the native plugin: tests inject a fake that records
// schedule/cancel calls, web and the local-stack inject the
// [NoOpLocalNotificationScheduler] (the plugin has no web implementation), and
// devices get [FlutterLocalNotificationScheduler].
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The notification channels this app schedules on. Each maps to a distinct
/// Android channel with its own importance so the OS can categorise them.
enum ReminderChannel {
  /// Ongoing-nosebleed reminders — High importance (urgent, time-sensitive).
  ongoingEpistaxis(
    id: 'ongoing_epistaxis_reminder',
    name: 'Ongoing nosebleed reminders',
    description:
        'Reminders to complete or confirm an ongoing nosebleed record.',
    importance: Importance.high,
    priority: Priority.high,
  ),

  /// Daily Yesterday Entry Reminder — Medium importance.
  dailyReminder(
    id: 'daily_entry_reminder',
    name: 'Daily diary reminders',
    description: 'A daily reminder to record the previous day in your diary.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  const ReminderChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.priority,
  });

  final String id;
  final String name;
  final String description;
  final Importance importance;
  final Priority priority;
}

/// Schedules and cancels OS-level local notifications by integer id. All times
/// are absolute UTC instants; the implementation converts to the OS scheduling
/// representation.
abstract interface class LocalNotificationScheduler {
  /// Schedule a one-shot notification with stable [id] to fire at [whenUtc] on
  /// [channel]. Re-scheduling the same [id] replaces any pending notification.
  Future<void> schedule({
    required int id,
    required DateTime whenUtc,
    required String title,
    required String body,
    ReminderChannel channel,
    String? payload,
  });

  /// Cancel the pending notification with [id] (no-op if none pending).
  Future<void> cancel(int id);

  /// Cancel every pending notification owned by this scheduler.
  Future<void> cancelAll();
}

/// No-op scheduler for web and the local-stack, where
/// `flutter_local_notifications` has no platform implementation. Keeps the
/// orchestrator wiring identical across platforms.
class NoOpLocalNotificationScheduler implements LocalNotificationScheduler {
  const NoOpLocalNotificationScheduler();

  @override
  Future<void> schedule({
    required int id,
    required DateTime whenUtc,
    required String title,
    required String body,
    ReminderChannel channel = ReminderChannel.ongoingEpistaxis,
    String? payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Production scheduler backed by `flutter_local_notifications.zonedSchedule`.
///
/// [initialize] must be awaited once before scheduling. Android uses an inexact
/// schedule mode ([AndroidScheduleMode.inexactAllowWhileIdle]) so the feature
/// needs no `SCHEDULE_EXACT_ALARM` permission on Android 14+ — a few minutes of
/// OS batching slack is acceptable for these reminders.
class FlutterLocalNotificationScheduler implements LocalNotificationScheduler {
  FlutterLocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  /// Initialize the plugin and the Android channels. Idempotent. [onTap] is
  /// invoked with the tapped notification's payload (foreground tap or launch
  /// via tap), so the app can route to the relevant surface.
  Future<void> initialize({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permission requests are owned by the FCM flow (MobileNotificationService);
    // do not request again here.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: onTap == null
          ? null
          : (response) => onTap(response.payload),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in ReminderChannel.values) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: channel.importance,
        ),
      );
    }
    _initialized = true;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime whenUtc,
    required String title,
    required String body,
    ReminderChannel channel = ReminderChannel.ongoingEpistaxis,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    // The fire time is an absolute instant; scheduling it as a UTC TZDateTime
    // makes the OS fire at that instant regardless of whether `tz.local` was
    // configured (TimezoneConverter only loads the IANA DB).
    final when = tz.TZDateTime.from(whenUtc.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.priority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
