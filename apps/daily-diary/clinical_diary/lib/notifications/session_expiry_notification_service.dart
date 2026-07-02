// Implements: DIARY-PRD-questionnaire-session-timeout/E+F+J — delivers the
//   Timeout Warning Notification before Session Expiry (E, at the configurable
//   timeoutWarningMinutes threshold, J) and the Session Expiry Notification at
//   the expiry instant (F). Both are LOCAL (OS-held) notifications: the OS
//   holds the timers so they fire while the app is backgrounded or closed —
//   exactly the window in which a session silently ages out. No server/FCM
//   involvement.
// Implements: DIARY-GUI-questionnaire-session-expiry/A+F — the two push
//   notification surfaces of the Session Expiry feature.
import 'package:clinical_diary/notifications/local_notification_scheduler.dart';

/// Schedules / cancels the pair of questionnaire-session notifications for an
/// instance: a **Timeout Warning** at `expiry - warningMinutes` and a
/// **Session Expiry** announcement at the expiry instant.
///
/// The session is anchored at the participant's most recent interaction (the
/// latest `checkpoint`'s timestamp); every re-anchor re-schedules the same
/// stable per-instance ids, so at most one warning + one expiry notification
/// is ever pending per instance. Cancel on submission / normal session end.
class SessionExpiryNotificationService {
  SessionExpiryNotificationService({
    required LocalNotificationScheduler scheduler,
    DateTime Function() now = DateTime.now,
  }) : _scheduler = scheduler,
       _now = now;

  final LocalNotificationScheduler _scheduler;
  final DateTime Function() _now;

  /// Payload tags so a tapped notification can be routed (seam for future
  /// deep-linking; today a tap simply opens the app / home screen).
  static const String warningPayload = 'questionnaire_session_warning';
  static const String expiryPayload = 'questionnaire_session_expiry';

  /// Minutes before expiry at which the warning fires when the definition
  /// does not configure `timeoutWarningMinutes`.
  static const int defaultWarningMinutes = 5;

  /// Base of the id range for these notifications: disjoint from the Ongoing
  /// Epistaxis range (max 0x3FFFFFFF) and the Yesterday reminder (2000000001 =
  /// 0x77359401). 27 bits of instance hash << 1 keeps the whole range within
  /// 0x48000000..0x4FFFFFFF (< 2^31, valid Android int id).
  static const int _idBase = 0x48000000;

  /// Stable id of the Timeout Warning Notification for [instanceId].
  static int warningIdFor(String instanceId) =>
      _idBase | ((_fnv1a(instanceId) & 0x03FFFFFF) << 1);

  /// Stable id of the Session Expiry Notification for [instanceId].
  static int expiryIdFor(String instanceId) => warningIdFor(instanceId) | 1;

  /// FNV-1a 32-bit over the instance id: deterministic across launches and
  /// platforms (unlike `String.hashCode`), so a notification scheduled in one
  /// app session can be cancelled in a later one.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// (Re-)schedules the warning + expiry notifications for a session on
  /// [instanceId] anchored at [lastInteraction] (the latest checkpoint's
  /// timestamp — the session start for a fresh flow). No-op when
  /// [sessionTimeoutMinutes] is null (no timeout configured → sessions never
  /// expire → nothing to announce).
  ///
  /// A fire time already in the past is not scheduled; its pending
  /// notification (from an earlier anchor) is cancelled instead so a stale
  /// warning cannot fire after the session was re-anchored.
  // Implements: DIARY-PRD-questionnaire-session-timeout/A+E+F+J
  // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
  Future<void> scheduleSession({
    required String instanceId,
    required String questionnaireName,
    required int? sessionTimeoutMinutes,
    required DateTime lastInteraction,
    int? warningMinutes,
  }) async {
    if (sessionTimeoutMinutes == null) return;
    final now = _now();
    final expiryAt = lastInteraction.add(
      Duration(minutes: sessionTimeoutMinutes),
    );
    final warnAt = expiryAt.subtract(
      Duration(minutes: warningMinutes ?? defaultWarningMinutes),
    );

    if (warnAt.isAfter(now)) {
      await _scheduler.schedule(
        id: warningIdFor(instanceId),
        whenUtc: warnAt.toUtc(),
        title: questionnaireName,
        body:
            'Your questionnaire session is about to expire. '
            'Return now to keep your answers.',
        channel: ReminderChannel.questionnaireSession,
        payload: warningPayload,
      );
    } else {
      await _scheduler.cancel(warningIdFor(instanceId));
    }

    if (expiryAt.isAfter(now)) {
      await _scheduler.schedule(
        id: expiryIdFor(instanceId),
        whenUtc: expiryAt.toUtc(),
        title: questionnaireName,
        body:
            'Your questionnaire session has expired and your answers '
            'were not saved.',
        channel: ReminderChannel.questionnaireSession,
        payload: expiryPayload,
      );
    } else {
      await _scheduler.cancel(expiryIdFor(instanceId));
    }
  }

  /// Cancels both pending notifications for [instanceId]. Called when the
  /// session ends: successful submission, or the (expired) draft is discarded
  /// after the Session Expiry Dialog.
  // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
  Future<void> cancelSession(String instanceId) async {
    await _scheduler.cancel(warningIdFor(instanceId));
    await _scheduler.cancel(expiryIdFor(instanceId));
  }
}
