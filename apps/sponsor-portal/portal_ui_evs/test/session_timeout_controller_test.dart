// Verifies: DIARY-PRD-session-management/I+K
// Verifies: DIARY-GUI-portal-session-expiry/A+B
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/session_timeout_controller.dart';

void main() {
  SessionTimeoutController make({
    required List<String> log,
    Duration idle = const Duration(minutes: 10),
    Duration warning = const Duration(seconds: 60),
  }) => SessionTimeoutController(
    idleTimeout: idle,
    warningLead: warning,
    onKeepAlive: () async => log.add('keepalive'),
    onExpired: () async => log.add('expired'),
  );

  test('shows warning at idle-warning, expires after idle+grace', () {
    fakeAsync((async) {
      final log = <String>[];
      final c = make(log: log)..start();
      expect(c.isWarning, isFalse);

      async.elapse(const Duration(minutes: 9)); // idle(10m) - warning(60s)
      expect(c.isWarning, isTrue);
      expect(c.secondsLeft, 60);

      async.elapse(const Duration(seconds: 30));
      expect(c.secondsLeft, 30);

      async.elapse(const Duration(seconds: 32)); // past idle + grace
      expect(log, contains('expired'));
      expect(c.isWarning, isFalse);
      c.dispose();
    });
  });

  test('passive activity does NOT reset once warning is shown', () {
    fakeAsync((async) {
      final log = <String>[];
      final c = make(log: log)..start();
      async.elapse(const Duration(minutes: 9));
      expect(c.isWarning, isTrue);

      c.notifyActivity(now: () => DateTime(2026)); // ignored while warning
      expect(c.isWarning, isTrue, reason: 'passive activity is a no-op');
      c.dispose();
    });
  });

  test('staySignedIn extends and fires keep-alive', () {
    fakeAsync((async) {
      final log = <String>[];
      final c = make(log: log)..start();
      async.elapse(const Duration(minutes: 9));
      expect(c.isWarning, isTrue);

      c.staySignedIn(now: () => DateTime(2026));
      async.flushMicrotasks();
      expect(c.isWarning, isFalse);
      expect(log, contains('keepalive'));

      // The window is fresh again: no warning until another 9 minutes.
      async.elapse(const Duration(minutes: 8));
      expect(c.isWarning, isFalse);
      c.dispose();
    });
  });

  test('activity keep-alive is throttled to once per minute', () {
    fakeAsync((async) {
      final log = <String>[];
      final c = make(log: log)..start();
      var t = DateTime(2026, 1, 1, 0, 0, 0);
      c.notifyActivity(now: () => t);
      c.notifyActivity(now: () => t.add(const Duration(seconds: 10)));
      async.flushMicrotasks();
      expect(
        log.where((e) => e == 'keepalive').length,
        1,
        reason: 'second activity within the throttle window is suppressed',
      );
      c.dispose();
    });
  });

  test('warns at halfway when idle window is shorter than the lead', () {
    fakeAsync((async) {
      final log = <String>[];
      final c = make(
        log: log,
        idle: const Duration(seconds: 60),
        warning: const Duration(seconds: 60),
      )..start();
      async.elapse(const Duration(seconds: 30)); // halfway
      expect(c.isWarning, isTrue);
      c.dispose();
    });
  });

  test('cancel clears the warning and stops timers', () {
    fakeAsync((async) {
      final log = <String>[];
      var notified = 0;
      final c = SessionTimeoutController(
        idleTimeout: const Duration(minutes: 10),
        warningLead: const Duration(seconds: 60),
        onKeepAlive: () async => log.add('keepalive'),
        onExpired: () async => log.add('expired'),
      )..start();
      c.addListener(() => notified++);
      async.elapse(const Duration(minutes: 9));
      expect(c.isWarning, isTrue);
      c.cancel();
      expect(c.isWarning, isFalse);
      expect(notified, greaterThan(0));
      // No expiry fires after cancel.
      async.elapse(const Duration(minutes: 5));
      expect(log, isNot(contains('expired')));
      c.dispose();
    });
  });

  test('a throttled-out activity event does not postpone the warning', () {
    // The timer reset is coupled to the throttled keep-alive: an activity event
    // inside the throttle window neither touches the server nor reschedules the
    // client timer, so the warning still fires on the original schedule (and the
    // client never believes it has more time than the server's last-seen grants).
    fakeAsync((async) {
      final log = <String>[];
      var clock = DateTime(2026, 1, 1, 12);
      final c = SessionTimeoutController(
        idleTimeout: const Duration(minutes: 10),
        warningLead: const Duration(seconds: 60),
        onKeepAlive: () async => log.add('keepalive'),
        onExpired: () async => log.add('expired'),
      )..start();

      // Anchor a keep-alive + reschedule at t=0.
      c.notifyActivity(now: () => clock);
      expect(log.where((e) => e == 'keepalive').length, 1);

      // 30 s later: a second activity, inside the 1-min throttle window.
      clock = clock.add(const Duration(seconds: 30));
      async.elapse(const Duration(seconds: 30));
      c.notifyActivity(now: () => clock);
      expect(
        log.where((e) => e == 'keepalive').length,
        1,
        reason: 'throttled out — no extra keep-alive',
      );

      // The warning must still fire 9 min after the anchor (not 9 min after the
      // 30 s activity): the throttled-out event did NOT reschedule the timer.
      async.elapse(const Duration(minutes: 8, seconds: 30));
      expect(c.isWarning, isTrue);
      c.dispose();
    });
  });
}
