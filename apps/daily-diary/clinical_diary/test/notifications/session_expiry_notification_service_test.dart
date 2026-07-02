// Verifies: DIARY-PRD-questionnaire-session-timeout/E+F+J — the Timeout
//   Warning Notification is scheduled at expiry - timeoutWarningMinutes (E/J)
//   and the Session Expiry Notification at the expiry instant (F); both are
//   local (OS-held) notifications with stable per-instance ids.
// Verifies: DIARY-GUI-questionnaire-session-expiry/A+F
import 'package:clinical_diary/notifications/local_notification_scheduler.dart';
import 'package:clinical_diary/notifications/session_expiry_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScheduledCall {
  _ScheduledCall(this.id, this.whenUtc, this.title, this.body, this.channel);
  final int id;
  final DateTime whenUtc;
  final String title;
  final String body;
  final ReminderChannel channel;
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
    scheduled.add(_ScheduledCall(id, whenUtc, title, body, channel));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late _FakeScheduler scheduler;
  late SessionExpiryNotificationService service;

  final now = DateTime(2026, 6, 26, 10);

  setUp(() {
    scheduler = _FakeScheduler();
    service = SessionExpiryNotificationService(
      scheduler: scheduler,
      now: () => now,
    );
  });

  test(
    'schedules the warning at expiry - warningMinutes and the expiry at '
    'lastInteraction + timeout, on the questionnaire-session channel',
    () async {
      await service.scheduleSession(
        instanceId: 'QI-1',
        questionnaireName: 'NOSE HHT',
        sessionTimeoutMinutes: 30,
        warningMinutes: 5,
        lastInteraction: now,
      );

      expect(scheduler.scheduled, hasLength(2));
      final warning = scheduler.scheduled.firstWhere(
        (c) => c.id == SessionExpiryNotificationService.warningIdFor('QI-1'),
      );
      final expiry = scheduler.scheduled.firstWhere(
        (c) => c.id == SessionExpiryNotificationService.expiryIdFor('QI-1'),
      );
      // Warning fires 5 minutes before the 30-minute expiry (A).
      expect(warning.whenUtc, now.add(const Duration(minutes: 25)).toUtc());
      expect(warning.body, contains('about to expire'));
      // Expiry announcement fires at the expiry instant (F).
      expect(expiry.whenUtc, now.add(const Duration(minutes: 30)).toUtc());
      expect(expiry.body, contains('has expired'));
      for (final call in scheduler.scheduled) {
        expect(call.channel, ReminderChannel.questionnaireSession);
        expect(call.title, 'NOSE HHT');
      }
    },
  );

  test(
    'defaults the warning threshold to 5 minutes when unconfigured',
    () async {
      await service.scheduleSession(
        instanceId: 'QI-2',
        questionnaireName: 'HHT-QoL',
        sessionTimeoutMinutes: 20,
        warningMinutes: null,
        lastInteraction: now,
      );

      final warning = scheduler.scheduled.firstWhere(
        (c) => c.id == SessionExpiryNotificationService.warningIdFor('QI-2'),
      );
      expect(warning.whenUtc, now.add(const Duration(minutes: 15)).toUtc());
    },
  );

  test('no timeout configured -> nothing scheduled', () async {
    await service.scheduleSession(
      instanceId: 'QI-3',
      questionnaireName: 'Ad hoc',
      sessionTimeoutMinutes: null,
      lastInteraction: now,
    );

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelled, isEmpty);
  });

  test('a warning instant already in the past is cancelled, not scheduled '
      '(re-anchor of an aging draft close to expiry)', () async {
    // Last interaction 27 minutes ago: warning instant (t+25m) has passed,
    // expiry (t+30m) is 3 minutes out.
    await service.scheduleSession(
      instanceId: 'QI-4',
      questionnaireName: 'NOSE HHT',
      sessionTimeoutMinutes: 30,
      warningMinutes: 5,
      lastInteraction: now.subtract(const Duration(minutes: 27)),
    );

    expect(scheduler.scheduled, hasLength(1));
    expect(
      scheduler.scheduled.single.id,
      SessionExpiryNotificationService.expiryIdFor('QI-4'),
    );
    expect(scheduler.cancelled, [
      SessionExpiryNotificationService.warningIdFor('QI-4'),
    ]);
  });

  test('cancelSession cancels both stable per-instance ids', () async {
    await service.cancelSession('QI-5');

    expect(scheduler.cancelled, [
      SessionExpiryNotificationService.warningIdFor('QI-5'),
      SessionExpiryNotificationService.expiryIdFor('QI-5'),
    ]);
  });

  test(
    'ids are stable per instance, distinct per kind, disjoint from the other '
    'notification id ranges, and within the 32-bit Android id space',
    () {
      final w1 = SessionExpiryNotificationService.warningIdFor('QI-abc');
      final w2 = SessionExpiryNotificationService.warningIdFor('QI-abc');
      final e1 = SessionExpiryNotificationService.expiryIdFor('QI-abc');
      final other = SessionExpiryNotificationService.warningIdFor('QI-xyz');

      expect(w1, w2); // deterministic (FNV-1a, not String.hashCode)
      expect(e1, w1 + 1);
      expect(w1, isNot(other));
      for (final id in [w1, e1, other]) {
        expect(id, greaterThan(0x3FFFFFFF)); // above ongoing-epistaxis range
        expect(id, lessThan(2000000001)); // below the yesterday reminder id
        expect(id, lessThan(0x80000000)); // valid signed 32-bit
      }
    },
  );
}
