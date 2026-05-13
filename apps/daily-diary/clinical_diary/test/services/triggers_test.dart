// Verifies: REQ-d00164-A+B+C+D+E.

import 'dart:async';

import 'package:clinical_diary/services/triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers / test doubles
// ---------------------------------------------------------------------------

/// A controllable fake timer that records how many times its tick callback
/// has been invoked.  Tests advance it manually by calling [tick].
class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final VoidCallback _callback;
  int _tickCount = 0;
  bool _cancelled = false;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => _tickCount;

  @override
  void cancel() => _cancelled = true;

  /// Advance by [count] ticks, invoking the callback each time.
  void advance([int count = 1]) {
    for (var i = 0; i < count; i++) {
      if (!_cancelled) {
        _tickCount++;
        _callback();
      }
    }
  }
}

/// A factory that captures the most-recently created [_FakeTimer] so tests
/// can drive it.
class _FakeTimerFactory {
  _FakeTimer? lastTimer;
  final List<Duration> intervals = [];

  Timer call(Duration interval, VoidCallback onTick) {
    intervals.add(interval);
    lastTimer = _FakeTimer(onTick);
    return lastTimer!;
  }
}

/// Creates a [LifecycleObserverFactory] that stores the observer in
/// [capturedObserver] and optionally calls the factory first.
class _LifecycleCapture {
  WidgetsBindingObserver? capturedObserver;

  WidgetsBindingObserver call(
    VoidCallback onResumed,
    ValueChanged<bool> onForegroundChange,
  ) {
    // Build the real observer so we can call didChangeAppLifecycleState.
    capturedObserver = _TestLifecycleObserver(
      onResumed: onResumed,
      onForegroundChange: onForegroundChange,
    );
    return capturedObserver!;
  }
}

/// Minimal [WidgetsBindingObserver] used by [_LifecycleCapture].
class _TestLifecycleObserver extends WidgetsBindingObserver {
  _TestLifecycleObserver({
    required this.onResumed,
    required this.onForegroundChange,
  });

  final VoidCallback onResumed;
  final ValueChanged<bool> onForegroundChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onForegroundChange(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// Simulates an [AppLifecycleState] change via the captured observer.
void _emitLifecycle(_LifecycleCapture capture, AppLifecycleState state) {
  capture.capturedObserver!.didChangeAppLifecycleState(state);
}

/// Minimal [RemoteMessage] with no content (triggers don't inspect payload).
RemoteMessage _fakeMessage() => const RemoteMessage();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int triggerCount;
  late Future<void> Function() onTrigger;

  setUp(() {
    triggerCount = 0;
    onTrigger = () async => triggerCount++;
  });

  // ---- A. Lifecycle resumed ------------------------------------------------

  group('A — Lifecycle resumed', () {
    test(
      // Verifies: REQ-d00164-A
      'AppLifecycleState.resumed calls onTrigger once',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        _emitLifecycle(lifecycleCapture, AppLifecycleState.resumed);

        // Allow the async trigger to complete.
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 1);

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- B. Periodic timer ---------------------------------------------------

  group('B — Periodic timer', () {
    test(
      // Verifies: REQ-d00164-B
      'Three timer ticks while in foreground → 3 onTrigger calls',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        // App starts in foreground (_inForeground defaults to true).
        timerFactory.lastTimer!.advance(3);
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 3);

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- C. Lifecycle gate on timer ------------------------------------------

  group('B+A — Timer gated by foreground state', () {
    test(
      // Verifies: REQ-d00164-A+B
      'Paused stops timer firing; resumed restarts it',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        // Foreground → 1 tick fires.
        timerFactory.lastTimer!.advance(1);
        await Future<void>.delayed(Duration.zero);
        expect(triggerCount, 1);

        // Pause the app — timer ticks must not fire.
        _emitLifecycle(lifecycleCapture, AppLifecycleState.paused);
        timerFactory.lastTimer!.advance(2);
        await Future<void>.delayed(Duration.zero);
        expect(triggerCount, 1, reason: 'timer should not fire while paused');

        // Resume — lifecycle fires onTrigger once, then next tick fires again.
        _emitLifecycle(lifecycleCapture, AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(triggerCount, 2, reason: 'resumed lifecycle should fire once');

        timerFactory.lastTimer!.advance(1);
        await Future<void>.delayed(Duration.zero);
        expect(triggerCount, 3, reason: 'timer should fire again after resume');

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- D. Connectivity restored --------------------------------------------

  group('C — Connectivity transitions', () {
    late _LifecycleCapture lifecycleCapture;
    late _FakeTimerFactory timerFactory;
    late StreamController<List<ConnectivityResult>> connectivityController;
    late StreamController<RemoteMessage> fcmMessageController;
    late StreamController<RemoteMessage> fcmOpenedController;
    late TriggerHandles handles;

    setUp(() async {
      lifecycleCapture = _LifecycleCapture();
      timerFactory = _FakeTimerFactory();
      connectivityController = StreamController<List<ConnectivityResult>>();
      fcmMessageController = StreamController<RemoteMessage>();
      fcmOpenedController = StreamController<RemoteMessage>();

      handles = await installTriggers(
        onTrigger: onTrigger,
        lifecycleObserverFactory: lifecycleCapture.call,
        periodicTimerFactory: timerFactory.call,
        connectivityStreamFactory: () => connectivityController.stream,
        fcmOnMessageStreamFactory: () => fcmMessageController.stream,
        fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
      );
    });

    tearDown(() async {
      await handles.dispose();
      await connectivityController.close();
      await fcmMessageController.close();
      await fcmOpenedController.close();
    });

    test(
      // Verifies: REQ-d00164-C
      'offline → online fires onTrigger once',
      () async {
        // First event: offline (sets baseline as none).
        connectivityController.add([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);
        expect(triggerCount, 0);

        // Transition to online.
        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);
        expect(triggerCount, 1);
      },
    );

    test(
      // Verifies: REQ-d00164-C
      'online → offline fires 0 onTrigger calls',
      () async {
        // First event: online (sets baseline as connected).
        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);
        // offline→online transition does not apply here (baseline was null).
        // Null baseline counts as "none" so wifi after null triggers once.
        final afterFirstEvent = triggerCount;

        // Now go offline.
        connectivityController.add([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);
        expect(
          triggerCount,
          afterFirstEvent,
          reason: 'going offline must not trigger sync',
        );
      },
    );

    test(
      // Verifies: REQ-d00164-C
      'online → different-network-type does NOT fire onTrigger',
      () async {
        // Establish online baseline.
        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);
        final afterWifi = triggerCount;

        // Switch to mobile (still connected — no offline→online transition).
        connectivityController.add([ConnectivityResult.mobile]);
        await Future<void>.delayed(Duration.zero);
        expect(
          triggerCount,
          afterWifi,
          reason: 'switching between network types must not fire',
        );
      },
    );
  });

  // ---- E. FCM onMessage ----------------------------------------------------

  group('D — FCM onMessage', () {
    test(
      // Verifies: REQ-d00164-D
      'FCM onMessage event fires onTrigger once',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        fcmMessageController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 1);

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- F. FCM onMessageOpenedApp -------------------------------------------

  group('E — FCM onMessageOpenedApp', () {
    test(
      // Verifies: REQ-d00164-E
      'FCM onMessageOpenedApp event fires onTrigger once',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        fcmOpenedController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 1);

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- F. onTrigger error recovery -----------------------------------------

  group('onTrigger error recovery', () {
    test(
      // Verifies: REQ-d00164-A+B+C+D+E — a single onTrigger() failure must
      // not poison the serial chain. Subsequent trigger sources must still
      // fire onTrigger() on the next event.
      'a thrown onTrigger does not disable subsequent triggers',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        var calls = 0;
        Future<void> failingThenPassing() async {
          calls++;
          if (calls == 1) {
            throw StateError('boom');
          }
        }

        final handles = await installTriggers(
          onTrigger: failingThenPassing,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        // First trigger throws.
        _emitLifecycle(lifecycleCapture, AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);

        // Subsequent triggers must still run.
        timerFactory.lastTimer!.advance();
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2, reason: 'periodic timer must still fire after error');

        // Connectivity transition off→on should also still fire.
        connectivityController.add([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);
        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);
        expect(calls, 3, reason: 'connectivity must still fire after error');

        // FCM streams should still fire.
        fcmMessageController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);
        expect(calls, 4, reason: 'FCM onMessage must still fire after error');

        fcmOpenedController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);
        expect(calls, 5, reason: 'FCM onOpened must still fire after error');

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- G. dispose cancels everything ---------------------------------------

  group('dispose', () {
    test(
      // Verifies: REQ-d00164-A+B+C+D+E
      'dispose cancels all triggers — nothing fires after dispose()',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        await handles.dispose();

        // After dispose, none of the following should increment triggerCount.

        // Lifecycle.
        _emitLifecycle(lifecycleCapture, AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);

        // Timer.
        timerFactory.lastTimer!.advance(5);
        await Future<void>.delayed(Duration.zero);

        // Connectivity.
        connectivityController
          ..add([ConnectivityResult.none])
          ..add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);

        // FCM messages.
        fcmMessageController.add(_fakeMessage());
        fcmOpenedController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 0, reason: 'no trigger should fire after dispose');

        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });

  // ---- Dynamic periodic interval (CUR-1311) -------------------------------

  group('Dynamic periodic interval', () {
    test(
      // Verifies: REQ-d00164-B (refined — interval is dynamic when FCM
      // permission is denied).
      'interval change after onTrigger cancels timer and reinstalls at new cadence',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        // Starts denied = false (long cadence), flips to true mid-test to
        // simulate the bootstrap probe noticing a permission revocation
        // during fullSync.
        var denied = false;

        final handles = await installTriggers(
          onTrigger: () async {
            triggerCount++;
            denied = true;
          },
          periodicInterval: () =>
              denied ? const Duration(minutes: 2) : const Duration(minutes: 15),
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        expect(timerFactory.intervals, [const Duration(minutes: 15)]);
        final initialTimer = timerFactory.lastTimer!;

        // Fire a trigger via FCM onMessage — the onTrigger sets denied=true,
        // and after the chain settles installTriggers should rotate the timer.
        fcmMessageController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 1);
        expect(
          initialTimer.isActive,
          isFalse,
          reason: 'old timer should be cancelled when interval changes',
        );
        expect(
          timerFactory.intervals,
          [const Duration(minutes: 15), const Duration(minutes: 2)],
          reason: 'a new timer should be created at the shortened cadence',
        );
        expect(timerFactory.lastTimer, isNot(same(initialTimer)));

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );

    test(
      // Verifies: REQ-d00164-B — same interval across consecutive triggers
      // does not churn the timer (regression guard against per-tick reset).
      'unchanged interval does not recreate the timer',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        final handles = await installTriggers(
          onTrigger: onTrigger,
          periodicInterval: () => const Duration(minutes: 15),
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        final initialTimer = timerFactory.lastTimer!;

        fcmMessageController
          ..add(_fakeMessage())
          ..add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 2);
        expect(
          timerFactory.intervals.length,
          1,
          reason: 'no rotation expected when interval value is unchanged',
        );
        expect(identical(timerFactory.lastTimer, initialTimer), isTrue);

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );

    test(
      // Verifies: REQ-d00164-B — re-granted permission swings the cadence
      // back to the long interval. Symmetric counterpart to the denial test
      // above; without this, a future refactor could leave the system stuck
      // on 2 min after the user re-enables notifications in Settings.
      'permission re-granted after denial returns timer to long cadence',
      () async {
        final lifecycleCapture = _LifecycleCapture();
        final timerFactory = _FakeTimerFactory();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        final fcmMessageController = StreamController<RemoteMessage>();
        final fcmOpenedController = StreamController<RemoteMessage>();

        // Sequence the probe simulation: denied → denied → granted.
        // The first fcm trigger flips to denied (short); the second flips
        // back to granted (long). Asserting both transitions in one test
        // documents the full state machine in one place.
        var denied = true;

        final handles = await installTriggers(
          onTrigger: () async {
            triggerCount++;
            // After the first trigger, simulate the user opening Settings
            // and re-enabling notifications.
            if (triggerCount == 1) denied = false;
          },
          periodicInterval: () =>
              denied ? const Duration(minutes: 2) : const Duration(minutes: 15),
          lifecycleObserverFactory: lifecycleCapture.call,
          periodicTimerFactory: timerFactory.call,
          connectivityStreamFactory: () => connectivityController.stream,
          fcmOnMessageStreamFactory: () => fcmMessageController.stream,
          fcmOnOpenedStreamFactory: () => fcmOpenedController.stream,
        );

        // Initial creation is on the short cadence (denied=true at install).
        expect(timerFactory.intervals, [const Duration(minutes: 2)]);
        final shortTimer = timerFactory.lastTimer!;

        // Trigger once: onTrigger flips denied=false; rotation should swap
        // the timer to the long cadence after the chain settles.
        fcmMessageController.add(_fakeMessage());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(triggerCount, 1);
        expect(
          shortTimer.isActive,
          isFalse,
          reason: 'short-cadence timer should be cancelled',
        );
        expect(timerFactory.intervals, [
          const Duration(minutes: 2),
          const Duration(minutes: 15),
        ], reason: 'rotated to long cadence on re-grant');
        expect(timerFactory.lastTimer, isNot(same(shortTimer)));

        await handles.dispose();
        await connectivityController.close();
        await fcmMessageController.close();
        await fcmOpenedController.close();
      },
    );
  });
}
